"""Write assembled DataFrames to the Data.xlsx output.

This is infrastructure — it knows about Excel format details but not
about domain logic. It receives validated DataFrames and writes them.
"""

from __future__ import annotations

import logging
from pathlib import Path

import pandas as pd

from mgen.shared.schemas import (
    CLARITY_COLUMNS,
    MACRO1_COLUMNS,
    MACRO_COLUMNS,
    MACRO_SPECIES_COLUMNS,
    SEDIMENT_COLUMNS,
    SEDIMENT_SIZE_COLUMNS,
)

__all__ = ["SHEET_ORDER", "write_data_xlsx"]

logger = logging.getLogger(__name__)

SHEET_ORDER = ["Macro", "Macro1", "MacroSpecies", "Sediment", "SedimentSize", "Clarity"]

_SCHEMA_MAP: dict[str, list[str]] = {
    "Macro": MACRO_COLUMNS,
    "Macro1": MACRO1_COLUMNS,
    "MacroSpecies": MACRO_SPECIES_COLUMNS,
    "Sediment": SEDIMENT_COLUMNS,
    "SedimentSize": SEDIMENT_SIZE_COLUMNS,
    "Clarity": CLARITY_COLUMNS,
}


def write_data_xlsx(data: dict[str, pd.DataFrame], output_path: Path) -> None:
    """Write all domain outputs to a single Data.xlsx file.

    Args:
        data: Mapping of sheet_name → DataFrame. Must contain all sheets
            listed in SHEET_ORDER.
        output_path: Where to write the xlsx file.

    Raises:
        ValueError: If any required sheet is missing, any DataFrame is empty,
            or columns don't match the expected schema.
    """
    missing = set(SHEET_ORDER) - set(data.keys())
    if missing:
        msg = f"Missing required sheets: {sorted(missing)}"
        raise ValueError(msg)

    for sheet_name in SHEET_ORDER:
        df = data[sheet_name]
        if df.empty:
            msg = f"Sheet {sheet_name!r} is empty — refusing to write partial output"
            raise ValueError(msg)

        expected_cols = _SCHEMA_MAP[sheet_name]
        if list(df.columns) != expected_cols:
            msg = (
                f"Sheet {sheet_name!r} column mismatch: "
                f"expected {expected_cols}, got {list(df.columns)}"
            )
            raise ValueError(msg)

    output_path.parent.mkdir(parents=True, exist_ok=True)

    with pd.ExcelWriter(output_path, engine="openpyxl") as writer:
        for sheet_name in SHEET_ORDER:
            df = data[sheet_name]
            df.to_excel(writer, sheet_name=sheet_name, index=False)

    logger.info("Wrote Data.xlsx to %s (%d sheets)", output_path, len(SHEET_ORDER))
