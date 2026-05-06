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


def _generate_macro(data: dict[str, pd.DataFrame], output_dir: Path) -> list[Path]:
    """Generate macro metric plots with CI error bars."""
    from mgen.plots.macro import plot_macro_metrics  # noqa: PLC0415
    from mgen.stats.confidence import summarize_with_ci  # noqa: PLC0415
    from mgen.stats.triggers import compute_trigger  # noqa: PLC0415

    if "Macro1" not in data:
        return []

    macro_df = data["Macro1"]
    sites = sorted(macro_df["Site"].unique())
    metrics = ["QMCI", "EPTrich", "EPTabun"]

    summaries: dict[str, dict[str, list]] = {}
    triggers: dict[str, dict[str, float]] = {}

    for site in sites:
        site_df = macro_df[macro_df["Site"] == site]
        summaries[site] = {}
        triggers[site] = {}

        for metric in metrics:
            date_summaries = []
            for dt in sorted(site_df["Date"].unique()):
                values = site_df[site_df["Date"] == dt][metric]
                date_summaries.append(summarize_with_ci(values))
            summaries[site][metric] = date_summaries

            try:
                triggers[site][metric] = compute_trigger(
                    macro_df,
                    metric_col=metric,
                    site=site,
                    direction="decline",
                    threshold_pct=0.15,
                )
            except ValueError:
                pass

    return plot_macro_metrics(macro_df, summaries, triggers, output_dir)


def _generate_community(
    data: dict[str, pd.DataFrame],
    output_dir: Path,
    result: FigureResult,
) -> list[Path]:
    """Generate NMDS plots and community analysis exports."""
    from mgen.exports.community_tables import (  # noqa: PLC0415
        export_anosim_summary,
        export_indicator_species_table,
        export_species_drivers_table,
    )
    from mgen.plots.community import (  # noqa: PLC0415
        plot_nmds_ordination,
        plot_nmds_per_site,
    )
    from mgen.stats.community import (  # noqa: PLC0415
        bray_curtis_matrix,
        envfit_species_drivers,
        indicator_species_analysis,
        run_anosim,
        run_nmds,
    )

    if "Community" not in data:
        return []

    community_df = data["Community"]
    paths: list[Path] = []

    meta_cols = {"Date", "Site", "Period"}
    species_cols = [c for c in community_df.columns if c not in meta_cols]

    if not species_cols:
        result.warnings.append("No species columns found in Community sheet")
        return []

    species_df = community_df[species_cols]
    metadata = community_df[["Date", "Site", "Period"]].copy()

    # 1. Bray-Curtis distance matrix
    dm = bray_curtis_matrix(species_df)

    # 2. NMDS ordination
    nmds = run_nmds(dm, n_dims=2, seed=42)

    # 3. NMDS plots
    plot_nmds_ordination(nmds, metadata, output_dir)
    plot_nmds_per_site(nmds, metadata, output_dir)

    for f in output_dir.iterdir():
        if f.suffix in (".png", ".pdf") and "NMDS" in f.name:
            paths.append(f)

    # 4. ANOSIM
    anosim_results: dict[str, object] = {}
    if "Period" in metadata.columns:
        anosim_results["Period Effect"] = run_anosim(dm, metadata["Period"], seed=42)

    if anosim_results:
        anosim_path = output_dir / "ANOSIM_Results.xlsx"
        export_anosim_summary(anosim_results, anosim_path)
        paths.append(anosim_path)

    # 5. Indicator species
    if "Period" in metadata.columns:
        indicators = indicator_species_analysis(species_df, metadata["Period"], seed=42)
        if indicators:
            ind_path = output_dir / "Indicator_Species.xlsx"
            export_indicator_species_table(indicators, ind_path)
            paths.append(ind_path)

    # 6. Envfit species drivers
    drivers = envfit_species_drivers(nmds.points, species_df, seed=42)
    if not drivers.empty:
        drivers_path = output_dir / "Species_Drivers.xlsx"
        export_species_drivers_table(drivers, drivers_path)
        paths.append(drivers_path)

    return paths
