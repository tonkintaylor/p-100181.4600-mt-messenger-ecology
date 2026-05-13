"""RPD domain: residual pool depth from the Aquatic Monitoring Database.

Reads the "RPD Summary" sheet and produces the RPD output DataFrame with
columns: Site, Date, Count, Mean, StdDev, CI_Lower, CI_Upper.
"""

from __future__ import annotations

import logging
from pathlib import Path

import pandas as pd

from mgen.shared.errors import DomainResult, ValidationError
from mgen.shared.schemas import RPD_COLUMNS

__all__ = ["process_rpd_domain"]

logger = logging.getLogger(__name__)

_SOURCE_SHEET = "RPD Summary"
_HEADER_ROWS = 3  # Rows 1-3 are title/description/catchment header

_SOURCE_COLUMNS = {
    "Site": "Site",
    "Date": "Date",
    "Count": "Count",
    "Mean (cm)": "Mean",
    "Std Dev": "StdDev",
    "CI Lower": "CI_Lower",
    "CI Upper": "CI_Upper",
}


def process_rpd_domain(path: Path) -> DomainResult:
    """Process the RPD Summary sheet and return residual pool depth data.

    Args:
        path: Path to the Aquatic Monitoring Database Excel file.

    Returns:
        DomainResult with data={"RPD": DataFrame} on success,
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
    output["Count"] = pd.to_numeric(output["Count"], errors="coerce").astype("Int64")
    for col in ("Mean", "StdDev", "CI_Lower", "CI_Upper"):
        output[col] = pd.to_numeric(output[col], errors="coerce")

    # Drop rows where Date could not be parsed.
    output = output.dropna(subset=["Date"])

    # Validate output has expected columns.
    output = output[RPD_COLUMNS]

    logger.info(
        "RPD: extracted %d rows from %d sites", len(output), output["Site"].nunique()
    )
    return DomainResult(data={"RPD": output})


def _make_error(path: Path, message: str) -> DomainResult:
    return DomainResult(
        errors=[
            ValidationError(
                domain="RPD",
                severity="error",
                file=str(path),
                sheet=_SOURCE_SHEET,
                location="sheet",
                message=message,
            )
        ]
    )
