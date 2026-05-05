"""Output DataFrame schemas for Data.xlsx sheets.

These define the exact column names and dtypes that the downstream R scripts
expect. Any change here is a breaking change for Phase 2.
"""

from __future__ import annotations

# Macro1 sheet: full-precision metrics, one row per site x date
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
    **dict.fromkeys(SEDIMENT_SIZE_COLUMNS[4:], "float64"),
}
