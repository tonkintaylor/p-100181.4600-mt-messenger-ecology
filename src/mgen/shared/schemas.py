"""Output DataFrame schemas for Data.xlsx sheets.

These define the exact column names and dtypes that the downstream R scripts
expect. Any change here is a breaking change for Phase 2.
"""

from __future__ import annotations

_DATETIME = "datetime64[ns]"

# Macro1 sheet: full-precision metrics, one row per site x date
MACRO1_COLUMNS = ["Site", "Date", "Period", "EPTrich", "EPTabun", "QMCI", "Season"]
MACRO1_DTYPES = {
    "Site": "object",
    "Date": _DATETIME,
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
MACRO_SPECIES_COLUMNS = [
    "Phase",
    "Date",
    "Site",
    "Taxa",
    "Species",
    "Tally",
    "is_additional",
]
MACRO_SPECIES_DTYPES = {
    "Phase": "object",
    "Date": _DATETIME,
    "Site": "object",
    "Taxa": "object",
    "Species": "object",
    "Tally": "int64",
    "is_additional": "bool",
}

# Sediment sheet: SAM scores
SEDIMENT_COLUMNS = ["Site", "Date", "Period", "SAM1", "SAM3", "Season"]
SEDIMENT_DTYPES = {
    "Site": "object",
    "Date": _DATETIME,
    "Period": "object",
    "SAM1": "float64",
    "SAM3": "float64",
    "Season": "object",
}

# Clarity sheet: water clarity monitoring data.
CLARITY_COLUMNS = [
    "Site",
    "Date",
    "NTU-Fieldmeter",
    "NTU-Continuous Sensor",
    "NTU-Lab",
    "pH-Fieldmeter",
    "pH-Lab",
    "TSS-Lab",
    "Clarity (mm)",
    "Comments",
]
CLARITY_DTYPES = {
    "Site": "object",
    "Date": _DATETIME,
    "NTU-Fieldmeter": "float64",
    "NTU-Continuous Sensor": "float64",
    "NTU-Lab": "float64",
    "pH-Fieldmeter": "float64",
    "pH-Lab": "float64",
    "TSS-Lab": "float64",
    "Clarity (mm)": "float64",
    "Comments": "object",
}

# SedimentSize sheet: grain-size distribution (Wentworth scale).
# The 10 size-class columns pass through with their original source names.
# A future phase may aggregate bins (e.g. split Clay/silt, sum Fines);
# that will require ecologist sign-off and a schema migration.
SEDIMENT_SIZE_COLUMNS = [
    "Site",
    "Date",
    "Period",
    "Season",
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
SEDIMENT_SIZE_DTYPES = {
    "Site": "object",
    "Date": _DATETIME,
    "Period": "object",
    "Season": "object",
    **dict.fromkeys(SEDIMENT_SIZE_COLUMNS[4:], "float64"),
}

# RPD sheet: residual pool depth summary per site/date
RPD_COLUMNS = ["Site", "Date", "Count", "Mean", "StdDev", "CI_Lower", "CI_Upper"]
RPD_DTYPES = {
    "Site": "object",
    "Date": _DATETIME,
    "Count": "int64",
    "Mean": "float64",
    "StdDev": "float64",
    "CI_Lower": "float64",
    "CI_Upper": "float64",
}

# LDV sheet: low-flow depth variability (CV%) per site/date
LDV_COLUMNS = ["Site", "Date", "Season", "CV_pct"]
LDV_DTYPES = {
    "Site": "object",
    "Date": _DATETIME,
    "Season": "object",
    "CV_pct": "float64",
}
