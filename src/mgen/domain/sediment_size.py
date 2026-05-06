"""SedimentSize domain: grain-size distribution from the Aquatic Monitoring Database.

Reads the Sediment sheet and produces the SedimentSize output DataFrame with
columns: Site, Date, Period, Season + 10 Wentworth-scale grain-size bins.
"""

from __future__ import annotations

import logging
from pathlib import Path

import pandas as pd

from mgen.domain.sediment_ingest import (
    GRAIN_SIZE_SOURCE_COLUMNS,
    IngestError,
    make_error_result,
    read_sediment_sheet,
)
from mgen.shared.errors import DomainResult
from mgen.shared.schemas import SEDIMENT_SIZE_COLUMNS, SEDIMENT_SIZE_DTYPES

__all__ = ["process_sediment_size_domain"]

logger = logging.getLogger(__name__)


def process_sediment_size_domain(path: Path) -> DomainResult:
    """Process the Sediment sheet and return grain-size distribution data.

    Args:
        path: Path to the Aquatic Monitoring Database Excel file.

    Returns:
        DomainResult with data={"SedimentSize": DataFrame} on success,
        or errors on failure.
    """
    try:
        df = read_sediment_sheet(path)
    except IngestError as exc:
        logger.warning("SedimentSize ingest failed: %s", exc)
        return make_error_result("SedimentSize", path, str(exc))
    except Exception as exc:
        logger.exception("Unexpected error reading Sediment sheet")
        return make_error_result("SedimentSize", path, f"Unexpected error: {exc}")

    # Validate grain-size columns exist.
    missing_grain = [c for c in GRAIN_SIZE_SOURCE_COLUMNS if c not in df.columns]
    if missing_grain:
        return make_error_result(
            "SedimentSize",
            path,
            f"Missing grain-size columns: {missing_grain}",
        )

    # Build output DataFrame.
    output = pd.DataFrame({"Site": df["Site"], "Date": df["Date"]})
    output["Period"] = df["Period"]
    output["Season"] = df["Season"]

    for col in GRAIN_SIZE_SOURCE_COLUMNS:
        output[col] = pd.to_numeric(df[col], errors="coerce").astype("float64")

    # Enforce column order.
    output = output[SEDIMENT_SIZE_COLUMNS]

    # Enforce dtypes.
    for col, dtype in SEDIMENT_SIZE_DTYPES.items():
        if col != "Date":
            output[col] = output[col].astype(dtype)

    output = output.reset_index(drop=True)

    logger.info("SedimentSize domain: %d rows produced", len(output))
    return DomainResult(data={"SedimentSize": output})
