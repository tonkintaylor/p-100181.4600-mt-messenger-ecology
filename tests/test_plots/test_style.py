"""Tests for shared plot styling helpers."""

from __future__ import annotations

from datetime import date

import matplotlib as mpl
import matplotlib.pyplot as plt

mpl.use("Agg")

from mgen.plots._style import (
    BASELINE_END,
    PERIOD_COLORS,
    SITES,
    add_baseline_vline,
    add_summer_shading,
    apply_ecology_theme,
    save_figure,
)


class TestConstants:
    def test_period_colors_has_three_entries(self) -> None:
        assert len(PERIOD_COLORS) == 3
        assert "Baseline" in PERIOD_COLORS
        assert "Routine Construction" in PERIOD_COLORS
        assert "Incident" in PERIOD_COLORS

    def test_sites_order(self) -> None:
        assert SITES == ["EM1", "EM2", "EM3", "EM5", "EM4", "EM7", "EM8"]

    def test_baseline_end_date(self) -> None:
        assert date(2022, 2, 28) == BASELINE_END


class TestApplyEcologyTheme:
    def test_sets_grid(self) -> None:
        fig, ax = plt.subplots()
        apply_ecology_theme(ax)
        # Grid should be enabled
        assert ax.get_xgridlines()[0].get_visible()
        plt.close(fig)


class TestAddSummerShading:
    def test_adds_patches_for_each_year(self) -> None:
        fig, ax = plt.subplots()
        ax.set_xlim(date(2020, 1, 1).toordinal(), date(2023, 12, 31).toordinal())
        add_summer_shading(ax, year_range=(2020, 2023))
        # Should have 4 patches (2020, 2021, 2022, 2023)
        patches = list(ax.patches)
        assert len(patches) == 4
        plt.close(fig)


class TestAddBaselineVline:
    def test_adds_vertical_line(self) -> None:
        fig, ax = plt.subplots()
        add_baseline_vline(ax)
        # Should have at least one vertical line
        assert len(ax.get_lines()) >= 1
        plt.close(fig)


class TestSaveFigure:
    def test_saves_png_and_pdf(self, tmp_path) -> None:
        fig, ax = plt.subplots()
        ax.plot([1, 2, 3], [1, 2, 3])
        paths = save_figure(fig, tmp_path / "test_plot")
        assert (tmp_path / "test_plot.png").exists()
        assert (tmp_path / "test_plot.pdf").exists()
        assert len(paths) == 2

    def test_saves_only_requested_formats(self, tmp_path) -> None:
        fig, ax = plt.subplots()
        ax.plot([1, 2, 3], [1, 2, 3])
        paths = save_figure(fig, tmp_path / "test_plot", formats=["png"])
        assert (tmp_path / "test_plot.png").exists()
        assert not (tmp_path / "test_plot.pdf").exists()
        assert len(paths) == 1
