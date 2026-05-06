"""Sediment monitoring plots.

Provides:
- Grain-size distribution stacked bar charts (per site)
- SAM1/SAM3 time-series with trigger levels (per site)
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

_SIZE_COLORS = [
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
]


def plot_sediment_size_distribution(
    df: pd.DataFrame,
    output_dir: Path,
) -> list[Path]:
    """Create per-site stacked bar charts of grain-size percentage.

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
        fig, ax = plt.subplots(figsize=(10, 6))

        dates = site_df["Date"].dt.strftime("%b %Y")
        x = np.arange(len(dates))
        bottom = np.zeros(len(dates))

        for i, col in enumerate(_SIZE_COLS):
            values = site_df[col].to_numpy()
            ax.bar(
                x, values, bottom=bottom, label=col, color=_SIZE_COLORS[i], width=0.7
            )
            bottom += values

        ax.set_xlabel("Date")
        ax.set_ylabel("Percentage (%)")
        ax.set_title(f"Sediment Size Distribution — {site}")
        ax.set_xticks(x)
        ax.set_xticklabels(dates, rotation=90, ha="center")
        ax.legend(loc="upper right", fontsize=7, ncol=2)
        ax.set_ylim(0, 100)

        fig.tight_layout()
        paths = save_figure(fig, output_dir / f"sediment_size_{site}")
        all_paths.extend(paths)

    return all_paths


def plot_sediment_timeseries(
    df: pd.DataFrame,
    triggers: dict[str, float],
    output_dir: Path,
) -> list[Path]:
    """Create per-site SAM1/SAM3 time-series plots with trigger levels.

    Args:
        df: Sediment DataFrame with columns Site, Date, Period, SAM1, SAM3.
        triggers: Mapping of site → trigger level for SAM1.
        output_dir: Directory to save output files.

    Returns:
        List of paths to saved figure files (PNG + PDF per site).
    """
    if df.empty:
        return []

    sites = sorted(df["Site"].unique())
    all_paths: list[Path] = []

    for site in sites:
        site_df = df[df["Site"] == site].sort_values("Date")
        fig, axes = plt.subplots(2, 1, figsize=(10, 8), sharex=True)

        for ax_idx, metric in enumerate(["SAM1", "SAM3"]):
            ax = axes[ax_idx]
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
                    color="red",
                    linestyle="-",
                    linewidth=1,
                    alpha=0.7,
                    label="Trigger",
                )

            ax.set_ylabel(metric)
            ax.set_title(f"{site} — {metric}")

            year_min = site_df["Date"].dt.year.min()
            year_max = site_df["Date"].dt.year.max()
            add_summer_shading(ax, (year_min, year_max))
            add_baseline_vline(ax)
            apply_ecology_theme(ax)

            if ax_idx == 0:
                ax.legend(loc="upper left", fontsize=8)

        fig.tight_layout()
        paths = save_figure(fig, output_dir / f"sediment_timeseries_{site}")
        all_paths.extend(paths)

    return all_paths
