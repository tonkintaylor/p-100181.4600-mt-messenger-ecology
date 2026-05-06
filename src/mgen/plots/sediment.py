"""Sediment monitoring plots.

Provides:
- Grain-size distribution stacked bar charts (per site)
- SAM1/SAM3 time-series with trigger levels (per site)

Reimplements MountMessSedimentSizeDistributionPlots.R and
MountMessSedimentPlots.R as robust Python.
"""

from __future__ import annotations

from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

from mgen.plots._style import (
    PERIOD_COLORS,
    add_baseline_vline,
    add_summer_shading,
    apply_ecology_theme,
    save_figure,
)
from mgen.shared.schemas import SEDIMENT_SIZE_COLUMNS

__all__ = ["plot_sediment_size_distribution", "plot_sediment_timeseries"]

_SIZE_COLS = SEDIMENT_SIZE_COLUMNS[4:]

# ColorBrewer "Paired" palette (matches R scale_fill_brewer(palette="Paired"))
_PAIRED_PALETTE = [
    "#a6cee3",
    "#1f78b4",
    "#b2df8a",
    "#33a02c",
    "#fb9a99",
    "#e31a1c",
    "#fdbf6f",
    "#ff7f00",
    "#cab2d6",
    "#6a3d9a",
    "#ffff99",
    "#b15928",
]


def _find_construction_start_index(df: pd.DataFrame) -> int | None:
    """Find the bar index where construction period begins.

    Returns the index of the first row where Period != 'Baseline',
    or None if all data is one period.
    """
    for i, period in enumerate(df["Period"]):
        if period != "Baseline":
            return i
    return None


def plot_sediment_size_distribution(
    df: pd.DataFrame,
    output_dir: Path,
) -> list[Path]:
    """Create per-site stacked bar charts of grain-size percentage.

    Matches R ggplot output: Paired palette, construction annotation,
    dd/mm/YYYY date labels on x-axis.

    Args:
        df: SedimentSize DataFrame with columns from SEDIMENT_SIZE_COLUMNS.
        output_dir: Directory to save output files.

    Returns:
        List of paths to saved figure files (PNG + PDF per site).
    """
    if df.empty:
        return []

    sites = sorted(df["Site"].unique())
    all_paths: list[Path] = []

    for site in sites:
        site_df = df[df["Site"] == site].sort_values("Date").reset_index(drop=True)
        fig, ax = plt.subplots(figsize=(12, 8))

        dates = site_df["Date"].dt.strftime("%d/%m/%Y")
        x = np.arange(len(dates))
        bottom = np.zeros(len(dates))

        for i, col in enumerate(_SIZE_COLS):
            values = site_df[col].to_numpy()
            color = _PAIRED_PALETTE[i % len(_PAIRED_PALETTE)]
            ax.bar(x, values, bottom=bottom, label=col, color=color, width=0.7)
            bottom += values

        # Construction begins annotation (matching R annotate("segment"))
        constr_idx = _find_construction_start_index(site_df)
        if constr_idx is not None:
            line_x = constr_idx - 0.5
            ax.axvline(
                x=line_x,
                color="black",
                linewidth=1.5,
                linestyle="--",
                zorder=5,
            )
            ax.text(
                line_x,
                85,
                "Construction Begins",
                rotation=90,
                va="center",
                ha="right",
                fontsize=10,
                color="black",
            )

        ax.set_xlabel("Sampling Date", fontsize=14)
        ax.set_ylabel("Percentage", fontsize=14)
        ax.set_title(
            f"Sediment Size Distribution for {site}", fontsize=14, fontweight="bold"
        )
        ax.set_xticks(x)
        ax.set_xticklabels(dates, rotation=45, ha="right", fontsize=11)
        ax.tick_params(axis="y", labelsize=11)
        ax.legend(
            title="Sediment Size",
            loc="upper right",
            fontsize=11,
            title_fontsize=14,
        )
        ax.set_ylim(0, 105)
        ax.margins(x=0.02)

        fig.tight_layout()
        paths = save_figure(fig, output_dir / f"sediment_size_{site}")
        all_paths.extend(paths)

    return all_paths


def _plot_single_sediment_metric(
    site_df: pd.DataFrame,
    metric: str,
    trigger_value: float | None,
    site: str,
) -> plt.Figure:
    """Create a single SAM metric time-series plot matching R layout."""
    fig, ax = plt.subplots(figsize=(8, 6))

    # Summer shading
    year_min = site_df["Date"].dt.year.min()
    year_max = site_df["Date"].dt.year.max()
    ax.set_ylim(0, 102)
    add_summer_shading(ax, (year_min, year_max))

    # Plot points coloured by period
    for period, color in PERIOD_COLORS.items():
        mask = site_df["Period"] == period
        subset = site_df[mask]
        if not subset.empty:
            ax.scatter(
                subset["Date"],
                subset[metric],
                c=color,
                label=period,
                s=30,
                zorder=3,
            )

    # Trigger level
    if trigger_value is not None:
        ax.axhline(
            y=trigger_value,
            color="black",
            linestyle="-",
            linewidth=0.8,
            label="Trigger Level",
            zorder=2,
        )

    # Baseline end vline
    add_baseline_vline(ax)
    apply_ecology_theme(ax)

    ylabel_map = {
        "SAM1": "SAM1 Mean Sediment Cover (%)",
        "SAM3": "SAM3 Mean Sediment Cover (%)",
    }
    ax.set_ylabel(ylabel_map.get(metric, metric))
    ax.set_xlabel("")
    ax.legend(loc="upper left", fontsize=9)
    ax.set_title(f"{site} — {metric}", fontsize=14, fontweight="bold")

    fig.tight_layout()
    return fig


def plot_sediment_timeseries(
    df: pd.DataFrame,
    triggers: dict[str, float],
    output_dir: Path,
) -> list[Path]:
    """Create per-site SAM1 and SAM3 time-series plots with trigger levels.

    Produces both individual metric plots (matching R per-plot JPG output)
    and a combined 2-panel figure per site.

    Args:
        df: Sediment DataFrame with columns Site, Date, Period, SAM1, SAM3.
        triggers: Mapping of site → trigger level for SAM1.
        output_dir: Directory to save output files.

    Returns:
        List of paths to saved figure files.
    """
    if df.empty:
        return []

    sites = sorted(df["Site"].unique())
    all_paths: list[Path] = []

    for site in sites:
        site_df = df[df["Site"] == site].sort_values("Date")

        for metric in ["SAM1", "SAM3"]:
            trigger_val = triggers.get(site)
            fig = _plot_single_sediment_metric(site_df, metric, trigger_val, site)
            paths = save_figure(fig, output_dir / f"{site}_{metric}_plot")
            all_paths.extend(paths)

        # Also produce combined 2-panel figure
        fig, axes = plt.subplots(2, 1, figsize=(10, 8), sharex=True)
        for ax_idx, metric in enumerate(["SAM1", "SAM3"]):
            ax = axes[ax_idx]
            ax.set_ylim(0, 102)

            year_min = site_df["Date"].dt.year.min()
            year_max = site_df["Date"].dt.year.max()
            add_summer_shading(ax, (year_min, year_max))

            for period, color in PERIOD_COLORS.items():
                mask = site_df["Period"] == period
                subset = site_df[mask]
                if not subset.empty:
                    ax.scatter(
                        subset["Date"],
                        subset[metric],
                        c=color,
                        label=period,
                        s=30,
                        zorder=3,
                    )

            if site in triggers:
                ax.axhline(
                    y=triggers[site],
                    color="black",
                    linestyle="-",
                    linewidth=0.8,
                    label="Trigger Level",
                )

            ylabel_map = {
                "SAM1": "SAM1 Mean Sediment Cover (%)",
                "SAM3": "SAM3 Mean Sediment Cover (%)",
            }
            ax.set_ylabel(ylabel_map.get(metric, metric))

            add_baseline_vline(ax)
            apply_ecology_theme(ax)

            if ax_idx == 0:
                ax.legend(loc="upper left", fontsize=8)

        fig.suptitle(site, fontsize=14, fontweight="bold")
        fig.tight_layout()
        paths = save_figure(fig, output_dir / f"sediment_timeseries_{site}")
        all_paths.extend(paths)

    return all_paths
