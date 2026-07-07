# field_wq.R — spot water-quality readings from the Aquatic Monitoring Database
# "FieldWQ" sheet, for report Appendix B3 Tables 1 & 2. R-only sheet (no Python
# counterpart). One row per Site x Date; values are emitted faithfully (no
# cleaning of source data-quality issues).

.field_wq_sheet <- "FieldWQ"
.field_wq_required <- c("Season", "Site", "Date", "Time taken",
                        "Water temperature", "pH", "Specific conductivity",
                        "Dissolved oxygen (mg/L)", "Dissolved oxygen (%)")

.field_wq_error <- function(path, message) {
  DomainResult$new(data = NULL, errors = list(ValidationError(
    domain = "FieldWQ", severity = "error", file = as.character(path),
    sheet = .field_wq_sheet, location = "sheet", message = message)))
}

# Mangapepeke is the upper catchment (EM1-EM3); all other sites are Mimi.
.field_wq_catchment <- function(site) {
  ifelse(site %in% c("EM1", "EM2", "EM3"), "Mangapepeke", "Mimi")
}

process_field_wq_domain <- function(path) {
  df <- suppressWarnings(suppressMessages(tryCatch(
    readxl::read_excel(path, sheet = .field_wq_sheet, .name_repair = "minimal"),
    error = function(e) e)))
  if (inherits(df, "error")) {
    return(.field_wq_error(path, sprintf(
      "Sheet '%s' not found or unreadable in %s", .field_wq_sheet, path)))
  }
  names(df) <- trimws(names(df))
  missing <- setdiff(.field_wq_required, names(df))
  if (length(missing) > 0) {
    return(.field_wq_error(path, sprintf("Missing required columns: %s",
      paste0("[", paste(sprintf("'%s'", sort(missing)), collapse = ", "), "]"))))
  }

  site <- trimws(as.character(df[["Site"]]))
  date <- as.Date(df[["Date"]])
  # "Time taken" is an Excel time (a 1899-12-31 datetime); keep HH:MM, NA if blank.
  time_taken <- format(as.POSIXct(df[["Time taken"]]), "%H:%M")

  out <- data.frame(
    Catchment = .field_wq_catchment(site),
    Site = site,
    Season = trimws(as.character(df[["Season"]])),
    Year = as.integer(format(date, "%Y")),
    Date = date,
    TimeTaken = time_taken,
    WaterTempC = suppressWarnings(as.numeric(df[["Water temperature"]])),
    pH = suppressWarnings(as.numeric(df[["pH"]])),
    SpecCond = suppressWarnings(as.numeric(df[["Specific conductivity"]])),
    DO_mgL = suppressWarnings(as.numeric(df[["Dissolved oxygen (mg/L)"]])),
    DO_pctSat = suppressWarnings(as.numeric(df[["Dissolved oxygen (%)"]])),
    stringsAsFactors = FALSE, check.names = FALSE)

  # Drop rows with no site or unparseable date (structural, not data-quality).
  out <- out[!is.na(out$Site) & nzchar(out$Site) & !is.na(out$Date), ,
             drop = FALSE]
  out <- out[order(out$Date, out$Site), FIELDWQ_COLUMNS, drop = FALSE]
  rownames(out) <- NULL
  DomainResult$new(data = list(FieldWQ = out))
}
