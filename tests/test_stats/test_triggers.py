"""Tests for baseline trigger level calculation."""

from __future__ import annotations

from datetime import date

import pandas as pd
import pytest

from mgen.stats.triggers import compute_trigger


class TestComputeTriggerSediment:
    """Sediment trigger: baseline_mean * 1.15, capped at 100."""

    @pytest.fixture
    def sediment_df(self) -> pd.DataFrame:
        return pd.DataFrame(
            {
                "Site": ["EM1"] * 4 + ["EM2"] * 4,
                "Date": pd.to_datetime(
                    [
                        "2021-03-15",
                        "2021-06-15",
                        "2021-09-15",
                        "2021-12-15",
                        "2021-03-15",
                        "2021-06-15",
                        "2021-09-15",
                        "2021-12-15",
                    ]
                ),
                "Period": ["Baseline"] * 8,
                "SAM1": [60.0, 70.0, 80.0, 90.0, 85.0, 90.0, 88.0, 92.0],
                "SAM3": [50.0, 55.0, 60.0, 65.0, 70.0, 72.0, 74.0, 76.0],
            }
        )

    def test_basic_trigger_level(self, sediment_df: pd.DataFrame) -> None:
        result = compute_trigger(
            sediment_df,
            metric_col="SAM1",
            site="EM1",
            direction="increase",
            threshold_pct=0.15,
        )
        assert result == pytest.approx(86.25)

    def test_trigger_capped_at_100(self, sediment_df: pd.DataFrame) -> None:
        result = compute_trigger(
            sediment_df,
            metric_col="SAM1",
            site="EM2",
            direction="increase",
            threshold_pct=0.15,
            cap=100.0,
        )
        assert result == 100.0

    def test_uses_only_baseline_data(self, sediment_df: pd.DataFrame) -> None:
        extra = pd.DataFrame(
            {
                "Site": ["EM1"],
                "Date": pd.to_datetime(["2023-03-15"]),
                "Period": ["Routine Construction"],
                "SAM1": [200.0],
                "SAM3": [200.0],
            }
        )
        df = pd.concat([sediment_df, extra], ignore_index=True)
        result = compute_trigger(
            df,
            metric_col="SAM1",
            site="EM1",
            direction="increase",
            threshold_pct=0.15,
        )
        assert result == pytest.approx(86.25)


class TestComputeTriggerMacro:
    """Macro trigger: baseline_mean * 0.85 (15% decline)."""

    @pytest.fixture
    def macro_df(self) -> pd.DataFrame:
        return pd.DataFrame(
            {
                "Site": ["EM1"] * 4,
                "Date": pd.to_datetime(
                    [
                        "2021-03-15",
                        "2021-06-15",
                        "2021-09-15",
                        "2021-12-15",
                    ]
                ),
                "Period": ["Baseline"] * 4,
                "QMCI": [5.0, 6.0, 5.5, 5.5],
            }
        )

    def test_decline_trigger(self, macro_df: pd.DataFrame) -> None:
        result = compute_trigger(
            macro_df,
            metric_col="QMCI",
            site="EM1",
            direction="decline",
            threshold_pct=0.15,
        )
        assert result == pytest.approx(4.675)

    def test_no_cap_by_default(self, macro_df: pd.DataFrame) -> None:
        result = compute_trigger(
            macro_df,
            metric_col="QMCI",
            site="EM1",
            direction="decline",
            threshold_pct=0.15,
        )
        assert result == pytest.approx(4.675)


class TestComputeTriggerEdgeCases:
    """Edge cases for trigger calculation."""

    def test_empty_baseline_raises(self) -> None:
        df = pd.DataFrame(
            {
                "Site": ["EM1"],
                "Date": pd.to_datetime(["2023-03-15"]),
                "Period": ["Routine Construction"],
                "SAM1": [50.0],
            }
        )
        with pytest.raises(ValueError, match="No baseline data"):
            compute_trigger(df, metric_col="SAM1", site="EM1", direction="increase")

    def test_site_not_found_raises(self) -> None:
        df = pd.DataFrame(
            {
                "Site": ["EM1"],
                "Date": pd.to_datetime(["2021-03-15"]),
                "Period": ["Baseline"],
                "SAM1": [50.0],
            }
        )
        with pytest.raises(ValueError, match="No baseline data"):
            compute_trigger(df, metric_col="SAM1", site="EM99", direction="increase")

    def test_custom_baseline_end_date(self) -> None:
        df = pd.DataFrame(
            {
                "Site": ["EM1"] * 2,
                "Date": pd.to_datetime(["2020-01-15", "2021-06-15"]),
                "Period": ["Baseline", "Baseline"],
                "SAM1": [40.0, 60.0],
            }
        )
        result = compute_trigger(
            df,
            metric_col="SAM1",
            site="EM1",
            direction="increase",
            threshold_pct=0.15,
            baseline_end=date(2021, 1, 1),
        )
        assert result == pytest.approx(46.0)
