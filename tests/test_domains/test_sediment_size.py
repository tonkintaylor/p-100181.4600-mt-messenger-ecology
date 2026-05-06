"""Tests for the SedimentSize domain module.

Validates that process_sediment_size_domain() correctly reads the Aquatic
Monitoring Database "Sediment" sheet and produces a DomainResult with the
SedimentSize output DataFrame matching SEDIMENT_SIZE_COLUMNS schema.
"""

from __future__ import annotations

from pathlib import Path
from unittest.mock import patch

import pandas as pd

from mgen.domain.sediment import process_sediment_domain
from mgen.domain.sediment_size import process_sediment_size_domain
from mgen.shared.schemas import SEDIMENT_SIZE_COLUMNS, SEDIMENT_SIZE_DTYPES


class TestProcessSedimentSizeDomainIntegration:
    """Integration tests using the real Aquatic Monitoring Database fixture."""

    def test_returns_domain_result_ok(self, example_aquatic_db: Path) -> None:
        result = process_sediment_size_domain(example_aquatic_db)
        assert result.ok

    def test_data_key_is_sediment_size(self, example_aquatic_db: Path) -> None:
        result = process_sediment_size_domain(example_aquatic_db)
        assert "SedimentSize" in result.data

    def test_columns_match_schema(self, example_aquatic_db: Path) -> None:
        result = process_sediment_size_domain(example_aquatic_db)
        df = result.data["SedimentSize"]
        assert list(df.columns) == SEDIMENT_SIZE_COLUMNS

    def test_dtypes_match_schema(self, example_aquatic_db: Path) -> None:
        result = process_sediment_size_domain(example_aquatic_db)
        df = result.data["SedimentSize"]
        for col, expected_dtype in SEDIMENT_SIZE_DTYPES.items():
            assert str(df[col].dtype) == expected_dtype, (
                f"Column {col!r}: expected {expected_dtype}, got {df[col].dtype}"
            )

    def test_row_count_at_least_78(self, example_aquatic_db: Path) -> None:
        """Source has 87 rows; expected output has ≥78 rows."""
        result = process_sediment_size_domain(example_aquatic_db)
        df = result.data["SedimentSize"]
        assert len(df) >= 78

    def test_period_values_are_valid(self, example_aquatic_db: Path) -> None:
        result = process_sediment_size_domain(example_aquatic_db)
        df = result.data["SedimentSize"]
        valid_periods = {"Baseline", "Routine Construction", "Incident"}
        assert set(df["Period"].unique()).issubset(valid_periods)

    def test_season_values_are_valid(self, example_aquatic_db: Path) -> None:
        result = process_sediment_size_domain(example_aquatic_db)
        df = result.data["SedimentSize"]
        valid_seasons = {"Spring", "Summer"}
        assert set(df["Season"].unique()).issubset(valid_seasons)

    def test_site_values_are_stripped(self, example_aquatic_db: Path) -> None:
        result = process_sediment_size_domain(example_aquatic_db)
        df = result.data["SedimentSize"]
        for site in df["Site"].unique():
            assert site == site.strip()

    def test_grain_size_columns_are_numeric(self, example_aquatic_db: Path) -> None:
        result = process_sediment_size_domain(example_aquatic_db)
        df = result.data["SedimentSize"]
        grain_cols = SEDIMENT_SIZE_COLUMNS[4:]
        for col in grain_cols:
            assert pd.api.types.is_float_dtype(df[col]), (
                f"Grain-size column {col!r} should be float64"
            )

    def test_grain_size_values_non_negative(self, example_aquatic_db: Path) -> None:
        """Grain-size percentages should be ≥0."""
        result = process_sediment_size_domain(example_aquatic_db)
        df = result.data["SedimentSize"]
        grain_cols = SEDIMENT_SIZE_COLUMNS[4:]
        for col in grain_cols:
            assert (df[col].dropna() >= 0).all(), f"Column {col!r} has negative values"

    def test_no_duplicate_site_date_rows(self, example_aquatic_db: Path) -> None:
        result = process_sediment_size_domain(example_aquatic_db)
        df = result.data["SedimentSize"]
        dupes = df.duplicated(subset=["Site", "Date"], keep=False)
        assert not dupes.any()

    def test_same_row_count_as_sediment_domain(self, example_aquatic_db: Path) -> None:
        """SedimentSize should have the same rows as Sediment (same source)."""
        sed = process_sediment_domain(example_aquatic_db)
        size = process_sediment_size_domain(example_aquatic_db)
        assert len(sed.data["Sediment"]) == len(size.data["SedimentSize"])


class TestProcessSedimentSizeDomainErrors:
    """Error path tests."""

    def test_missing_file_returns_error(self, tmp_path: Path) -> None:
        result = process_sediment_size_domain(tmp_path / "nonexistent.xlsx")
        assert not result.ok

    def test_missing_sediment_sheet(self, tmp_path: Path) -> None:
        fake_path = tmp_path / "fake.xlsx"
        pd.DataFrame({"x": [1]}).to_excel(fake_path, sheet_name="Other")
        result = process_sediment_size_domain(fake_path)
        assert not result.ok

    def test_missing_grain_size_columns(self, tmp_path: Path) -> None:
        """Sheet has metadata columns but no grain-size data."""
        fake_path = tmp_path / "partial.xlsx"
        df = pd.DataFrame(
            {
                " ": ["Baseline"],
                "Site ": ["EM1"],
                "Date": [pd.Timestamp("2020-01-01")],
                "Season": ["Spring"],
            }
        )
        with pd.ExcelWriter(fake_path) as w:
            df.to_excel(w, sheet_name="Sediment", index=False)
        result = process_sediment_size_domain(fake_path)
        assert not result.ok

    @patch("mgen.domain.sediment_ingest.pd.read_excel")
    def test_unexpected_read_error(self, mock_read: object) -> None:
        mock_read.side_effect = RuntimeError("disk failure")
        result = process_sediment_size_domain(Path("any.xlsx"))
        assert not result.ok

    @patch("mgen.domain.sediment_size.read_sediment_sheet")
    def test_unexpected_exception_after_ingest(self, mock_ingest: object) -> None:
        """Exception not wrapped in IngestError is still handled."""
        mock_ingest.side_effect = TypeError("unexpected")
        result = process_sediment_size_domain(Path("any.xlsx"))
        assert not result.ok
