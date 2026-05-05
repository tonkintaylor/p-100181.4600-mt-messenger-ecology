"""Tests for shared validation primitives."""

from __future__ import annotations

import pandas as pd
import pytest

from mgen.shared.validation import (
    check_no_nulls,
    check_required_columns,
    check_value_range,
)


class TestCheckRequiredColumns:
    def test_all_present_returns_empty(self) -> None:
        df = pd.DataFrame({"A": [1], "B": [2], "C": [3]})

        errors = check_required_columns(
            df, ["A", "B", "C"], domain="test", file="f.xlsx", sheet="Sheet1"
        )

        assert errors == []

    def test_missing_columns_returns_error(self) -> None:
        df = pd.DataFrame({"A": [1]})

        errors = check_required_columns(
            df, ["A", "B", "C"], domain="test", file="f.xlsx", sheet="Sheet1"
        )

        assert len(errors) == 1
        assert errors[0].severity == "error"
        assert "B" in errors[0].message
        assert "C" in errors[0].message

    def test_empty_expected_returns_empty(self) -> None:
        df = pd.DataFrame({"A": [1]})

        errors = check_required_columns(
            df, [], domain="test", file="f.xlsx", sheet="Sheet1"
        )

        assert errors == []


class TestCheckNoNulls:
    def test_no_nulls_returns_empty(self) -> None:
        df = pd.DataFrame({"A": [1, 2, 3], "B": ["x", "y", "z"]})

        errors = check_no_nulls(
            df, ["A", "B"], domain="test", file="f.xlsx", sheet="Sheet1"
        )

        assert errors == []

    def test_nulls_present_returns_error_with_row_indices(self) -> None:
        df = pd.DataFrame({"A": [1, None, 3], "B": [None, None, "z"]})

        errors = check_no_nulls(
            df, ["A", "B"], domain="test", file="f.xlsx", sheet="Sheet1"
        )

        assert len(errors) == 2
        # Column A has 1 null
        a_error = next(e for e in errors if "'A'" in e.location)
        assert "1 null" in a_error.message
        # Column B has 2 nulls
        b_error = next(e for e in errors if "'B'" in e.location)
        assert "2 null" in b_error.message

    def test_missing_column_is_skipped(self) -> None:
        df = pd.DataFrame({"A": [1, 2]})

        errors = check_no_nulls(
            df, ["A", "NonExistent"], domain="test", file="f.xlsx", sheet="Sheet1"
        )

        assert errors == []

    def test_shows_first_five_rows_only(self) -> None:
        df = pd.DataFrame({"A": [None] * 10})

        errors = check_no_nulls(df, ["A"], domain="test", file="f.xlsx", sheet="Sheet1")

        assert len(errors) == 1
        assert "rows [0, 1, 2, 3, 4]" in errors[0].location


class TestCheckValueRange:
    def test_within_range_returns_empty(self) -> None:
        df = pd.DataFrame({"val": [0.0, 50.0, 100.0]})

        errors = check_value_range(
            df, "val", min_val=0, max_val=100, domain="test", file="f.xlsx", sheet="S"
        )

        assert errors == []

    def test_below_minimum_returns_error(self) -> None:
        df = pd.DataFrame({"val": [-1.0, 5.0, 10.0]})

        errors = check_value_range(
            df, "val", min_val=0, domain="test", file="f.xlsx", sheet="S"
        )

        assert len(errors) == 1
        assert "below minimum" in errors[0].message

    def test_above_maximum_returns_error(self) -> None:
        df = pd.DataFrame({"val": [50.0, 101.0]})

        errors = check_value_range(
            df, "val", max_val=100, domain="test", file="f.xlsx", sheet="S"
        )

        assert len(errors) == 1
        assert "above maximum" in errors[0].message

    def test_missing_column_returns_empty(self) -> None:
        df = pd.DataFrame({"other": [1, 2, 3]})

        errors = check_value_range(
            df, "val", min_val=0, max_val=100, domain="test", file="f.xlsx", sheet="S"
        )

        assert errors == []

    def test_non_numeric_values_detected(self) -> None:
        df = pd.DataFrame({"val": [1.0, "N/A", ">10", 5.0]})

        errors = check_value_range(
            df, "val", min_val=0, max_val=100, domain="test", file="f.xlsx", sheet="S"
        )

        assert any("non-numeric" in e.message.lower() for e in errors)
        non_numeric_error = next(
            e for e in errors if "non-numeric" in e.message.lower()
        )
        assert "2" in non_numeric_error.message  # 2 non-numeric values

    @pytest.mark.parametrize(
        ("min_val", "max_val"),
        [(None, None), (None, 100), (0, None)],
    )
    def test_partial_bounds(self, min_val: float | None, max_val: float | None) -> None:
        df = pd.DataFrame({"val": [50.0]})

        errors = check_value_range(
            df,
            "val",
            min_val=min_val,
            max_val=max_val,
            domain="test",
            file="f.xlsx",
            sheet="S",
        )

        assert errors == []
