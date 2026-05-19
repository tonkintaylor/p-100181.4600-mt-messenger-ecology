"""LDV domain: low-flow depth variability from the Aquatic Monitoring Database.

Reads the "LDV Summary" sheet and produces the LDV output DataFrame with
columns: Site, Date, Season, CV_pct.
"""

from __future__ import annotations

import logging
from pathlib import Path

import pandas as pd

from mgen.shared.errors import DomainResult, ValidationError
from mgen.shared.schemas import LDV_COLUMNS

__all__ = ["process_ldv_domain"]

logger = logging.getLogger(__name__)

_SOURCE_SHEET = "LDV Summary"
_HEADER_ROWS = 13  # Rows 1-13 are notes/instructions/blank

_SOURCE_COLUMNS = {
    "Site": "Site",
    "Date": "Date",
    "Season": "Season",
    "CV (%)": "CV_pct",
}


def process_ldv_domain(path: Path) -> DomainResult:
    """Process the LDV Summary sheet and return depth variability data.

    Args:
        path: Path to the Aquatic Monitoring Database Excel file.

    Returns:
        DomainResult with data={"LDV": DataFrame} on success,
        or errors on failure.
    """
    try:
        df = pd.read_excel(path, sheet_name=_SOURCE_SHEET, skiprows=_HEADER_ROWS)
    except FileNotFoundError:
        return _make_error(path, f"File not found: {path}")
    except ValueError:
        return _make_error(path, f"Sheet {_SOURCE_SHEET!r} not found in {path}")
    except OSError as exc:
        return _make_error(path, f"Failed to read {path}: {exc}")

    # Strip whitespace from column names.
    df.columns = df.columns.str.strip()

    # Validate required source columns.
    missing = set(_SOURCE_COLUMNS.keys()) - set(df.columns)
    if missing:
        return _make_error(path, f"Missing required columns: {sorted(missing)}")

    # Select and rename to output schema.
    output = df[list(_SOURCE_COLUMNS.keys())].rename(columns=_SOURCE_COLUMNS)

    # Drop rows with no Site (trailing blank rows).
    output = output.dropna(subset=["Site"])

    # Coerce types.
    output["Date"] = pd.to_datetime(output["Date"], errors="coerce")
    output["CV_pct"] = pd.to_numeric(output["CV_pct"], errors="coerce")

    # Drop rows where Date could not be parsed.
    output = output.dropna(subset=["Date"])

    # Validate output has expected columns.
    output = output[LDV_COLUMNS]

    logger.info(
        "LDV: extracted %d rows from %d sites", len(output), output["Site"].nunique()
    )
    return DomainResult(data={"LDV": output})


def _make_error(path: Path, message: str) -> DomainResult:
    return DomainResult(
        errors=[
            ValidationError(
                domain="LDV",
                severity="error",
                file=str(path),
                sheet=_SOURCE_SHEET,
                location="sheet",
                message=message,
            )
        ]
    )
