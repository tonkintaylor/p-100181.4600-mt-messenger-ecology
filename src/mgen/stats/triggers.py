"""Baseline trigger level calculation for ecological monitoring.

Trigger levels are computed as a percentage deviation from the baseline mean:
- Sediment: baseline_mean * (1 + threshold_pct), capped at 100%
- Macro: baseline_mean * (1 - threshold_pct)
"""

from __future__ import annotations

from datetime import date
from typing import Literal

import pandas as pd

__all__ = ["DEFAULT_BASELINE_END", "compute_trigger"]

DEFAULT_BASELINE_END = date(2022, 2, 28)


def compute_trigger(
    df: pd.DataFrame,
    metric_col: str,
    site: str,
    direction: Literal["decline", "increase"] = "decline",
    threshold_pct: float = 0.15,
    cap: float | None = None,
    baseline_end: date = DEFAULT_BASELINE_END,
) -> float:
    """Compute trigger level from baseline mean for a given site and metric.

    Args:
        df: DataFrame with columns Site, Date, Period, and metric_col.
        metric_col: Name of the numeric column to compute trigger for.
        site: Site identifier (e.g. "EM1").
        direction: "increase" multiplies by (1 + threshold_pct),
            "decline" multiplies by (1 - threshold_pct).
        threshold_pct: Fractional deviation from mean (default 0.15 = 15%).
        cap: Upper bound for the trigger value (e.g. 100.0 for percentages).
        baseline_end: Only data with Date <= this date is considered baseline.

    Returns:
        Trigger level as a float.

    Raises:
        ValueError: If no baseline data exists for the given site.
    """
    baseline = df[
        (df["Site"] == site)
        & (df["Period"] == "Baseline")
        & (df["Date"].dt.date <= baseline_end)
    ]

    if baseline.empty:
        msg = f"No baseline data for site={site!r}, metric={metric_col!r}"
        raise ValueError(msg)

    mean = baseline[metric_col].mean()

    if direction == "increase":
        trigger = mean * (1 + threshold_pct)
    else:
        trigger = mean * (1 - threshold_pct)

    if cap is not None:
        trigger = min(trigger, cap)

    return trigger
