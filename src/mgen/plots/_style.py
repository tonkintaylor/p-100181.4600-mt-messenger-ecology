"""Shared plot styling for ecological monitoring figures.

Provides consistent visual language across all plot types:
period colors, summer shading, baseline end marker, and figure saving.
"""

from __future__ import annotations

from datetime import date
from pathlib import Path
from typing import TYPE_CHECKING

import matplotlib.dates as mdates
import matplotlib.patches as mpatches
import matplotlib.pyplot as plt

from mgen.stats.triggers import DEFAULT_BASELINE_END

if TYPE_CHECKING:
    from matplotlib.axes import Axes
    from matplotlib.figure import Figure

__all__ = [
    "BASELINE_END",
    "PERIOD_COLORS",
    "SITES",
    "add_baseline_vline",
    "add_summer_shading",
    "apply_ecology_theme",
    "save_figure",
]

PERIOD_COLORS: dict[str, str] = {
    "Baseline": "#ff9f1c",
    "Routine Construction": "#2ec4b6",
    "Incident": "#e71d36",
}

SITES: list[str] = ["EM1", "EM2", "EM3", "EM5", "EM4", "EM7", "EM8"]

BASELINE_END = DEFAULT_BASELINE_END

_DPI = 300


def apply_ecology_theme(ax: Axes) -> None:
    """Apply standard axis formatting for ecology monitoring plots.

    Sets grid, date formatting with 3-month intervals, and clean spines.
    """
    ax.grid(visible=True, alpha=0.3, linestyle="--")
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)

    ax.xaxis.set_major_locator(mdates.MonthLocator(interval=3))
    ax.xaxis.set_major_formatter(mdates.DateFormatter("%b %y"))
    plt.setp(ax.xaxis.get_majorticklabels(), rotation=90, ha="center")


def add_summer_shading(ax: Axes, year_range: tuple[int, int]) -> None:
    """Add gray shading rectangles for Jan-Mar of each year in range.

    Args:
        ax: Matplotlib axes to add shading to.
        year_range: (start_year, end_year) inclusive.
    """
    for year in range(year_range[0], year_range[1] + 1):
        start = date(year, 1, 1)
        end = date(year, 3, 31)
        rect = mpatches.Rectangle(
            (mdates.date2num(start), ax.get_ylim()[0]),
            width=mdates.date2num(end) - mdates.date2num(start),
            height=ax.get_ylim()[1] - ax.get_ylim()[0],
            facecolor="gray",
            alpha=0.15,
            edgecolor="none",
            zorder=0,
        )
        ax.add_patch(rect)


def add_baseline_vline(ax: Axes, *, add_label: bool = True) -> None:
    """Add dashed vertical line at baseline monitoring end date.

    Args:
        ax: Matplotlib axes to add the line to.
        add_label: If True, include label for legend display.
    """
    label = "Baseline \nMonitoring End" if add_label else None
    ax.axvline(
        x=mdates.date2num(BASELINE_END),
        color="black",
        linestyle="--",
        linewidth=0.8,
        alpha=0.7,
        zorder=1,
        label=label,
    )


def save_figure(
    fig: Figure,
    path: Path,
    formats: list[str] | None = None,
) -> list[Path]:
    """Save figure at 300 DPI in requested formats.

    Args:
        fig: Matplotlib figure to save.
        path: Base path without extension (e.g. Path("output/plot_name")).
        formats: List of format extensions (default: ["png", "pdf"]).

    Returns:
        List of paths to saved files.
    """
    if formats is None:
        formats = ["png", "pdf"]

    paths: list[Path] = []
    for fmt in formats:
        out = path.with_suffix(f".{fmt}")
        out.parent.mkdir(parents=True, exist_ok=True)
        fig.savefig(out, dpi=_DPI, bbox_inches="tight", format=fmt)
        paths.append(out)

    plt.close(fig)
    return paths
