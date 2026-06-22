# ldv.R — low-flow depth variability from "LDV Summary" (skip 13 header rows).

.ldv_sheet <- "LDV Summary"
.ldv_skip <- 13
.ldv_map <- c("Site" = "Site", "Date" = "Date", "Season" = "Season",
              "CV (%)" = "CV_pct")

.ldv_error <- function(path, message) {
  DomainResult$new(data = NULL, errors = list(ValidationError(
    domain = "LDV", severity = "error", file = as.character(path),
    sheet = .ldv_sheet, location = "sheet", message = message)))
}

process_ldv_domain <- function(path) {
  df <- suppressMessages(tryCatch(
    suppressWarnings(readxl::read_excel(path, sheet = .ldv_sheet, skip = .ldv_skip)),
    error = function(e) e))
  if (inherits(df, "error")) {
    return(.ldv_error(path, sprintf("Sheet '%s' not found or unreadable in %s",
                                    .ldv_sheet, path)))
  }
  names(df) <- trimws(names(df))
  missing <- setdiff(names(.ldv_map), names(df))
  if (length(missing) > 0) {
    return(.ldv_error(path, sprintf("Missing required columns: %s",
      paste0("[", paste(sprintf("'%s'", sort(missing)), collapse = ", "), "]"))))
  }
  out <- df[, names(.ldv_map), drop = FALSE]
  names(out) <- unname(.ldv_map[names(out)])
  out <- out[!is.na(out$Site) & trimws(as.character(out$Site)) != "", , drop = FALSE]
  out$Date <- suppressWarnings(as.Date(out$Date))
  out$CV_pct <- suppressWarnings(as.numeric(out$CV_pct))
  out <- out[!is.na(out$Date), , drop = FALSE]
  out$Site <- as.character(out$Site)
  out$Season <- as.character(out$Season)
  # Match the Python pipeline: pandas reads "N/A" (and similar tokens) as a
  # missing value, so the golden writes a blank cell. Coerce those sentinels
  # to NA here rather than passing the literal string through.
  .na_tokens <- c("", "n/a", "na", "null", "nan", "none", "#n/a")
  out$Season[trimws(tolower(out$Season)) %in% .na_tokens] <- NA_character_
  out <- out[, LDV_COLUMNS, drop = FALSE]
  rownames(out) <- NULL
  DomainResult$new(data = list(LDV = out))
}
