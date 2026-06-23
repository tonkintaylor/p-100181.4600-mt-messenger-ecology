# sediment_ingest.R — ACL for the Aquatic Monitoring Database "Sediment" sheet.

SOURCE_SAM1_COL <- "SAM1 %fine cover"
SOURCE_SAM3_COL <- "SAM3 (%Fine Cover)"
GRAIN_SIZE_SOURCE_COLUMNS <- c(
  "Clay/silt (<0.06 mm)", "Sand (>0.06-2 mm)", "Small gravel (>2-8 mm)",
  "Small-med gravel (>8-16 mm)", "Med-large gravel (>16-32 mm)",
  "Large gravel (>32-64 mm)", "Small cobble (>64-128 mm)",
  "Large cobble (>128-256 mm)", "Boulders (>256 mm)", "Bedrock"
)

# Column identifiers as returned by readxl::read_excel(..., .name_repair="minimal").
# The source workbook's period header is a single space; readxl strips it to "".
# The source workbook's site header is "Site " (trailing space); readxl strips to "Site".
# The "" column cannot be accessed via df[[""]] (R returns NULL); use .sed_get_period().
.sed_period_col <- ""
.sed_site_col <- "Site"
.sed_season_col <- "Season"
.sed_date_col <- "Date"
# Required cols for validation — "" is checked via %in% names(df).
.sed_required <- c(.sed_period_col, .sed_site_col, .sed_season_col, .sed_date_col)

# Access the empty-named period column by position (df[[""]] returns NULL in R).
.sed_get_period <- function(df) df[[match("", names(df))]]

sediment_make_error <- function(domain, path, message) {
  DomainResult$new(data = NULL, errors = list(ValidationError(
    domain = domain, severity = "error", file = as.character(path),
    sheet = "Sediment", location = "sheet", message = message)))
}

read_sediment_sheet <- function(path) {
  df <- tryCatch(readxl::read_excel(path, sheet = "Sediment", .name_repair = "minimal"),
                 error = function(e) stop(sprintf(
                   "Sheet 'Sediment' not found or unreadable in %s", path)))
  missing <- setdiff(.sed_required, names(df))
  if (length(missing) > 0) {
    stop(sprintf("Missing required columns: %s",
      paste0("[", paste(sprintf("'%s'", sort(missing)), collapse = ", "), "]")))
  }
  period_raw <- trimws(as.character(.sed_get_period(df)))
  season_raw <- trimws(as.character(df[[.sed_season_col]]))

  Period <- rep("Routine Construction", nrow(df))
  Period[period_raw == "Baseline"] <- "Baseline"
  Period[startsWith(season_raw, "Additional")] <- "Incident"

  Season <- rep("Spring", nrow(df))
  Season[grepl("Summer", season_raw, fixed = TRUE)] <- "Summer"

  # Match pandas df[col].astype(str).str.strip(): a missing Site cell becomes
  # the literal string "nan" (these rows are not dropped downstream), so map
  # NA -> "nan" before trimming rather than leaving an R NA.
  site_chr <- as.character(df[[.sed_site_col]])
  site_chr[is.na(site_chr)] <- "nan"
  df$Site <- trimws(site_chr)
  df$Date <- as.Date(df[[.sed_date_col]])
  Period[!is.na(df$Date) & df$Date <= BASELINE_END] <- "Baseline"
  df$Period <- Period
  df$Season <- Season
  df
}
