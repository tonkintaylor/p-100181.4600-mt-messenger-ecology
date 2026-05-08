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
        result.files_written.extend(_generate_sediment(data, output_dir / "Sediment"))

    if only in ("all", "macro"):
        result.files_written.extend(_generate_macro(data, output_dir / "Macro"))

    if only in ("all", "community"):
        result.files_written.extend(
            _generate_community(data, output_dir / "NMDS", result)
        )

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
        triggers: dict[str, dict[str, float]] = {}
        for site in sites:
            triggers[site] = {}
            for metric in ("SAM1", "SAM3"):
                try:
                    triggers[site][metric] = compute_trigger(
                        sediment_df,
                        metric_col=metric,
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

    if "Macro1" not in data:
        return []

    macro_df = data["Macro1"]
    sites = sorted(macro_df["Site"].unique())
    metrics = ["QMCI", "EPTrich", "EPTabun"]

    summaries: dict[str, dict[str, list]] = {}
    triggers: dict[str, dict[str, float]] = {}

    # R computes triggers from per-date means (average replicates first).
    # This ensures dates with more replicates don't bias the baseline mean.
    macro_means = (
        macro_df.groupby(["Site", "Date", "Period"])[metrics].mean().reset_index()
    )

    for site in sites:
        site_df = macro_df[macro_df["Site"] == site]
        summaries[site] = {}
        triggers[site] = {}

        for metric in metrics:
            date_summaries = []
            # QMCI is 0-10 scale; EPTrich/EPTabun are 0-100%
            clamp_upper = 10.0 if metric == "QMCI" else 100.0
            for dt in sorted(site_df["Date"].unique()):
                values = site_df[site_df["Date"] == dt][metric]
                date_summaries.append(
                    summarize_with_ci(values, clamp_upper=clamp_upper)
                )
            summaries[site][metric] = date_summaries

            # Trigger: mean of per-date baseline averages * 0.85 (decline)
            baseline_means = macro_means[
                (macro_means["Site"] == site) & (macro_means["Period"] == "Baseline")
            ][metric]
            if not baseline_means.empty:
                triggers[site][metric] = float(baseline_means.mean() * 0.85)

    return plot_macro_metrics(macro_df, summaries, triggers, output_dir)


def _generate_community(  # noqa: C901, PLR0912, PLR0915
    data: dict[str, pd.DataFrame],
    output_dir: Path,
    result: FigureResult,
) -> list[Path]:
    """Generate NMDS plots and community analysis exports."""
    from mgen.exports.community_tables import (  # noqa: PLC0415
        export_anosim_summary,
        export_indicator_species_table,
        export_nmds_scores_table,
        export_species_drivers_per_catchment,
        export_species_drivers_table,
        export_topspecies_individualsites,
    )
    from mgen.plots.community import (  # noqa: PLC0415
        CATCHMENT_SUBSETS,
        plot_nmds_grouped,
        plot_nmds_per_site,
    )
    from mgen.stats.community import (  # noqa: PLC0415
        bray_curtis_matrix,
        compute_abundance_change,
        envfit_species_drivers,
        envfit_species_drivers_per_group,
        indicator_species_analysis,
        run_anosim,
        run_nmds,
    )

    if "Community" not in data and "MacroSpecies" not in data:
        return []

    if "Community" in data:
        community_df = data["Community"]
    else:
        # Build community matrix from MacroSpecies long-format
        # (same as R: group by Site/Date/Species → mean Tally → pivot wider)
        ms = data["MacroSpecies"].copy()
        ms.columns = [c.strip() for c in ms.columns]
        grouped = (
            ms.groupby(["Site", "Date", "Species"], observed=True)["Tally"]
            .mean()
            .reset_index()
        )
        community_df = grouped.pivot_table(
            index=["Site", "Date"],
            columns="Species",
            values="Tally",
            fill_value=0,
        ).reset_index()
        community_df.columns.name = None
        # Add Period from Phase if available in MacroSpecies
        if "Phase" in ms.columns:
            phase_map = ms.drop_duplicates(["Site", "Date"])[["Site", "Date", "Phase"]]
            community_df = community_df.merge(
                phase_map, on=["Site", "Date"], how="left"
            ).rename(columns={"Phase": "Period"})

    paths: list[Path] = []

    meta_cols = {"Date", "Site", "Period"}
    species_cols = [c for c in community_df.columns if c not in meta_cols]

    if not species_cols:
        result.warnings.append("No species columns found in Community data")
        return []

    species_df = community_df[species_cols]
    meta_available = [
        c for c in ["Date", "Site", "Period"] if c in community_df.columns
    ]
    metadata = community_df[meta_available].copy()

    # Build catchment lookup for per-site titles
    catchment_lookup: dict[str, str] = {}
    for catchment, sites in CATCHMENT_SUBSETS.items():
        for s in sites:
            if s not in catchment_lookup:
                catchment_lookup[s] = catchment

    # --- All-sites NMDS ---
    dm = bray_curtis_matrix(species_df)
    nmds = run_nmds(dm, n_dims=2, seed=42)

    paths.extend(plot_nmds_grouped(nmds, metadata, output_dir, "NMDS_AllSites"))

    # --- NMDS scores table (Appendix B4) ---
    nmds_table_path = output_dir / "Dissimilarity_Table.xlsx"
    export_nmds_scores_table(dm, metadata, nmds_table_path)
    paths.append(nmds_table_path)

    # --- Per-site NMDS with regression arrows ---
    paths.extend(
        plot_nmds_per_site(
            nmds,
            metadata,
            output_dir,
            filename_prefix="NMDS_PerSite",
            catchment_lookup=catchment_lookup,
        )
    )

    # --- Catchment subset NMDS ---
    for catchment_name, catchment_sites in CATCHMENT_SUBSETS.items():
        mask = metadata["Site"].isin(catchment_sites)
        if mask.sum() < 4:
            continue

        subset_species = species_df[mask]
        subset_meta = metadata[mask].reset_index(drop=True)

        dm_sub = bray_curtis_matrix(subset_species)
        nmds_sub = run_nmds(dm_sub, n_dims=2, seed=42)

        safe_name = catchment_name.replace("ē", "e").replace(" ", "_")
        paths.extend(
            plot_nmds_grouped(
                nmds_sub,
                subset_meta,
                output_dir,
                filename_prefix=f"NMDS_{safe_name}",
                title_suffix=f"{catchment_name} Sites",
                shape_legend_title=f"{catchment_name} Site",
            )
        )

    # --- ANOSIM ---
    anosim_results: dict[str, object] = {}
    if "Period" in metadata.columns:
        anosim_results["Period Effect"] = run_anosim(dm, metadata["Period"], seed=42)

    if anosim_results:
        anosim_path = output_dir / "ANOSIM_Results.xlsx"
        export_anosim_summary(anosim_results, anosim_path)
        paths.append(anosim_path)

    # --- Indicator species by Site (matching R multipatt with Site as grouping) ---
    if "Site" in metadata.columns:
        # All sites
        indicators_all = indicator_species_analysis(
            species_df, metadata["Site"], seed=42
        )
        if indicators_all:
            ind_path = output_dir / "significant_species_importance.xlsx"
            export_indicator_species_table(indicators_all, ind_path)
            paths.append(ind_path)

        # Per-catchment subsets (R: _13 = Mangapepeke, _4578 = Mimi)
        catchment_indicator_sites = {
            "13": ["EM1", "EM2", "EM3"],
            "4578": ["EM4", "EM7", "EM8"],
        }
        for suffix, sites_list in catchment_indicator_sites.items():
            mask = metadata["Site"].isin(sites_list)
            if mask.sum() < 4:
                continue
            sub_species = species_df[mask].reset_index(drop=True)
            sub_groups = metadata.loc[mask, "Site"].reset_index(drop=True)
            indicators_sub = indicator_species_analysis(
                sub_species, sub_groups, seed=42
            )
            if indicators_sub:
                sub_path = output_dir / f"significant_species_importance_{suffix}.xlsx"
                export_indicator_species_table(indicators_sub, sub_path)
                paths.append(sub_path)

    # --- Envfit species drivers (all-sites) ---
    drivers = envfit_species_drivers(nmds.points, species_df, seed=42)
    if not drivers.empty:
        drivers_path = output_dir / "Species_Drivers.xlsx"
        export_species_drivers_table(drivers, drivers_path)
        paths.append(drivers_path)

    # --- Per-site envfit species drivers + topspecies ---
    if "Site" in metadata.columns:
        per_site_drivers = envfit_species_drivers_per_group(
            species_df, metadata["Site"], seed=42, group_col_name="Site"
        )
        if not per_site_drivers.empty and "MacroSpecies" in data:
            abundance_change = compute_abundance_change(data["MacroSpecies"])
            top_path = output_dir / "topspecies_individualsites.xlsx"
            export_topspecies_individualsites(
                per_site_drivers, abundance_change, top_path
            )
            paths.append(top_path)

    # --- Per-catchment envfit species drivers ---
    if "Site" in metadata.columns:
        catchment_driver_sites = {
            "Mangapepeke": ["EM2", "EM3"],
            "Mimi": ["EM4", "EM7", "EM8"],
        }
        catchment_series = metadata["Site"].map(
            {s: c for c, sites in catchment_driver_sites.items() for s in sites}
        )
        valid_mask = catchment_series.notna()
        if valid_mask.sum() >= 4:
            catchment_drivers = envfit_species_drivers_per_group(
                species_df[valid_mask].reset_index(drop=True),
                catchment_series[valid_mask].reset_index(drop=True),
                seed=42,
                group_col_name="Catchment",
            )
            if not catchment_drivers.empty:
                cd_path = output_dir / "species_drivers_sig.xlsx"
                export_species_drivers_per_catchment(catchment_drivers, cd_path)
                paths.append(cd_path)

    return paths
