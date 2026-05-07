"""Tests for clarity plot rendering."""

from __future__ import annotations

from pathlib import Path

import pandas as pd

from mgen.plots.clarity import (
    add_quarter_column,
    plot_clarity_boxplot,
    plot_clarity_ntu_relationship,
    plot_clarity_timeseries,
    prepare_ntu_data,
    resolve_ntu_sensor_column,
)

# ---------------------------------------------------------------------------
# Helper tests
# ---------------------------------------------------------------------------


class TestResolveNtuSensorColumn:
    """Tests for NTU column name resolution (typo handling)."""

    def test_typo_spelling(self) -> None:
        df = pd.DataFrame({"NTU-Continous Sensor": [1]})
        assert resolve_ntu_sensor_column(df) == "NTU-Continous Sensor"

    def test_correct_spelling(self) -> None:
        df = pd.DataFrame({"NTU-Continuous Sensor": [1]})
        assert resolve_ntu_sensor_column(df) == "NTU-Continuous Sensor"

    def test_neither_present(self) -> None:
        df = pd.DataFrame({"other": [1]})
        assert resolve_ntu_sensor_column(df) is None

    def test_typo_takes_precedence(self) -> None:
        df = pd.DataFrame({"NTU-Continous Sensor": [1], "NTU-Continuous Sensor": [2]})
        assert resolve_ntu_sensor_column(df) == "NTU-Continous Sensor"


class TestAddQuarterColumn:
    """Tests for quarter label generation and ordering."""

    def test_adds_quarter_column(self) -> None:
        df = pd.DataFrame({"Date": pd.to_datetime(["2024-01-15", "2024-06-15"])})
        result = add_quarter_column(df)
        assert "Quarter" in result.columns
        assert list(result["Quarter"]) == ["2024 Q1", "2024 Q2"]

    def test_chronological_order_with_unsorted_input(self) -> None:
        df = pd.DataFrame(
            {"Date": pd.to_datetime(["2024-06-15", "2023-01-15", "2024-01-15"])}
        )
        result = add_quarter_column(df)
        quarters = result["Quarter"].cat.categories.tolist()
        assert quarters == ["2023 Q1", "2024 Q1", "2024 Q2"]

    def test_drops_rows_with_missing_dates(self) -> None:
        df = pd.DataFrame({"Date": ["2024-01-15", None, "not-a-date"]})
        result = add_quarter_column(df)
        assert len(result) == 1


class TestPrepareNtuData:
    """Tests for NTU data preparation."""

    def test_returns_dataframe_with_valid_data(self, clarity_df: pd.DataFrame) -> None:
        result = prepare_ntu_data(clarity_df)
        assert result is not None
        assert "x" in result.columns
        assert "y" in result.columns

    def test_returns_none_without_sensor_column(self) -> None:
        df = pd.DataFrame({"Site": ["CM1"], "NTU-Lab": [5.0]})
        assert prepare_ntu_data(df) is None

    def test_returns_none_without_lab_column(self) -> None:
        df = pd.DataFrame({"Site": ["CM1"], "NTU-Continous Sensor": [5.0]})
        assert prepare_ntu_data(df) is None

    def test_returns_none_with_insufficient_data(self) -> None:
        df = pd.DataFrame(
            {
                "Site": ["CM1"],
                "NTU-Continous Sensor": [5.0],
                "NTU-Lab": [5.0],
            }
        )
        assert prepare_ntu_data(df) is None

    def test_filters_to_known_sites(self) -> None:
        df = pd.DataFrame(
            {
                "Site": ["UNKNOWN", "UNKNOWN", "UNKNOWN"],
                "NTU-Continous Sensor": [1.0, 2.0, 3.0],
                "NTU-Lab": [1.0, 2.0, 3.0],
            }
        )
        assert prepare_ntu_data(df) is None

    def test_coerces_non_numeric_to_nan(self) -> None:
        df = pd.DataFrame(
            {
                "Site": ["CM1", "CM1", "CM1"],
                "NTU-Continous Sensor": ["abc", 2.0, 3.0],
                "NTU-Lab": [1.0, "xyz", 3.0],
            }
        )
        result = prepare_ntu_data(df)
        # Only 1 valid row (3rd), n<2 so None
        assert result is None


# ---------------------------------------------------------------------------
# Boxplot tests
# ---------------------------------------------------------------------------


class TestPlotClarityBoxplot:
    """Structural tests for clarity boxplot with attribute bands."""

    def test_returns_file_paths(self, tmp_path: Path, clarity_df: pd.DataFrame) -> None:
        paths = plot_clarity_boxplot(clarity_df, tmp_path)
        assert len(paths) > 0
        for p in paths:
            assert p.exists()
            assert p.stat().st_size > 0

    def test_creates_png_and_pdf(
        self, tmp_path: Path, clarity_df: pd.DataFrame
    ) -> None:
        paths = plot_clarity_boxplot(clarity_df, tmp_path)
        extensions = {p.suffix for p in paths}
        assert ".png" in extensions
        assert ".pdf" in extensions

    def test_file_names(self, tmp_path: Path, clarity_df: pd.DataFrame) -> None:
        paths = plot_clarity_boxplot(clarity_df, tmp_path)
        stems = {p.stem for p in paths}
        assert "clarity_boxplot" in stems

    def test_empty_dataframe_returns_empty(self, tmp_path: Path) -> None:
        empty = pd.DataFrame(columns=["Site", "Clarity (mm)"])
        assert plot_clarity_boxplot(empty, tmp_path) == []

    def test_unknown_sites_filtered(self, tmp_path: Path) -> None:
        df = pd.DataFrame({"Site": ["UNKNOWN"] * 5, "Clarity (mm)": [800.0] * 5})
        assert plot_clarity_boxplot(df, tmp_path) == []


# ---------------------------------------------------------------------------
# Time-series tests
# ---------------------------------------------------------------------------


class TestPlotClarityTimeseries:
    """Structural tests for faceted clarity time-series."""

    def test_returns_file_paths(self, tmp_path: Path, clarity_df: pd.DataFrame) -> None:
        paths = plot_clarity_timeseries(clarity_df, tmp_path)
        assert len(paths) > 0
        for p in paths:
            assert p.exists()
            assert p.stat().st_size > 0

    def test_creates_png_and_pdf(
        self, tmp_path: Path, clarity_df: pd.DataFrame
    ) -> None:
        paths = plot_clarity_timeseries(clarity_df, tmp_path)
        extensions = {p.suffix for p in paths}
        assert ".png" in extensions
        assert ".pdf" in extensions

    def test_file_names(self, tmp_path: Path, clarity_df: pd.DataFrame) -> None:
        paths = plot_clarity_timeseries(clarity_df, tmp_path)
        stems = {p.stem for p in paths}
        assert "clarity_timeseries" in stems

    def test_empty_dataframe_returns_empty(self, tmp_path: Path) -> None:
        empty = pd.DataFrame(columns=["Site", "Date", "Clarity (mm)"])
        assert plot_clarity_timeseries(empty, tmp_path) == []


# ---------------------------------------------------------------------------
# NTU relationship tests
# ---------------------------------------------------------------------------


class TestPlotClarityNtuRelationship:
    """Structural tests for NTU sensor vs lab scatter."""

    def test_returns_file_paths(self, tmp_path: Path, clarity_df: pd.DataFrame) -> None:
        paths = plot_clarity_ntu_relationship(clarity_df, tmp_path)
        assert len(paths) > 0
        for p in paths:
            assert p.exists()
            assert p.stat().st_size > 0

    def test_creates_png_and_pdf(
        self, tmp_path: Path, clarity_df: pd.DataFrame
    ) -> None:
        paths = plot_clarity_ntu_relationship(clarity_df, tmp_path)
        extensions = {p.suffix for p in paths}
        assert ".png" in extensions
        assert ".pdf" in extensions

    def test_file_names(self, tmp_path: Path, clarity_df: pd.DataFrame) -> None:
        paths = plot_clarity_ntu_relationship(clarity_df, tmp_path)
        stems = {p.stem for p in paths}
        assert "clarity_ntu_relationship" in stems

    def test_missing_ntu_columns_returns_empty(self, tmp_path: Path) -> None:
        df = pd.DataFrame({"Site": ["CM1"], "other": [1]})
        assert plot_clarity_ntu_relationship(df, tmp_path) == []

    def test_insufficient_data_returns_empty(self, tmp_path: Path) -> None:
        df = pd.DataFrame(
            {
                "Site": ["CM1"],
                "NTU-Continous Sensor": [5.0],
                "NTU-Lab": [5.0],
            }
        )
        assert plot_clarity_ntu_relationship(df, tmp_path) == []
