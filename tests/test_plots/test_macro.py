"""Tests for macro metric plot rendering."""

from __future__ import annotations

from pathlib import Path

import pytest

from mgen.plots.macro import plot_macro_metrics
from mgen.stats.confidence import MetricSummary


class TestPlotMacroMetrics:
    """Structural tests for macro 3-panel plots."""

    @pytest.fixture
    def mock_summaries(self) -> dict[str, dict[str, list[MetricSummary]]]:
        """Pre-computed summaries for 2 sites, 3 dates, 3 metrics."""
        summaries: dict[str, dict[str, list[MetricSummary]]] = {}
        for site in ["EM1", "EM2"]:
            summaries[site] = {}
            for metric in ["QMCI", "EPTrich", "EPTabun"]:
                summaries[site][metric] = [
                    MetricSummary(mean=5.0, ci_lower=4.0, ci_upper=6.0, n=3),
                    MetricSummary(mean=5.5, ci_lower=4.5, ci_upper=6.5, n=3),
                    MetricSummary(mean=6.0, ci_lower=5.0, ci_upper=7.0, n=3),
                ]
        return summaries

    @pytest.fixture
    def mock_triggers(self) -> dict[str, dict[str, float]]:
        return {
            "EM1": {"QMCI": 4.675, "EPTrich": 34.0, "EPTabun": 42.5},
            "EM2": {"QMCI": 5.1, "EPTrich": 42.5, "EPTabun": 46.75},
        }

    def test_returns_file_paths(
        self,
        tmp_path: Path,
        macro1_df,
        mock_summaries,
        mock_triggers,
    ) -> None:
        paths = plot_macro_metrics(macro1_df, mock_summaries, mock_triggers, tmp_path)
        assert len(paths) > 0
        for p in paths:
            assert p.exists()

    def test_creates_png_per_site(
        self,
        tmp_path: Path,
        macro1_df,
        mock_summaries,
        mock_triggers,
    ) -> None:
        paths = plot_macro_metrics(macro1_df, mock_summaries, mock_triggers, tmp_path)
        png_paths = [p for p in paths if p.suffix == ".png"]
        # 2 combined (one per site) + 6 individual metrics (3 metrics x 2 sites)
        assert len(png_paths) == 8

    def test_empty_df_returns_empty(
        self,
        tmp_path: Path,
        macro1_df,
    ) -> None:
        empty = macro1_df.iloc[0:0]
        paths = plot_macro_metrics(empty, {}, {}, tmp_path)
        assert paths == []
