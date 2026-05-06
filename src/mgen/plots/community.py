"""NMDS ordination plots for macroinvertebrate community analysis.

Produces:
- All-sites ordination with period-coloured convex hulls
- Per-site ordination with temporal trend arrows
"""

from __future__ import annotations

from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from scipy.spatial import ConvexHull, QhullError

from mgen.plots._style import (
    PERIOD_COLORS,
    save_figure,
)
from mgen.stats.community import NMDSResult

__all__ = [
    "plot_nmds_ordination",
    "plot_nmds_per_site",
]


def _apply_nmds_theme(ax: plt.Axes) -> None:
    """Apply axis styling suitable for NMDS scatter plots."""
    ax.grid(visible=True, alpha=0.3, linestyle="--")
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)


def plot_nmds_ordination(
    nmds: NMDSResult,
    metadata: pd.DataFrame,
    output_dir: Path,
    filename_prefix: str = "NMDS_AllSites",
) -> None:
    """Plot NMDS ordination with period-coloured convex hulls.

    Args:
        nmds: NMDSResult with points array and stress.
        metadata: DataFrame with 'Period' and 'Site' columns matching point order.
        output_dir: Directory to write output files.
        filename_prefix: Base filename for outputs.
    """
    if nmds.points.size == 0:
        return

    fig, ax = plt.subplots(figsize=(10, 8))
    _apply_nmds_theme(ax)

    periods = metadata["Period"].unique()
    for period in periods:
        mask = metadata["Period"] == period
        points = nmds.points[mask]
        color = PERIOD_COLORS.get(period, "#999999")

        ax.scatter(
            points[:, 0],
            points[:, 1],
            c=color,
            label=period,
            s=60,
            alpha=0.8,
            edgecolors="white",
            linewidth=0.5,
        )

        if len(points) >= 3:
            try:
                hull = ConvexHull(points)
                hull_pts = points[hull.vertices]
                hull_pts = np.vstack([hull_pts, hull_pts[0]])
                ax.fill(hull_pts[:, 0], hull_pts[:, 1], alpha=0.15, color=color)
                ax.plot(
                    hull_pts[:, 0],
                    hull_pts[:, 1],
                    color=color,
                    linewidth=1,
                    alpha=0.5,
                )
            except QhullError:
                pass

    ax.set_xlabel("NMDS1")
    ax.set_ylabel("NMDS2")
    ax.set_title(f"NMDS Ordination (stress = {nmds.stress:.3f})")
    ax.legend(loc="best", framealpha=0.9)

    save_figure(fig, output_dir / filename_prefix)


def plot_nmds_per_site(
    nmds: NMDSResult,
    metadata: pd.DataFrame,
    output_dir: Path,
    filename_prefix: str = "NMDS_PerSite",
) -> None:
    """Plot per-site NMDS with temporal trend arrows.

    Each site gets its own figure showing movement through ordination space
    over time, with arrows indicating direction of change.

    Args:
        nmds: NMDSResult with points array and stress.
        metadata: DataFrame with 'Period', 'Site', 'Date' columns.
        output_dir: Directory to write output files.
        filename_prefix: Base filename for outputs.
    """
    if nmds.points.size == 0:
        return

    sites = metadata["Site"].unique()

    for site in sites:
        fig, ax = plt.subplots(figsize=(6, 5))
        _apply_nmds_theme(ax)

        site_mask = metadata["Site"] == site
        site_points = nmds.points[site_mask]
        site_meta = metadata[site_mask].reset_index(drop=True)

        sort_order = site_meta["Date"].argsort()
        sorted_points = site_points[sort_order]
        sorted_meta = site_meta.iloc[sort_order].reset_index(drop=True)

        for period in sorted_meta["Period"].unique():
            pmask = sorted_meta["Period"] == period
            pts = sorted_points[pmask.to_numpy()]
            color = PERIOD_COLORS.get(period, "#999999")
            ax.scatter(
                pts[:, 0],
                pts[:, 1],
                c=color,
                label=period,
                s=40,
                alpha=0.8,
                edgecolors="white",
                linewidth=0.5,
            )

        for i in range(len(sorted_points) - 1):
            ax.annotate(
                "",
                xy=(sorted_points[i + 1, 0], sorted_points[i + 1, 1]),
                xytext=(sorted_points[i, 0], sorted_points[i, 1]),
                arrowprops={"arrowstyle": "->", "color": "gray", "lw": 0.8},
            )

        ax.set_title(f"{site} (stress = {nmds.stress:.3f})")
        ax.set_xlabel("NMDS1")
        ax.set_ylabel("NMDS2")
        ax.legend(loc="best", framealpha=0.9)

        save_figure(fig, output_dir / f"{filename_prefix}_{site}")
