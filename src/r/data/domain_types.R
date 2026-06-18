# domain_types.R — shared monitoring constants.

# Samples on or before this date are Baseline regardless of source label.
BASELINE_END <- as.Date("2022-03-31")

# "MMA 6"/"MMA 6b" contain a space — matches source database values.
VALID_SITES <- c("EM1", "EM2", "EM3", "EM4", "EM5", "EM7", "EM8", "MMA 6", "MMA 6b")

# Sites lacking replicates — use QMCI-sb and are excluded from aggregated Macro.
SITES_WITHOUT_REPLICATES <- c("EM1", "EM2", "EM4", "EM8")

VALID_PERIODS <- c("Baseline", "Construction")
VALID_SEASONS <- c("Baseline", "Construction", "Routine", "Additional")
