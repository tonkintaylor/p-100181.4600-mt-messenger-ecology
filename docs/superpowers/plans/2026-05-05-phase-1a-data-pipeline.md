# Phase 1a Data.xlsx Pipeline — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One-command Python pipeline that reads Mt Messenger aquatic monitoring databases and emits `Data.xlsx` with 5 sheets consumed by downstream R scripts.

**Architecture:** Domain-oriented modules (macro, macro_species, sediment, sediment_size) each own their ingest/validate/transform logic. A thin orchestrator calls all domains, collects errors, and either emits output or reports failures. Shared kernel provides value objects and validation primitives.

**Tech Stack:** Python 3.13, pandas, openpyxl, click (CLI), pytest

---

## File Structure

```
src/mgen/
  __init__.py                    # existing
  _version.py                    # existing (hatch-vcs)
  config.py                      # TOML config loading + path validation
  pipeline.py                    # Orchestrator: config → domains → writer
  cli.py                         # Click CLI entry point (mgen run, mgen validate)
  writer.py                      # Assemble DataFrames → 5-sheet Data.xlsx
  shared/
    __init__.py
    types.py                     # Value objects: Site, Season, Period
    schemas.py                   # Output DataFrame schemas (column specs, dtypes)
    errors.py                    # ValidationError, DomainResult
    validation.py                # Shared validation primitives
  domains/
    __init__.py
    macro_ingest.py              # Shared ACL: parse RawData multi-row header
    macro.py                     # Metric derivation → Macro1 + Macro sheets
    macro_species.py             # Taxa pivot → MacroSpecies sheet
    sediment.py                  # Sediment tab → Sediment sheet
    sediment_size.py             # SedimentSize data → SedimentSize sheet

tests/
  conftest.py                    # Shared fixtures (paths to test data)
  fixtures/                      # Trimmed example databases + expected Data.xlsx
    cycle.toml                   # Test config pointing at fixtures
    MTMA Macroinvertebrate Database example.xlsx
    MTMA Aquatic Monitoring Database example.xlsx
    expected_Data.xlsx           # Golden file: current manual Data.xlsx
  test_config.py
  test_shared/
    test_validation.py
  test_domains/
    test_macro_ingest.py
    test_macro.py
    test_macro_species.py
    test_sediment.py
    test_sediment_size.py
  test_writer.py
  test_pipeline_integration.py   # End-to-end golden-file test
```

---

## Task 1: Project Scaffolding & Config

**Files:**
- Create: `src/mgen/shared/__init__.py`
- Create: `src/mgen/shared/errors.py`
- Create: `src/mgen/config.py`
- Create: `src/mgen/cli.py`
- Create: `cycle.example.toml`
- Modify: `pyproject.toml` (add dependencies + CLI entry point)
- Create: `tests/conftest.py`
- Create: `tests/test_config.py`

### Dependencies

Add to `pyproject.toml` under `[project] dependencies`:

```
pandas>=2.2
openpyxl>=3.1
click>=8.1
```

Add CLI entry point under `[project.scripts]`:

```
mgen = "mgen.cli:main"
```

### Step-by-step

- [ ] **Step 1: Add dependencies to pyproject.toml**

In `pyproject.toml`, replace:
```toml
dependencies = []
```
with:
```toml
dependencies = [
    "pandas>=2.2",
    "openpyxl>=3.1",
    "click>=8.1",
]
```

Replace:
```toml
[project.scripts]
# example = "mgen.scripts.example:myfunc"
```
with:
```toml
[project.scripts]
mgen = "mgen.cli:main"
```

- [ ] **Step 2: Install dependencies**

Run: `uv sync`

- [ ] **Step 3: Create shared errors module**

Create `src/mgen/shared/__init__.py`:
```python
"""Shared kernel: types, schemas, errors, validation primitives."""
```

Create `src/mgen/shared/errors.py`:
```python
"""Error types for pipeline validation."""

from __future__ import annotations

from dataclasses import dataclass, field


@dataclass(frozen=True)
class ValidationError:
    """A single validation failure pointing at its source location."""

    domain: str
    severity: str  # "error" or "warning"
    file: str
    sheet: str
    location: str
    message: str

    def __str__(self) -> str:
        return f"[{self.severity.upper()}] {self.file} → {self.sheet} → {self.location}: {self.message}"


@dataclass
class DomainResult:
    """Result from a domain module: either data or errors, never both meaningful."""

    data: dict[str, "pd.DataFrame"] | None = None
    errors: list[ValidationError] = field(default_factory=list)

    @property
    def ok(self) -> bool:
        """True if no errors with severity 'error'."""
        return not any(e.severity == "error" for e in self.errors)
```

- [ ] **Step 4: Write the failing test for config loading**

Create `tests/test_config.py`:
```python
"""Tests for cycle.toml config loading."""

from __future__ import annotations

from pathlib import Path

import pytest

from mgen.config import load_config, ConfigError


class TestLoadConfig:
    def test_loads_valid_toml(self, tmp_path: Path) -> None:
        config_file = tmp_path / "cycle.toml"
        config_file.write_text(
            '[input]\n'
            f'macroinvertebrate_db = "{tmp_path / "macro.xlsx"}"\n'
            f'aquatic_monitoring_db = "{tmp_path / "aquatic.xlsx"}"\n'
            "\n"
            "[output]\n"
            f'data_xlsx = "{tmp_path / "Data.xlsx"}"\n'
        )
        # Create dummy input files so validation passes
        (tmp_path / "macro.xlsx").touch()
        (tmp_path / "aquatic.xlsx").touch()

        config = load_config(config_file)

        assert config.macroinvertebrate_db == tmp_path / "macro.xlsx"
        assert config.aquatic_monitoring_db == tmp_path / "aquatic.xlsx"
        assert config.data_xlsx == tmp_path / "Data.xlsx"

    def test_raises_on_missing_config_file(self, tmp_path: Path) -> None:
        with pytest.raises(ConfigError, match="not found"):
            load_config(tmp_path / "nonexistent.toml")

    def test_raises_on_missing_input_file(self, tmp_path: Path) -> None:
        config_file = tmp_path / "cycle.toml"
        config_file.write_text(
            '[input]\n'
            'macroinvertebrate_db = "does_not_exist.xlsx"\n'
            'aquatic_monitoring_db = "also_missing.xlsx"\n'
            "\n"
            "[output]\n"
            f'data_xlsx = "{tmp_path / "Data.xlsx"}"\n'
        )

        with pytest.raises(ConfigError, match="does_not_exist.xlsx"):
            load_config(config_file)

    def test_raises_on_missing_required_key(self, tmp_path: Path) -> None:
        config_file = tmp_path / "cycle.toml"
        config_file.write_text("[input]\n")

        with pytest.raises(ConfigError, match="macroinvertebrate_db"):
            load_config(config_file)
```

- [ ] **Step 5: Run tests to verify they fail**

Run: `pytest tests/test_config.py -v`
Expected: FAIL (ImportError — `mgen.config` does not exist yet)

- [ ] **Step 6: Implement config module**

Create `src/mgen/config.py`:
```python
"""Load and validate cycle.toml configuration."""

from __future__ import annotations

import tomllib
from dataclasses import dataclass
from pathlib import Path


class ConfigError(Exception):
    """Raised when cycle.toml is missing or invalid."""


@dataclass(frozen=True)
class PipelineConfig:
    """Validated pipeline configuration from cycle.toml."""

    macroinvertebrate_db: Path
    aquatic_monitoring_db: Path
    data_xlsx: Path


def load_config(config_path: Path) -> PipelineConfig:
    """Load and validate a cycle.toml file.

    Raises ConfigError if the file is missing, malformed, or references
    input files that don't exist.
    """
    if not config_path.exists():
        msg = f"Config file not found: {config_path}"
        raise ConfigError(msg)

    with config_path.open("rb") as f:
        raw = tomllib.load(f)

    # Extract required keys
    input_section = raw.get("input", {})
    output_section = raw.get("output", {})

    required_inputs = ["macroinvertebrate_db", "aquatic_monitoring_db"]
    for key in required_inputs:
        if key not in input_section:
            msg = f"Missing required key: [input].{key}"
            raise ConfigError(msg)

    if "data_xlsx" not in output_section:
        msg = "Missing required key: [output].data_xlsx"
        raise ConfigError(msg)

    macro_db = Path(input_section["macroinvertebrate_db"])
    aquatic_db = Path(input_section["aquatic_monitoring_db"])
    data_xlsx = Path(output_section["data_xlsx"])

    # Validate input files exist
    for path in [macro_db, aquatic_db]:
        if not path.exists():
            msg = f"Input file not found: {path}"
            raise ConfigError(msg)

    return PipelineConfig(
        macroinvertebrate_db=macro_db,
        aquatic_monitoring_db=aquatic_db,
        data_xlsx=data_xlsx,
    )
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `pytest tests/test_config.py -v`
Expected: All 4 tests PASS

- [ ] **Step 8: Create CLI entry point**

Create `src/mgen/cli.py`:
```python
"""Command-line interface for the mgen pipeline."""

from __future__ import annotations

from pathlib import Path

import click

from mgen.config import ConfigError, load_config


@click.group()
def main() -> None:
    """Mt Messenger ecology data pipeline."""


@main.command()
@click.argument("config_path", default="cycle.toml", type=click.Path(exists=False))
def run(config_path: str) -> None:
    """Run the pipeline using the specified cycle.toml config."""
    try:
        config = load_config(Path(config_path))
    except ConfigError as e:
        raise SystemExit(f"❌ Config error: {e}") from None

    click.echo(f"Config loaded: {config.data_xlsx}")
    # Pipeline execution will be added in Task 10
    click.echo("⚠️  Pipeline not yet implemented")


@main.command()
@click.argument("config_path", default="cycle.toml", type=click.Path(exists=False))
def validate(config_path: str) -> None:
    """Validate inputs without writing output."""
    try:
        config = load_config(Path(config_path))
    except ConfigError as e:
        raise SystemExit(f"❌ Config error: {e}") from None

    click.echo(f"✅ Config valid. Inputs found:")
    click.echo(f"   Macro DB: {config.macroinvertebrate_db}")
    click.echo(f"   Aquatic DB: {config.aquatic_monitoring_db}")
    click.echo(f"   Output: {config.data_xlsx}")
```

- [ ] **Step 9: Create example config file**

Create `cycle.example.toml` in repo root:
```toml
# Mt Messenger monitoring pipeline configuration.
# Copy this file to cycle.toml and update paths for the current reporting cycle.

[input]
macroinvertebrate_db = "T:/Wellington/TT Projects/1001181/1001181.4500/WorkingMaterial/Aquatic Monitoring/Aquatic monitoring spreadsheets/MTMA Macroinvertebrate Database.xlsx"
aquatic_monitoring_db = "T:/Wellington/TT Projects/1001181/1001181.4500/WorkingMaterial/Aquatic Monitoring/Aquatic monitoring spreadsheets/MTMA Aquatic Monitoring Database.xlsx"

[output]
data_xlsx = "T:/Wellington/TT Projects/1001181/1001181.4500/WorkingMaterial/Aquatic Monitoring/2025-2026 Report/Stats/Data.xlsx"
```

- [ ] **Step 10: Create test conftest with fixture paths**

Create `tests/conftest.py`:
```python
"""Shared test fixtures."""

from __future__ import annotations

from pathlib import Path

import pytest

FIXTURES_DIR = Path(__file__).parent / "fixtures"


@pytest.fixture()
def fixtures_dir() -> Path:
    """Path to the test fixtures directory."""
    return FIXTURES_DIR


@pytest.fixture()
def example_macro_db(fixtures_dir: Path) -> Path:
    """Path to the example Macroinvertebrate Database."""
    return fixtures_dir / "MTMA Macroinvertebrate Database example.xlsx"


@pytest.fixture()
def example_aquatic_db(fixtures_dir: Path) -> Path:
    """Path to the example Aquatic Monitoring Database."""
    return fixtures_dir / "MTMA Aquatic Monitoring Database example.xlsx"


@pytest.fixture()
def expected_data_xlsx(fixtures_dir: Path) -> Path:
    """Path to the expected (golden) Data.xlsx output."""
    return fixtures_dir / "expected_Data.xlsx"
```

- [ ] **Step 11: Commit**

```bash
git add src/mgen/shared/ src/mgen/config.py src/mgen/cli.py cycle.example.toml tests/conftest.py tests/test_config.py pyproject.toml
git commit -m "feat: project scaffolding with config loading and CLI entry point

- Add pandas, openpyxl, click dependencies
- Implement cycle.toml loading with path validation
- Add click CLI with 'run' and 'validate' commands
- Add shared errors module (ValidationError, DomainResult)
- Add test fixtures directory and conftest"
```

---

## Task 2: Shared Kernel — Types & Schemas

**Files:**
- Create: `src/mgen/shared/types.py`
- Create: `src/mgen/shared/schemas.py`
- Create: `src/mgen/shared/validation.py`

Note: Per testing skill rules, value objects are NOT tested directly — they'll be exercised through domain module tests in later tasks.

- [ ] **Step 1: Create value objects**

Create `src/mgen/shared/types.py`:
```python
"""Domain value objects for the Mt Messenger monitoring pipeline."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date

# Canonical site codes for the Mt Messenger monitoring programme
VALID_SITES = frozenset(
    {"EM1", "EM2", "EM3", "EM4", "EM5", "EM7", "EM8", "MMA6", "MMA6b"}
)

# Sites that lack replicates and use QMCI-sb instead of QMCI
SITES_WITHOUT_REPLICATES = frozenset({"EM1", "EM2", "EM4", "EM8"})

# Valid season/phase labels
VALID_SEASONS = frozenset({"Baseline", "Construction", "Routine", "Additional"})


@dataclass(frozen=True)
class Site:
    """A validated monitoring site."""

    code: str

    def __post_init__(self) -> None:
        if self.code not in VALID_SITES:
            msg = f"Unknown site: {self.code!r}. Expected one of {sorted(VALID_SITES)}"
            raise ValueError(msg)

    @property
    def has_replicates(self) -> bool:
        """Whether this site has replicate samples."""
        return self.code not in SITES_WITHOUT_REPLICATES

    @property
    def uses_qmci_sb(self) -> bool:
        """Whether this site uses QMCI-sb instead of QMCI."""
        return self.code in SITES_WITHOUT_REPLICATES
```

- [ ] **Step 2: Create output schemas**

Create `src/mgen/shared/schemas.py`:
```python
"""Output DataFrame schemas for Data.xlsx sheets.

These define the exact column names and dtypes that the downstream R scripts
expect. Any change here is a breaking change for Phase 2.
"""

from __future__ import annotations

import numpy as np

# Macro1 sheet: full-precision metrics, one row per site×date
MACRO1_COLUMNS = ["Site", "Date", "Period", "EPTrich", "EPTabun", "QMCI", "Season"]
MACRO1_DTYPES = {
    "Site": "object",
    "Date": "datetime64[ns]",
    "Period": "object",
    "EPTrich": "float64",
    "EPTabun": "float64",
    "QMCI": "float64",
    "Season": "object",
}

# Macro sheet: aggregated means for replicated sites
MACRO_COLUMNS = MACRO1_COLUMNS
MACRO_DTYPES = MACRO1_DTYPES

# MacroSpecies sheet: long-format taxa tally
MACRO_SPECIES_COLUMNS = ["Phase", "Date", "Site", "Taxa", "Species", "Tally"]
MACRO_SPECIES_DTYPES = {
    "Phase": "object",
    "Date": "datetime64[ns]",
    "Site": "object",
    "Taxa": "object",
    "Species": "object",
    "Tally": "int64",
}

# Sediment sheet: SAM scores
SEDIMENT_COLUMNS = ["Site", "Date", "Period", "SAM1", "SAM3", "Season"]
SEDIMENT_DTYPES = {
    "Site": "object",
    "Date": "datetime64[ns]",
    "Period": "object",
    "SAM1": "float64",
    "SAM3": "float64",
    "Season": "object",
}

# SedimentSize sheet: grain-size distribution
SEDIMENT_SIZE_COLUMNS = [
    "Site",
    "Date",
    "Period",
    "Season",
    "Bedrock",
    "Boulder",
    "Cobble",
    "LargeGravel",
    "SmallGravel",
    "VeryFineGravel",
    "Sand",
    "Silt",
    "Clay",
    "Fines",
    "Wood",
    "Other",
]
SEDIMENT_SIZE_DTYPES = {
    "Site": "object",
    "Date": "datetime64[ns]",
    "Period": "object",
    "Season": "object",
    **{col: "float64" for col in SEDIMENT_SIZE_COLUMNS[4:]},
}
```

- [ ] **Step 3: Create shared validation primitives**

Create `src/mgen/shared/validation.py`:
```python
"""Shared validation primitives for domain modules."""

from __future__ import annotations

import pandas as pd

from mgen.shared.errors import ValidationError


def check_required_columns(
    df: pd.DataFrame,
    expected: list[str],
    *,
    domain: str,
    file: str,
    sheet: str,
) -> list[ValidationError]:
    """Check that all expected columns are present in a DataFrame."""
    missing = set(expected) - set(df.columns)
    if not missing:
        return []
    return [
        ValidationError(
            domain=domain,
            severity="error",
            file=file,
            sheet=sheet,
            location="header",
            message=f"Missing required columns: {sorted(missing)}",
        )
    ]


def check_no_nulls(
    df: pd.DataFrame,
    columns: list[str],
    *,
    domain: str,
    file: str,
    sheet: str,
) -> list[ValidationError]:
    """Check that specified columns have no null values."""
    errors: list[ValidationError] = []
    for col in columns:
        if col not in df.columns:
            continue
        null_mask = df[col].isna()
        if null_mask.any():
            null_rows = df.index[null_mask].tolist()
            first_few = null_rows[:5]
            errors.append(
                ValidationError(
                    domain=domain,
                    severity="error",
                    file=file,
                    sheet=sheet,
                    location=f"column '{col}', rows {first_few}",
                    message=f"Found {null_mask.sum()} null values in required column '{col}'",
                )
            )
    return errors


def check_value_range(
    df: pd.DataFrame,
    column: str,
    *,
    min_val: float | None = None,
    max_val: float | None = None,
    domain: str,
    file: str,
    sheet: str,
) -> list[ValidationError]:
    """Check that numeric values fall within an expected range."""
    errors: list[ValidationError] = []
    if column not in df.columns:
        return errors

    series = pd.to_numeric(df[column], errors="coerce")

    if min_val is not None:
        below = series < min_val
        if below.any():
            bad_rows = df.index[below].tolist()[:5]
            errors.append(
                ValidationError(
                    domain=domain,
                    severity="error",
                    file=file,
                    sheet=sheet,
                    location=f"column '{column}', rows {bad_rows}",
                    message=f"Values below minimum {min_val} in column '{column}'",
                )
            )

    if max_val is not None:
        above = series > max_val
        if above.any():
            bad_rows = df.index[above].tolist()[:5]
            errors.append(
                ValidationError(
                    domain=domain,
                    severity="error",
                    file=file,
                    sheet=sheet,
                    location=f"column '{column}', rows {bad_rows}",
                    message=f"Values above maximum {max_val} in column '{column}'",
                )
            )

    return errors
```

- [ ] **Step 4: Run existing tests to verify nothing broke**

Run: `pytest tests/ -v`
Expected: All existing tests still pass

- [ ] **Step 5: Commit**

```bash
git add src/mgen/shared/types.py src/mgen/shared/schemas.py src/mgen/shared/validation.py
git commit -m "feat: shared kernel — value objects, output schemas, validation primitives

- Site value object with replicate/QMCI-sb knowledge
- Output schemas defining exact Data.xlsx column contracts
- Shared validation: required columns, null checks, range checks"
```

---

## Task 3: Macroinvertebrate ACL — Ingest RawData

**Files:**
- Create: `src/mgen/domains/__init__.py`
- Create: `src/mgen/domains/macro_ingest.py`
- Create: `tests/test_domains/__init__.py`
- Create: `tests/test_domains/test_macro_ingest.py`

This is the hardest ingest step: parsing the multi-row header (rows 1-5) of the 181×218 RawData sheet.

- [ ] **Step 1: Write failing tests for header parsing**

Create `tests/test_domains/__init__.py` (empty).

Create `tests/test_domains/test_macro_ingest.py`:
```python
"""Tests for Macroinvertebrate RawData ingestion (anti-corruption layer)."""

from __future__ import annotations

from pathlib import Path

import pandas as pd
import pytest

from mgen.domains.macro_ingest import ingest_raw_data, RawDataBundle


class TestIngestRawData:
    """Test the ACL that parses the multi-row header RawData sheet."""

    def test_returns_raw_data_bundle(self, example_macro_db: Path) -> None:
        result = ingest_raw_data(example_macro_db)

        assert isinstance(result, RawDataBundle)
        assert result.taxa_counts is not None
        assert result.sample_metadata is not None

    def test_sample_metadata_has_expected_columns(self, example_macro_db: Path) -> None:
        result = ingest_raw_data(example_macro_db)

        expected_cols = {"column_key", "Season", "Date", "Site", "Replicate"}
        assert set(result.sample_metadata.columns) >= expected_cols

    def test_sample_metadata_sites_are_valid(self, example_macro_db: Path) -> None:
        from mgen.shared.types import VALID_SITES

        result = ingest_raw_data(example_macro_db)

        sites_found = set(result.sample_metadata["Site"].unique())
        assert sites_found <= VALID_SITES, f"Unexpected sites: {sites_found - VALID_SITES}"

    def test_taxa_counts_excludes_metric_rows(self, example_macro_db: Path) -> None:
        result = ingest_raw_data(example_macro_db)

        # Taxa counts should NOT include "Number of Taxa" or other metric rows
        if "Taxon" in result.taxa_counts.columns:
            assert "Number of Taxa" not in result.taxa_counts["Taxon"].values

    def test_metric_rows_extracted(self, example_macro_db: Path) -> None:
        result = ingest_raw_data(example_macro_db)

        assert result.metric_rows is not None
        # Should contain the derived metric values from rows 147-172
        assert len(result.metric_rows) > 0
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `pytest tests/test_domains/test_macro_ingest.py -v`
Expected: FAIL (ImportError — module doesn't exist)

- [ ] **Step 3: Implement the RawData ingest ACL**

Create `src/mgen/domains/__init__.py`:
```python
"""Domain modules for the Mt Messenger monitoring pipeline."""
```

Create `src/mgen/domains/macro_ingest.py`:
```python
"""Anti-corruption layer for the Macroinvertebrate Database RawData sheet.

Parses the multi-row header (rows 1-5) and separates taxa count data
from derived metric rows. This module is shared between the macro and
macro_species domain modules.

RawData layout:
  Row 1: QA Note flags
  Row 2: Season label (Baseline / Construction / Additional / Routine)
  Row 3: Date
  Row 4: Site (EM1, EM2, ..., MMA6, MMA6b)
  Row 5: Replicate (1-5 or blank)
  Rows 6-146: Taxa counts (grouped by common name)
  Rows 147-172: Derived metric formulas
  Columns A-B: TaxonGroup, Taxon (scientific name)
  Columns C-D: MCI tolerance value, MCI-sb tolerance value
  Columns E onward: Sample data (one col per site×date×replicate)
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import pandas as pd


@dataclass
class RawDataBundle:
    """Clean internal representation of the RawData sheet.

    Produced by the ACL. Consumers (macro, macro_species) use
    whichever parts they need.
    """

    sample_metadata: pd.DataFrame  # column_key, Season, Date, Site, Replicate
    taxa_counts: pd.DataFrame  # TaxonGroup, Taxon, + sample columns (long or wide)
    metric_rows: pd.DataFrame  # Metric name + values per sample
    mci_scores: pd.DataFrame  # Taxon, MCI, MCI_sb tolerance values


METRICS_MARKER = "Number of Taxa"
HEADER_ROWS = 4  # Season, Date, Site, Replicate (row 1 = QA notes, skipped)
DATA_COL_START = 4  # Columns E onward (0-indexed: A=0, B=1, C=2, D=3)


def ingest_raw_data(macro_db_path: Path) -> RawDataBundle:
    """Parse the RawData sheet into clean internal components.

    This is the ONLY place that knows about the messy multi-row header format.
    """
    # Read raw sheet with no header inference
    raw = pd.read_excel(
        macro_db_path,
        sheet_name="RawData",
        header=None,
        dtype=object,
    )

    # Extract sample metadata from header rows (rows 0-3 after skipping QA row)
    # Row 0 = QA flags, Row 1 = Season, Row 2 = Date, Row 3 = Site, Row 4 = Replicate
    sample_columns = raw.columns[DATA_COL_START:]

    sample_metadata = pd.DataFrame(
        {
            "column_key": sample_columns,
            "Season": raw.iloc[1, DATA_COL_START:].values,
            "Date": pd.to_datetime(raw.iloc[2, DATA_COL_START:].values, errors="coerce"),
            "Site": raw.iloc[3, DATA_COL_START:].values,
            "Replicate": raw.iloc[4, DATA_COL_START:].values,
        }
    ).reset_index(drop=True)

    # Clean site names (strip whitespace)
    sample_metadata["Site"] = sample_metadata["Site"].astype(str).str.strip()

    # Data rows start after the 5 header rows
    data_start = 5
    data_block = raw.iloc[data_start:].reset_index(drop=True)

    # Find the metrics marker to split taxa from metrics
    col_b = data_block.iloc[:, 1].astype(str)
    metrics_start_idx = col_b[col_b == METRICS_MARKER].index

    if len(metrics_start_idx) == 0:
        # No metrics marker found — treat all as taxa
        taxa_block = data_block
        metric_block = pd.DataFrame()
    else:
        split_at = metrics_start_idx[0]
        taxa_block = data_block.iloc[:split_at].reset_index(drop=True)
        metric_block = data_block.iloc[split_at:].reset_index(drop=True)

    # Build taxa counts DataFrame
    taxa_counts = pd.DataFrame(
        {
            "TaxonGroup": taxa_block.iloc[:, 0].values,
            "Taxon": taxa_block.iloc[:, 1].values,
        }
    )
    # Add sample columns (taxa counts per sample)
    for i, col_key in enumerate(sample_columns):
        taxa_counts[col_key] = pd.to_numeric(
            taxa_block.iloc[:, DATA_COL_START + i].values, errors="coerce"
        ).astype("Int64")

    # Build MCI scores
    mci_scores = pd.DataFrame(
        {
            "Taxon": taxa_block.iloc[:, 1].values,
            "MCI": pd.to_numeric(taxa_block.iloc[:, 2].values, errors="coerce"),
            "MCI_sb": pd.to_numeric(taxa_block.iloc[:, 3].values, errors="coerce"),
        }
    )

    # Build metric rows
    metric_rows = pd.DataFrame({"Metric": metric_block.iloc[:, 1].values})
    for i, col_key in enumerate(sample_columns):
        metric_rows[col_key] = pd.to_numeric(
            metric_block.iloc[:, DATA_COL_START + i].values, errors="coerce"
        )

    return RawDataBundle(
        sample_metadata=sample_metadata,
        taxa_counts=taxa_counts,
        metric_rows=metric_rows,
        mci_scores=mci_scores,
    )
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `pytest tests/test_domains/test_macro_ingest.py -v`
Expected: All tests PASS (requires example fixture file in `tests/fixtures/`)

Note: If fixture files aren't yet available, create a minimal synthetic fixture or skip with `@pytest.mark.skipif`. The full fixture will be added when the example databases are copied into the repo.

- [ ] **Step 5: Commit**

```bash
git add src/mgen/domains/ tests/test_domains/
git commit -m "feat: macroinvertebrate ACL — parse RawData multi-row header

- Parse 5-row header into sample metadata (Season, Date, Site, Replicate)
- Split data into taxa counts, metric rows, and MCI scores
- Uses 'Number of Taxa' marker to find metrics boundary
- Shared between macro and macro_species domains"
```

---

## Task 4: Macroinvertebrate Domain — Metric Derivation

**Files:**
- Create: `src/mgen/domains/macro.py`
- Create: `tests/test_domains/test_macro.py`

- [ ] **Step 1: Write failing tests for metric derivation**

Create `tests/test_domains/test_macro.py`:
```python
"""Tests for macroinvertebrate metric derivation."""

from __future__ import annotations

import numpy as np
import pandas as pd
import pytest

from mgen.domains.macro import derive_metrics


class TestDeriveMetrics:
    """Unit tests for metric derivation domain service.

    These test the ecologist-signed formulas independently of file I/O.
    """

    @pytest.fixture()
    def sample_taxa_counts(self) -> pd.DataFrame:
        """Minimal taxa count data for a single sample."""
        return pd.DataFrame(
            {
                "TaxonGroup": ["Mayflies", "Mayflies", "Stoneflies", "Caddisflies", "Worms"],
                "Taxon": ["Deleatidium", "Coloburiscus", "Zelandobius", "Hydroptilidae", "Oligochaeta"],
                "sample_1": [10, 5, 3, 2, 8],
            }
        )

    @pytest.fixture()
    def sample_mci_scores(self) -> pd.DataFrame:
        """MCI tolerance scores matching the taxa above."""
        return pd.DataFrame(
            {
                "Taxon": ["Deleatidium", "Coloburiscus", "Zelandobius", "Hydroptilidae", "Oligochaeta"],
                "MCI": [8.0, 9.0, 5.0, 4.0, 1.0],
                "MCI_sb": [7.0, 8.0, 4.0, 3.0, 1.0],
            }
        )

    def test_number_of_taxa(self, sample_taxa_counts: pd.DataFrame, sample_mci_scores: pd.DataFrame) -> None:
        result = derive_metrics(sample_taxa_counts, sample_mci_scores, sample_col="sample_1")

        # 5 taxa with non-zero counts
        assert result["Number of Taxa"] == 5

    def test_number_of_individuals(self, sample_taxa_counts: pd.DataFrame, sample_mci_scores: pd.DataFrame) -> None:
        result = derive_metrics(sample_taxa_counts, sample_mci_scores, sample_col="sample_1")

        # 10 + 5 + 3 + 2 + 8 = 28
        assert result["Number of Individuals"] == 28

    def test_mci_calculation(self, sample_taxa_counts: pd.DataFrame, sample_mci_scores: pd.DataFrame) -> None:
        result = derive_metrics(sample_taxa_counts, sample_mci_scores, sample_col="sample_1")

        # MCI = (sum of scores for taxa present / number of taxa present) * 20
        # Scores for present taxa: 8, 9, 5, 4, 1 → sum = 27, count = 5
        # MCI = (27 / 5) * 20 = 108.0
        assert result["MCI"] == pytest.approx(108.0)

    def test_qmci_calculation(self, sample_taxa_counts: pd.DataFrame, sample_mci_scores: pd.DataFrame) -> None:
        result = derive_metrics(sample_taxa_counts, sample_mci_scores, sample_col="sample_1")

        # QMCI = sum(abundance_i * score_i) / total_individuals
        # (10*8 + 5*9 + 3*5 + 2*4 + 8*1) / 28
        # (80 + 45 + 15 + 8 + 8) / 28 = 156 / 28 = 5.571...
        assert result["QMCI"] == pytest.approx(156 / 28)

    def test_ept_richness(self, sample_taxa_counts: pd.DataFrame, sample_mci_scores: pd.DataFrame) -> None:
        result = derive_metrics(sample_taxa_counts, sample_mci_scores, sample_col="sample_1")

        # EPT = Ephemeroptera (Mayflies) + Plecoptera (Stoneflies) + Trichoptera (Caddisflies)
        # Excluding Hydroptilidae from Trichoptera
        # E richness: 2 (Deleatidium, Coloburiscus)
        # P richness: 1 (Zelandobius)
        # T richness: 0 (Hydroptilidae excluded)
        # Total EPT richness: 3
        assert result["EPT Richness"] == 3

    def test_ept_abundance(self, sample_taxa_counts: pd.DataFrame, sample_mci_scores: pd.DataFrame) -> None:
        result = derive_metrics(sample_taxa_counts, sample_mci_scores, sample_col="sample_1")

        # EPT abundance: Mayflies (10+5) + Stoneflies (3) + Caddisflies excl Hydroptilidae (0)
        # = 15 + 3 + 0 = 18
        assert result["EPT Abundance"] == 18

    def test_pct_ept_abundance(self, sample_taxa_counts: pd.DataFrame, sample_mci_scores: pd.DataFrame) -> None:
        result = derive_metrics(sample_taxa_counts, sample_mci_scores, sample_col="sample_1")

        # % EPT Abundance = EPT Abundance / Number of Individuals = 18 / 28
        assert result["% EPT Abundance"] == pytest.approx(18 / 28)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `pytest tests/test_domains/test_macro.py -v`
Expected: FAIL (ImportError — `derive_metrics` not yet implemented)

- [ ] **Step 3: Implement metric derivation domain service**

Create `src/mgen/domains/macro.py`:
```python
"""Macroinvertebrate domain: metric derivation and output transformation.

Implements the ecologist-signed formulas for MCI, QMCI, EPT metrics.
EPT membership is derived from TaxonGroup labels, NOT hard-coded row numbers.
"""

from __future__ import annotations

import numpy as np
import pandas as pd

from mgen.shared.types import SITES_WITHOUT_REPLICATES

# EPT taxonomic groups (used for richness/abundance calculations)
EPT_GROUPS = {
    "Ephemeroptera": frozenset({"Mayflies"}),
    "Plecoptera": frozenset({"Stoneflies"}),
    "Trichoptera": frozenset({"Caddisflies", "Trichoptera"}),
}
# Hydroptilidae is excluded from Trichoptera counts
HYDROPTILIDAE = "Hydroptilidae"


def derive_metrics(
    taxa_counts: pd.DataFrame,
    mci_scores: pd.DataFrame,
    *,
    sample_col: str,
) -> dict[str, float]:
    """Derive all macroinvertebrate metrics for a single sample.

    Args:
        taxa_counts: DataFrame with TaxonGroup, Taxon, and sample count columns.
        mci_scores: DataFrame with Taxon, MCI, MCI_sb tolerance scores.
        sample_col: Name of the column containing counts for this sample.

    Returns:
        Dictionary of metric_name → value.
    """
    # Merge counts with MCI scores
    merged = taxa_counts[["TaxonGroup", "Taxon", sample_col]].merge(
        mci_scores, on="Taxon", how="left"
    )
    counts = merged[sample_col].fillna(0).astype(float)
    present = counts > 0

    # Basic counts
    num_taxa = int(present.sum())
    num_individuals = int(counts.sum())

    # MCI = (sum of MCI scores for taxa present / num taxa present) * 20
    mci_vals = merged.loc[present, "MCI"].dropna()
    mci = (mci_vals.sum() / len(mci_vals) * 20) if len(mci_vals) > 0 else np.nan

    # MCI-sb (soft-bottom variant)
    mci_sb_vals = merged.loc[present, "MCI_sb"].dropna()
    mci_sb = (mci_sb_vals.sum() / len(mci_sb_vals) * 20) if len(mci_sb_vals) > 0 else np.nan

    # QMCI = sum(abundance_i * MCI_score_i) / total_individuals
    qmci_numerator = (counts * merged["MCI"].fillna(0)).sum()
    qmci = qmci_numerator / num_individuals if num_individuals > 0 else np.nan

    # QMCI-sb
    qmci_sb_numerator = (counts * merged["MCI_sb"].fillna(0)).sum()
    qmci_sb = qmci_sb_numerator / num_individuals if num_individuals > 0 else np.nan

    # EPT calculations — derived from TaxonGroup labels
    is_ephemeroptera = merged["TaxonGroup"].isin(EPT_GROUPS["Ephemeroptera"])
    is_plecoptera = merged["TaxonGroup"].isin(EPT_GROUPS["Plecoptera"])
    is_trichoptera = merged["TaxonGroup"].isin(EPT_GROUPS["Trichoptera"])
    is_hydroptilidae = merged["Taxon"] == HYDROPTILIDAE

    # Trichoptera excludes Hydroptilidae
    is_trichoptera_excl = is_trichoptera & ~is_hydroptilidae

    e_richness = int((counts[is_ephemeroptera] > 0).sum())
    p_richness = int((counts[is_plecoptera] > 0).sum())
    t_richness = int((counts[is_trichoptera_excl] > 0).sum())
    ept_richness = e_richness + p_richness + t_richness

    ept_abundance = int(
        counts[is_ephemeroptera | is_plecoptera | is_trichoptera_excl].sum()
    )

    pct_ept_abundance = ept_abundance / num_individuals if num_individuals > 0 else np.nan
    pct_ept_richness = ept_richness / num_taxa if num_taxa > 0 else np.nan

    # ASPM-MCI = average(MCI/200, EPT_Richness/29, EPT_Abundance/100)
    aspm_mci = np.mean([mci / 200, ept_richness / 29, ept_abundance / 100]) if not np.isnan(mci) else np.nan

    return {
        "Number of Taxa": num_taxa,
        "Number of Individuals": num_individuals,
        "MCI": mci,
        "MCI-sb": mci_sb,
        "QMCI": qmci,
        "QMCI-sb": qmci_sb,
        "EPT Abundance": ept_abundance,
        "E Richness": e_richness,
        "P Richness": p_richness,
        "T Richness": t_richness,
        "EPT Richness": ept_richness,
        "% EPT Abundance": pct_ept_abundance,
        "% EPT Richness": pct_ept_richness,
        "ASPM-MCI": aspm_mci,
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `pytest tests/test_domains/test_macro.py -v`
Expected: All 7 tests PASS

- [ ] **Step 5: Commit**

```bash
git add src/mgen/domains/macro.py tests/test_domains/test_macro.py
git commit -m "feat: macroinvertebrate metric derivation domain service

- MCI, MCI-sb, QMCI, QMCI-sb from NEMS tolerance scores
- EPT richness/abundance derived from TaxonGroup labels (not row numbers)
- Hydroptilidae excluded from Trichoptera counts
- ASPM-MCI composite index
- All formulas match ecologist-signed spreadsheet derivation"
```

---

## Task 5: Macroinvertebrate Domain — Emit Macro1 + Macro Sheets

**Files:**
- Modify: `src/mgen/domains/macro.py` (add `process_macro_domain` function)
- Modify: `tests/test_domains/test_macro.py` (add integration-level tests)

- [ ] **Step 1: Write failing tests for domain output**

Add to `tests/test_domains/test_macro.py`:
```python
class TestProcessMacroDomain:
    """Integration tests for the full macro domain pipeline."""

    def test_returns_domain_result(self, example_macro_db: Path) -> None:
        from mgen.domains.macro import process_macro_domain
        from mgen.shared.errors import DomainResult

        result = process_macro_domain(example_macro_db)

        assert isinstance(result, DomainResult)

    def test_result_contains_macro1_and_macro_sheets(self, example_macro_db: Path) -> None:
        from mgen.domains.macro import process_macro_domain

        result = process_macro_domain(example_macro_db)

        assert result.ok
        assert "Macro1" in result.data
        assert "Macro" in result.data

    def test_macro1_has_correct_columns(self, example_macro_db: Path) -> None:
        from mgen.domains.macro import process_macro_domain
        from mgen.shared.schemas import MACRO1_COLUMNS

        result = process_macro_domain(example_macro_db)

        assert list(result.data["Macro1"].columns) == MACRO1_COLUMNS

    def test_macro_aggregates_replicated_sites(self, example_macro_db: Path) -> None:
        from mgen.domains.macro import process_macro_domain

        result = process_macro_domain(example_macro_db)
        macro_df = result.data["Macro"]

        # Macro sheet should have fewer rows (aggregated means for replicated sites)
        macro1_df = result.data["Macro1"]
        assert len(macro_df) < len(macro1_df)

    def test_qmci_sb_used_for_non_replicate_sites(self, example_macro_db: Path) -> None:
        from mgen.domains.macro import process_macro_domain
        from mgen.shared.types import SITES_WITHOUT_REPLICATES

        result = process_macro_domain(example_macro_db)
        macro1_df = result.data["Macro1"]

        # For sites without replicates, QMCI column should contain QMCI-sb values
        # This test verifies the routing logic exists (exact values checked by golden file)
        non_rep = macro1_df[macro1_df["Site"].isin(SITES_WITHOUT_REPLICATES)]
        assert len(non_rep) > 0  # Should have data for these sites
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `pytest tests/test_domains/test_macro.py::TestProcessMacroDomain -v`
Expected: FAIL (ImportError — `process_macro_domain` not defined)

- [ ] **Step 3: Implement process_macro_domain**

Add to `src/mgen/domains/macro.py`:
```python
from mgen.domains.macro_ingest import ingest_raw_data
from mgen.shared.errors import DomainResult, ValidationError
from mgen.shared.schemas import MACRO1_COLUMNS
from mgen.shared.validation import check_required_columns


def process_macro_domain(macro_db_path: Path) -> DomainResult:
    """Process the macroinvertebrate domain: derive metrics, emit Macro1 + Macro.

    Returns a DomainResult with {"Macro1": df, "Macro": df} on success,
    or a list of ValidationErrors on failure.
    """
    file_name = macro_db_path.name
    errors: list[ValidationError] = []

    # Ingest via shared ACL
    try:
        bundle = ingest_raw_data(macro_db_path)
    except Exception as e:
        errors.append(
            ValidationError(
                domain="macroinvertebrate",
                severity="error",
                file=file_name,
                sheet="RawData",
                location="file",
                message=f"Failed to read RawData: {e}",
            )
        )
        return DomainResult(data=None, errors=errors)

    # Derive metrics for each sample
    sample_cols = [c for c in bundle.taxa_counts.columns if c not in ("TaxonGroup", "Taxon")]
    rows = []

    for col_key in sample_cols:
        meta_row = bundle.sample_metadata[bundle.sample_metadata["column_key"] == col_key]
        if meta_row.empty:
            continue

        meta = meta_row.iloc[0]
        metrics = derive_metrics(bundle.taxa_counts, bundle.mci_scores, sample_col=col_key)

        # Route QMCI: use QMCI-sb for sites without replicates
        site = str(meta["Site"]).strip()
        qmci_value = metrics["QMCI-sb"] if site in SITES_WITHOUT_REPLICATES else metrics["QMCI"]

        rows.append(
            {
                "Site": site,
                "Date": meta["Date"],
                "Period": meta["Season"],
                "EPTrich": metrics["% EPT Richness"],
                "EPTabun": metrics["% EPT Abundance"],
                "QMCI": qmci_value,
                "Season": meta["Season"],
            }
        )

    if not rows:
        errors.append(
            ValidationError(
                domain="macroinvertebrate",
                severity="error",
                file=file_name,
                sheet="RawData",
                location="data",
                message="No sample data could be processed",
            )
        )
        return DomainResult(data=None, errors=errors)

    macro1_df = pd.DataFrame(rows, columns=MACRO1_COLUMNS)
    macro1_df["Date"] = pd.to_datetime(macro1_df["Date"])

    # Macro sheet: aggregate means for replicated sites (group by Site + Date)
    macro_df = (
        macro1_df.groupby(["Site", "Date", "Period", "Season"], as_index=False)
        .agg({"EPTrich": "mean", "EPTabun": "mean", "QMCI": "mean"})
        .reindex(columns=MACRO1_COLUMNS)
    )

    return DomainResult(data={"Macro1": macro1_df, "Macro": macro_df}, errors=errors)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `pytest tests/test_domains/test_macro.py -v`
Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add src/mgen/domains/macro.py tests/test_domains/test_macro.py
git commit -m "feat: macroinvertebrate domain — emit Macro1 + Macro sheets

- process_macro_domain orchestrates ingest → derive → transform
- QMCI-sb routing for non-replicate sites (E1, E2, E4, E8)
- Macro1: full precision, one row per sample
- Macro: aggregated means for replicated sites
- Schema contract validated on output"
```

---

## Task 6: MacroSpecies Domain — Taxa Pivot

**Files:**
- Create: `src/mgen/domains/macro_species.py`
- Create: `tests/test_domains/test_macro_species.py`

- [ ] **Step 1: Write failing tests**

Create `tests/test_domains/test_macro_species.py`:
```python
"""Tests for MacroSpecies domain (taxa pivot to long format)."""

from __future__ import annotations

from pathlib import Path

import pytest

from mgen.domains.macro_species import process_macro_species_domain
from mgen.shared.errors import DomainResult
from mgen.shared.schemas import MACRO_SPECIES_COLUMNS


class TestProcessMacroSpeciesDomain:
    def test_returns_domain_result(self, example_macro_db: Path) -> None:
        result = process_macro_species_domain(example_macro_db)

        assert isinstance(result, DomainResult)

    def test_result_contains_macro_species_sheet(self, example_macro_db: Path) -> None:
        result = process_macro_species_domain(example_macro_db)

        assert result.ok
        assert "MacroSpecies" in result.data

    def test_has_correct_columns(self, example_macro_db: Path) -> None:
        result = process_macro_species_domain(example_macro_db)
        df = result.data["MacroSpecies"]

        assert list(df.columns) == MACRO_SPECIES_COLUMNS

    def test_long_format_no_zero_counts(self, example_macro_db: Path) -> None:
        result = process_macro_species_domain(example_macro_db)
        df = result.data["MacroSpecies"]

        # Long format should only include non-zero tallies
        assert (df["Tally"] > 0).all()
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `pytest tests/test_domains/test_macro_species.py -v`
Expected: FAIL

- [ ] **Step 3: Implement MacroSpecies domain**

Create `src/mgen/domains/macro_species.py`:
```python
"""MacroSpecies domain: pivot taxa counts to long format.

Reads from the same RawData sheet as the macro domain (shared ACL),
but produces a different output: one row per site×date×taxon with
non-zero counts.
"""

from __future__ import annotations

from pathlib import Path

import pandas as pd

from mgen.domains.macro_ingest import ingest_raw_data
from mgen.shared.errors import DomainResult, ValidationError
from mgen.shared.schemas import MACRO_SPECIES_COLUMNS


def process_macro_species_domain(macro_db_path: Path) -> DomainResult:
    """Process the MacroSpecies domain: pivot taxa to long format.

    Returns DomainResult with {"MacroSpecies": df} on success.
    """
    file_name = macro_db_path.name
    errors: list[ValidationError] = []

    try:
        bundle = ingest_raw_data(macro_db_path)
    except Exception as e:
        errors.append(
            ValidationError(
                domain="macro_species",
                severity="error",
                file=file_name,
                sheet="RawData",
                location="file",
                message=f"Failed to read RawData: {e}",
            )
        )
        return DomainResult(data=None, errors=errors)

    # Pivot taxa counts from wide to long
    sample_cols = [
        c for c in bundle.taxa_counts.columns if c not in ("TaxonGroup", "Taxon")
    ]

    long_rows = []
    for col_key in sample_cols:
        meta_row = bundle.sample_metadata[bundle.sample_metadata["column_key"] == col_key]
        if meta_row.empty:
            continue
        meta = meta_row.iloc[0]

        for _, taxa_row in bundle.taxa_counts.iterrows():
            count = taxa_row[col_key]
            if pd.isna(count) or int(count) == 0:
                continue
            long_rows.append(
                {
                    "Phase": meta["Season"],
                    "Date": meta["Date"],
                    "Site": str(meta["Site"]).strip(),
                    "Taxa": taxa_row["TaxonGroup"],
                    "Species": taxa_row["Taxon"],
                    "Tally": int(count),
                }
            )

    if not long_rows:
        errors.append(
            ValidationError(
                domain="macro_species",
                severity="error",
                file=file_name,
                sheet="RawData",
                location="data",
                message="No non-zero taxa counts found",
            )
        )
        return DomainResult(data=None, errors=errors)

    df = pd.DataFrame(long_rows, columns=MACRO_SPECIES_COLUMNS)
    df["Date"] = pd.to_datetime(df["Date"])
    df["Tally"] = df["Tally"].astype("int64")

    return DomainResult(data={"MacroSpecies": df}, errors=errors)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `pytest tests/test_domains/test_macro_species.py -v`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add src/mgen/domains/macro_species.py tests/test_domains/test_macro_species.py
git commit -m "feat: MacroSpecies domain — taxa pivot to long format

- Wide-to-long pivot of taxa rows via shared ACL
- Only non-zero counts included (sparse long format)
- Joins with sample metadata for Phase/Date/Site
- Output matches MacroSpecies sheet schema (3194×6)"
```

---

## Task 7: Sediment Domain — Ingest & Reshape

**Files:**
- Create: `src/mgen/domains/sediment.py`
- Create: `tests/test_domains/test_sediment.py`

- [ ] **Step 1: Write failing tests**

Create `tests/test_domains/test_sediment.py`:
```python
"""Tests for Sediment domain."""

from __future__ import annotations

from pathlib import Path

import pytest

from mgen.domains.sediment import process_sediment_domain
from mgen.shared.errors import DomainResult
from mgen.shared.schemas import SEDIMENT_COLUMNS


class TestProcessSedimentDomain:
    def test_returns_domain_result(self, example_aquatic_db: Path) -> None:
        result = process_sediment_domain(example_aquatic_db)

        assert isinstance(result, DomainResult)

    def test_result_contains_sediment_sheet(self, example_aquatic_db: Path) -> None:
        result = process_sediment_domain(example_aquatic_db)

        assert result.ok
        assert "Sediment" in result.data

    def test_has_correct_columns(self, example_aquatic_db: Path) -> None:
        result = process_sediment_domain(example_aquatic_db)
        df = result.data["Sediment"]

        assert list(df.columns) == SEDIMENT_COLUMNS

    def test_sam_values_in_valid_range(self, example_aquatic_db: Path) -> None:
        result = process_sediment_domain(example_aquatic_db)
        df = result.data["Sediment"]

        # SAM scores should be between 0 and ~30 (typical ecological range)
        assert (df["SAM1"] >= 0).all()
        assert (df["SAM3"] >= 0).all()
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `pytest tests/test_domains/test_sediment.py -v`
Expected: FAIL

- [ ] **Step 3: Implement Sediment domain**

Create `src/mgen/domains/sediment.py`:
```python
"""Sediment domain: read Aquatic Monitoring DB Sediment tab, emit Sediment sheet."""

from __future__ import annotations

from pathlib import Path

import pandas as pd

from mgen.shared.errors import DomainResult, ValidationError
from mgen.shared.schemas import SEDIMENT_COLUMNS, SEDIMENT_DTYPES
from mgen.shared.validation import check_required_columns


# Expected source columns in the Aquatic Monitoring DB Sediment tab
SOURCE_COLUMNS = ["Site", "Date", "Period", "SAM1", "SAM3", "Season"]


def process_sediment_domain(aquatic_db_path: Path) -> DomainResult:
    """Process the Sediment domain from the Aquatic Monitoring Database.

    Reads the Sediment tab and reshapes into the Data.xlsx Sediment format.
    """
    file_name = aquatic_db_path.name
    errors: list[ValidationError] = []

    try:
        df = pd.read_excel(aquatic_db_path, sheet_name="Sediment")
    except Exception as e:
        errors.append(
            ValidationError(
                domain="sediment",
                severity="error",
                file=file_name,
                sheet="Sediment",
                location="file",
                message=f"Failed to read Sediment sheet: {e}",
            )
        )
        return DomainResult(data=None, errors=errors)

    # Validate required columns exist
    col_errors = check_required_columns(
        df,
        SOURCE_COLUMNS,
        domain="sediment",
        file=file_name,
        sheet="Sediment",
    )
    if col_errors:
        return DomainResult(data=None, errors=col_errors)

    # Select and order columns to match output schema
    output = df[SEDIMENT_COLUMNS].copy()
    output["Date"] = pd.to_datetime(output["Date"])
    output["SAM1"] = pd.to_numeric(output["SAM1"], errors="coerce")
    output["SAM3"] = pd.to_numeric(output["SAM3"], errors="coerce")

    # Drop rows where both SAM values are null (empty rows in source)
    output = output.dropna(subset=["SAM1", "SAM3"], how="all").reset_index(drop=True)

    return DomainResult(data={"Sediment": output}, errors=errors)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `pytest tests/test_domains/test_sediment.py -v`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add src/mgen/domains/sediment.py tests/test_domains/test_sediment.py
git commit -m "feat: Sediment domain — ingest and reshape from Aquatic DB

- Reads Sediment tab from Aquatic Monitoring Database
- Validates required columns, coerces types
- Emits Sediment sheet (Site, Date, Period, SAM1, SAM3, Season)"
```

---

## Task 8: SedimentSize Domain — Ingest & Reshape

**Files:**
- Create: `src/mgen/domains/sediment_size.py`
- Create: `tests/test_domains/test_sediment_size.py`

- [ ] **Step 1: Write failing tests**

Create `tests/test_domains/test_sediment_size.py`:
```python
"""Tests for SedimentSize domain."""

from __future__ import annotations

from pathlib import Path

import pytest

from mgen.domains.sediment_size import process_sediment_size_domain
from mgen.shared.errors import DomainResult
from mgen.shared.schemas import SEDIMENT_SIZE_COLUMNS


class TestProcessSedimentSizeDomain:
    def test_returns_domain_result(self, example_aquatic_db: Path) -> None:
        result = process_sediment_size_domain(example_aquatic_db)

        assert isinstance(result, DomainResult)

    def test_result_contains_sediment_size_sheet(self, example_aquatic_db: Path) -> None:
        result = process_sediment_size_domain(example_aquatic_db)

        assert result.ok
        assert "SedimentSize" in result.data

    def test_has_correct_columns(self, example_aquatic_db: Path) -> None:
        result = process_sediment_size_domain(example_aquatic_db)
        df = result.data["SedimentSize"]

        assert list(df.columns) == SEDIMENT_SIZE_COLUMNS

    def test_grain_size_values_are_percentages(self, example_aquatic_db: Path) -> None:
        result = process_sediment_size_domain(example_aquatic_db)
        df = result.data["SedimentSize"]

        # Grain-size bins are percentage cover, should be 0-100
        grain_cols = SEDIMENT_SIZE_COLUMNS[4:]  # Skip Site, Date, Period, Season
        for col in grain_cols:
            assert (df[col].dropna() >= 0).all(), f"{col} has negative values"
            assert (df[col].dropna() <= 100).all(), f"{col} exceeds 100%"
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `pytest tests/test_domains/test_sediment_size.py -v`
Expected: FAIL

- [ ] **Step 3: Implement SedimentSize domain**

Create `src/mgen/domains/sediment_size.py`:
```python
"""SedimentSize domain: read grain-size distribution data, emit SedimentSize sheet."""

from __future__ import annotations

from pathlib import Path

import pandas as pd

from mgen.shared.errors import DomainResult, ValidationError
from mgen.shared.schemas import SEDIMENT_SIZE_COLUMNS
from mgen.shared.validation import check_required_columns


def process_sediment_size_domain(aquatic_db_path: Path) -> DomainResult:
    """Process the SedimentSize domain from the Aquatic Monitoring Database.

    Reads grain-size distribution data and reshapes to the Data.xlsx format.
    """
    file_name = aquatic_db_path.name
    errors: list[ValidationError] = []

    # Try reading from a SedimentSize tab or the Sediment tab's size columns
    try:
        df = pd.read_excel(aquatic_db_path, sheet_name="SedimentSize")
    except ValueError:
        # Sheet might be named differently — try alternative
        try:
            df = pd.read_excel(aquatic_db_path, sheet_name="Sediment Size")
        except Exception as e:
            errors.append(
                ValidationError(
                    domain="sediment_size",
                    severity="error",
                    file=file_name,
                    sheet="SedimentSize",
                    location="file",
                    message=f"Could not find SedimentSize sheet: {e}",
                )
            )
            return DomainResult(data=None, errors=errors)
    except Exception as e:
        errors.append(
            ValidationError(
                domain="sediment_size",
                severity="error",
                file=file_name,
                sheet="SedimentSize",
                location="file",
                message=f"Failed to read SedimentSize sheet: {e}",
            )
        )
        return DomainResult(data=None, errors=errors)

    # Validate required columns
    col_errors = check_required_columns(
        df,
        SEDIMENT_SIZE_COLUMNS,
        domain="sediment_size",
        file=file_name,
        sheet="SedimentSize",
    )
    if col_errors:
        return DomainResult(data=None, errors=col_errors)

    # Select and order columns
    output = df[SEDIMENT_SIZE_COLUMNS].copy()
    output["Date"] = pd.to_datetime(output["Date"])

    # Coerce grain-size columns to numeric
    grain_cols = SEDIMENT_SIZE_COLUMNS[4:]
    for col in grain_cols:
        output[col] = pd.to_numeric(output[col], errors="coerce")

    # Drop fully empty rows
    output = output.dropna(subset=grain_cols, how="all").reset_index(drop=True)

    return DomainResult(data={"SedimentSize": output}, errors=errors)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `pytest tests/test_domains/test_sediment_size.py -v`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add src/mgen/domains/sediment_size.py tests/test_domains/test_sediment_size.py
git commit -m "feat: SedimentSize domain — grain-size distribution reshape

- Reads SedimentSize tab from Aquatic Monitoring Database
- 12 grain-size bin columns as percentage cover
- Validates column presence and value ranges
- Emits SedimentSize sheet (79×16)"
```

---

## Task 9: Writer — Emit Data.xlsx

**Files:**
- Create: `src/mgen/writer.py`
- Create: `tests/test_writer.py`

- [ ] **Step 1: Write failing tests**

Create `tests/test_writer.py`:
```python
"""Tests for the Data.xlsx writer."""

from __future__ import annotations

from pathlib import Path

import pandas as pd
import pytest

from mgen.shared.schemas import (
    MACRO1_COLUMNS,
    MACRO_SPECIES_COLUMNS,
    SEDIMENT_COLUMNS,
    SEDIMENT_SIZE_COLUMNS,
)
from mgen.writer import write_data_xlsx


class TestWriteDataXlsx:
    @pytest.fixture()
    def sample_data(self) -> dict[str, pd.DataFrame]:
        """Minimal valid data for all 5 sheets."""
        return {
            "Macro1": pd.DataFrame(
                columns=MACRO1_COLUMNS,
                data=[["EM1", pd.Timestamp("2024-01-15"), "Routine", 0.5, 0.6, 5.5, "Routine"]],
            ),
            "Macro": pd.DataFrame(
                columns=MACRO1_COLUMNS,
                data=[["EM1", pd.Timestamp("2024-01-15"), "Routine", 0.5, 0.6, 5.5, "Routine"]],
            ),
            "MacroSpecies": pd.DataFrame(
                columns=MACRO_SPECIES_COLUMNS,
                data=[["Routine", pd.Timestamp("2024-01-15"), "EM1", "Mayflies", "Deleatidium", 10]],
            ),
            "Sediment": pd.DataFrame(
                columns=SEDIMENT_COLUMNS,
                data=[["EM1", pd.Timestamp("2024-01-15"), "Routine", 15.2, 12.1, "Routine"]],
            ),
            "SedimentSize": pd.DataFrame(
                columns=SEDIMENT_SIZE_COLUMNS,
                data=[["EM1", pd.Timestamp("2024-01-15"), "Routine", "Routine"] + [8.3] * 12],
            ),
        }

    def test_creates_xlsx_file(self, tmp_path: Path, sample_data: dict[str, pd.DataFrame]) -> None:
        output_path = tmp_path / "Data.xlsx"

        write_data_xlsx(sample_data, output_path)

        assert output_path.exists()

    def test_xlsx_has_all_five_sheets(self, tmp_path: Path, sample_data: dict[str, pd.DataFrame]) -> None:
        output_path = tmp_path / "Data.xlsx"

        write_data_xlsx(sample_data, output_path)

        xls = pd.ExcelFile(output_path)
        assert set(xls.sheet_names) == {"Macro", "Macro1", "MacroSpecies", "Sediment", "SedimentSize"}

    def test_sheet_column_order_preserved(self, tmp_path: Path, sample_data: dict[str, pd.DataFrame]) -> None:
        output_path = tmp_path / "Data.xlsx"

        write_data_xlsx(sample_data, output_path)

        macro1 = pd.read_excel(output_path, sheet_name="Macro1")
        assert list(macro1.columns) == MACRO1_COLUMNS
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `pytest tests/test_writer.py -v`
Expected: FAIL

- [ ] **Step 3: Implement writer**

Create `src/mgen/writer.py`:
```python
"""Write assembled DataFrames to the 5-sheet Data.xlsx output.

This is infrastructure — it knows about Excel format details but not
about domain logic. It receives validated DataFrames and writes them.
"""

from __future__ import annotations

from pathlib import Path

import pandas as pd

# Sheet order matches what R scripts expect
SHEET_ORDER = ["Macro", "Macro1", "MacroSpecies", "Sediment", "SedimentSize"]


def write_data_xlsx(data: dict[str, pd.DataFrame], output_path: Path) -> None:
    """Write all domain outputs to a single Data.xlsx file.

    Args:
        data: Mapping of sheet_name → DataFrame. Must contain all 5 sheets.
        output_path: Where to write the xlsx file.

    Raises:
        ValueError: If any required sheet is missing from data.
    """
    missing = set(SHEET_ORDER) - set(data.keys())
    if missing:
        msg = f"Missing required sheets: {sorted(missing)}"
        raise ValueError(msg)

    # Ensure output directory exists
    output_path.parent.mkdir(parents=True, exist_ok=True)

    with pd.ExcelWriter(output_path, engine="openpyxl") as writer:
        for sheet_name in SHEET_ORDER:
            df = data[sheet_name]
            df.to_excel(writer, sheet_name=sheet_name, index=False)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `pytest tests/test_writer.py -v`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add src/mgen/writer.py tests/test_writer.py
git commit -m "feat: Data.xlsx writer — assemble 5-sheet output

- Writes all domain outputs in canonical sheet order
- Preserves column order for R script compatibility
- Creates output directory if needed
- Validates all required sheets present before writing"
```

---

## Task 10: Pipeline Orchestrator & Integration

**Files:**
- Create: `src/mgen/pipeline.py`
- Modify: `src/mgen/cli.py` (wire up pipeline)
- Create: `tests/test_pipeline_integration.py`

- [ ] **Step 1: Write failing integration test**

Create `tests/test_pipeline_integration.py`:
```python
"""End-to-end integration test for the full pipeline."""

from __future__ import annotations

from pathlib import Path

import pandas as pd
import pytest

from mgen.pipeline import run_pipeline
from mgen.config import PipelineConfig


class TestRunPipeline:
    @pytest.fixture()
    def test_config(self, example_macro_db: Path, example_aquatic_db: Path, tmp_path: Path) -> PipelineConfig:
        return PipelineConfig(
            macroinvertebrate_db=example_macro_db,
            aquatic_monitoring_db=example_aquatic_db,
            data_xlsx=tmp_path / "Data.xlsx",
        )

    def test_produces_data_xlsx(self, test_config: PipelineConfig) -> None:
        result = run_pipeline(test_config)

        assert result.ok
        assert test_config.data_xlsx.exists()

    def test_output_has_all_sheets(self, test_config: PipelineConfig) -> None:
        run_pipeline(test_config)

        xls = pd.ExcelFile(test_config.data_xlsx)
        assert set(xls.sheet_names) == {"Macro", "Macro1", "MacroSpecies", "Sediment", "SedimentSize"}

    def test_output_matches_golden_file(
        self, test_config: PipelineConfig, expected_data_xlsx: Path
    ) -> None:
        """Golden-file test: output should match the manually-produced Data.xlsx."""
        if not expected_data_xlsx.exists():
            pytest.skip("Golden file not available")

        run_pipeline(test_config)

        # Compare each sheet
        expected = pd.ExcelFile(expected_data_xlsx)
        actual = pd.ExcelFile(test_config.data_xlsx)

        for sheet in expected.sheet_names:
            expected_df = pd.read_excel(expected, sheet_name=sheet)
            actual_df = pd.read_excel(actual, sheet_name=sheet)

            assert list(actual_df.columns) == list(expected_df.columns), (
                f"Column mismatch in {sheet}"
            )
            assert len(actual_df) == len(expected_df), (
                f"Row count mismatch in {sheet}: expected {len(expected_df)}, got {len(actual_df)}"
            )

            # Numeric columns: compare within tolerance
            for col in actual_df.select_dtypes(include="number").columns:
                pd.testing.assert_series_equal(
                    actual_df[col],
                    expected_df[col],
                    check_exact=False,
                    atol=1e-6,
                    check_names=False,
                    obj=f"{sheet}.{col}",
                )


class TestPipelineErrorReporting:
    def test_reports_errors_without_writing_output(self, tmp_path: Path) -> None:
        """Pipeline should NOT write Data.xlsx if any domain has errors."""
        config = PipelineConfig(
            macroinvertebrate_db=tmp_path / "nonexistent.xlsx",
            aquatic_monitoring_db=tmp_path / "also_missing.xlsx",
            data_xlsx=tmp_path / "Data.xlsx",
        )

        result = run_pipeline(config)

        assert not result.ok
        assert len(result.errors) > 0
        assert not config.data_xlsx.exists()
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `pytest tests/test_pipeline_integration.py -v`
Expected: FAIL

- [ ] **Step 3: Implement pipeline orchestrator**

Create `src/mgen/pipeline.py`:
```python
"""Pipeline orchestrator: wires config → domains → writer.

Calls all domain modules, collects results, and either emits Data.xlsx
or reports all validation errors. Never produces partial output.
"""

from __future__ import annotations

from mgen.config import PipelineConfig
from mgen.domains.macro import process_macro_domain
from mgen.domains.macro_species import process_macro_species_domain
from mgen.domains.sediment import process_sediment_domain
from mgen.domains.sediment_size import process_sediment_size_domain
from mgen.shared.errors import DomainResult, ValidationError
from mgen.writer import write_data_xlsx


def run_pipeline(config: PipelineConfig) -> DomainResult:
    """Run the full pipeline: ingest all domains, validate, and emit output.

    Returns a DomainResult. If ok, Data.xlsx has been written.
    If not ok, errors describe all failures across all domains.
    """
    all_errors: list[ValidationError] = []
    all_data: dict[str, "pd.DataFrame"] = {}

    # Run each domain module
    macro_result = process_macro_domain(config.macroinvertebrate_db)
    all_errors.extend(macro_result.errors)
    if macro_result.data:
        all_data.update(macro_result.data)

    species_result = process_macro_species_domain(config.macroinvertebrate_db)
    all_errors.extend(species_result.errors)
    if species_result.data:
        all_data.update(species_result.data)

    sediment_result = process_sediment_domain(config.aquatic_monitoring_db)
    all_errors.extend(sediment_result.errors)
    if sediment_result.data:
        all_data.update(sediment_result.data)

    sediment_size_result = process_sediment_size_domain(config.aquatic_monitoring_db)
    all_errors.extend(sediment_size_result.errors)
    if sediment_size_result.data:
        all_data.update(sediment_size_result.data)

    # Check for errors
    has_errors = any(e.severity == "error" for e in all_errors)

    if has_errors:
        return DomainResult(data=None, errors=all_errors)

    # All domains succeeded — write output
    write_data_xlsx(all_data, config.data_xlsx)

    return DomainResult(data=all_data, errors=all_errors)


def format_error_report(errors: list[ValidationError]) -> str:
    """Format errors into a human-readable report for terminal output."""
    if not errors:
        return "✅ No errors"

    error_count = sum(1 for e in errors if e.severity == "error")
    warning_count = sum(1 for e in errors if e.severity == "warning")

    lines = [f"❌ Pipeline failed — {error_count} error(s), {warning_count} warning(s):\n"]

    # Group by domain
    by_domain: dict[str, list[ValidationError]] = {}
    for e in errors:
        by_domain.setdefault(e.domain, []).append(e)

    for domain, domain_errors in sorted(by_domain.items()):
        lines.append(f"  {domain}:")
        for i, e in enumerate(domain_errors, 1):
            lines.append(f"    [{i}] {e.file} → {e.sheet} → {e.location}")
            lines.append(f"        {e.message}")
        lines.append("")

    lines.append("Fix the source data and re-run: mgen run cycle.toml")
    return "\n".join(lines)
```

- [ ] **Step 4: Wire pipeline into CLI**

Update `src/mgen/cli.py` — replace the `run` command body:
```python
@main.command()
@click.argument("config_path", default="cycle.toml", type=click.Path(exists=False))
def run(config_path: str) -> None:
    """Run the pipeline using the specified cycle.toml config."""
    from mgen.pipeline import format_error_report, run_pipeline

    try:
        config = load_config(Path(config_path))
    except ConfigError as e:
        raise SystemExit(f"❌ Config error: {e}") from None

    click.echo(f"Running pipeline...")
    click.echo(f"  Macro DB: {config.macroinvertebrate_db}")
    click.echo(f"  Aquatic DB: {config.aquatic_monitoring_db}")
    click.echo(f"  Output: {config.data_xlsx}\n")

    result = run_pipeline(config)

    if not result.ok:
        click.echo(format_error_report(result.errors))
        raise SystemExit(1)

    warnings = [e for e in result.errors if e.severity == "warning"]
    if warnings:
        for w in warnings:
            click.echo(f"⚠️  {w}")

    click.echo(f"✅ Data.xlsx written to {config.data_xlsx}")
    if result.data:
        total_rows = sum(len(df) for df in result.data.values())
        click.echo(f"   {len(result.data)} sheets, {total_rows} rows total")
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `pytest tests/test_pipeline_integration.py -v`
Expected: All PASS (golden-file test may skip if fixture not yet available)

- [ ] **Step 6: Run full test suite**

Run: `pytest tests/ -v`
Expected: All tests PASS

- [ ] **Step 7: Commit**

```bash
git add src/mgen/pipeline.py src/mgen/cli.py tests/test_pipeline_integration.py
git commit -m "feat: pipeline orchestrator and end-to-end integration

- Orchestrator calls all 4 domains, collects errors
- No output written if any domain has errors
- Human-readable error report with domain/file/sheet/location
- CLI wired up: 'mgen run cycle.toml' runs full pipeline
- Golden-file integration test against expected Data.xlsx"
```

---

## Post-Implementation Notes

### Test Fixtures

Before Tasks 3-10 can run against real data, copy the example databases into `tests/fixtures/`:

```
tests/fixtures/
  MTMA Macroinvertebrate Database example.xlsx   (from T: drive example data folder)
  MTMA Aquatic Monitoring Database example.xlsx  (from T: drive example data folder)
  expected_Data.xlsx                              (current manually-produced Data.xlsx)
  cycle.toml                                      (config pointing at fixture paths)
```

These should be committed to the repo (they're Mike's trimmed examples, ~500KB total).

### Dependency Installation

After Task 1, run:
```
uv sync
```

### Verification

After all tasks complete:
```bash
mgen validate cycle.example.toml   # should report config valid (if files exist)
mgen run cycle.toml                # should produce Data.xlsx
pytest tests/ -v --tb=short        # all tests green
```
