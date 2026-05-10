"""Clarity domain: water clarity data from the Aquatic Monitoring Database.

Reads the "Clarity Data" sheet and produces the Clarity output DataFrame
for the R plotting pipeline to consume.
"""

from __future__ import annotations

import logging
from pathlib import Path

import pandas as pd

from mgen.shared.errors import DomainResult, ValidationError
from mgen.shared.schemas import CLARITY_COLUMNS, CLARITY_DTYPES

__all__ = ["process_clarity_domain"]

logger = logging.getLogger(__name__)

_SOURCE_SHEET = "Clarity Data"

_REQUIRED_COLUMNS = frozenset({"Site", "Date", "Clarity (mm)"})

# Source → output column name mapping (handles typo in older databases).
_COLUMN_RENAMES = {
    "NTU-Continous Sensor": "NTU-Continuous Sensor",
}


def process_clarity_domain(path: Path) -> DomainResult:
    """Process the Clarity Data sheet and return water clarity data.

    Args:
        path: Path to the Aquatic Monitoring Database Excel file.

    Returns:
        DomainResult with data={"Clarity": DataFrame} on success,
        or errors on failure.
    """
    try:
        df = pd.read_excel(path, sheet_name=_SOURCE_SHEET)
    except FileNotFoundError:
        return _make_error(path, f"File not found: {path}")
    except ValueError:
        return _make_error(path, f"Sheet {_SOURCE_SHEET!r} not found in {path}")
    except OSError as exc:
        return _make_error(path, f"Failed to read {path}: {exc}")

    # Strip whitespace from column names.
    df.columns = df.columns.str.strip()

    # Fix known typos in column names.
    df = df.rename(columns=_COLUMN_RENAMES)

    # Validate required columns.
    missing = _REQUIRED_COLUMNS - set(df.columns)
    if missing:
        return _make_error(path, f"Missing required columns: {sorted(missing)}")

    # Build output DataFrame with expected schema.
    output = pd.DataFrame()
    for col in CLARITY_COLUMNS:
        output[col] = _coerce_column(df, col)

    output = output.reset_index(drop=True)

    logger.info("Clarity domain: %d rows produced", len(output))
    return DomainResult(data={"Clarity": output})


def _coerce_column(df: pd.DataFrame, col: str) -> pd.Series:
    """Coerce a single column to its expected dtype, or fill with NA."""
    dtype = CLARITY_DTYPES[col]

    if col == "Date":
        return pd.to_datetime(df[col]).astype("datetime64[ns]")

    if col in df.columns:
        if dtype == "float64":
            return pd.to_numeric(df[col], errors="coerce").astype("float64")
        return df[col].astype(dtype)

    # Optional column not present — fill with appropriate NA.
    if dtype == "float64":
        return pd.Series([float("nan")] * len(df), dtype="float64")
    return pd.Series([None] * len(df), dtype="object")


def _make_error(path: Path, message: str) -> DomainResult:
    """Create a failed DomainResult with a single validation error."""
    return DomainResult(
        data=None,
        errors=[
            ValidationError(
                domain="Clarity",
                severity="error",
                file=str(path),
                sheet=_SOURCE_SHEET,
                location="sheet",
                message=message,
            )
        ],
    )
