"""Tests for output schemas — validates contract consistency."""

from __future__ import annotations

from mgen.shared.schemas import (
    MACRO1_COLUMNS,
    MACRO1_DTYPES,
    MACRO_SPECIES_COLUMNS,
    MACRO_SPECIES_DTYPES,
    SEDIMENT_COLUMNS,
    SEDIMENT_DTYPES,
    SEDIMENT_SIZE_COLUMNS,
    SEDIMENT_SIZE_DTYPES,
)


class TestSchemaConsistency:
    def test_macro1_columns_match_dtypes(self) -> None:
        assert set(MACRO1_COLUMNS) == set(MACRO1_DTYPES.keys())

    def test_macro_species_columns_match_dtypes(self) -> None:
        assert set(MACRO_SPECIES_COLUMNS) == set(MACRO_SPECIES_DTYPES.keys())

    def test_sediment_columns_match_dtypes(self) -> None:
        assert set(SEDIMENT_COLUMNS) == set(SEDIMENT_DTYPES.keys())

    def test_sediment_size_columns_match_dtypes(self) -> None:
        assert set(SEDIMENT_SIZE_COLUMNS) == set(SEDIMENT_SIZE_DTYPES.keys())
