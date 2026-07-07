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

# Fish: R-only sheet carrying the raw trapping rows the figure stage needs.
# No Python schemas.py counterpart (the Python pipeline reads fish live).
FISH_COLUMNS <- c(
  "Site", "Catchment", "Date", "Species category (for abundance)", "Number"
)

# MacroSummary: R-only per-site report table (Table 5.6). No Python counterpart.
# One row per Site x Date. Point estimates for single-sample (soft-bottom/D-net)
# sites; mean + 95% CI across replicates for multi-sample (hard-bottom/Surber)
# sites, so the "_CI" half-width columns are NA for single-sample sites.
# Catchment/Substrate/Method are joined from SITE_LEGEND; MCI/QMCI use the
# soft-bottom tolerance variant for soft-bottom sites (see SITES_WITHOUT_REPLICATES).
MACRO_SUMMARY_COLUMNS <- c(
  "Catchment", "Site", "Substrate", "Method", "Date", "Season",
  "NumIndividuals", "NumIndividuals_CI",
  "NumTaxa", "NumTaxa_CI",
  "MCI", "MCI_CI", "MCI_Class",
  "QMCI", "QMCI_CI", "QMCI_Class",
  "PctEPTRichness", "PctEPTRichness_CI",
  "PctEPTAbundance", "PctEPTAbundance_CI",
  "DominantTaxa"
)

# FishSummary: R-only per-site report table (Table 5.8). No Python counterpart.
# One row per Site x Season x Year. Species columns are catch counts (0 when
# absent); Shrimp is a qualitative abundance (Uncommon/Common/Abundant) since
# shrimp are not counted. TotalFish excludes koura and shrimp but includes
# unidentified fish/eels. TaxaRichness counts distinct identified taxa groups
# present (koura counts, shrimp excluded, unidentified not counted separately).
# CPUE is catch (excl. koura & shrimp) per net/trap, separately for mini-fyke
# nets (fykes) and Gee's minnow traps (GMTs). Catchment comes from the source.
FISH_SUMMARY_COLUMNS <- c(
  "Catchment", "Site", "Season", "Year",
  "LongfinEel", "ShortfinEel", "CommonBully", "RedfinBully",
  "BandedKokopu", "GiantKokopu", "Inanga",
  "UnidBully", "UnidKokopu", "UnidEel", "Koura",
  "Shrimp", "TotalFish", "TaxaRichness", "CPUE_fykes", "CPUE_GMTs"
)

SHEET_ORDER <- c(
  "Macro", "Macro1", "MacroSpecies", "Sediment",
  "SedimentSize", "Clarity", "RPD", "LDV", "Fish",
  "MacroSummary", "FishSummary"
)

SCHEMA_MAP <- list(
  Macro = MACRO_COLUMNS,
  Macro1 = MACRO1_COLUMNS,
  MacroSpecies = MACRO_SPECIES_COLUMNS,
  Sediment = SEDIMENT_COLUMNS,
  SedimentSize = SEDIMENT_SIZE_COLUMNS,
  Clarity = CLARITY_COLUMNS,
  RPD = RPD_COLUMNS,
  LDV = LDV_COLUMNS,
  Fish = FISH_COLUMNS,
  MacroSummary = MACRO_SUMMARY_COLUMNS,
  FishSummary = FISH_SUMMARY_COLUMNS
)
