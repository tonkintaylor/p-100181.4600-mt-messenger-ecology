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
  # Match pandas dropna(subset=["Site"]): drop only true-NA Site (empty cells
  # read as NA), not whitespace-only strings, which pandas retains.
  out <- out[!is.na(out$Site), , drop = FALSE]
  # Use the same serial-aware parser as RPD so Excel date serials arriving as a
  # numeric column are not misread with R's default 1970 origin.
  out$Date <- .rpd_parse_date(out$Date)
  out$CV_pct <- suppressWarnings(as.numeric(out$CV_pct))
  out <- out[!is.na(out$Date), , drop = FALSE]
  out$Site <- as.character(out$Site)
  out$Season <- as.character(out$Season)
  # Match the Python pipeline: pandas read_excel coerces its default na_values
  # to NaN at read time, so the golden writes a blank cell. Reproduce that exact
  # set, case-sensitively (e.g. "None" -> NA but "none" is kept, as in pandas).
  .na_tokens <- c("", "#N/A", "#N/A N/A", "#NA", "-1.#IND", "-1.#QNAN",
                  "-NaN", "-nan", "1.#IND", "1.#QNAN", "<NA>", "N/A", "NA",
                  "NULL", "NaN", "None", "n/a", "nan", "null")
  out$Season[out$Season %in% .na_tokens] <- NA_character_
  out <- out[, LDV_COLUMNS, drop = FALSE]
  rownames(out) <- NULL
  DomainResult$new(data = list(LDV = out))
}
