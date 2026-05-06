"""Confidence interval calculation using the t-distribution.

Matches the R implementation's summary_with_CI() helper function
which uses t-based confidence intervals clamped to valid ranges.
"""

from __future__ import annotations

import math
from dataclasses import dataclass

import pandas as pd
from scipy import stats

__all__ = ["MetricSummary", "summarize_with_ci"]


@dataclass(frozen=True)
class MetricSummary:
    """Summary statistics for a metric with confidence interval.

    Attributes:
        mean: Sample mean.
        ci_lower: Lower bound of confidence interval.
        ci_upper: Upper bound of confidence interval.
        n: Sample size.
    """

    mean: float
    ci_lower: float
    ci_upper: float
    n: int


def summarize_with_ci(
    values: pd.Series,
    confidence: float = 0.95,
    clamp_lower: float = 0.0,
    clamp_upper: float = 100.0,
) -> MetricSummary:
    """Compute mean and t-distribution confidence interval.

    Args:
        values: Series of numeric values (e.g. replicate measurements).
        confidence: Confidence level (default 0.95 for 95% CI).
        clamp_lower: Lower bound to clamp CI (default 0.0).
        clamp_upper: Upper bound to clamp CI (default 100.0).

    Returns:
        MetricSummary with mean, CI bounds, and sample size.
        CI bounds are NaN if n < 2 (insufficient data for variance).
    """
    n = len(values)
    mean = values.mean()

    if n < 2:
        return MetricSummary(
            mean=float(mean), ci_lower=float("nan"), ci_upper=float("nan"), n=n
        )

    se = values.std(ddof=1) / math.sqrt(n)
    t_crit = stats.t.ppf((1 + confidence) / 2, df=n - 1)
    margin = t_crit * se

    ci_lower = max(mean - margin, clamp_lower)
    ci_upper = min(mean + margin, clamp_upper)

    return MetricSummary(
        mean=float(mean),
        ci_lower=float(ci_lower),
        ci_upper=float(ci_upper),
        n=n,
    )
