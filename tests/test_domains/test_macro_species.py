"""Tests for macro_species domain — taxa pivot to long format."""

from __future__ import annotations

from pathlib import Path

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
