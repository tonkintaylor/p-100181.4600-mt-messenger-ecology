"""Tests for clarity domain processing."""

from __future__ import annotations

from pathlib import Path

import pandas as pd
import pytest

from mgen.domain.clarity import process_clarity_domain


class TestClarityNonBreakingSpace:
    """Verify that non-breaking spaces in numeric columns don't cause NaN."""

    @pytest.fixture
    def source_df_with_nbsp(self) -> pd.DataFrame:
        """Source data where Clarity (mm) values have trailing \\xa0."""
        return pd.DataFrame(
            {
                "Site": ["EM4", "CM2", "CM4"],
                "Date": pd.to_datetime(["2026-04-23", "2026-04-23", "2026-04-22"]),
                "Clarity (mm)": ["1200\xa0", "990\xa0", "930\xa0"],
                "NTU-Continuous Sensor": [5.54, 9.87, 9.59],
                "NTU-Lab": [3.90, 7.80, 15.00],
                "NTU-Fieldmeter": [2.8, 3.9, 7.0],
                "pH-Fieldmeter": [8.27, 8.16, 8.44],
                "pH-Lab": [7.6, 7.6, 7.6],
                "TSS-Lab": [3.0, 7.0, 12.0],
            }
        )

    def test_nbsp_stripped_before_numeric_coercion(
        self, source_df_with_nbsp: pd.DataFrame, tmp_path: Path
    ) -> None:
        """Non-breaking spaces in numeric columns are stripped, not coerced to NaN."""
        xlsx_path = tmp_path / "test_db.xlsx"
        source_df_with_nbsp.to_excel(xlsx_path, sheet_name="Clarity Data", index=False)

        result = process_clarity_domain(xlsx_path)

        assert result.data is not None
        clarity = result.data["Clarity"]
        assert clarity["Clarity (mm)"].tolist() == [1200.0, 990.0, 930.0]

    def test_normal_numeric_values_unaffected(self, tmp_path: Path) -> None:
        """Normal integer/float clarity values are not affected by the fix."""
        df = pd.DataFrame(
            {
                "Site": ["EM1", "EM2"],
                "Date": pd.to_datetime(["2025-01-21", "2025-01-22"]),
                "Clarity (mm)": [850, 720.5],
            }
        )
        xlsx_path = tmp_path / "test_db.xlsx"
        df.to_excel(xlsx_path, sheet_name="Clarity Data", index=False)

        result = process_clarity_domain(xlsx_path)

        assert result.data is not None
        clarity = result.data["Clarity"]
        assert clarity["Clarity (mm)"].tolist() == [850.0, 720.5]
