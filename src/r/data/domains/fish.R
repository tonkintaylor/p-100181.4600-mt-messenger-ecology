# fish.R — fish trapping from the Aquatic Monitoring Database "Fish Trapping".
# Writes the raw rows the figure stage aggregates; the source "Date retrieved"
# column is mapped to a generic "Date" for consistency with the other sheets.

.fish_source_sheet <- "Fish Trapping"
.fish_required <- c("Site", "Catchment", "Date retrieved",
                    "Species category (for abundance)", "Number")

.fish_error <- function(path, message) {
  DomainResult$new(data = NULL, errors = list(ValidationError(
    domain = "Fish", severity = "error", file = as.character(path),
    sheet = .fish_source_sheet, location = "sheet", message = message)))
}

process_fish_domain <- function(path) {
  df <- suppressWarnings(suppressMessages(tryCatch(
    readxl::read_excel(path, sheet = .fish_source_sheet),
    error = function(e) e)))
  if (inherits(df, "error")) {
    return(.fish_error(path, sprintf("Sheet '%s' not found or unreadable in %s",
                                     .fish_source_sheet, path)))
  }
  names(df) <- trimws(names(df))
  missing <- setdiff(.fish_required, names(df))
  if (length(missing) > 0) {
    return(.fish_error(path, sprintf("Missing required columns: %s",
      paste0("[", paste(sprintf("'%s'", sort(missing)), collapse = ", "), "]"))))
  }

  out <- data.frame(
    Site      = as.character(df[["Site"]]),
    Catchment = as.character(df[["Catchment"]]),
    Date      = as.Date(df[["Date retrieved"]]),
    `Species category (for abundance)` =
      as.character(df[["Species category (for abundance)"]]),
    Number    = suppressWarnings(as.numeric(df[["Number"]])),
    check.names = FALSE, stringsAsFactors = FALSE
  )
  out <- out[, FISH_COLUMNS, drop = FALSE]
  DomainResult$new(data = list(Fish = out))
}
