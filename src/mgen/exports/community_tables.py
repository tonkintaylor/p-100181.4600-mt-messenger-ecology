"""Export community analysis results to Excel tables.

Produces formatted Excel spreadsheets for:
- ANOSIM results summary
- Indicator species table (all-sites and per-catchment)
- Species environmental drivers (envfit) per site and per catchment
- Top species with abundance change
- Bray-Curtis dissimilarity matrix
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd

from mgen.stats.community import ANOSIMResult, IndicatorSpecies

__all__ = [
    "export_anosim_summary",
    "export_indicator_species_table",
    "export_nmds_scores_table",
    "export_species_drivers_per_catchment",
    "export_species_drivers_table",
    "export_topspecies_individualsites",
]


def export_anosim_summary(
    results: dict[str, ANOSIMResult],
    output_path: Path,
) -> None:
    """Export ANOSIM results to Excel.

    Args:
        results: Mapping of comparison name to ANOSIMResult.
        output_path: Path for the output xlsx file.
    """
    rows = [
        {
            "Comparison": name,
            "R_statistic": r.R_statistic,
            "p_value": r.p_value,
            "Permutations": r.permutations,
            "Significant": r.p_value < 0.05,
        }
        for name, r in results.items()
    ]
    df = pd.DataFrame(rows)
    df.to_excel(output_path, index=False, sheet_name="ANOSIM")


def export_indicator_species_table(
    indicators: list[IndicatorSpecies],
    output_path: Path,
) -> None:
    """Export indicator species results to Excel.

    Args:
        indicators: List of IndicatorSpecies results (already filtered by significance).
        output_path: Path for the output xlsx file.
    """
    sorted_indicators = sorted(indicators, key=lambda x: x.stat, reverse=True)
    rows = [
        {
            "Species": ind.species,
            "Indicator_Group": ind.group,
            "IndVal": ind.stat,
            "p_value": ind.p_value,
        }
        for ind in sorted_indicators
    ]
    df = pd.DataFrame(rows, columns=["Species", "Indicator_Group", "IndVal", "p_value"])
    df.to_excel(output_path, index=False, sheet_name="Indicator Species")


def export_species_drivers_table(
    drivers_df: pd.DataFrame,
    output_path: Path,
) -> None:
    """Export species environmental drivers (envfit) to Excel.

    Args:
        drivers_df: DataFrame with Species, NMDS1_corr, NMDS2_corr, R2, p_value.
        output_path: Path for the output xlsx file.
    """
    sorted_df = drivers_df.sort_values("R2", ascending=False).reset_index(drop=True)
    sorted_df.to_excel(output_path, index=False, sheet_name="Species Drivers")


def export_species_drivers_per_catchment(
    drivers_df: pd.DataFrame,
    output_path: Path,
) -> None:
    """Export per-catchment envfit species drivers (significant only) to Excel.

    Matches R output ``species_drivers_sig.xlsx``: columns are
    NMDS1, NMDS2, r, p, Catchment for each significant species.

    Args:
        drivers_df: DataFrame with Species, NMDS1_corr,
            NMDS2_corr, R2, p_value, Catchment.
        output_path: Path for the output xlsx file.
    """
    out = drivers_df.rename(
        columns={"NMDS1_corr": "NMDS1", "NMDS2_corr": "NMDS2", "R2": "r"}
    ).sort_values(["Catchment", "r"], ascending=[True, False])
    out.to_excel(output_path, index=False, sheet_name="Species Drivers")


def export_topspecies_individualsites(
    drivers_sig: pd.DataFrame,
    abundance_change: pd.DataFrame,
    output_path: Path,
) -> None:
    """Export top species driving NMDS shifts per site with abundance changes.

    Matches R output ``topspecies_individualsites.xlsx``: envfit-significant
    species joined with abundance change (Construction - Baseline).

    Args:
        drivers_sig: Significant per-site envfit results
            (Species, Site, R2, p_value, ...).
        abundance_change: DataFrame with Site, Species, Baseline, Construction, Change.
        output_path: Path for the output xlsx file.
    """
    merged = drivers_sig.merge(abundance_change, on=["Site", "Species"], how="left")
    merged = merged.sort_values(
        ["Site", "Change"], key=lambda s: s.abs(), ascending=[True, False]
    )
    merged.to_excel(output_path, index=False, sheet_name="Top Species")


def export_nmds_scores_table(
    distance_matrix: np.ndarray,
    metadata: pd.DataFrame,
    output_path: Path,
) -> None:
    """Export Bray-Curtis dissimilarity matrix with site/date metadata to Excel.

    This table goes into Appendix B4 of the monitoring report. Matches the
    R output format: columns are sample indices (1..n), rows are samples,
    with Site and Date appended.

    Args:
        distance_matrix: Square pairwise distance matrix (n_samples x n_samples).
        metadata: DataFrame with 'Site' and 'Date' columns matching sample order.
        output_path: Path for the output xlsx file.
    """
    n = distance_matrix.shape[0]
    col_names = [str(i + 1) for i in range(n)]

    scores_df = pd.DataFrame(distance_matrix, columns=col_names)
    scores_df["Site"] = metadata["Site"].to_numpy()
    scores_df["Date"] = metadata["Date"].to_numpy()
    scores_df.to_excel(output_path, index=False, sheet_name="Dissimilarity")
