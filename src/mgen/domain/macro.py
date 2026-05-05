"""Macroinvertebrate domain: metric derivation.

Implements the ecologist-signed formulas for MCI, QMCI, EPT metrics.
EPT membership is derived from TaxonGroup labels, NOT hard-coded row numbers.
"""

from __future__ import annotations

import numpy as np
import pandas as pd

# EPT taxonomic groups mapped from common names to order
_EPT_GROUPS = frozenset({"Mayflies", "Stoneflies", "Caddisflies"})

# Hydroptilidae genera excluded from Trichoptera counts (NZ freshwater)
_HYDROPTILIDAE_GENERA = frozenset({"Oxyethira", "Paroxyethira"})


def derive_metrics(
    taxa_counts: pd.DataFrame,
    mci_scores: pd.DataFrame,
    *,
    sample_col: int,
) -> dict[str, float]:
    """Derive all macroinvertebrate metrics for a single sample.

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

    # QMCI: weighted average of MCI scores by abundance
    qmci_numerator = (counts * merged["MCI"].fillna(0)).sum()
    qmci = qmci_numerator / num_individuals if num_individuals > 0 else np.nan

    # QMCI-sb
    qmci_sb_numerator = (counts * merged["MCI_sb"].fillna(0)).sum()
    qmci_sb = qmci_sb_numerator / num_individuals if num_individuals > 0 else np.nan

    # EPT calculations — derived from TaxonGroup labels
    is_ephemeroptera = merged["TaxonGroup"] == "Mayflies"
    is_plecoptera = merged["TaxonGroup"] == "Stoneflies"
    is_trichoptera = merged["TaxonGroup"] == "Caddisflies"
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

    # ASPM-MCI = average(MCI/200, EPT_Richness/29, EPT_Abundance/100)
    aspm_mci = (
        np.mean([mci / 200, ept_richness / 29, ept_abundance / 100])
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
