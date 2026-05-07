"""End-to-end integration test for figure generation pipeline."""

from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd
import pytest

from mgen.figures import FigureResult, generate_figures

_SITES = ["EM1", "EM2", "EM3"]

_SIZE_CLASS_COLS = [
    "Clay/silt (<0.06 mm)",
    "Sand (>0.06-2 mm)",
    "Small gravel (>2-8 mm)",
    "Small-med gravel (>8-16 mm)",
    "Med-large gravel (>16-32 mm)",
    "Large gravel (>32-64 mm)",
    "Small cobble (>64-128 mm)",
    "Large cobble (>128-256 mm)",
    "Boulders (>256 mm)",
    "Bedrock",
]


def _period(date: pd.Timestamp) -> str:
    return "Baseline" if date.year < 2022 else "Routine Construction"


def _make_sediment_size(rng: np.random.Generator) -> pd.DataFrame:
    rows = []
    for site in _SITES:
        for date in pd.date_range("2020-01-01", periods=4, freq="6ME"):
            raw = rng.uniform(1, 20, size=len(_SIZE_CLASS_COLS))
            raw = raw / raw.sum() * 100
            rows.append(
                {
                    "Site": site,
                    "Date": date,
                    "Period": _period(date),
                    "Season": "Summer",
                    **dict(zip(_SIZE_CLASS_COLS, raw, strict=False)),
                }
            )
    return pd.DataFrame(rows)


def _make_sediment(rng: np.random.Generator) -> pd.DataFrame:
    rows = []
    for site in _SITES:
        for date in pd.date_range("2020-01-01", periods=8, freq="3ME"):
            rows.append(
                {
                    "Site": site,
                    "Date": date,
                    "Period": _period(date),
                    "SAM1": rng.uniform(40, 90),
                    "SAM3": rng.uniform(40, 90),
                    "Season": "Summer",
                }
            )
    return pd.DataFrame(rows)


def _make_macro(rng: np.random.Generator) -> pd.DataFrame:
    rows = []
    for site in _SITES:
        for date in pd.date_range("2020-01-01", periods=6, freq="6ME"):
            rows.append(
                {
                    "Site": site,
                    "Date": date,
                    "Period": _period(date),
                    "QMCI": rng.uniform(3, 7),
                    "EPTrich": rng.integers(5, 20),
                    "EPTabun": rng.integers(50, 200),
                }
            )
    return pd.DataFrame(rows)


def _make_community(rng: np.random.Generator) -> pd.DataFrame:
    rows = []
    for site in _SITES:
        for date in pd.date_range("2020-01-01", periods=6, freq="6ME"):
            rows.append(
                {
                    "Site": site,
                    "Date": date,
                    "Period": _period(date),
                    **{f"Species_{i}": int(rng.integers(0, 50)) for i in range(10)},
                }
            )
    return pd.DataFrame(rows)


class TestEndToEndFigureGeneration:
    """Full pipeline test: data -> stats -> plots -> exports."""

    @pytest.fixture
    def synthetic_data(self) -> dict[str, pd.DataFrame]:
        """Create synthetic data mimicking Data.xlsx structure."""
        rng = np.random.default_rng(42)
        return {
            "SedimentSize": _make_sediment_size(rng),
            "Sediment": _make_sediment(rng),
            "Macro1": _make_macro(rng),
            "Community": _make_community(rng),
        }

    def test_generate_all_succeeds(
        self, synthetic_data: dict[str, pd.DataFrame], tmp_path: Path
    ) -> None:
        result = generate_figures(synthetic_data, tmp_path, only="all")
        assert isinstance(result, FigureResult)
        assert result.success

    def test_generates_sediment_outputs(
        self, synthetic_data: dict[str, pd.DataFrame], tmp_path: Path
    ) -> None:
        result = generate_figures(synthetic_data, tmp_path, only="sediment")
        assert result.success
        png_files = list(tmp_path.glob("*.png"))
        pdf_files = list(tmp_path.glob("*.pdf"))
        assert len(png_files) > 0
        assert len(pdf_files) > 0

    def test_generates_macro_outputs(
        self, synthetic_data: dict[str, pd.DataFrame], tmp_path: Path
    ) -> None:
        result = generate_figures(synthetic_data, tmp_path, only="macro")
        assert result.success
        png_files = list(tmp_path.glob("*.png"))
        assert len(png_files) > 0

    def test_generates_community_outputs(
        self, synthetic_data: dict[str, pd.DataFrame], tmp_path: Path
    ) -> None:
        result = generate_figures(synthetic_data, tmp_path, only="community")
        assert result.success
        # Should produce NMDS plots + Excel tables
        png_files = list(tmp_path.glob("*.png"))
        xlsx_files = list(tmp_path.glob("*.xlsx"))
        assert len(png_files) > 0
        assert len(xlsx_files) > 0

    def test_all_generates_more_than_individual(
        self, synthetic_data: dict[str, pd.DataFrame], tmp_path: Path
    ) -> None:
        result = generate_figures(synthetic_data, tmp_path, only="all")
        all_files = result.files_written

        # Should have files from all three generators
        assert len(all_files) >= 5  # At minimum: sediment + macro + community outputs

    def test_empty_data_produces_empty_result(self, tmp_path: Path) -> None:
        result = generate_figures({}, tmp_path, only="all")
        assert not result.success
        assert len(result.files_written) == 0

    def test_partial_data_generates_available(
        self, synthetic_data: dict[str, pd.DataFrame], tmp_path: Path
    ) -> None:
        # Only provide sediment data
        partial = {"Sediment": synthetic_data["Sediment"]}
        result = generate_figures(partial, tmp_path, only="all")
        assert result.success
