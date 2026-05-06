"""Macroinvertebrate metric plots with 95% confidence interval error bars.

Produces per-site 3-panel figures showing QMCI, %EPT Richness, and
%EPT Abundance over time, with trigger level lines and CI whiskers.

Also produces individual metric plots matching R output (one JPG per
site per metric).

Reimplements MountMessMacroPlots_250813.R as robust Python.
"""

from __future__ import annotations

from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd

from mgen.plots._style import (
    PERIOD_COLORS,
    add_baseline_vline,
    add_summer_shading,
    apply_ecology_theme,
    save_figure,
)
from mgen.stats.confidence import MetricSummary

__all__ = ["plot_macro_metrics"]

_METRICS = ["QMCI", "EPTrich", "EPTabun"]
_METRIC_LABELS = {
    "QMCI": "QMCI",
    "EPTrich": "%EPT Richness",
    "EPTabun": "%EPT Abundance",
}
# Y-axis limits matching R code
_Y_LIMITS = {
    "QMCI": (0, 8),
    "EPTrich": (0, 101),
    "EPTabun": (0, 101),
}


def _plot_metric_axes(
    ax: plt.Axes,
    site_df: pd.DataFrame,
    dates: list,
    metric: str,
    metric_summaries: list[MetricSummary],
    trigger_value: float | None,
) -> None:
    """Render a single metric on an axes with error bars and trigger."""
    zipped = zip(dates, metric_summaries, strict=False)
    for dt, summary in zipped:
        period = site_df[site_df["Date"] == dt]["Period"].iloc[0]
        color = PERIOD_COLORS.get(period, "gray")

        yerr_lower = (
            summary.mean - summary.ci_lower if not pd.isna(summary.ci_lower) else 0
        )
        yerr_upper = (
            summary.ci_upper - summary.mean if not pd.isna(summary.ci_upper) else 0
        )

        ax.errorbar(
            dt,
            summary.mean,
            yerr=[[yerr_lower], [yerr_upper]],
            fmt="o",
            color=color,
            capsize=3,
            markersize=5,
            zorder=3,
        )

    if trigger_value is not None:
        ax.axhline(
            y=trigger_value,
            color="black",
            linestyle="-",
            linewidth=0.8,
            label="Trigger Level",
            zorder=2,
        )

    ax.set_ylabel(_METRIC_LABELS[metric])
    ax.set_ylim(_Y_LIMITS[metric])

    year_min = site_df["Date"].dt.year.min()
    year_max = site_df["Date"].dt.year.max()
    add_summer_shading(ax, (year_min, year_max))
    add_baseline_vline(ax)
    apply_ecology_theme(ax)


def plot_macro_metrics(
    raw_df: pd.DataFrame,
    summaries: dict[str, dict[str, list[MetricSummary]]],
    triggers: dict[str, dict[str, float]],
    output_dir: Path,
) -> list[Path]:
    """Create per-site 3-panel figures and individual metric plots.

    Args:
        raw_df: Macro1 DataFrame (all replicates).
        summaries: site -> metric -> list of MetricSummary (one per date).
        triggers: site -> metric -> trigger level.
        output_dir: Directory to save output files.

    Returns:
        List of paths to saved figure files.
    """
    if raw_df.empty:
        return []

    sites = sorted(raw_df["Site"].unique())
    all_paths: list[Path] = []

    for site in sites:
        if site not in summaries:
            continue

        site_df = raw_df[raw_df["Site"] == site].sort_values("Date")
        dates = sorted(site_df["Date"].unique())
        site_triggers = triggers.get(site, {})

        # --- 3-panel combined figure (matching R ggarrange 3-row layout) ---
        fig, axes = plt.subplots(3, 1, figsize=(9, 12), sharex=True)

        for ax_idx, metric in enumerate(_METRICS):
            ax = axes[ax_idx]
            metric_summaries = summaries.get(site, {}).get(metric, [])
            trigger_val = site_triggers.get(metric)

            _plot_metric_axes(ax, site_df, dates, metric, metric_summaries, trigger_val)

            # Panel labels (a, b, c) matching R
            label = chr(ord("a") + ax_idx) + ")"
            ax.text(
                -0.08,
                1.02,
                label,
                transform=ax.transAxes,
                fontsize=12,
                fontweight="bold",
                va="bottom",
            )

        fig.suptitle(site, fontsize=14, fontweight="bold")
        fig.tight_layout()
        paths = save_figure(fig, output_dir / f"macro_{site}")
        all_paths.extend(paths)

        # --- Individual metric plots (matching R metric_plots_jpeg/) ---
        for metric in _METRICS:
            metric_summaries = summaries.get(site, {}).get(metric, [])
            trigger_val = site_triggers.get(metric)

            fig_single, ax_single = plt.subplots(figsize=(9, 6))
            _plot_metric_axes(
                ax_single, site_df, dates, metric, metric_summaries, trigger_val
            )
            ax_single.set_title(
                f"{site} — {_METRIC_LABELS[metric]}",
                fontsize=14,
                fontweight="bold",
            )
            if trigger_val is not None:
                ax_single.legend(loc="upper right", fontsize=9)
            fig_single.tight_layout()
            paths = save_figure(fig_single, output_dir / f"{site}_{metric}_DRAFT")
            all_paths.extend(paths)

    return all_paths
