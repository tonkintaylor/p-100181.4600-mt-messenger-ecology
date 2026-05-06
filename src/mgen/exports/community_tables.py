"""Export community analysis results to Excel tables.

Produces formatted Excel spreadsheets for:
- ANOSIM results summary
- Indicator species table
- Species environmental drivers (envfit)
"""

from __future__ import annotations

from pathlib import Path

import pandas as pd

from mgen.stats.community import ANOSIMResult, IndicatorSpecies

__all__ = [
    "export_anosim_summary",
    "export_indicator_species_table",
    "export_species_drivers_table",
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
