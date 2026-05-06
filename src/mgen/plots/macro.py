"""Macroinvertebrate metric plots with 95% confidence interval error bars.

Produces per-site 3-panel figures showing QMCI, %EPT Richness, and
%EPT Abundance over time, with trigger level lines and CI whiskers.
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


def plot_macro_metrics(
    raw_df: pd.DataFrame,
    summaries: dict[str, dict[str, list[MetricSummary]]],
    triggers: dict[str, dict[str, float]],
    output_dir: Path,
) -> list[Path]:
    """Create per-site 3-panel figures with CI error bars.

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

        fig, axes = plt.subplots(3, 1, figsize=(10, 12), sharex=True)

        for ax_idx, metric in enumerate(_METRICS):
            ax = axes[ax_idx]
            metric_summaries = summaries.get(site, {}).get(metric, [])

            zipped = zip(dates, metric_summaries, strict=False)
            for _i, (dt, summary) in enumerate(zipped):
                period = site_df[site_df["Date"] == dt]["Period"].iloc[0]
                color = PERIOD_COLORS.get(period, "gray")
                if not pd.isna(summary.ci_lower):
                    yerr_lower = summary.mean - summary.ci_lower
                else:
                    yerr_lower = 0
                if not pd.isna(summary.ci_upper):
                    yerr_upper = summary.ci_upper - summary.mean
                else:
                    yerr_upper = 0
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

            site_triggers = triggers.get(site, {})
            if metric in site_triggers:
                ax.axhline(
                    y=site_triggers[metric],
                    color="red",
                    linestyle="-",
                    linewidth=1,
                    alpha=0.7,
                    label="Trigger",
                )

            ax.set_ylabel(_METRIC_LABELS[metric])
            ax.set_title(f"{site} — {_METRIC_LABELS[metric]}")

            year_min = site_df["Date"].dt.year.min()
            year_max = site_df["Date"].dt.year.max()
            add_summer_shading(ax, (year_min, year_max))
            add_baseline_vline(ax)
            apply_ecology_theme(ax)

        fig.tight_layout()
        paths = save_figure(fig, output_dir / f"macro_{site}")
        all_paths.extend(paths)

    return all_paths
