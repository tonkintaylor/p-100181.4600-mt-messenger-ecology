"""Tests for community NMDS ordination plots."""

from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd
import pytest

from mgen.figures import generate_figures
from mgen.plots.community import plot_nmds_ordination, plot_nmds_per_site
from mgen.stats.community import NMDSResult


class TestPlotNMDSOrdination:
    @pytest.fixture
    def nmds_result(self) -> NMDSResult:
        """5 samples, 2 dims."""
        return NMDSResult(
            points=np.array(
                [
                    [-0.5, -0.3],
                    [-0.4, -0.2],
                    [-0.3, -0.1],
                    [0.5, 0.3],
                    [0.6, 0.4],
                ]
            ),
            stress=0.12,
        )

    @pytest.fixture
    def sample_metadata(self) -> pd.DataFrame:
        """Period labels for each sample."""
        return pd.DataFrame(
            {
                "Period": [
                    "Baseline",
                    "Baseline",
                    "Baseline",
                    "Construction",
                    "Construction",
                ],
                "Site": ["EM1", "EM2", "EM3", "EM1", "EM2"],
                "Date": pd.to_datetime(
                    [
                        "2020-06-01",
                        "2020-06-01",
                        "2020-06-01",
                        "2023-06-01",
                        "2023-06-01",
                    ]
                ),
            }
        )

    def test_creates_output_files(
        self, nmds_result: NMDSResult, sample_metadata: pd.DataFrame, tmp_path: Path
    ) -> None:
        plot_nmds_ordination(nmds_result, sample_metadata, output_dir=tmp_path)
        png_files = list(tmp_path.glob("*.png"))
        assert len(png_files) >= 1

    def test_creates_pdf(
        self, nmds_result: NMDSResult, sample_metadata: pd.DataFrame, tmp_path: Path
    ) -> None:
        plot_nmds_ordination(nmds_result, sample_metadata, output_dir=tmp_path)
        pdf_files = list(tmp_path.glob("*.pdf"))
        assert len(pdf_files) >= 1

    def test_handles_empty_result(
        self, sample_metadata: pd.DataFrame, tmp_path: Path
    ) -> None:
        empty = NMDSResult(points=np.empty((0, 2)), stress=0.0)
        # Should not raise, just skip
        plot_nmds_ordination(empty, sample_metadata, output_dir=tmp_path)
        assert len(list(tmp_path.glob("*"))) == 0


class TestPlotNMDSPerSite:
    @pytest.fixture
    def nmds_result(self) -> NMDSResult:
        """8 samples across 2 sites, 2 time points."""
        return NMDSResult(
            points=np.array(
                [
                    [-0.5, -0.3],
                    [-0.4, -0.2],
                    [0.3, 0.2],
                    [0.4, 0.3],
                    [-0.3, 0.4],
                    [-0.2, 0.5],
                    [0.5, -0.2],
                    [0.6, -0.1],
                ]
            ),
            stress=0.10,
        )

    @pytest.fixture
    def sample_metadata(self) -> pd.DataFrame:
        return pd.DataFrame(
            {
                "Period": ["Baseline", "Baseline", "Construction", "Construction"] * 2,
                "Site": ["EM1"] * 4 + ["EM2"] * 4,
                "Date": pd.to_datetime(
                    ["2020-06-01", "2021-06-01", "2023-06-01", "2024-06-01"] * 2
                ),
            }
        )

    def test_creates_per_site_files(
        self, nmds_result: NMDSResult, sample_metadata: pd.DataFrame, tmp_path: Path
    ) -> None:
        plot_nmds_per_site(nmds_result, sample_metadata, output_dir=tmp_path)
        png_files = list(tmp_path.glob("*.png"))
        # Should create at least one file per site
        assert len(png_files) >= 2

    def test_creates_per_site_pdf(
        self, nmds_result: NMDSResult, sample_metadata: pd.DataFrame, tmp_path: Path
    ) -> None:
        plot_nmds_per_site(nmds_result, sample_metadata, output_dir=tmp_path)
        pdf_files = list(tmp_path.glob("*.pdf"))
        assert len(pdf_files) >= 1


class TestGenerateCommunityIntegration:
    """Integration test for _generate_community via generate_figures."""

    @pytest.fixture
    def community_data(self) -> dict[str, pd.DataFrame]:
        """Minimal community dataset with species counts."""
        rng = np.random.default_rng(42)
        n_samples = 12
        dates = pd.to_datetime(["2020-06-01", "2020-12-01", "2021-06-01"] * 4)
        sites = ["EM1"] * 3 + ["EM2"] * 3 + ["EM3"] * 3 + ["EM4"] * 3
        periods = ["Baseline"] * 6 + ["Construction"] * 6

        species_data = {}
        for i in range(8):
            species_data[f"Species_{i}"] = rng.integers(0, 50, n_samples)

        df = pd.DataFrame(
            {
                "Date": dates,
                "Site": sites,
                "Period": periods,
                **species_data,
            }
        )
        return {"Community": df}

    def test_generates_output_files(
        self, community_data: dict[str, pd.DataFrame], tmp_path: Path
    ) -> None:
        result = generate_figures(community_data, tmp_path, only="community")
        assert result.success
        assert len(result.files_written) > 0

    def test_generates_plots_and_tables(
        self, community_data: dict[str, pd.DataFrame], tmp_path: Path
    ) -> None:
        result = generate_figures(community_data, tmp_path, only="community")
        extensions = {p.suffix for p in result.files_written}
        assert ".png" in extensions
        assert ".xlsx" in extensions
