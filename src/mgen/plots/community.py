"""NMDS ordination plots for macroinvertebrate community analysis.

Reimplements MountMessMacroNMDSPlots.R as robust Python.

Produces:
- All-sites NMDS with temporal colour gradient (red→blue) and per-site convex hulls
- Subset NMDS: Mangapēpeke, Mimi, Soft-bottom, Hard-bottom catchments
- Per-site individual NMDS with linear regression trend arrow
"""

from __future__ import annotations

from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from matplotlib.colors import LinearSegmentedColormap
from scipy.spatial import ConvexHull, QhullError

from mgen.plots._style import save_figure
from mgen.stats.community import NMDSResult

__all__ = [
    "plot_nmds_grouped",
    "plot_nmds_per_site",
]

# Site shape markers matching R scale_shape_manual
_SITE_MARKERS = {
    "EM1": "o",
    "EM1 Control": "o",
    "EM2": "^",
    "EM3": "s",
    "EM4": "P",
    "EM4 Control": "P",
    "EM5": "X",
    "EM5 Control": "X",
    "EM7": "D",
    "EM8": "d",
}

# Catchment subsets matching R definitions
CATCHMENT_SUBSETS: dict[str, list[str]] = {
    "Mangapepeke": ["EM1", "EM2", "EM3", "EM5"],
    "Mimi": ["EM4", "EM5", "EM7", "EM8"],
    "Soft-bottom": ["EM1", "EM2", "EM4", "EM8"],
    "Hard-bottom": ["EM3", "EM5", "EM7"],
}

# Control site display names
_CONTROL_NAMES = {"EM1": "EM1 Control", "EM4": "EM4 Control", "EM5": "EM5 Control"}

# Red→blue temporal colour ramp
_TEMPORAL_CMAP = LinearSegmentedColormap.from_list("temporal", ["red", "blue"])


def _apply_nmds_theme(ax: plt.Axes) -> None:
    """Apply minimal axis styling for NMDS scatter plots."""
    ax.grid(visible=True, alpha=0.3, linestyle="--")
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    ax.set_xlabel("NMDS1", fontweight="bold")
    ax.set_ylabel("NMDS2", fontweight="bold")


def _temporal_colors(n: int) -> list[str]:
    """Generate n colours on a red-to-blue gradient."""
    if n <= 1:
        return ["red"]
    return [
        "#{:02x}{:02x}{:02x}".format(
            *[int(c * 255) for c in _TEMPORAL_CMAP(i / (n - 1))[:3]]
        )
        for i in range(n)
    ]


def _draw_convex_hulls(
    ax: plt.Axes,
    points: np.ndarray,
    site_labels: np.ndarray,
) -> None:
    """Draw per-site convex hulls with black outlines and alpha fill."""
    unique_sites = np.unique(site_labels)
    for site in unique_sites:
        mask = site_labels == site
        site_pts = points[mask]
        if len(site_pts) >= 3:
            try:
                hull = ConvexHull(site_pts)
                hull_vertices = site_pts[hull.vertices]
                hull_vertices = np.vstack([hull_vertices, hull_vertices[0]])
                ax.fill(
                    hull_vertices[:, 0],
                    hull_vertices[:, 1],
                    alpha=0.15,
                    label=f"_{site}",
                )
                ax.plot(
                    hull_vertices[:, 0],
                    hull_vertices[:, 1],
                    color="black",
                    linewidth=0.8,
                    alpha=0.5,
                )
            except QhullError:
                pass


def plot_nmds_grouped(
    nmds: NMDSResult,
    metadata: pd.DataFrame,
    output_dir: Path,
    filename_prefix: str = "NMDS_AllSites",
    title_suffix: str = "",
    shape_legend_title: str = "Site",
) -> list[Path]:
    """Plot grouped NMDS with temporal colours and per-site convex hulls.

    Points are coloured by sampling date (red→blue gradient) and shaped by site.
    Convex hulls are drawn around each site's points.

    Args:
        nmds: NMDSResult with ordination coordinates.
        metadata: DataFrame with 'Site' and 'Date' columns matching point order.
        output_dir: Output directory for saved files.
        filename_prefix: Base filename.
        title_suffix: Additional text for plot title.
        shape_legend_title: Legend title for site shapes.

    Returns:
        List of saved file paths.
    """
    if nmds.points.size == 0:
        return []

    fig, ax = plt.subplots(figsize=(10, 8))
    _apply_nmds_theme(ax)

    # Sort unique dates for temporal colour assignment
    unique_dates = sorted(metadata["Date"].unique())
    date_to_idx = {d: i for i, d in enumerate(unique_dates)}
    colors = _temporal_colors(len(unique_dates))

    # Draw convex hulls first (behind points)
    _draw_convex_hulls(ax, nmds.points, metadata["Site"].to_numpy())

    # Plot points with temporal colour + site shape
    for site in metadata["Site"].unique():
        mask = metadata["Site"] == site
        site_points = nmds.points[mask]
        site_dates = metadata.loc[mask, "Date"]
        marker = _SITE_MARKERS.get(site, "o")

        for pt, dt in zip(site_points, site_dates, strict=False):
            color = colors[date_to_idx[dt]]
            ax.scatter(
                pt[0],
                pt[1],
                c=color,
                marker=marker,
                s=60,
                edgecolors="white",
                linewidth=0.3,
                zorder=3,
            )

        # Invisible scatter for shape legend
        ax.scatter([], [], marker=marker, c="gray", s=60, label=site)

    ax.legend(
        title=shape_legend_title,
        loc="best",
        framealpha=0.9,
        fontsize=10,
    )

    stress_text = f"stress = {nmds.stress:.3f}"
    title = f"NMDS Ordination ({stress_text})"
    if title_suffix:
        title = f"{title_suffix} — {stress_text}"
    ax.set_title(title, fontsize=14, fontweight="bold")

    return save_figure(fig, output_dir / filename_prefix)


def plot_nmds_per_site(
    nmds: NMDSResult,
    metadata: pd.DataFrame,
    output_dir: Path,
    filename_prefix: str = "NMDS_PerSite",
    catchment_lookup: dict[str, str] | None = None,
) -> list[Path]:
    """Plot per-site NMDS with linear regression trend arrow.

    Each site gets its own NMDS ordination. A linear regression arrow
    shows the overall direction of community change over time (from
    the predicted start position to predicted end position).

    Points are coloured with a temporal red→blue gradient.

    Args:
        nmds: NMDSResult with ordination coordinates.
        metadata: DataFrame with 'Site', 'Date', 'Period' columns.
        output_dir: Output directory.
        filename_prefix: Base filename prefix.
        catchment_lookup: Optional mapping of site → catchment name for titles.

    Returns:
        List of saved file paths.
    """
    if nmds.points.size == 0:
        return []

    all_paths: list[Path] = []
    sites = metadata["Site"].unique()

    for site in sites:
        site_mask = metadata["Site"] == site
        site_points = nmds.points[site_mask]
        site_meta = metadata[site_mask].reset_index(drop=True)

        if len(site_points) <= 2:
            continue

        # Sort by date
        sort_order = site_meta["Date"].argsort()
        sorted_points = site_points[sort_order]
        sorted_meta = site_meta.iloc[sort_order].reset_index(drop=True)

        fig, ax = plt.subplots(figsize=(8, 6))
        _apply_nmds_theme(ax)

        # Temporal colour gradient
        n_pts = len(sorted_points)
        colors = _temporal_colors(n_pts)

        # Plot points with Period-based shape
        for i in range(n_pts):
            period = sorted_meta.iloc[i]["Period"]
            marker = "o" if period == "Baseline" else "^"
            ax.scatter(
                sorted_points[i, 0],
                sorted_points[i, 1],
                c=colors[i],
                marker=marker,
                s=60,
                edgecolors="white",
                linewidth=0.3,
                zorder=3,
            )

        # Linear regression trend arrow (R approach: lm(NMDS1~time), lm(NMDS2~time))
        t_numeric = (
            sorted_meta["Date"].apply(lambda d: d.toordinal()).to_numpy().astype(float)
        )
        if t_numeric.std() > 0:
            # Fit linear models for each NMDS axis
            t_min, t_max = t_numeric.min(), t_numeric.max()
            slope1, intercept1 = np.polyfit(t_numeric, sorted_points[:, 0], 1)
            slope2, intercept2 = np.polyfit(t_numeric, sorted_points[:, 1], 1)

            start_x = slope1 * t_min + intercept1
            start_y = slope2 * t_min + intercept2
            end_x = slope1 * t_max + intercept1
            end_y = slope2 * t_max + intercept2

            ax.annotate(
                "",
                xy=(end_x, end_y),
                xytext=(start_x, start_y),
                arrowprops={
                    "arrowstyle": "-|>",
                    "color": "black",
                    "lw": 1.5,
                    "mutation_scale": 15,
                },
                zorder=4,
            )

        # Legend for period shapes
        ax.scatter([], [], marker="o", c="gray", s=60, label="Baseline")
        ax.scatter([], [], marker="^", c="gray", s=60, label="Construction")
        ax.legend(loc="best", framealpha=0.9, fontsize=10, title="Period")

        # Title with catchment info
        catchment = ""
        if catchment_lookup and site in catchment_lookup:
            catchment = catchment_lookup[site]
        display_name = _CONTROL_NAMES.get(site, site)
        title_parts = [catchment, display_name] if catchment else [display_name]
        ax.set_title(" — ".join(title_parts), fontsize=14, fontweight="bold")

        # Filename uses catchment prefix (matching R: Mangapepeke_EM2.jpeg)
        fname_site = site.replace(" ", "_")
        if catchment:
            fname_catchment = catchment.replace("ē", "e").replace(" ", "_")
            fname = f"{fname_catchment}_{fname_site}"
        else:
            fname = f"{filename_prefix}_{fname_site}"

        paths = save_figure(fig, output_dir / fname)
        all_paths.extend(paths)

    return all_paths
