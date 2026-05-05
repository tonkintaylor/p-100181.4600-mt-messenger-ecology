---
name: golden-file-testing
description: Patterns for comparing DataFrame outputs against expected "golden" fixture files (xlsx/csv) with float tolerance, per-sheet validation, and a controlled update workflow. Use when writing integration tests that verify pipeline output matches a known-good reference file.
module: make.python.test.golden
---

# Golden File Testing

Patterns for testing data pipeline outputs by comparing against known-good reference files ("golden files"). Designed for pandas DataFrames read from or written to Excel/CSV, with support for floating-point tolerance, per-sheet comparison, and a disciplined update workflow.

## When to Use

- Integration tests that verify pipeline output matches expected results
- Regression testing after refactors (output should not change)
- Verifying complex transformations where hand-written assertions would be brittle
- Any test where the "expected" output is an entire DataFrame or multi-sheet workbook

## When NOT to Use

- Unit tests for individual functions (use direct assertions instead)
- Tests where expected values can be expressed in 1-3 assertions
- Tests that need to verify behavior under error conditions (golden files only cover the happy path)

## Core Principles

1. **Golden files are committed to the repo** — they live in `tests/fixtures/` and are version-controlled. Changes to golden files are reviewed in PRs just like code changes.

2. **Never update golden files silently** — updates require an explicit flag (`--update-golden`) and should trigger a diff review before committing.

3. **Float tolerance is mandatory** — scientific data passes through multiple floating-point operations. Always compare with `rtol` and `atol`, never exact equality.

4. **Column order matters** — R scripts downstream depend on exact column order. Golden file comparisons must be order-sensitive.

5. **Report all differences, not just the first** — when a comparison fails, show which columns differ, how many rows are affected, and the magnitude of differences.

## File Organisation

```
tests/
  fixtures/
    expected_Data.xlsx          # Golden file: the full expected output
    cycle.toml                  # Test config pointing at fixture databases
    MTMA Macroinvertebrate Database example.xlsx
    MTMA Aquatic Monitoring Database example.xlsx
  conftest.py                   # Fixtures providing paths + comparison helpers
```

## Comparison Helper

Define a reusable comparison helper in `tests/conftest.py`:

```python
import pandas as pd
import pytest
from pathlib import Path


def assert_frame_equal_golden(
    actual: pd.DataFrame,
    expected: pd.DataFrame,
    *,
    sheet_name: str = "",
    rtol: float = 1e-5,
    atol: float = 1e-8,
    check_dtype: bool = True,
    check_column_order: bool = True,
) -> None:
    """Compare a DataFrame against a golden reference with clear error reporting.

    Parameters
    ----------
    actual : DataFrame produced by the code under test
    expected : DataFrame loaded from the golden file
    sheet_name : Name for error messages (e.g. "Macro1")
    rtol : Relative tolerance for float comparisons
    atol : Absolute tolerance for float comparisons
    check_dtype : Whether to verify dtypes match
    check_column_order : Whether column order must match exactly
    """
    prefix = f"[{sheet_name}] " if sheet_name else ""

    # Shape check
    assert actual.shape == expected.shape, (
        f"{prefix}Shape mismatch: got {actual.shape}, expected {expected.shape}"
    )

    # Column check
    if check_column_order:
        assert list(actual.columns) == list(expected.columns), (
            f"{prefix}Column mismatch:\n"
            f"  Got:      {list(actual.columns)}\n"
            f"  Expected: {list(expected.columns)}"
        )
    else:
        assert set(actual.columns) == set(expected.columns), (
            f"{prefix}Column set mismatch:\n"
            f"  Missing: {set(expected.columns) - set(actual.columns)}\n"
            f"  Extra:   {set(actual.columns) - set(expected.columns)}"
        )

    # Dtype check
    if check_dtype:
        for col in expected.columns:
            if actual[col].dtype != expected[col].dtype:
                pytest.fail(
                    f"{prefix}Column '{col}' dtype mismatch: "
                    f"got {actual[col].dtype}, expected {expected[col].dtype}"
                )

    # Value comparison column-by-column
    mismatches = []
    for col in expected.columns:
        if pd.api.types.is_numeric_dtype(expected[col]):
            close = pd.Series(
                [
                    _values_close(a, e, rtol=rtol, atol=atol)
                    for a, e in zip(actual[col], expected[col])
                ]
            )
            if not close.all():
                n_bad = (~close).sum()
                # Find worst difference
                diffs = (actual[col] - expected[col]).abs()
                worst_idx = diffs.idxmax()
                mismatches.append(
                    f"  {col}: {n_bad}/{len(close)} values differ "
                    f"(worst: row {worst_idx}, got {actual[col].iloc[worst_idx]}, "
                    f"expected {expected[col].iloc[worst_idx]})"
                )
        else:
            # Non-numeric: exact comparison (handles NaN == NaN)
            neq = actual[col].fillna("__NULL__") != expected[col].fillna("__NULL__")
            if neq.any():
                n_bad = neq.sum()
                first_idx = neq.idxmax()
                mismatches.append(
                    f"  {col}: {n_bad}/{len(neq)} values differ "
                    f"(first: row {first_idx}, got {actual[col].iloc[first_idx]!r}, "
                    f"expected {expected[col].iloc[first_idx]!r})"
                )

    if mismatches:
        pytest.fail(
            f"{prefix}Value mismatches in {len(mismatches)} column(s):\n"
            + "\n".join(mismatches)
        )


def _values_close(a, b, *, rtol: float, atol: float) -> bool:
    """Compare two values with tolerance, handling NaN."""
    if pd.isna(a) and pd.isna(b):
        return True
    if pd.isna(a) or pd.isna(b):
        return False
    return abs(a - b) <= atol + rtol * abs(b)
```

## Test Patterns

### Single-sheet comparison

```python
class TestMacro1Output:
    def test_matches_golden_file(
        self, example_macro_db: Path, golden_data_xlsx: Path
    ) -> None:
        from mgen.domains.macro import process_macro_domain

        result = process_macro_domain(example_macro_db)
        assert result.ok

        expected = pd.read_excel(golden_data_xlsx, sheet_name="Macro1")
        assert_frame_equal_golden(
            result.data["Macro1"], expected, sheet_name="Macro1"
        )
```

### Multi-sheet comparison (full pipeline)

```python
class TestPipelineGoldenFile:
    """End-to-end golden file comparison."""

    SHEETS = ["Macro", "Macro1", "MacroSpecies", "Sediment", "SedimentSize"]

    def test_all_sheets_match_golden(
        self, test_config: PipelineConfig, golden_data_xlsx: Path
    ) -> None:
        from mgen.pipeline import run_pipeline

        result = run_pipeline(test_config)
        assert result.ok, f"Pipeline failed: {result.errors}"

        actual_sheets = pd.read_excel(
            test_config.data_xlsx, sheet_name=None
        )

        for sheet in self.SHEETS:
            expected = pd.read_excel(golden_data_xlsx, sheet_name=sheet)
            assert_frame_equal_golden(
                actual_sheets[sheet], expected, sheet_name=sheet
            )
```

### Parametrised per-sheet comparison

```python
@pytest.mark.parametrize("sheet_name", [
    "Macro", "Macro1", "MacroSpecies", "Sediment", "SedimentSize",
])
def test_sheet_matches_golden(
    self, sheet_name: str, output_xlsx: Path, golden_data_xlsx: Path
) -> None:
    actual = pd.read_excel(output_xlsx, sheet_name=sheet_name)
    expected = pd.read_excel(golden_data_xlsx, sheet_name=sheet_name)
    assert_frame_equal_golden(actual, expected, sheet_name=sheet_name)
```

## Golden File Update Workflow

### conftest.py fixture for update mode

```python
def pytest_addoption(parser):
    parser.addoption(
        "--update-golden",
        action="store_true",
        default=False,
        help="Update golden files instead of comparing against them",
    )


@pytest.fixture()
def update_golden(request) -> bool:
    return request.config.getoption("--update-golden")
```

### Test that supports update mode

```python
def test_matches_golden_or_update(
    self,
    output_xlsx: Path,
    golden_data_xlsx: Path,
    update_golden: bool,
) -> None:
    if update_golden:
        import shutil
        shutil.copy2(output_xlsx, golden_data_xlsx)
        pytest.skip("Golden file updated — review diff before committing")

    actual = pd.read_excel(output_xlsx, sheet_name="Macro1")
    expected = pd.read_excel(golden_data_xlsx, sheet_name="Macro1")
    assert_frame_equal_golden(actual, expected, sheet_name="Macro1")
```

### Update commands

```bash
# Update golden files (creates new expected output)
pytest tests/test_pipeline_integration.py --update-golden

# Review what changed
git diff tests/fixtures/expected_Data.xlsx

# If changes are intentional, commit
git add tests/fixtures/expected_Data.xlsx
git commit -m "test: update golden file after [reason]"
```

## Fixture Setup

### conftest.py fixtures for golden file paths

```python
@pytest.fixture()
def golden_data_xlsx() -> Path:
    """Path to the golden Data.xlsx reference file."""
    path = Path(__file__).parent / "fixtures" / "expected_Data.xlsx"
    assert path.exists(), f"Golden file not found: {path}"
    return path


@pytest.fixture()
def example_macro_db() -> Path:
    """Path to trimmed example Macroinvertebrate Database."""
    path = Path(__file__).parent / "fixtures" / "MTMA Macroinvertebrate Database example.xlsx"
    assert path.exists(), f"Fixture not found: {path}"
    return path


@pytest.fixture()
def example_aquatic_db() -> Path:
    """Path to trimmed example Aquatic Monitoring Database."""
    path = Path(__file__).parent / "fixtures" / "MTMA Aquatic Monitoring Database example.xlsx"
    assert path.exists(), f"Fixture not found: {path}"
    return path
```

## Tolerance Guidelines

| Data type | Recommended `rtol` | Recommended `atol` | Rationale |
|-----------|--------------------|--------------------|-----------|
| MCI/QMCI scores | 1e-5 | 1e-8 | Computed from integer counts; low numerical error |
| Percentages (%EPT) | 1e-5 | 1e-8 | Ratio of integers |
| Sediment measures | 1e-4 | 1e-6 | Field measurements with inherent imprecision |
| Dates (as float) | 0 | 0.5 | Excel serial dates should be exact or within 1 day |

## Anti-Patterns

### Don't use `pd.testing.assert_frame_equal` directly

It provides poor diagnostics on failure (cryptic diff output) and doesn't support per-column tolerance. Use the `assert_frame_equal_golden` helper instead.

### Don't compare entire workbooks as binary blobs

Excel files contain metadata (timestamps, creator info) that changes between writes. Always compare at the DataFrame level after reading.

### Don't suppress dtype mismatches

If a column is `float64` in the golden file but `object` in actual output, that's a real bug (usually means NaN handling went wrong). Always check dtypes.

### Don't update golden files without review

The `--update-golden` flag is a power tool. After running it:
1. Run `git diff` on the fixture file
2. Verify the changes are intentional
3. Explain *why* output changed in the commit message

### Don't test against golden files in unit tests

Golden files are for integration tests only. Unit tests should use hand-crafted small DataFrames with explicit assertions. Golden files test "the whole pipeline produces correct output"; unit tests test "this function handles edge cases".
