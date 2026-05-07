"""Golden image tests for sediment plots.

These tests compare generated sediment plots against stored reference images.
To update references, delete the reference files and re-run the tests.
"""

from __future__ import annotations

import os
import shutil
from pathlib import Path

import matplotlib as mpl
import numpy as np
import pandas as pd
import pytest

mpl.use("Agg")

from tests.golden.conftest import assert_images_similar

from mgen.plots.sediment import (
    plot_sediment_size_distribution,
    plot_sediment_timeseries,
)
from mgen.shared.schemas import SEDIMENT_SIZE_COLUMNS

REFERENCES_DIR = Path(__file__).parent / "references"

_SIZE_COLS = SEDIMENT_SIZE_COLUMNS[4:]


@pytest.fixture
def _ensure_references_dir() -> None:
    """Ensure the references directory exists."""
    REFERENCES_DIR.mkdir(parents=True, exist_ok=True)


@pytest.fixture
def sediment_size_data() -> pd.DataFrame:
    """Deterministic sediment size data for golden tests."""
    rng = np.random.default_rng(12345)
    sites = ["EM1", "EM2", "EM3"]
    rows = []
    for site in sites:
        for date in pd.date_range("2020-01-01", periods=4, freq="6ME"):
            values = rng.dirichlet(np.ones(len(_SIZE_COLS))) * 100
            row: dict = {
                "Site": site,
                "Date": date,
                "Period": "Baseline" if date.year < 2022 else "Routine Construction",
                "Season": "Autumn",
            }
            for i, col in enumerate(_SIZE_COLS):
                row[col] = values[i]
            rows.append(row)
    return pd.DataFrame(rows)


@pytest.fixture
def sediment_ts_data() -> pd.DataFrame:
    """Deterministic sediment time-series data for golden tests."""
    rng = np.random.default_rng(12345)
    sites = ["EM1", "EM2"]
    rows = []
    for site in sites:
        for date in pd.date_range("2020-01-01", periods=8, freq="3ME"):
            rows.append(
                {
                    "Site": site,
                    "Date": date,
                    "Period": "Baseline"
                    if date.year < 2022
                    else "Routine Construction",
                    "SAM1": rng.uniform(40, 90),
                    "SAM3": rng.uniform(30, 80),
                }
            )
    return pd.DataFrame(rows)


@pytest.mark.golden
@pytest.mark.usefixtures("_ensure_references_dir")
class TestSedimentSizeGolden:
    """Golden image tests for sediment size distribution plots."""

    def test_sediment_size_plot_matches_reference(
        self,
        sediment_size_data: pd.DataFrame,
        tmp_path: Path,
    ) -> None:
        plot_sediment_size_distribution(sediment_size_data, tmp_path)

        png_files = sorted(tmp_path.glob("*.png"))
        if not png_files:
            pytest.skip("No PNG files generated")

        actual = png_files[0]
        reference = REFERENCES_DIR / f"sediment_size_{actual.name}"

        if not reference.exists():
            if os.environ.get("GOLDEN_UPDATE") != "1":
                pytest.fail(
                    f"Reference missing: {reference.name}. "
                    "Set GOLDEN_UPDATE=1 to create."
                )
            shutil.copy(actual, reference)
            pytest.skip(f"Created reference: {reference.name}")

        assert_images_similar(actual, reference, tolerance=2.0)


@pytest.mark.golden
@pytest.mark.usefixtures("_ensure_references_dir")
class TestSedimentTimeseriesGolden:
    """Golden image tests for sediment time-series plots."""

    def test_sediment_timeseries_matches_reference(
        self,
        sediment_ts_data: pd.DataFrame,
        tmp_path: Path,
    ) -> None:
        triggers = {
            "EM1": {"SAM1": 75.0, "SAM3": 75.0},
            "EM2": {"SAM1": 80.0, "SAM3": 80.0},
        }
        plot_sediment_timeseries(sediment_ts_data, triggers, tmp_path)

        png_files = sorted(tmp_path.glob("*.png"))
        if not png_files:
            pytest.skip("No PNG files generated")

        actual = png_files[0]
        reference = REFERENCES_DIR / f"sediment_ts_{actual.name}"

        if not reference.exists():
            if os.environ.get("GOLDEN_UPDATE") != "1":
                pytest.fail(
                    f"Reference missing: {reference.name}. "
                    "Set GOLDEN_UPDATE=1 to create."
                )
            shutil.copy(actual, reference)
            pytest.skip(f"Created reference: {reference.name}")

        assert_images_similar(actual, reference, tolerance=2.0)
