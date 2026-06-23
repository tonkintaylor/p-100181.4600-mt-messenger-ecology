# schemas.R — output column contracts for Data.xlsx sheets.
# Verbatim from src/mgen/shared/schemas.py. Any change here is a breaking
# change for the R figure pipeline.

MACRO1_COLUMNS <- c("Site", "Date", "Period", "EPTrich", "EPTabun", "QMCI", "Season")
MACRO_COLUMNS <- MACRO1_COLUMNS

MACRO_SPECIES_COLUMNS <- c(
  "Phase", "Date", "Site", "Taxa", "Species", "Tally", "is_additional"
)

SEDIMENT_COLUMNS <- c("Site", "Date", "Period", "SAM1", "SAM3", "Season")

CLARITY_COLUMNS <- c(
  "Site", "Date", "NTU-Fieldmeter", "NTU-Continuous Sensor", "NTU-Lab",
  "pH-Fieldmeter", "pH-Lab", "TSS-Lab", "Clarity (mm)", "Comments"
)

SEDIMENT_SIZE_COLUMNS <- c(
  "Site", "Date", "Period", "Season",
  "Clay/silt (<0.06 mm)", "Sand (>0.06-2 mm)", "Small gravel (>2-8 mm)",
  "Small-med gravel (>8-16 mm)", "Med-large gravel (>16-32 mm)",
  "Large gravel (>32-64 mm)", "Small cobble (>64-128 mm)",
  "Large cobble (>128-256 mm)", "Boulders (>256 mm)", "Bedrock"
)

RPD_COLUMNS <- c("Site", "Date", "Count", "Mean", "StdDev", "CI_Lower", "CI_Upper")

LDV_COLUMNS <- c("Site", "Date", "Season", "CV_pct")

SHEET_ORDER <- c(
  "Macro", "Macro1", "MacroSpecies", "Sediment",
  "SedimentSize", "Clarity", "RPD", "LDV"
)

SCHEMA_MAP <- list(
  Macro = MACRO_COLUMNS,
  Macro1 = MACRO1_COLUMNS,
  MacroSpecies = MACRO_SPECIES_COLUMNS,
  Sediment = SEDIMENT_COLUMNS,
  SedimentSize = SEDIMENT_SIZE_COLUMNS,
  Clarity = CLARITY_COLUMNS,
  RPD = RPD_COLUMNS,
  LDV = LDV_COLUMNS
)
