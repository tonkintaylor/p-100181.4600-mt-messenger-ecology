"""Tests for sediment plot rendering."""

from __future__ import annotations

from pathlib import Path

from mgen.plots.sediment import plot_sediment_size_distribution


class TestPlotSedimentSizeDistribution:
    """Structural tests for grain-size stacked bar chart."""

    def test_returns_file_paths(self, tmp_path: Path, sediment_size_df) -> None:
        paths = plot_sediment_size_distribution(sediment_size_df, tmp_path)
        assert len(paths) > 0
        for p in paths:
            assert p.exists()
            assert p.stat().st_size > 0

    def test_creates_one_png_per_site(self, tmp_path: Path, sediment_size_df) -> None:
        paths = plot_sediment_size_distribution(sediment_size_df, tmp_path)
        png_paths = [p for p in paths if p.suffix == ".png"]
        # 2 sites in fixture data
        assert len(png_paths) == 2

    def test_creates_pdf_per_site(self, tmp_path: Path, sediment_size_df) -> None:
        paths = plot_sediment_size_distribution(sediment_size_df, tmp_path)
        pdf_paths = [p for p in paths if p.suffix == ".pdf"]
        assert len(pdf_paths) == 2

    def test_file_names_contain_site(self, tmp_path: Path, sediment_size_df) -> None:
        paths = plot_sediment_size_distribution(sediment_size_df, tmp_path)
        png_names = [p.stem for p in paths if p.suffix == ".png"]
        assert any("EM1" in name for name in png_names)
        assert any("EM2" in name for name in png_names)

    def test_empty_dataframe_returns_empty_list(
        self, tmp_path: Path, sediment_size_df
    ) -> None:
        empty_df = sediment_size_df.iloc[0:0]
        paths = plot_sediment_size_distribution(empty_df, tmp_path)
        assert paths == []
