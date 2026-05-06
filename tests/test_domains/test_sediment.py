"""Tests for the Sediment domain module.

Validates that process_sediment_domain() correctly reads the Aquatic Monitoring
Database "Sediment" sheet and produces a DomainResult with the Sediment output
DataFrame matching SEDIMENT_COLUMNS schema.
"""

from __future__ import annotations

from pathlib import Path
from unittest.mock import patch

import pandas as pd

from mgen.domain.sediment import process_sediment_domain
from mgen.shared.schemas import SEDIMENT_COLUMNS, SEDIMENT_DTYPES


class TestProcessSedimentDomainIntegration:
    """Integration tests using the real Aquatic Monitoring Database fixture."""

    def test_returns_domain_result_ok(self, example_aquatic_db: Path) -> None:
        result = process_sediment_domain(example_aquatic_db)
        assert result.ok

    def test_data_key_is_sediment(self, example_aquatic_db: Path) -> None:
        result = process_sediment_domain(example_aquatic_db)
        assert "Sediment" in result.data

    def test_columns_match_schema(self, example_aquatic_db: Path) -> None:
        result = process_sediment_domain(example_aquatic_db)
        df = result.data["Sediment"]
        assert list(df.columns) == SEDIMENT_COLUMNS

    def test_dtypes_match_schema(self, example_aquatic_db: Path) -> None:
        result = process_sediment_domain(example_aquatic_db)
        df = result.data["Sediment"]
        for col, expected_dtype in SEDIMENT_DTYPES.items():
            assert str(df[col].dtype) == expected_dtype, (
                f"Column {col!r}: expected {expected_dtype}, got {df[col].dtype}"
            )

    def test_row_count_at_least_78(self, example_aquatic_db: Path) -> None:
        """Source has 87 rows; expected output has at least 78 rows."""
        result = process_sediment_domain(example_aquatic_db)
        df = result.data["Sediment"]
        assert len(df) >= 78

    def test_period_values_are_valid(self, example_aquatic_db: Path) -> None:
        result = process_sediment_domain(example_aquatic_db)
        df = result.data["Sediment"]
        valid_periods = {"Baseline", "Routine Construction", "Incident"}
        assert set(df["Period"].unique()).issubset(valid_periods)

    def test_season_values_are_valid(self, example_aquatic_db: Path) -> None:
        result = process_sediment_domain(example_aquatic_db)
        df = result.data["Sediment"]
        valid_seasons = {"Spring", "Summer"}
        assert set(df["Season"].unique()).issubset(valid_seasons)

    def test_site_values_are_stripped(self, example_aquatic_db: Path) -> None:
        """Site codes should not have trailing whitespace."""
        result = process_sediment_domain(example_aquatic_db)
        df = result.data["Sediment"]
        for site in df["Site"].unique():
            assert site == site.strip()

    def test_baseline_period_mapping(self, example_aquatic_db: Path) -> None:
        """Source 'Baseline' rows map to Period='Baseline'."""
        result = process_sediment_domain(example_aquatic_db)
        df = result.data["Sediment"]
        baseline = df[df["Period"] == "Baseline"]
        assert len(baseline) > 0

    def test_routine_construction_period_mapping(
        self, example_aquatic_db: Path
    ) -> None:
        """Source 'Construction' + non-Additional → 'Routine Construction'."""
        result = process_sediment_domain(example_aquatic_db)
        df = result.data["Sediment"]
        routine = df[df["Period"] == "Routine Construction"]
        assert len(routine) > 0

    def test_incident_period_mapping(self, example_aquatic_db: Path) -> None:
        """Source 'Construction' + 'Additional - *' → 'Incident'."""
        result = process_sediment_domain(example_aquatic_db)
        df = result.data["Sediment"]
        incident = df[df["Period"] == "Incident"]
        assert len(incident) >= 5

    def test_nan_sam1_preserved(self, example_aquatic_db: Path) -> None:
        """Rows with NaN SAM1 should not be dropped."""
        result = process_sediment_domain(example_aquatic_db)
        df = result.data["Sediment"]
        assert df["SAM1"].isna().sum() >= 1

    def test_dates_are_datetime(self, example_aquatic_db: Path) -> None:
        result = process_sediment_domain(example_aquatic_db)
        df = result.data["Sediment"]
        assert pd.api.types.is_datetime64_any_dtype(df["Date"])

    def test_no_duplicate_site_date_rows(self, example_aquatic_db: Path) -> None:
        result = process_sediment_domain(example_aquatic_db)
        df = result.data["Sediment"]
        dupes = df.duplicated(subset=["Site", "Date"], keep=False)
        assert not dupes.any()


class TestProcessSedimentDomainErrors:
    """Error path tests."""

    def test_missing_file_returns_error(self, tmp_path: Path) -> None:
        result = process_sediment_domain(tmp_path / "nonexistent.xlsx")
        assert not result.ok

    def test_missing_sediment_sheet(self, tmp_path: Path) -> None:
        """File exists but has no 'Sediment' sheet."""
        fake_path = tmp_path / "fake.xlsx"
        pd.DataFrame({"x": [1]}).to_excel(fake_path, sheet_name="Other")
        result = process_sediment_domain(fake_path)
        assert not result.ok

    def test_missing_required_columns(self, tmp_path: Path) -> None:
        """Sediment sheet exists but lacks required columns."""
        fake_path = tmp_path / "bad_cols.xlsx"
        df = pd.DataFrame({"BadCol": [1, 2, 3]})
        with pd.ExcelWriter(fake_path) as w:
            df.to_excel(w, sheet_name="Sediment", index=False)
        result = process_sediment_domain(fake_path)
        assert not result.ok

    @patch("mgen.domain.sediment_ingest.pd.read_excel")
    def test_unexpected_read_error(self, mock_read: object) -> None:
        """Unexpected exception during read is handled gracefully."""
        mock_read.side_effect = RuntimeError("disk failure")
        result = process_sediment_domain(Path("any.xlsx"))
        assert not result.ok

    @patch("mgen.domain.sediment.read_sediment_sheet")
    def test_unexpected_exception_after_ingest(self, mock_ingest: object) -> None:
        """Exception not wrapped in IngestError is still handled."""
        mock_ingest.side_effect = TypeError("unexpected")
        result = process_sediment_domain(Path("any.xlsx"))
        assert not result.ok

    def test_missing_sam_columns(self, tmp_path: Path) -> None:
        """Sheet has base columns but no SAM score columns."""
        fake_path = tmp_path / "no_sam.xlsx"
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
        result = process_sediment_domain(fake_path)
        assert not result.ok
