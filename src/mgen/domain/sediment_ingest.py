"""Anti-corruption layer for the Aquatic Monitoring Database Sediment sheet.

Reads the "Sediment" sheet and normalises quirky header names, derives
the output Period and Season columns from source values, and strips
whitespace from site codes. Shared by both sediment and sediment_size
domain modules.

Source layout quirks:
  - First column header is a literal space character (' ')
  - Site column has a trailing space ('Site ')
  - Season values include "Additional - *" prefixes for incident monitoring
"""

from __future__ import annotations

import logging
from pathlib import Path

import pandas as pd

from mgen.shared.errors import DomainResult, ValidationError

__all__ = [
    "GRAIN_SIZE_SOURCE_COLUMNS",
    "SOURCE_SAM1_COL",
    "SOURCE_SAM3_COL",
    "IngestError",
    "make_error_result",
    "read_sediment_sheet",
]

logger = logging.getLogger(__name__)

# Source column names (exact strings from the workbook).
_SOURCE_PERIOD_COL = " "
_SOURCE_SITE_COL = "Site "
_SOURCE_SEASON_COL = "Season"
_SOURCE_DATE_COL = "Date"
SOURCE_SAM1_COL = "SAM1 %fine cover"
SOURCE_SAM3_COL = "SAM3 (%Fine Cover)"

# Grain-size source columns in output order.
GRAIN_SIZE_SOURCE_COLUMNS = [
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

# Minimum required source columns for reading the sheet at all.
_REQUIRED_COLUMNS = frozenset(
    {_SOURCE_PERIOD_COL, _SOURCE_SITE_COL, _SOURCE_SEASON_COL, _SOURCE_DATE_COL}
)


class IngestError(Exception):
    """Raised when the Sediment sheet cannot be parsed."""


def read_sediment_sheet(path: Path) -> pd.DataFrame:
    """Read and normalise the Sediment sheet from the Aquatic Monitoring Database.

    Returns a DataFrame with normalised columns:
      Site, Date, Period, Season + SAM columns + grain-size columns.

    Raises:
        IngestError: If the file or sheet cannot be read or is missing
            required columns.
    """
    try:
        df = pd.read_excel(path, sheet_name="Sediment")
    except FileNotFoundError as exc:
        msg = f"File not found: {path}"
        raise IngestError(msg) from exc
    except ValueError as exc:
        msg = f"Sheet 'Sediment' not found in {path}"
        raise IngestError(msg) from exc
    except Exception as exc:
        msg = f"Failed to read {path}: {exc}"
        raise IngestError(msg) from exc

    # Validate required columns exist.
    missing = _REQUIRED_COLUMNS - set(df.columns)
    if missing:
        msg = f"Missing required columns: {sorted(missing)}"
        raise IngestError(msg)

    # Derive output Period and Season (vectorized).
    period_raw = df[_SOURCE_PERIOD_COL].astype(str).str.strip()
    season_raw = df[_SOURCE_SEASON_COL].astype(str).str.strip()

    df["Period"] = "Routine Construction"
    df.loc[period_raw == "Baseline", "Period"] = "Baseline"
    df.loc[season_raw.str.startswith("Additional"), "Period"] = "Incident"

    df["Season"] = "Spring"
    df.loc[season_raw.str.contains("Summer", na=False), "Season"] = "Summer"

    # Normalise Site (strip trailing whitespace).
    df["Site"] = df[_SOURCE_SITE_COL].astype(str).str.strip()

    # Ensure Date is datetime64[ns].
    df["Date"] = pd.to_datetime(df[_SOURCE_DATE_COL]).astype("datetime64[ns]")

    return df


def make_error_result(domain: str, path: Path, message: str) -> DomainResult:
    """Create a failed DomainResult with a single validation error."""
    return DomainResult(
        data=None,
        errors=[
            ValidationError(
                domain=domain,
                severity="error",
                file=str(path),
                sheet="Sediment",
                location="sheet",
                message=message,
            )
        ],
    )
