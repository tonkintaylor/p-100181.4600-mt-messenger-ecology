"""Figure generation orchestrator.

Coordinates stats computation, plot rendering, and export writing.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path

import pandas as pd

__all__ = ["FigureResult", "generate_figures"]


@dataclass
class FigureResult:
    """Result from figure generation.

    Attributes:
        files_written: List of paths to generated files.
        warnings: List of warning messages.
    """

    files_written: list[Path] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)

    @property
    def success(self) -> bool:
        """Return True if at least one file was generated."""
        return len(self.files_written) > 0


def generate_figures(
    data: dict[str, pd.DataFrame],
    output_dir: Path,
    only: str = "all",
) -> FigureResult:
    """Run stats -> plots -> exports for requested subset.

    Args:
        data: Mapping of sheet_name -> DataFrame from Data.xlsx.
        output_dir: Directory to write figures to.
        only: Which subset to generate ("all", "sediment", "macro", "community").

    Returns:
        FigureResult with list of files written and any warnings.
    """
    result = FigureResult()
    output_dir.mkdir(parents=True, exist_ok=True)

    if only in ("all", "sediment"):
        result.files_written.extend(_generate_sediment(data, output_dir))

    if only in ("all", "macro"):
        result.files_written.extend(_generate_macro(data, output_dir))

    if only in ("all", "community"):
        result.files_written.extend(_generate_community(data, output_dir, result))

    return result


def _generate_sediment(data: dict[str, pd.DataFrame], output_dir: Path) -> list[Path]:
    """Generate sediment plots (grain-size + time-series)."""
    from mgen.plots.sediment import (  # noqa: PLC0415
        plot_sediment_size_distribution,
        plot_sediment_timeseries,
    )
    from mgen.stats.triggers import compute_trigger  # noqa: PLC0415

    paths: list[Path] = []

    if "SedimentSize" in data:
        paths.extend(plot_sediment_size_distribution(data["SedimentSize"], output_dir))

    if "Sediment" in data:
        sediment_df = data["Sediment"]
        sites = sorted(sediment_df["Site"].unique())
        triggers: dict[str, float] = {}
        for site in sites:
            try:
                triggers[site] = compute_trigger(
                    sediment_df,
                    metric_col="SAM1",
                    site=site,
                    direction="increase",
                    threshold_pct=0.15,
                    cap=100.0,
                )
            except ValueError:
                pass
        paths.extend(plot_sediment_timeseries(sediment_df, triggers, output_dir))

    return paths


def _generate_macro(_data: dict[str, pd.DataFrame], _output_dir: Path) -> list[Path]:
    """Generate macro metric plots."""
    return []


def _generate_community(
    _data: dict[str, pd.DataFrame],
    _output_dir: Path,
    _result: FigureResult,
) -> list[Path]:
    """Generate NMDS plots and exports."""
    return []
