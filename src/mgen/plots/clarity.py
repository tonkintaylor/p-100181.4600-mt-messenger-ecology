"""Water clarity monitoring plots.

Provides:
- Clarity boxplot with attribute bands (A/B/C/D) per site
- Clarity time-series faceted by site with attribute bands
- NTU continuous sensor vs lab scatter with regression

Reimplements ``ref/mike_extra_request/Site clarity plots.R`` in Python.
"""

from __future__ import annotations

import logging
from pathlib import Path
from typing import TYPE_CHECKING

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from matplotlib.patches import Rectangle

from mgen.plots._style import save_figure

if TYPE_CHECKING:
    from matplotlib.axes import Axes

__all__ = [
    "plot_clarity_boxplot",
    "plot_clarity_ntu_relationship",
    "plot_clarity_timeseries",
]

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

SITE_ORDER: list[str] = ["CM1", "CM2", "CM3", "CM4", "CMDSF13", "EM1", "EM4"]

_THRESHOLDS_MM: dict[str, int] = {"A": 930, "B": 760, "C": 610}
_THRESHOLDS_M: dict[str, float] = {k: v / 1000 for k, v in _THRESHOLDS_MM.items()}

_BOXPLOT_BAND_COLORS: dict[str, str] = {
    "A": "#1b9e77",
    "B": "#7570b3",
    "C": "#e6ab02",
    "D": "#d95f02",
}

_TIMESERIES_BAND_COLORS: dict[str, str] = {
    "A": "green",
    "B": "yellow",
    "C": "orange",
    "D": "red",
}

_TIMESERIES_Y_MIN = 300
_TIMESERIES_Y_MAX = 1300

# Possible column names for the continuous-sensor NTU (typo in source data).
_NTU_SENSOR_CANDIDATES = ["NTU-Continous Sensor", "NTU-Continuous Sensor"]


# ---------------------------------------------------------------------------
# Data-preparation helpers (pure functions, easy to test)
# ---------------------------------------------------------------------------


def resolve_ntu_sensor_column(df: pd.DataFrame) -> str | None:
    """Return the NTU continuous-sensor column name present in *df*.

    Handles the known ``Continous`` / ``Continuous`` typo.  Returns ``None``
    if neither variant is found.
    """
    for candidate in _NTU_SENSOR_CANDIDATES:
        if candidate in df.columns:
            return candidate
    return None


def add_quarter_column(df: pd.DataFrame) -> pd.DataFrame:
    """Add a chronologically-ordered ``Quarter`` column (e.g. ``2024 Q1``).

    The input must contain a ``Date`` column parseable by ``pd.to_datetime``.
    Rows with missing dates are dropped.  The returned DataFrame is sorted by
    date so the quarter categorical preserves chronological order.
    """
    out = df.copy()
    out["Date"] = pd.to_datetime(out["Date"], errors="coerce")
    out = out.dropna(subset=["Date"])
    out = out.sort_values("Date")

    out["Quarter"] = (
        out["Date"].dt.year.astype(str) + " Q" + out["Date"].dt.quarter.astype(str)
    )

    # Build ordered categorical from first-appearance order (already sorted).
    quarter_order = out["Quarter"].unique().tolist()
    out["Quarter"] = pd.Categorical(
        out["Quarter"], categories=quarter_order, ordered=True
    )
    return out


def prepare_ntu_data(df: pd.DataFrame) -> pd.DataFrame | None:
    """Prepare NTU sensor vs lab data for regression plotting.

    Returns a DataFrame with columns ``x`` (sensor), ``y`` (lab), ``Site``,
    or ``None`` if insufficient data for a meaningful plot.
    """
    sensor_col = resolve_ntu_sensor_column(df)
    if sensor_col is None or "NTU-Lab" not in df.columns:
        return None

    out = df[["Site", sensor_col, "NTU-Lab"]].copy()
    out = out.rename(columns={sensor_col: "x", "NTU-Lab": "y"})
    out["x"] = pd.to_numeric(out["x"], errors="coerce")
    out["y"] = pd.to_numeric(out["y"], errors="coerce")
    out = out.dropna(subset=["x", "y", "Site"])

    if len(out) < 2 or out["x"].nunique() < 2:
        return None

    # Filter to known sites.
    out = out[out["Site"].isin(SITE_ORDER)].copy()
    out["Site"] = pd.Categorical(out["Site"], categories=SITE_ORDER, ordered=True)
    return out if len(out) >= 2 else None


# ---------------------------------------------------------------------------
# Plot 1 – Clarity boxplot with attribute bands
# ---------------------------------------------------------------------------


def plot_clarity_boxplot(
    df: pd.DataFrame,
    output_dir: Path,
) -> list[Path]:
    """Boxplot + jittered scatter of clarity (m) per site with attribute bands.

    Args:
        df: DataFrame with at least ``Site`` and ``Clarity (mm)`` columns.
        output_dir: Directory to write output figures.

    Returns:
        List of saved file paths (PNG + PDF).
    """
    plot_df = df[["Site", "Clarity (mm)"]].copy()
    plot_df["Clarity (mm)"] = pd.to_numeric(plot_df["Clarity (mm)"], errors="coerce")
    plot_df = plot_df.dropna(subset=["Site", "Clarity (mm)"])
    plot_df = plot_df[plot_df["Site"].isin(SITE_ORDER)]

    if plot_df.empty:
        return []

    plot_df["clarity_m"] = plot_df["Clarity (mm)"] / 1000
    plot_df["Site"] = pd.Categorical(
        plot_df["Site"], categories=SITE_ORDER, ordered=True
    )
    plot_df = plot_df.sort_values("Site")

    # Y-axis limits with padding.
    y_rng = (plot_df["clarity_m"].min(), plot_df["clarity_m"].max())
    pad = 0.04 * (y_rng[1] - y_rng[0])
    if not np.isfinite(pad) or pad == 0:
        pad = 0.05
    y_lower = y_rng[0] - pad
    y_upper = y_rng[1] + pad

    # Build band rectangles.
    bands = [
        ("A", _THRESHOLDS_M["A"], y_upper),
        ("B", _THRESHOLDS_M["B"], _THRESHOLDS_M["A"]),
        ("C", _THRESHOLDS_M["C"], _THRESHOLDS_M["B"]),
        ("D", y_lower, _THRESHOLDS_M["C"]),
    ]

    n_sites = len(SITE_ORDER)
    pad_x = 0.7
    x_left = 1 - pad_x
    x_right = n_sites + pad_x

    fig, ax = plt.subplots(figsize=(10, 6))

    # Attribute bands.
    for band_label, ymin, ymax in bands:
        rect = Rectangle(
            (x_left, ymin),
            x_right - x_left,
            ymax - ymin,
            facecolor=_BOXPLOT_BAND_COLORS[band_label],
            alpha=0.22,
            edgecolor="none",
            zorder=0,
            label=band_label,
        )
        ax.add_patch(rect)

    # Band boundary dashed lines.
    for threshold in _THRESHOLDS_M.values():
        ax.axhline(y=threshold, linestyle="--", color="grey", alpha=0.6, linewidth=0.8)

    # Group data by site for boxplot.
    site_data = [
        plot_df.loc[plot_df["Site"] == s, "clarity_m"].to_numpy() for s in SITE_ORDER
    ]
    positions = list(range(1, n_sites + 1))

    bp = ax.boxplot(
        site_data,
        positions=positions,
        widths=0.6,
        patch_artist=True,
        showfliers=False,
        zorder=2,
    )
    for box in bp["boxes"]:
        box.set(facecolor="lightgrey", edgecolor="black")

    # Jittered scatter.
    rng = np.random.default_rng(42)
    for i, site in enumerate(SITE_ORDER, start=1):
        vals = plot_df.loc[plot_df["Site"] == site, "clarity_m"].to_numpy()
        if len(vals) == 0:
            continue
        jitter = rng.uniform(-0.15, 0.15, size=len(vals))
        ax.scatter(
            i + jitter, vals, color="grey", s=30, alpha=0.9, zorder=3, edgecolors="none"
        )

    ax.set_xlim(x_left, x_right)
    ax.set_ylim(y_lower, y_upper)
    ax.set_xticks(positions)
    ax.set_xticklabels(SITE_ORDER, rotation=45, ha="right")
    ax.set_xlabel("Site")
    ax.set_ylabel("Clarity (m)")
    ax.set_title("Clarity by Site: Boxplot + Scatter with attribute bands")
    ax.legend(title="Band", loc="upper right")

    fig.tight_layout()
    return save_figure(fig, output_dir / "clarity_boxplot")


# ---------------------------------------------------------------------------
# Plot 2 – Clarity time-series faceted by site
# ---------------------------------------------------------------------------


def plot_clarity_timeseries(
    df: pd.DataFrame,
    output_dir: Path,
) -> list[Path]:
    """Faceted clarity time-series (mm) per site with attribute bands.

    Args:
        df: DataFrame with ``Site``, ``Date``, and ``Clarity (mm)`` columns.
        output_dir: Directory to write output figures.

    Returns:
        List of saved file paths (PNG + PDF).
    """
    plot_df = df[["Site", "Date", "Clarity (mm)"]].copy()
    plot_df["Clarity (mm)"] = pd.to_numeric(plot_df["Clarity (mm)"], errors="coerce")
    plot_df = plot_df.dropna(subset=["Site", "Clarity (mm)"])
    plot_df = plot_df[plot_df["Site"].isin(SITE_ORDER)]

    if plot_df.empty:
        return []

    plot_df = add_quarter_column(plot_df)

    # Use ordered quarter categories for x-axis.
    quarter_cats = plot_df["Quarter"].cat.categories.tolist()
    present_sites = [s for s in SITE_ORDER if s in plot_df["Site"].to_numpy()]

    if not present_sites:
        return []

    n_cols = 2
    n_rows = (len(present_sites) + n_cols - 1) // n_cols
    fig, axes = plt.subplots(n_rows, n_cols, figsize=(12, 2.5 * n_rows), squeeze=False)

    bands_mm = [
        ("A", _THRESHOLDS_MM["A"], _TIMESERIES_Y_MAX),
        ("B", _THRESHOLDS_MM["B"], _THRESHOLDS_MM["A"]),
        ("C", _THRESHOLDS_MM["C"], _THRESHOLDS_MM["B"]),
        ("D", _TIMESERIES_Y_MIN, _THRESHOLDS_MM["C"]),
    ]

    for idx, site in enumerate(present_sites):
        row, col = divmod(idx, n_cols)
        ax: Axes = axes[row][col]
        site_df = plot_df[plot_df["Site"] == site].copy()

        # Attribute bands.
        for band_label, ymin, ymax in bands_mm:
            ax.axhspan(
                ymin,
                ymax,
                color=_TIMESERIES_BAND_COLORS[band_label],
                alpha=0.55,
                zorder=0,
            )

        # Band labels on left edge.
        for band_label, ymin, ymax in bands_mm:
            y_mid = (ymin + ymax) / 2
            ax.text(
                -0.02,
                y_mid,
                band_label,
                transform=ax.get_yaxis_transform(),
                ha="right",
                va="center",
                fontsize=6,
                fontweight="bold",
            )

        # Map quarter labels to numeric positions for line + point.
        site_df = site_df.sort_values("Quarter")
        q_indices = [quarter_cats.index(q) for q in site_df["Quarter"]]

        ax.plot(
            q_indices,
            site_df["Clarity (mm)"].to_numpy(),
            color="black",
            linewidth=0.6,
            zorder=2,
        )
        ax.scatter(
            q_indices,
            site_df["Clarity (mm)"].to_numpy(),
            color="grey",
            s=15,
            zorder=3,
        )

        ax.set_ylim(_TIMESERIES_Y_MIN, _TIMESERIES_Y_MAX)
        ax.set_yticks(range(_TIMESERIES_Y_MIN, _TIMESERIES_Y_MAX + 1, 150))
        ax.set_xlim(-0.5, len(quarter_cats) - 0.5)
        ax.set_xticks(range(len(quarter_cats)))
        ax.set_xticklabels(quarter_cats, rotation=45, ha="right", fontsize=6)
        ax.set_title(site, fontsize=7)
        ax.tick_params(axis="y", labelsize=6)

    # Label shared axes.
    for row_idx in range(n_rows):
        axes[row_idx][0].set_ylabel("Clarity (mm)", fontsize=7)
    for col_idx in range(n_cols):
        axes[-1][col_idx].set_xlabel("Quarter", fontsize=7)

    # Hide unused subplots.
    for idx in range(len(present_sites), n_rows * n_cols):
        row, col = divmod(idx, n_cols)
        axes[row][col].set_visible(False)

    fig.suptitle(
        "Water Quality Changes Over Time At Each Site",
        fontsize=10,
        fontweight="bold",
    )
    fig.tight_layout(rect=[0, 0, 1, 0.96])
    return save_figure(fig, output_dir / "clarity_timeseries")


# ---------------------------------------------------------------------------
# Plot 3 – NTU continuous sensor vs lab scatter with regression
# ---------------------------------------------------------------------------


def plot_clarity_ntu_relationship(
    df: pd.DataFrame,
    output_dir: Path,
) -> list[Path]:
    """Scatter of NTU lab vs continuous sensor with regression line.

    Args:
        df: DataFrame with ``Site``, ``NTU-Lab``, and either
            ``NTU-Continous Sensor`` or ``NTU-Continuous Sensor``.
        output_dir: Directory to write output figures.

    Returns:
        List of saved file paths (PNG + PDF), or empty list if
        insufficient data.
    """
    plot_df = prepare_ntu_data(df)
    if plot_df is None or plot_df.empty:
        return []

    x = plot_df["x"].to_numpy()
    y = plot_df["y"].to_numpy()

    # Axis limits (minimum 60 on each axis).
    x_max = max(60.0, float(np.nanmax(x)))
    y_max = max(60.0, float(np.nanmax(y)))

    fig, ax = plt.subplots(figsize=(8, 7))

    # 1:1 reference line.
    diag_max = max(x_max, y_max)
    ax.plot(
        [0, diag_max],
        [0, diag_max],
        linestyle="--",
        color="black",
        linewidth=0.8,
        label="1:1 line",
        zorder=1,
    )

    # Scatter colored by site.
    sites_present = plot_df["Site"].cat.categories
    cmap = plt.get_cmap("tab10")
    for i, site in enumerate(sites_present):
        mask = plot_df["Site"] == site
        if not mask.any():
            continue
        ax.scatter(
            plot_df.loc[mask, "x"],
            plot_df.loc[mask, "y"],
            color=cmap(i),
            s=40,
            alpha=0.95,
            label=site,
            zorder=3,
        )

    # OLS regression line + annotation.
    coeffs = np.polyfit(x, y, deg=1)
    slope, intercept = coeffs
    y_pred = np.polyval(coeffs, x)
    ss_res = np.sum((y - y_pred) ** 2)
    ss_tot = np.sum((y - np.mean(y)) ** 2)
    r_squared = 1 - ss_res / ss_tot if ss_tot != 0 else float("nan")
    rmse = float(np.sqrt(np.mean((y - y_pred) ** 2)))
    n = len(x)

    x_line = np.array([0, x_max])
    ax.plot(
        x_line,
        np.polyval(coeffs, x_line),
        color="red",
        linewidth=0.8,
        zorder=2,
    )

    label_txt = (
        f"y = {slope:.2f}x + {intercept:.2f}\n"
        f"R\u00b2 = {r_squared:.3f}\n"
        f"RMSE = {rmse:.2f}\n"
        f"n = {n}"
    )
    ax.annotate(
        label_txt,
        xy=(0.97, 0.97),
        xycoords="axes fraction",
        ha="right",
        va="top",
        fontsize=9,
        bbox={"boxstyle": "round,pad=0.4", "facecolor": "white", "edgecolor": "grey"},
        zorder=4,
    )

    ax.set_xlim(0, x_max)
    ax.set_ylim(0, y_max)
    ax.set_xlabel("NTU-Continuous Sensor")
    ax.set_ylabel("NTU-Lab")
    ax.set_title("NTU: Continuous Sensor vs NTU: Lab", ha="center")
    ax.legend(title="Site", loc="lower right")

    fig.tight_layout()
    return save_figure(fig, output_dir / "clarity_ntu_relationship")
