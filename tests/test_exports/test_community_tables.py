"""Tests for community analysis Excel exports."""

from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd
import pytest

from mgen.exports.community_tables import (
    export_anosim_summary,
    export_indicator_species_table,
    export_nmds_scores_table,
    export_species_drivers_table,
)
from mgen.stats.community import ANOSIMResult, IndicatorSpecies


class TestExportANOSIMSummary:
    def test_creates_xlsx_file(self, tmp_path: Path) -> None:
        results = {
            "All Sites": ANOSIMResult(
                R_statistic=0.45, p_value=0.001, permutations=999
            ),
            "EM1": ANOSIMResult(R_statistic=0.32, p_value=0.01, permutations=999),
        }
        output_path = tmp_path / "anosim.xlsx"
        export_anosim_summary(results, output_path)
        assert output_path.exists()

    def test_contains_correct_columns(self, tmp_path: Path) -> None:
        results = {
            "All Sites": ANOSIMResult(
                R_statistic=0.45, p_value=0.001, permutations=999
            ),
        }
        output_path = tmp_path / "anosim.xlsx"
        export_anosim_summary(results, output_path)
        df = pd.read_excel(output_path)
        assert "Comparison" in df.columns
        assert "R_statistic" in df.columns
        assert "p_value" in df.columns

    def test_correct_values(self, tmp_path: Path) -> None:
        results = {
            "Period Effect": ANOSIMResult(
                R_statistic=0.55, p_value=0.002, permutations=999
            ),
        }
        output_path = tmp_path / "anosim.xlsx"
        export_anosim_summary(results, output_path)
        df = pd.read_excel(output_path)
        assert df.iloc[0]["R_statistic"] == pytest.approx(0.55)
        assert df.iloc[0]["p_value"] == pytest.approx(0.002)


class TestExportIndicatorSpeciesTable:
    def test_creates_xlsx_file(self, tmp_path: Path) -> None:
        indicators = [
            IndicatorSpecies(
                species="Deleatidium", group="Baseline", stat=0.85, p_value=0.001
            ),
            IndicatorSpecies(
                species="Chironomidae", group="Construction", stat=0.72, p_value=0.01
            ),
        ]
        output_path = tmp_path / "indicators.xlsx"
        export_indicator_species_table(indicators, output_path)
        assert output_path.exists()

    def test_sorted_by_stat_descending(self, tmp_path: Path) -> None:
        indicators = [
            IndicatorSpecies(species="Sp_A", group="G1", stat=0.5, p_value=0.01),
            IndicatorSpecies(species="Sp_B", group="G2", stat=0.9, p_value=0.001),
            IndicatorSpecies(species="Sp_C", group="G1", stat=0.7, p_value=0.005),
        ]
        output_path = tmp_path / "indicators.xlsx"
        export_indicator_species_table(indicators, output_path)
        df = pd.read_excel(output_path)
        assert df.iloc[0]["Species"] == "Sp_B"
        assert df.iloc[1]["Species"] == "Sp_C"

    def test_empty_list_creates_empty_xlsx(self, tmp_path: Path) -> None:
        output_path = tmp_path / "indicators.xlsx"
        export_indicator_species_table([], output_path)
        assert output_path.exists()
        df = pd.read_excel(output_path)
        assert len(df) == 0


class TestExportSpeciesDriversTable:
    def test_creates_xlsx_file(self, tmp_path: Path) -> None:
        drivers_df = pd.DataFrame(
            {
                "Species": ["Sp_A", "Sp_B"],
                "NMDS1_corr": [0.8, -0.3],
                "NMDS2_corr": [0.2, 0.7],
                "R2": [0.68, 0.58],
                "p_value": [0.001, 0.003],
            }
        )
        output_path = tmp_path / "drivers.xlsx"
        export_species_drivers_table(drivers_df, output_path)
        assert output_path.exists()

    def test_preserves_data(self, tmp_path: Path) -> None:
        drivers_df = pd.DataFrame(
            {
                "Species": ["Sp_A"],
                "NMDS1_corr": [0.8],
                "NMDS2_corr": [0.2],
                "R2": [0.68],
                "p_value": [0.001],
            }
        )
        output_path = tmp_path / "drivers.xlsx"
        export_species_drivers_table(drivers_df, output_path)
        result = pd.read_excel(output_path)
        assert result.iloc[0]["Species"] == "Sp_A"
        assert result.iloc[0]["R2"] == pytest.approx(0.68)

    def test_sorted_by_r2_descending(self, tmp_path: Path) -> None:
        drivers_df = pd.DataFrame(
            {
                "Species": ["Low", "High", "Mid"],
                "NMDS1_corr": [0.1, 0.9, 0.5],
                "NMDS2_corr": [0.1, 0.1, 0.5],
                "R2": [0.02, 0.82, 0.50],
                "p_value": [0.5, 0.001, 0.01],
            }
        )
        output_path = tmp_path / "drivers.xlsx"
        export_species_drivers_table(drivers_df, output_path)
        result = pd.read_excel(output_path)
        assert result.iloc[0]["Species"] == "High"


class TestExportNmdsScoresTable:
    """Tests for Bray-Curtis dissimilarity matrix export."""

    def _make_symmetric_matrix(self, n: int) -> np.ndarray:
        """Create a valid symmetric distance matrix with zero diagonal."""
        rng = np.random.default_rng(42)
        upper = rng.uniform(0.1, 0.9, size=(n, n))
        dm = (upper + upper.T) / 2
        np.fill_diagonal(dm, 0.0)
        return dm

    def test_creates_xlsx_file(self, tmp_path: Path) -> None:
        dm = self._make_symmetric_matrix(4)
        metadata = pd.DataFrame(
            {"Site": ["A", "B", "C", "D"], "Date": pd.to_datetime(["2020-01-01"] * 4)}
        )
        output_path = tmp_path / "dissimilarity.xlsx"
        export_nmds_scores_table(dm, metadata, output_path)
        assert output_path.exists()

    def test_correct_shape_and_columns(self, tmp_path: Path) -> None:
        dm = self._make_symmetric_matrix(5)
        metadata = pd.DataFrame(
            {"Site": list("ABCDE"), "Date": pd.to_datetime(["2020-01-01"] * 5)}
        )
        output_path = tmp_path / "dissimilarity.xlsx"
        export_nmds_scores_table(dm, metadata, output_path)
        df = pd.read_excel(output_path)
        assert df.shape == (5, 7)  # 5 distance cols + Site + Date
        assert list(df.columns) == ["1", "2", "3", "4", "5", "Site", "Date"]

    def test_values_match_input(self, tmp_path: Path) -> None:
        dm = self._make_symmetric_matrix(3)
        metadata = pd.DataFrame(
            {"Site": ["X", "Y", "Z"], "Date": pd.to_datetime(["2021-06-15"] * 3)}
        )
        output_path = tmp_path / "dissimilarity.xlsx"
        export_nmds_scores_table(dm, metadata, output_path)
        df = pd.read_excel(output_path)
        for i in range(3):
            for j in range(3):
                assert df.iloc[i][str(j + 1)] == pytest.approx(dm[i, j], abs=1e-8)

    def test_site_and_date_preserved(self, tmp_path: Path) -> None:
        dm = self._make_symmetric_matrix(3)
        dates = pd.to_datetime(["2020-03-01", "2021-06-15", "2022-12-31"])
        metadata = pd.DataFrame({"Site": ["EM1", "EM2", "EM3"], "Date": dates})
        output_path = tmp_path / "dissimilarity.xlsx"
        export_nmds_scores_table(dm, metadata, output_path)
        df = pd.read_excel(output_path)
        assert list(df["Site"]) == ["EM1", "EM2", "EM3"]
        result_dates = pd.to_datetime(df["Date"])
        assert (result_dates == dates).all()
