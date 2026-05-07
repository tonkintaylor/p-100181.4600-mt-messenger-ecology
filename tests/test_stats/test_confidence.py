"""Tests for t-distribution confidence interval calculation."""

from __future__ import annotations

import pandas as pd
import pytest

from mgen.stats.confidence import MetricSummary, summarize_with_ci


class TestSummarizeWithCI:
    """Test the summarize_with_ci function."""

    def test_known_values(self) -> None:
        # 4 values: mean=5.5, std=1.2909944, se=0.6454972
        # t_crit(0.975, df=3) = 3.182446
        # margin = 3.182446 * 0.6454972 = 2.054
        values = pd.Series([4.0, 5.0, 6.0, 7.0])
        result = summarize_with_ci(values)
        assert result.mean == pytest.approx(5.5)
        assert result.n == 4
        assert result.ci_lower == pytest.approx(5.5 - 2.054, abs=0.01)
        assert result.ci_upper == pytest.approx(5.5 + 2.054, abs=0.01)

    def test_ci_clamped_to_zero(self) -> None:
        # Values close to zero → CI lower bound clamped at 0
        values = pd.Series([0.5, 0.3, 0.1, 0.2])
        result = summarize_with_ci(values, clamp_lower=0.0)
        assert result.ci_lower >= 0.0

    def test_ci_clamped_to_100(self) -> None:
        # Values close to 100 → CI upper bound clamped at 100
        values = pd.Series([98.0, 99.0, 100.0, 99.5])
        result = summarize_with_ci(values, clamp_upper=100.0)
        assert result.ci_upper <= 100.0

    def test_single_value_returns_nan_ci(self) -> None:
        # Can't compute CI with n=1
        values = pd.Series([5.0])
        result = summarize_with_ci(values)
        assert result.mean == pytest.approx(5.0)
        assert result.n == 1
        # CI should be NaN for single value (no variance)
        assert pd.isna(result.ci_lower)
        assert pd.isna(result.ci_upper)

    def test_custom_confidence_level(self) -> None:
        values = pd.Series([4.0, 5.0, 6.0, 7.0])
        result_95 = summarize_with_ci(values, confidence=0.95)
        result_99 = summarize_with_ci(values, confidence=0.99)
        # 99% CI should be wider than 95% CI
        width_95 = result_95.ci_upper - result_95.ci_lower
        width_99 = result_99.ci_upper - result_99.ci_lower
        assert width_99 > width_95

    def test_returns_metric_summary_dataclass(self) -> None:
        values = pd.Series([4.0, 5.0, 6.0, 7.0])
        result = summarize_with_ci(values)
        assert isinstance(result, MetricSummary)
