"""Macroinvertebrate domain: metric derivation and pipeline orchestration.

Implements the ecologist-signed formulas for MCI, QMCI, EPT metrics.
EPT membership is derived from TaxonGroup labels, NOT hard-coded row numbers.
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd

from mgen.domain.macro_ingest import IngestError, ingest_raw_data
from mgen.shared.domain_types import SITES_WITHOUT_REPLICATES
from mgen.shared.errors import DomainResult, ValidationError
from mgen.shared.schemas import MACRO1_COLUMNS

__all__ = ["derive_metrics", "process_macro_domain"]

# EPT taxonomic groups — the source spreadsheet uses common names (not
# scientific orders like Ephemeroptera/Plecoptera/Trichoptera).
_EPT_GROUPS = frozenset({"Mayflies", "Stoneflies", "Caddisflies"})

# Hydroptilidae genera excluded from Trichoptera counts (NZ freshwater)
_HYDROPTILIDAE_GENERA = frozenset({"Oxyethira", "Paroxyethira"})

# ASPM-MCI normalisation ceilings (Stark & Maxted 2007)
_ASPM_MCI_MAX = 200
_ASPM_EPT_RICHNESS_MAX = 29
_ASPM_EPT_ABUNDANCE_MAX = 100


def derive_metrics(
    taxa_counts: pd.DataFrame,
    mci_scores: pd.DataFrame,
    *,
    sample_col: int,
) -> dict[str, float | int]:
    """Derive all macroinvertebrate metrics for a single sample.

    Computes both QMCI and QMCI-sb unconditionally. The caller (orchestrator)
    is responsible for selecting the appropriate variant based on site metadata
    (e.g. SITES_WITHOUT_REPLICATES use QMCI-sb).

    Args:
        taxa_counts: DataFrame with TaxonGroup, Taxon, and integer sample columns.
        mci_scores: DataFrame with Taxon, MCI, MCI_sb tolerance scores.
        sample_col: Column index (int) identifying the sample to compute.

    Returns:
        Dictionary of metric_name → value.
    """
    merged = taxa_counts[["TaxonGroup", "Taxon", sample_col]].merge(
        mci_scores, on="Taxon", how="left"
    )
    counts = merged[sample_col].fillna(0).astype(float)
    present = counts > 0

    # Basic counts
    num_taxa = int(present.sum())
    num_individuals = int(counts.sum())

    # MCI = (sum of MCI scores for taxa present / num taxa present) * 20
    mci_vals = merged.loc[present, "MCI"].dropna()
    mci = (mci_vals.sum() / len(mci_vals) * 20) if len(mci_vals) > 0 else np.nan

    # MCI-sb (soft-bottom variant)
    mci_sb_vals = merged.loc[present, "MCI_sb"].dropna()
    mci_sb = (
        (mci_sb_vals.sum() / len(mci_sb_vals) * 20) if len(mci_sb_vals) > 0 else np.nan
    )

    # QMCI: weighted average of MCI scores by abundance.
    # fillna(0) matches the spreadsheet formula — taxa without an MCI score
    # contribute their abundance to the denominator but zero to the numerator.
    qmci_numerator = (counts * merged["MCI"].fillna(0)).sum()
    qmci = qmci_numerator / num_individuals if num_individuals > 0 else np.nan

    # QMCI-sb (same fillna(0) convention)
    qmci_sb_numerator = (counts * merged["MCI_sb"].fillna(0)).sum()
    qmci_sb = qmci_sb_numerator / num_individuals if num_individuals > 0 else np.nan

    # EPT calculations — derived from TaxonGroup labels
    is_ept = merged["TaxonGroup"].isin(_EPT_GROUPS)
    is_ephemeroptera = merged["TaxonGroup"] == "Mayflies"
    is_plecoptera = merged["TaxonGroup"] == "Stoneflies"
    is_trichoptera = is_ept & ~is_ephemeroptera & ~is_plecoptera
    is_hydroptilidae = merged["Taxon"].str.strip().isin(_HYDROPTILIDAE_GENERA)

    # Trichoptera excludes Hydroptilidae
    is_trichoptera_excl = is_trichoptera & ~is_hydroptilidae

    e_richness = int((counts[is_ephemeroptera] > 0).sum())
    p_richness = int((counts[is_plecoptera] > 0).sum())
    t_richness = int((counts[is_trichoptera_excl] > 0).sum())
    ept_richness = e_richness + p_richness + t_richness

    ept_abundance = int(
        counts[is_ephemeroptera | is_plecoptera | is_trichoptera_excl].sum()
    )

    pct_ept_abundance = (
        ept_abundance / num_individuals if num_individuals > 0 else np.nan
    )
    pct_ept_richness = ept_richness / num_taxa if num_taxa > 0 else np.nan

    # ASPM-MCI: composite index normalised to theoretical ceilings
    aspm_mci = (
        np.mean(
            [
                mci / _ASPM_MCI_MAX,
                ept_richness / _ASPM_EPT_RICHNESS_MAX,
                ept_abundance / _ASPM_EPT_ABUNDANCE_MAX,
            ]
        )
        if not np.isnan(mci)
        else np.nan
    )

    return {
        "Number of Taxa": num_taxa,
        "Number of Individuals": num_individuals,
        "MCI": mci,
        "MCI-sb": mci_sb,
        "QMCI": qmci,
        "QMCI-sb": qmci_sb,
        "EPT Abundance": ept_abundance,
        "E Richness": e_richness,
        "P Richness": p_richness,
        "T Richness": t_richness,
        "EPT Richness": ept_richness,
        "% EPT Abundance": pct_ept_abundance,
        "% EPT Richness": pct_ept_richness,
        "ASPM-MCI": aspm_mci,
    }


def process_macro_domain(macro_db_path: Path) -> DomainResult:
    """Process the macroinvertebrate domain: derive metrics, emit Macro1 + Macro.

    Orchestrates: ingest → derive_metrics per sample → QMCI routing →
    build Macro1 (full precision) → aggregate Macro (replicated sites only).

    Returns:
        DomainResult with {"Macro1": df, "Macro": df} on success,
        or errors on failure.
    """
    file_name = macro_db_path.name
    errors: list[ValidationError] = []

    try:
        bundle = ingest_raw_data(macro_db_path)
    except IngestError as e:
        errors.append(
            ValidationError(
                domain="macroinvertebrate",
                severity="error",
                file=file_name,
                sheet="RawData",
                location="file",
                message=f"Failed to read RawData: {e}",
            )
        )
        return DomainResult(data=None, errors=errors)

    # Derive metrics for each sample column
    sample_ids = bundle.sample_metadata["sample_id"].tolist()
    rows: list[dict[str, object]] = []

    for sample_id in sample_ids:
        meta_row = bundle.sample_metadata[
            bundle.sample_metadata["sample_id"] == sample_id
        ]
        if meta_row.empty:
            continue

        meta = meta_row.iloc[0]
        metrics = derive_metrics(
            bundle.taxa_counts, bundle.mci_scores, sample_col=sample_id
        )

        # Route QMCI: use QMCI-sb for sites without replicates
        site = str(meta["Site"]).strip()
        qmci_value = (
            metrics["QMCI-sb"] if site in SITES_WITHOUT_REPLICATES else metrics["QMCI"]
        )

        rows.append(
            {
                "Site": site,
                "Date": meta["Date"],
                "Period": meta["Season"],
                "EPTrich": metrics["% EPT Richness"],
                "EPTabun": metrics["% EPT Abundance"],
                "QMCI": qmci_value,
                "Season": meta["Season"],
            }
        )

    if not rows:
        errors.append(
            ValidationError(
                domain="macroinvertebrate",
                severity="error",
                file=file_name,
                sheet="RawData",
                location="data",
                message="No sample data could be processed",
            )
        )
        return DomainResult(data=None, errors=errors)

    macro1_df = pd.DataFrame(rows, columns=MACRO1_COLUMNS)
    macro1_df["Date"] = pd.to_datetime(macro1_df["Date"])

    # Macro sheet: aggregated means for replicated sites only
    replicated = macro1_df[~macro1_df["Site"].isin(SITES_WITHOUT_REPLICATES)]
    macro_df = (
        replicated.groupby(["Site", "Date", "Period", "Season"], as_index=False)
        .agg({"EPTrich": "mean", "EPTabun": "mean", "QMCI": "mean"})
        .reindex(columns=MACRO1_COLUMNS)
    )

    return DomainResult(data={"Macro1": macro1_df, "Macro": macro_df}, errors=errors)
