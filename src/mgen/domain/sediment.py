"""Sediment domain: SAM score extraction from the Aquatic Monitoring Database.

Reads the Sediment sheet and produces the Sediment output DataFrame with
columns: Site, Date, Period, SAM1, SAM3, Season.
"""

from __future__ import annotations

import logging
from pathlib import Path

import pandas as pd

from mgen.domain.sediment_ingest import (
    SOURCE_SAM1_COL,
    SOURCE_SAM3_COL,
    IngestError,
    make_error_result,
    read_sediment_sheet,
)
from mgen.shared.errors import DomainResult
from mgen.shared.schemas import SEDIMENT_COLUMNS, SEDIMENT_DTYPES

__all__ = ["process_sediment_domain"]

logger = logging.getLogger(__name__)


def process_sediment_domain(path: Path) -> DomainResult:
    """Process the Sediment sheet and return SAM score data.

    Args:
        path: Path to the Aquatic Monitoring Database Excel file.

    Returns:
        DomainResult with data={"Sediment": DataFrame} on success,
        or errors on failure.
    """
    try:
        df = read_sediment_sheet(path)
    except IngestError as exc:
        logger.warning("Sediment ingest failed: %s", exc)
        return make_error_result("Sediment", path, str(exc))
    except Exception as exc:
        logger.exception("Unexpected error reading Sediment sheet")
        return make_error_result("Sediment", path, f"Unexpected error: {exc}")

    # Validate SAM columns exist.
    for col in (SOURCE_SAM1_COL, SOURCE_SAM3_COL):
        if col not in df.columns:
            return make_error_result(
                "Sediment", path, f"Missing required column: {col!r}"
            )

    # Select and rename to output schema.
    output = pd.DataFrame(
        {
            "Site": df["Site"],
            "Date": df["Date"],
            "Period": df["Period"],
            "SAM1": pd.to_numeric(df[SOURCE_SAM1_COL], errors="coerce").astype(
                "float64"
            ),
            "SAM3": pd.to_numeric(df[SOURCE_SAM3_COL], errors="coerce").astype(
                "float64"
            ),
            "Season": df["Season"],
        }
    )

    # Enforce column order and dtypes.
    output = output[SEDIMENT_COLUMNS]
    for col, dtype in SEDIMENT_DTYPES.items():
        if col != "Date":
            output[col] = output[col].astype(dtype)

    output = output.reset_index(drop=True)

    logger.info("Sediment domain: %d rows produced", len(output))
    return DomainResult(data={"Sediment": output})
