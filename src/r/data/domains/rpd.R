# rpd.R — residual pool depth.
#
# PRIMARY SOURCE: the raw "Residual pool depths" sheet, one row per POOL,
# aggregated per Site x Date:
#
#   Count  = number of pools measured in the survey
#   Mean   = mean residual pool depth
#   StdDev = sample sd (Excel STDEV)
#   CI_Lower/CI_Upper = Mean +/- t(0.975, n-1) * StdDev / sqrt(n)
#
# The CI is deliberately t-based. The "RPD Summary" tab stores a z (1.96)
# approximation, which is noticeably narrower on the small pool counts these
# surveys produce; the printed report uses the t interval and so does
# rpd_summary.R (Appendix B1 Table 4). Author-confirmed 2026-07-29: t only, do
# not reproduce the spreadsheet's z convention. The CI columns are consumed by
# the habitat figures; Appendix B1 Table 4 reads only Count/Mean/StdDev and
# recomputes its own pooled t interval, so it is unaffected either way.
#
# FALLBACK ONLY: the pre-summarised "RPD Summary" sheet (header on row 4) is read
# when the raw sheet is absent, so older databases keep working. It is NOT
# required -- the source database is expected to drop it eventually, and a
# workbook carrying only the raw sheet runs unchanged. QA Notes are ignored.

.rpd_sheet <- "RPD Summary"
.rpd_skip <- 3
.rpd_map <- c("Site" = "Site", "Date" = "Date", "Count" = "Count",
              "Mean (cm)" = "Mean", "Std Dev" = "StdDev",
              "CI Lower" = "CI_Lower", "CI Upper" = "CI_Upper")

.rpd_raw_sheet <- "Residual pool depths"
# One row per POOL: Order, Timing, Season, Year, Date, Site, Pool Number,
# Maximum pool depth (cm), Crest depth (cm), Residual pool depth (cm), QA Notes.
# Only Site, Date and a residual depth are needed; Count is the number of pools.
.rpd_raw_required <- c("Site", "Date")
.rpd_raw_header_scan <- 20L

# Depth columns are matched by prefix rather than exact name: the source headers
# carry a "(cm)" unit suffix, which is the kind of thing that gets reworded, and
# these three prefixes are mutually exclusive so there is no ambiguity.
.RPD_RAW_RESIDUAL_RE <- "^residual pool depth"
.RPD_RAW_MAXIMUM_RE  <- "^maximum pool depth"
.RPD_RAW_CREST_RE    <- "^crest depth"
# Name used in error messages when no residual depth can be resolved.
.RPD_RAW_RESIDUAL_LABEL <- "Residual pool depth (cm)"

# 95% CI half-width from n, sd: t-based, NOT the z (1.96) approximation stored in
# the "RPD Summary" tab. NA when n < 2 (no sample sd, hence no interval).
.rpd_ci95 <- function(n, sd_) {
  if (is.na(sd_) || n < 2L) return(NA_real_)
  stats::qt(0.975, df = n - 1L) * sd_ / sqrt(n)
}

# First column whose (trimmed, lowercased) name matches `pattern`; NA if none.
.rpd_match_col <- function(nms, pattern) {
  hit <- grep(pattern, tolower(trimws(nms)))
  if (length(hit) == 0L) NA_character_ else nms[hit[1L]]
}

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

# Parse dates that may be written day-first as text ("22/08/2024"), as the raw
# measurement sheets are. Text dates MUST be tried day-first before
# .rpd_parse_date(), which starts from R's default character parse: that reads
# "22/08/2024" as %Y/%m/%d and, because strptime tolerates trailing characters,
# silently returns 0022-08-20 instead of failing over. A wrong-but-valid date is
# worse than an NA here, since only NA dates get dropped downstream.
.rpd_parse_date_dayfirst <- function(x) {
  if (inherits(x, "POSIXt") || inherits(x, "Date") || is.numeric(x)) {
    return(.rpd_parse_date(x))
  }
  chars <- as.character(x)
  parsed <- as.Date(chars, format = "%d/%m/%Y")
  fallback <- is.na(parsed) & !is.na(chars)
  if (any(fallback)) parsed[fallback] <- .rpd_parse_date(chars[fallback])
  parsed
}

.rpd_error <- function(path, message, sheet = .rpd_sheet) {
  DomainResult$new(data = NULL, errors = list(ValidationError(
    domain = "RPD", severity = "error", file = as.character(path),
    sheet = sheet, location = "sheet", message = message)))
}

process_rpd_domain <- function(path) {
  sheets <- tryCatch(readxl::excel_sheets(path),
                     error = function(e) character(0))
  if (.rpd_raw_sheet %in% sheets) return(.rpd_from_raw(path))
  if (.rpd_sheet %in% sheets) return(.rpd_from_summary(path))
  # Neither present. The summary tab is a fallback only -- it is expected to
  # disappear from the source database eventually -- so name both sheets rather
  # than reporting the fallback's absence as if it were the requirement.
  .rpd_error(path, sprintf(
    "Neither the raw '%s' sheet nor the fallback '%s' sheet found in %s",
    .rpd_raw_sheet, .rpd_sheet, path), sheet = .rpd_raw_sheet)
}

# --- primary path: aggregate the raw per-measurement pool depths --------------

.rpd_from_raw <- function(path) {
  hdr <- find_header_row(path, .rpd_raw_sheet, .rpd_raw_required,
                         .rpd_raw_header_scan)
  if (is.na(hdr)) {
    return(.rpd_error(path, missing_cols_msg(setdiff(
      .rpd_raw_required, header_names(path, .rpd_raw_sheet))),
      sheet = .rpd_raw_sheet))
  }

  df <- suppressWarnings(suppressMessages(tryCatch(
    readxl::read_excel(path, sheet = .rpd_raw_sheet, skip = hdr - 1L,
                       .name_repair = "minimal"),
    error = function(e) e)))
  if (inherits(df, "error")) {
    return(.rpd_error(path, sprintf("Sheet '%s' not found or unreadable in %s",
                                    .rpd_raw_sheet, path),
                      sheet = .rpd_raw_sheet))
  }
  names(df) <- trimws(names(df))

  # Prefer the sheet's own residual depth column. If it is absent, fall back to
  # reconstructing it as maximum pool depth - crest depth, which is how the
  # sheet derives it (verified against the source rows).
  residual_col <- .rpd_match_col(names(df), .RPD_RAW_RESIDUAL_RE)
  num <- function(col) suppressWarnings(as.numeric(df[[col]]))
  if (!is.na(residual_col)) {
    depth <- num(residual_col)
  } else {
    max_col <- .rpd_match_col(names(df), .RPD_RAW_MAXIMUM_RE)
    crest_col <- .rpd_match_col(names(df), .RPD_RAW_CREST_RE)
    if (is.na(max_col) || is.na(crest_col)) {
      return(.rpd_error(path, missing_cols_msg(.RPD_RAW_RESIDUAL_LABEL),
                        sheet = .rpd_raw_sheet))
    }
    depth <- num(max_col) - num(crest_col)
  }

  site <- trimws(as.character(df[["Site"]]))
  date <- .rpd_parse_date_dayfirst(df[["Date"]])

  # A pool is usable only with a site, a parseable date and a numeric residual
  # depth; anything else cannot be grouped or averaged.
  usable <- !is.na(site) & nzchar(site) & !is.na(date) & !is.na(depth)
  errors <- list()
  if (any(!usable)) {
    bad <- which(!usable)
    errors <- c(errors, list(ValidationError(
      domain = "RPD", severity = "warning", file = as.character(path),
      sheet = .rpd_raw_sheet, location = sprintf("rows %s", .first_rows(bad)),
      message = sprintf(
        paste("Dropped %d row(s) with missing Site, unparseable Date",
              "or non-numeric residual pool depth"), length(bad)))))
  }
  if (!any(usable)) {
    return(DomainResult$new(data = NULL, errors = c(errors, list(
      ValidationError(
        domain = "RPD", severity = "error", file = as.character(path),
        sheet = .rpd_raw_sheet, location = "sheet",
        message = "No usable pool depths found")))))
  }

  idx <- which(usable)
  keys <- paste(site[idx], as.integer(date[idx]), sep = "\r")
  rows <- lapply(split(idx, keys), function(g) {
    d <- depth[g]
    n <- length(d)
    m <- mean(d)
    # n < 2 has no sample sd, so no CI either.
    sd_ <- if (n < 2L) NA_real_ else stats::sd(d)
    half <- .rpd_ci95(n, sd_)
    data.frame(Site = site[g[1L]], Date = date[g[1L]],
               Count = as.integer(n), Mean = m, StdDev = sd_,
               CI_Lower = m - half, CI_Upper = m + half,
               stringsAsFactors = FALSE, check.names = FALSE)
  })

  out <- do.call(rbind, rows)
  out <- out[order(out$Date, out$Site), RPD_COLUMNS, drop = FALSE]
  rownames(out) <- NULL
  DomainResult$new(data = list(RPD = out), errors = errors)
}

# --- season labels as recorded on the raw sheet -------------------------------

# Season/Year exactly as the raw sheet records them, one row per Site x Date.
# rpd_summary.R (Appendix B1 Table 4) uses these in preference to deriving the
# season from the survey date -- author-confirmed 2026-07-29: use the sheet's
# own value, do not infer it.
#
# Returns NULL when the workbook has no raw sheet (the "RPD Summary" fallback
# carries no season labels at all) and NA in either column where the sheet leaves
# it blank, which it does for baseline and event-based surveys. Callers decide
# what to do with those; see .rpd_season_year() in rpd_summary.R.
rpd_raw_season_labels <- function(path) {
  sheets <- tryCatch(readxl::excel_sheets(path),
                     error = function(e) character(0))
  if (!.rpd_raw_sheet %in% sheets) return(NULL)
  hdr <- find_header_row(path, .rpd_raw_sheet, .rpd_raw_required,
                         .rpd_raw_header_scan)
  if (is.na(hdr)) return(NULL)
  df <- suppressWarnings(suppressMessages(tryCatch(
    readxl::read_excel(path, sheet = .rpd_raw_sheet, skip = hdr - 1L,
                       .name_repair = "minimal"),
    error = function(e) NULL)))
  if (is.null(df) || nrow(df) == 0L) return(NULL)
  names(df) <- trimws(names(df))

  site <- trimws(as.character(df[["Site"]]))
  date <- .rpd_parse_date_dayfirst(df[["Date"]])
  blank <- function(v) is.na(v) | !nzchar(v) | v %in% NA_TOKENS
  season <- if ("Season" %in% names(df)) {
    s <- trimws(as.character(df[["Season"]]))
    s[blank(s)] <- NA_character_
    s
  } else {
    rep(NA_character_, nrow(df))
  }
  year <- if ("Year" %in% names(df)) {
    suppressWarnings(as.integer(as.numeric(as.character(df[["Year"]]))))
  } else {
    rep(NA_integer_, nrow(df))
  }

  keep <- !is.na(site) & nzchar(site) & !is.na(date)
  if (!any(keep)) return(NULL)
  idx <- which(keep)
  # One label per survey: the first non-blank value recorded against it.
  rows <- lapply(split(idx, paste(site[idx], as.integer(date[idx]), sep = "\r")),
                 function(g) {
    first <- function(v) {
      v <- v[!is.na(v)]
      if (length(v) == 0L) v[NA_integer_] else v[1L]
    }
    data.frame(Site = site[g[1L]], Date = date[g[1L]],
               Season = first(season[g]), Year = first(year[g]),
               stringsAsFactors = FALSE, check.names = FALSE)
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

# --- fallback path: read the pre-summarised "RPD Summary" tab -----------------

.rpd_from_summary <- function(path) {
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
  # Match pandas dropna(subset=["Site"]): drop only true-NA Site (empty cells
  # read as NA), not whitespace-only strings, which pandas retains.
  out <- out[!is.na(out$Site), , drop = FALSE]
  out$Date <- .rpd_parse_date(out$Date)
  # Match pandas .astype("Int64"), which truncates toward zero rather than
  # rounding half-to-even.
  out$Count <- suppressWarnings(as.integer(trunc(as.numeric(out$Count))))
  for (col in c("Mean", "StdDev", "CI_Lower", "CI_Upper")) {
    out[[col]] <- suppressWarnings(as.numeric(out[[col]]))
  }
  out <- out[!is.na(out$Date), , drop = FALSE]
  out$Site <- as.character(out$Site)
  out <- out[, RPD_COLUMNS, drop = FALSE]
  rownames(out) <- NULL
  DomainResult$new(data = list(RPD = out))
}
