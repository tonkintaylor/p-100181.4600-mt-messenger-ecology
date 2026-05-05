"""Shared test fixtures."""

from __future__ import annotations

from pathlib import Path

import pytest

collect_ignore_glob = ["assets/**"]
pytest_plugins = []

FIXTURES_DIR = Path(__file__).parent / "fixtures"


@pytest.fixture(scope="session")
def assets_dir() -> Path:
    """Return a path to the test assets directory."""
    return Path(__file__).parent / "assets"


@pytest.fixture
def fixtures_dir() -> Path:
    """Path to the test fixtures directory."""
    return FIXTURES_DIR


@pytest.fixture
def example_macro_db(fixtures_dir: Path) -> Path:
    """Path to the example Macroinvertebrate Database."""
    return fixtures_dir / "MTMA Macroinvertebrate Database example.xlsx"


@pytest.fixture
def example_aquatic_db(fixtures_dir: Path) -> Path:
    """Path to the example Aquatic Monitoring Database."""
    return fixtures_dir / "MTMA Aquatic Monitoring Database example.xlsx"


@pytest.fixture
def expected_data_xlsx(fixtures_dir: Path) -> Path:
    """Path to the expected (golden) Data.xlsx output."""
    return fixtures_dir / "expected_Data.xlsx"
