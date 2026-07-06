# domain_types.R — shared monitoring constants.

# Samples on or before this date are Baseline regardless of source label.
BASELINE_END <- as.Date("2022-03-31")

# "MMA 6"/"MMA 6b" contain a space — matches source database values.
VALID_SITES <- c("EM1", "EM2", "EM3", "EM4", "EM5", "EM7", "EM8", "MMA 6", "MMA 6b")

# Sites lacking replicates — use QMCI-sb and are excluded from aggregated Macro.
SITES_WITHOUT_REPLICATES <- c("EM1", "EM2", "EM4", "EM8")

# Static per-site attributes from the project site legend. These are fixed
# properties of each monitoring site, not per-sample values.
#   Substrate == "Soft bottom"  -> D-net sampling, MCI-sb/QMCI-sb metrics
#   Substrate == "Hard bottom"  -> Surber sampling (5 replicates averaged), MCI/QMCI
# The soft-bottom set is identical to SITES_WITHOUT_REPLICATES (see test).
# MMA 6 / MMA 6b are omitted: they are not part of the EM site legend.
SITE_LEGEND <- data.frame(
  Site      = c("EM1", "EM2", "EM3", "EM4", "EM5", "EM7", "EM8"),
  Catchment = c("Mangapepeke", "Mangapepeke", "Mangapepeke",
                "Mimi", "Mimi", "Mimi", "Mimi"),
  Substrate = c("Soft bottom", "Soft bottom", "Hard bottom",
                "Soft bottom", "Hard bottom", "Hard bottom", "Soft bottom"),
  Method    = c("D-net", "D-net", "Surber",
                "D-net", "Surber", "Surber", "D-net"),
  IsControl = c(TRUE, FALSE, FALSE, TRUE, FALSE, FALSE, FALSE),
  stringsAsFactors = FALSE
)

VALID_PERIODS <- c("Baseline", "Construction")
VALID_SEASONS <- c("Baseline", "Construction", "Routine", "Additional")
