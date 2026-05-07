"""Tests for the Data.xlsx writer."""

from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd
import pytest

from mgen.domain.clarity import process_clarity_domain
from mgen.domain.macro import process_macro_domain
from mgen.domain.macro_species import process_macro_species_domain
from mgen.domain.sediment import process_sediment_domain
from mgen.domain.sediment_size import process_sediment_size_domain
from mgen.shared.schemas import (
    MACRO1_COLUMNS,
    MACRO_SPECIES_COLUMNS,
    SEDIMENT_SIZE_COLUMNS,
)
from mgen.writer import SHEET_ORDER, write_data_xlsx


@pytest.fixture
def sample_data() -> dict[str, pd.DataFrame]:
    """Minimal valid data for all 5 sheets."""
    return {
        "Macro": pd.DataFrame(
            {
                "Site": ["EM1"],
                "Date": pd.to_datetime(["2024-01-15"]),
                "Period": ["Baseline"],
                "EPTrich": [0.5],
                "EPTabun": [0.6],
                "QMCI": [5.5],
                "Season": ["Spring"],
            }
        ),
        "Macro1": pd.DataFrame(
            {
                "Site": ["EM1"],
                "Date": pd.to_datetime(["2024-01-15"]),
                "Period": ["Baseline"],
                "EPTrich": [0.5],
                "EPTabun": [0.6],
                "QMCI": [5.5],
                "Season": ["Spring"],
            }
        ),
        "MacroSpecies": pd.DataFrame(
            {
                "Phase": ["Baseline"],
                "Date": pd.to_datetime(["2024-01-15"]),
                "Site": ["EM1"],
                "Taxa": ["Mayflies"],
                "Species": ["Deleatidium"],
                "Tally": [10],
            }
        ),
        "Sediment": pd.DataFrame(
            {
                "Site": ["EM1"],
                "Date": pd.to_datetime(["2024-01-15"]),
                "Period": ["Baseline"],
                "SAM1": [15.2],
                "SAM3": [12.1],
                "Season": ["Spring"],
            }
        ),
        "SedimentSize": pd.DataFrame(
            {
                "Site": ["EM1"],
                "Date": pd.to_datetime(["2024-01-15"]),
                "Period": ["Baseline"],
                "Season": ["Spring"],
                "Clay/silt (<0.06 mm)": [8.3],
                "Sand (>0.06-2 mm)": [12.0],
                "Small gravel (>2-8 mm)": [15.1],
                "Small-med gravel (>8-16 mm)": [10.0],
                "Med-large gravel (>16-32 mm)": [9.5],
                "Large gravel (>32-64 mm)": [14.2],
                "Small cobble (>64-128 mm)": [11.0],
                "Large cobble (>128-256 mm)": [8.0],
                "Boulders (>256 mm)": [7.5],
                "Bedrock": [4.4],
            }
        ),
        "Clarity": pd.DataFrame(
            {
                "Site": ["CM1"],
                "Date": pd.to_datetime(["2024-01-25"]),
                "NTU-Fieldmeter": [3.5],
                "NTU-Continuous Sensor": [2.1],
                "NTU-Lab": [1.9],
                "pH-Fieldmeter": [7.2],
                "pH-Lab": [7.1],
                "TSS-Lab": [5.0],
                "Clarity (mm)": [1200.0],
                "Comments": [None],
            }
        ),
    }


class TestWriteDataXlsx:
    """Tests for write_data_xlsx()."""

    def test_creates_xlsx_file(
        self, tmp_path: Path, sample_data: dict[str, pd.DataFrame]
    ) -> None:
        output_path = tmp_path / "Data.xlsx"

        write_data_xlsx(sample_data, output_path)

        assert output_path.exists()

    def test_xlsx_has_all_sheets_in_order(
        self, tmp_path: Path, sample_data: dict[str, pd.DataFrame]
    ) -> None:
        output_path = tmp_path / "Data.xlsx"

        write_data_xlsx(sample_data, output_path)

        with pd.ExcelFile(output_path) as xls:
            assert xls.sheet_names == SHEET_ORDER

    def test_macro1_column_order_preserved(
        self, tmp_path: Path, sample_data: dict[str, pd.DataFrame]
    ) -> None:
        output_path = tmp_path / "Data.xlsx"

        write_data_xlsx(sample_data, output_path)

        macro1 = pd.read_excel(output_path, sheet_name="Macro1")
        assert list(macro1.columns) == MACRO1_COLUMNS

    def test_sediment_size_column_order_preserved(
        self, tmp_path: Path, sample_data: dict[str, pd.DataFrame]
    ) -> None:
        output_path = tmp_path / "Data.xlsx"

        write_data_xlsx(sample_data, output_path)

        df = pd.read_excel(output_path, sheet_name="SedimentSize")
        assert list(df.columns) == SEDIMENT_SIZE_COLUMNS

    def test_macro_species_column_order_preserved(
        self, tmp_path: Path, sample_data: dict[str, pd.DataFrame]
    ) -> None:
        output_path = tmp_path / "Data.xlsx"

        write_data_xlsx(sample_data, output_path)

        df = pd.read_excel(output_path, sheet_name="MacroSpecies")
        assert list(df.columns) == MACRO_SPECIES_COLUMNS

    def test_dates_written_as_datetime(
        self, tmp_path: Path, sample_data: dict[str, pd.DataFrame]
    ) -> None:
        """Date columns should be Excel dates (read back as Timestamp)."""
        output_path = tmp_path / "Data.xlsx"

        write_data_xlsx(sample_data, output_path)

        macro1 = pd.read_excel(output_path, sheet_name="Macro1")
        assert pd.api.types.is_datetime64_any_dtype(macro1["Date"])

    def test_creates_parent_directories(
        self, tmp_path: Path, sample_data: dict[str, pd.DataFrame]
    ) -> None:
        output_path = tmp_path / "subdir" / "nested" / "Data.xlsx"

        write_data_xlsx(sample_data, output_path)

        assert output_path.exists()


class TestWriteDataXlsxErrors:
    """Error handling tests for write_data_xlsx()."""

    def test_missing_sheet_raises_value_error(
        self, tmp_path: Path, sample_data: dict[str, pd.DataFrame]
    ) -> None:
        del sample_data["Sediment"]
        output_path = tmp_path / "Data.xlsx"

        with pytest.raises(ValueError, match="Missing required sheets"):
            write_data_xlsx(sample_data, output_path)

        assert not output_path.exists()

    def test_empty_dataframe_raises_value_error(
        self, tmp_path: Path, sample_data: dict[str, pd.DataFrame]
    ) -> None:
        sample_data["Macro"] = pd.DataFrame(columns=MACRO1_COLUMNS)
        output_path = tmp_path / "Data.xlsx"

        with pytest.raises(ValueError, match="empty"):
            write_data_xlsx(sample_data, output_path)

        assert not output_path.exists()

    def test_wrong_columns_raises_value_error(
        self, tmp_path: Path, sample_data: dict[str, pd.DataFrame]
    ) -> None:
        sample_data["Sediment"] = pd.DataFrame({"BadCol": [1], "Wrong": [2]})
        output_path = tmp_path / "Data.xlsx"

        with pytest.raises(ValueError, match="column mismatch"):
            write_data_xlsx(sample_data, output_path)

        assert not output_path.exists()


class TestGoldenFileComparison:
    """Integration test: run all domains, write output, compare to golden file."""

    @pytest.fixture(scope="class")
    def pipeline_data(
        self, example_macro_db: Path, example_aquatic_db: Path
    ) -> dict[str, pd.DataFrame]:
        """Run all domain modules and assemble the combined data dict."""
        macro_result = process_macro_domain(example_macro_db)
        species_result = process_macro_species_domain(example_macro_db)
        sed_result = process_sediment_domain(example_aquatic_db)
        sed_size_result = process_sediment_size_domain(example_aquatic_db)
        clarity_result = process_clarity_domain(example_aquatic_db)

        assert macro_result.ok, macro_result.errors
        assert species_result.ok, species_result.errors
        assert sed_result.ok, sed_result.errors
        assert sed_size_result.ok, sed_size_result.errors
        assert clarity_result.ok, clarity_result.errors

        data: dict[str, pd.DataFrame] = {}
        data.update(macro_result.data)
        data.update(species_result.data)
        data.update(sed_result.data)
        data.update(sed_size_result.data)
        data.update(clarity_result.data)
        return data

    def test_all_sheets_produced(self, pipeline_data: dict[str, pd.DataFrame]) -> None:
        assert set(pipeline_data.keys()) == set(SHEET_ORDER)

    def test_write_succeeds(
        self,
        tmp_path_factory: pytest.TempPathFactory,
        pipeline_data: dict[str, pd.DataFrame],
    ) -> None:
        output_path = tmp_path_factory.mktemp("golden") / "Data.xlsx"
        write_data_xlsx(pipeline_data, output_path)
        assert output_path.exists()

    @pytest.mark.parametrize(
        "sheet_name",
        SHEET_ORDER,
    )
    def test_sheet_matches_golden_file(
        self,
        sheet_name: str,
        pipeline_data: dict[str, pd.DataFrame],
        expected_data_xlsx: Path,
    ) -> None:
        """Each sheet's data should match the golden file within float tolerance."""
        self._assert_sheet_matches_golden(sheet_name, pipeline_data, expected_data_xlsx)

    @staticmethod
    def _assert_sheet_matches_golden(
        sheet_name: str,
        pipeline_data: dict[str, pd.DataFrame],
        expected_data_xlsx: Path,
    ) -> None:
        """Compare pipeline output against golden file, filtering to golden dates."""
        expected = pd.read_excel(expected_data_xlsx, sheet_name=sheet_name)

        # Normalise column names (golden file has trailing spaces on some).
        expected.columns = [c.strip() for c in expected.columns]

        actual = pipeline_data[sheet_name]

        # Filter actual to only dates present in the golden file.
        golden_dates = set(expected["Date"].dropna().unique())
        actual = actual[actual["Date"].isin(golden_dates)]

        # Sort both by Date+Site for stable row alignment.
        sort_cols = ["Date", "Site"]
        actual = actual.sort_values(sort_cols).reset_index(drop=True)
        expected = expected.sort_values(sort_cols).reset_index(drop=True)

        # Same row count after filtering.
        assert len(actual) == len(expected), (
            f"{sheet_name}: row count {len(actual)} != golden {len(expected)}"
        )

        # Same columns (after stripping).
        assert list(actual.columns) == list(expected.columns), (
            f"{sheet_name}: columns differ"
        )

        # Compare values column-by-column.
        for col in actual.columns:
            actual_col = actual[col]
            expected_col = expected[col]

            if pd.api.types.is_numeric_dtype(actual_col):
                np.testing.assert_allclose(
                    actual_col.to_numpy(dtype="float64", na_value=np.nan),
                    expected_col.to_numpy(dtype="float64", na_value=np.nan),
                    rtol=1e-10,
                    atol=1e-10,
                    equal_nan=True,
                    err_msg=f"{sheet_name}.{col}",
                )
            elif pd.api.types.is_datetime64_any_dtype(actual_col):
                pd.testing.assert_series_equal(
                    actual_col.reset_index(drop=True),
                    expected_col.reset_index(drop=True),
                    check_names=False,
                    check_dtype=False,
                )
            else:
                pd.testing.assert_series_equal(
                    actual_col.reset_index(drop=True),
                    expected_col.reset_index(drop=True),
                    check_names=False,
                    check_dtype=False,
                )
