"""Tests for macro_species domain — taxa pivot to long format."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from unittest.mock import patch

import pandas as pd

from mgen.domain.macro_species import process_macro_species_domain
from mgen.shared.errors import DomainResult
from mgen.shared.schemas import MACRO_SPECIES_COLUMNS, MACRO_SPECIES_DTYPES


class TestProcessMacroSpeciesDomain:
    """Integration tests for the macro species pivot pipeline."""

    def test_returns_domain_result(self, example_macro_db: Path) -> None:
        result = process_macro_species_domain(example_macro_db)

        assert isinstance(result, DomainResult)

    def test_result_is_ok(self, example_macro_db: Path) -> None:
        result = process_macro_species_domain(example_macro_db)

        assert result.ok

    def test_result_contains_macro_species_key(self, example_macro_db: Path) -> None:
        result = process_macro_species_domain(example_macro_db)

        assert "MacroSpecies" in result.data

    def test_has_correct_columns(self, example_macro_db: Path) -> None:
        result = process_macro_species_domain(example_macro_db)
        df = result.data["MacroSpecies"]

        assert list(df.columns) == MACRO_SPECIES_COLUMNS

    def test_has_correct_dtypes(self, example_macro_db: Path) -> None:
        result = process_macro_species_domain(example_macro_db)
        df = result.data["MacroSpecies"]

        for col, expected_dtype in MACRO_SPECIES_DTYPES.items():
            assert str(df[col].dtype) == expected_dtype, (
                f"Column {col}: expected {expected_dtype}, got {df[col].dtype}"
            )

    def test_no_zero_tallies(self, example_macro_db: Path) -> None:
        """Only non-zero counts should appear (sparse format)."""
        result = process_macro_species_domain(example_macro_db)
        df = result.data["MacroSpecies"]

        assert (df["Tally"] > 0).all()

    def test_no_nan_tallies(self, example_macro_db: Path) -> None:
        """Tally column must not contain NaN values."""
        result = process_macro_species_domain(example_macro_db)
        df = result.data["MacroSpecies"]

        assert df["Tally"].notna().all()

    def test_has_expected_row_count(self, example_macro_db: Path) -> None:
        """Full dataset should produce ~3194 rows."""
        result = process_macro_species_domain(example_macro_db)
        df = result.data["MacroSpecies"]

        # Allow tolerance for minor dataset variations
        assert 2800 < len(df) < 4000

    def test_phase_values_are_seasons(self, example_macro_db: Path) -> None:
        """Phase column should contain season labels from source."""
        result = process_macro_species_domain(example_macro_db)
        df = result.data["MacroSpecies"]

        valid_phases = {"Baseline", "Construction", "Additional", "Routine"}
        assert set(df["Phase"].unique()).issubset(valid_phases)

    def test_taxa_column_populated(self, example_macro_db: Path) -> None:
        """Taxa (TaxonGroup) should never be empty."""
        result = process_macro_species_domain(example_macro_db)
        df = result.data["MacroSpecies"]

        assert df["Taxa"].notna().all()
        assert (df["Taxa"].str.strip() != "").all()

    def test_species_column_populated(self, example_macro_db: Path) -> None:
        """Species (Taxon) should never be empty."""
        result = process_macro_species_domain(example_macro_db)
        df = result.data["MacroSpecies"]

        assert df["Species"].notna().all()
        assert (df["Species"].str.strip() != "").all()

    def test_invalid_path_returns_error(self, tmp_path: Path) -> None:
        result = process_macro_species_domain(tmp_path / "nonexistent.xlsx")

        assert not result.ok
        assert len(result.errors) > 0

    def test_invalid_path_error_references_domain(self, tmp_path: Path) -> None:
        result = process_macro_species_domain(tmp_path / "nonexistent.xlsx")

        assert result.errors[0].domain == "MacroSpecies"

    def test_unexpected_ingest_error_returns_error(self, tmp_path: Path) -> None:
        """Unexpected exceptions during ingest are caught and reported."""
        db_path = tmp_path / "dummy.xlsx"
        db_path.touch()

        with patch(
            "mgen.domain.macro_species.ingest_raw_data",
            side_effect=RuntimeError("disk failure"),
        ):
            result = process_macro_species_domain(db_path)

        assert not result.ok
        assert "Unexpected error" in result.errors[0].message

    def test_missing_sample_column_warns_and_continues(
        self, example_macro_db: Path
    ) -> None:
        """A KeyError on a sample column logs a warning but doesn't fail."""
        with patch(
            "mgen.domain.macro_species._pivot_sample",
            side_effect=KeyError("bad_col"),
        ):
            result = process_macro_species_domain(example_macro_db)

        # All samples fail → no rows → error result
        assert not result.ok
        assert any(e.severity == "warning" for e in result.errors)

    def test_unexpected_sample_error_warns_and_continues(
        self, example_macro_db: Path
    ) -> None:
        """Unexpected per-sample errors are caught as warnings."""
        with patch(
            "mgen.domain.macro_species._pivot_sample",
            side_effect=TypeError("unexpected"),
        ):
            result = process_macro_species_domain(example_macro_db)

        assert not result.ok
        assert any("Unexpected error" in e.message for e in result.errors)

    def test_all_zero_counts_returns_error(self, tmp_path: Path) -> None:
        """When all tallies are zero, returns an error result."""
        metadata = pd.DataFrame(
            {
                "sample_id": [10],
                "Season": ["Baseline"],
                "Date": [pd.Timestamp("2020-01-01")],
                "Site": ["EM1"],
                "Replicate": [1],
            }
        )
        taxa_counts = pd.DataFrame(
            {
                "TaxonGroup": ["Mayflies"],
                "Taxon": ["Deleatidium"],
                10: pd.array([0], dtype="Int64"),
            }
        )

        @dataclass
        class FakeBundle:
            sample_metadata: pd.DataFrame
            taxa_counts: pd.DataFrame
            metric_rows: pd.DataFrame
            mci_scores: pd.DataFrame

        bundle = FakeBundle(
            sample_metadata=metadata,
            taxa_counts=taxa_counts,
            metric_rows=pd.DataFrame(),
            mci_scores=pd.DataFrame(),
        )

        db_path = tmp_path / "zeros.xlsx"
        db_path.touch()

        with patch("mgen.domain.macro_species.ingest_raw_data", return_value=bundle):
            result = process_macro_species_domain(db_path)

        assert not result.ok
        assert "No non-zero taxa counts" in result.errors[-1].message

    def test_sample_not_in_index_skipped(self, tmp_path: Path) -> None:
        """Sample IDs not found in meta_lookup index are skipped."""
        metadata = pd.DataFrame(
            {
                "sample_id": [10, None],
                "Season": ["Baseline", "Baseline"],
                "Date": [
                    pd.Timestamp("2020-01-01"),
                    pd.Timestamp("2020-01-01"),
                ],
                "Site": ["EM1", "EM1"],
                "Replicate": [1, 2],
            }
        )
        taxa_counts = pd.DataFrame(
            {
                "TaxonGroup": ["Mayflies"],
                "Taxon": ["Deleatidium"],
                10: pd.array([5], dtype="Int64"),
            }
        )

        @dataclass
        class FakeBundle:
            sample_metadata: pd.DataFrame
            taxa_counts: pd.DataFrame
            metric_rows: pd.DataFrame
            mci_scores: pd.DataFrame

        bundle = FakeBundle(
            sample_metadata=metadata,
            taxa_counts=taxa_counts,
            metric_rows=pd.DataFrame(),
            mci_scores=pd.DataFrame(),
        )

        db_path = tmp_path / "test.xlsx"
        db_path.touch()

        with patch(
            "mgen.domain.macro_species.ingest_raw_data",
            return_value=bundle,
        ):
            result = process_macro_species_domain(db_path)

        # Sample 10 succeeds, None is skipped
        assert result.ok
