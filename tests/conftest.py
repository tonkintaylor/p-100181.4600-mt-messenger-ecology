"""Shared test fixtures."""

from __future__ import annotations

from pathlib import Path

import pytest

collect_ignore_glob = ["assets/**"]
pytest_plugins = []

ASSETS_DIR = Path(__file__).parent / "assets"


@pytest.fixture(scope="session")
def assets_dir() -> Path:
    """Return a path to the test assets directory."""
    return ASSETS_DIR


@pytest.fixture(scope="session")
def example_macro_db() -> Path:
    """Path to the example Macroinvertebrate Database."""
    return ASSETS_DIR / "MTMA Macroinvertebrate Database.xlsx"


@pytest.fixture
def example_aquatic_db() -> Path:
    """Path to the example Aquatic Monitoring Database."""
    return ASSETS_DIR / "MTMA Aquatic Monitoring Database.xlsx"


@pytest.fixture
def expected_data_xlsx() -> Path:
    """Path to the expected (golden) Data.xlsx output."""
    return ASSETS_DIR / "expected_Data.xlsx"
