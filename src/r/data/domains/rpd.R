# rpd.R — residual pool depth from "RPD Summary" (skip 3 header rows).

.rpd_sheet <- "RPD Summary"
.rpd_skip <- 3
.rpd_map <- c("Site" = "Site", "Date" = "Date", "Count" = "Count",
              "Mean (cm)" = "Mean", "Std Dev" = "StdDev",
              "CI Lower" = "CI_Lower", "CI Upper" = "CI_Upper")

# Parse Date that may be POSIXct, numeric, or character Excel serial number.
# Mirrors pandas pd.to_datetime(errors="coerce") behaviour.
.rpd_parse_date <- function(x) {
  if (inherits(x, "POSIXct") || inherits(x, "POSIXlt")) {
    return(as.Date(x))
  }
  if (is.numeric(x)) {
    return(as.Date(x, origin = "1899-12-30"))
  }
  # Character: try element-wise conversion, falling back to Excel serial numeric.
  chars <- as.character(x)
  result <- vapply(chars, function(v) {
    if (is.na(v) || nchar(trimws(v)) == 0L) return(NA_real_)
    # Try standard date parse first.
    d <- tryCatch(as.Date(v), error = function(e) NA_real_)
    if (!is.na(d)) return(as.numeric(d))
    # Fall back: treat as numeric Excel serial.
    n <- suppressWarnings(as.numeric(v))
    if (!is.na(n)) return(as.numeric(as.Date(n, origin = "1899-12-30")))
    NA_real_
  }, numeric(1))
  as.Date(result, origin = "1970-01-01")
}

.rpd_error <- function(path, message) {
  DomainResult$new(data = NULL, errors = list(ValidationError(
    domain = "RPD", severity = "error", file = as.character(path),
    sheet = .rpd_sheet, location = "sheet", message = message)))
}

process_rpd_domain <- function(path) {
  df <- suppressMessages(tryCatch(
    readxl::read_excel(path, sheet = .rpd_sheet, skip = .rpd_skip),
    error = function(e) e))
  if (inherits(df, "error")) {
    return(.rpd_error(path, sprintf("Sheet '%s' not found or unreadable in %s",
                                    .rpd_sheet, path)))
  }
  names(df) <- trimws(names(df))
  missing <- setdiff(names(.rpd_map), names(df))
  if (length(missing) > 0) {
    return(.rpd_error(path, sprintf("Missing required columns: %s",
      paste0("[", paste(sprintf("'%s'", sort(missing)), collapse = ", "), "]"))))
  }
  out <- df[, names(.rpd_map), drop = FALSE]
  names(out) <- unname(.rpd_map[names(out)])
  out <- out[!is.na(out$Site) & trimws(as.character(out$Site)) != "", , drop = FALSE]
  out$Date <- .rpd_parse_date(out$Date)
  out$Count <- suppressWarnings(as.integer(round(as.numeric(out$Count))))
  for (col in c("Mean", "StdDev", "CI_Lower", "CI_Upper")) {
    out[[col]] <- suppressWarnings(as.numeric(out[[col]]))
  }
  out <- out[!is.na(out$Date), , drop = FALSE]
  out$Site <- as.character(out$Site)
  out <- out[, RPD_COLUMNS, drop = FALSE]
  rownames(out) <- NULL
  DomainResult$new(data = list(RPD = out))
}
