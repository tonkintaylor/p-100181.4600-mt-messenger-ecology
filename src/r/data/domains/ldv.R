# ldv.R — low-flow depth variability.
#
# PRIMARY SOURCE: the raw "LDV" sheet, one row per depth measurement (100 per
# survey), from which CV% is derived per Site x Date:
#
#   CV% = sd(Depth) / mean(Depth) * 100        (sample sd, i.e. Excel STDEV)
#
# Deriving this removes the need for the ecology team to keep the pre-summarised
# "LDV Summary" tab up to date by hand. Calibrated against that tab's own
# published values: all 10 of its first rows reproduce to within the 2 dp
# rounding of the displayed mean/sd (see tests/r/test-domain-ldv.R).
#
# NB the sample-vs-population sd convention cannot be settled from the published
# table alone (its CV is self-consistent with whichever sd it displays). Sample
# sd is used here because it is Excel's STDEV default; a population-sd source
# would show up as a uniform ~0.5% bias across every row when a full workbook
# run is diffed against the summary tab.
#
# The QA column is deliberately ignored: every row with a numeric depth counts
# (confirmed 2026-07-29).
#
# FALLBACK ONLY: "LDV Summary" (header on row 14) is read when the raw sheet is
# absent, so older databases keep working. It is NOT required -- the source
# database is expected to drop it eventually, and a workbook carrying only the
# raw sheet runs unchanged.

.ldv_sheet <- "LDV Summary"
.ldv_skip <- 13
.ldv_map <- c("Site" = "Site", "Date" = "Date", "Season" = "Season",
              "CV (%)" = "CV_pct")

.ldv_raw_sheet <- "LDV"
# Season is optional (NA when absent): it is a label only, carried through for
# the output schema and unused by the figures. Depth/Site/Date are structural.
.ldv_raw_required <- c("Site", "Date", "Depth (cm)")
# Rows scanned when locating the header. The raw sheet has its header on row 1,
# but scanning tolerates title/note rows being inserted above it -- the failure
# mode that the fixed skip on "LDV Summary" is prone to.
.ldv_raw_header_scan <- 20L

.ldv_error <- function(path, message, sheet = .ldv_sheet) {
  DomainResult$new(data = NULL, errors = list(ValidationError(
    domain = "LDV", severity = "error", file = as.character(path),
    sheet = sheet, location = "sheet", message = message)))
}

.ldv_warning <- function(path, location, message, sheet = .ldv_raw_sheet) {
  ValidationError(domain = "LDV", severity = "warning",
                  file = as.character(path), sheet = sheet,
                  location = location, message = message)
}

process_ldv_domain <- function(path) {
  sheets <- tryCatch(readxl::excel_sheets(path),
                     error = function(e) character(0))
  if (.ldv_raw_sheet %in% sheets) return(.ldv_from_raw(path))
  if (.ldv_sheet %in% sheets) return(.ldv_from_summary(path))
  # Neither present. The summary tab is a fallback only -- it is expected to
  # disappear from the source database eventually -- so name both sheets rather
  # than reporting the fallback's absence as if it were the requirement.
  .ldv_error(path, sprintf(
    "Neither the raw '%s' sheet nor the fallback '%s' sheet found in %s",
    .ldv_raw_sheet, .ldv_sheet, path), sheet = .ldv_raw_sheet)
}

# --- primary path: derive CV% from the raw per-measurement depths -------------

.ldv_from_raw <- function(path) {
  hdr <- find_header_row(path, .ldv_raw_sheet, .ldv_raw_required,
                         .ldv_raw_header_scan)
  if (is.na(hdr)) {
    return(.ldv_error(path, missing_cols_msg(setdiff(
      .ldv_raw_required, header_names(path, .ldv_raw_sheet))),
      sheet = .ldv_raw_sheet))
  }

  df <- suppressWarnings(suppressMessages(tryCatch(
    readxl::read_excel(path, sheet = .ldv_raw_sheet, skip = hdr - 1L,
                       .name_repair = "minimal"),
    error = function(e) e)))
  if (inherits(df, "error")) {
    return(.ldv_error(path, sprintf("Sheet '%s' not found or unreadable in %s",
                                    .ldv_raw_sheet, path),
                      sheet = .ldv_raw_sheet))
  }
  names(df) <- trimws(names(df))

  site  <- trimws(as.character(df[["Site"]]))
  date  <- .rpd_parse_date_dayfirst(df[["Date"]])
  depth <- suppressWarnings(as.numeric(df[["Depth (cm)"]]))
  season <- if ("Season" %in% names(df)) {
    s <- trimws(as.character(df[["Season"]]))
    s[s %in% NA_TOKENS] <- NA_character_
    s
  } else {
    rep(NA_character_, nrow(df))
  }

  # A measurement is usable only with a site, a parseable date and a numeric
  # depth. Anything else cannot be grouped or averaged, so it is dropped and
  # reported as a warning (warnings do not block the pipeline).
  usable <- !is.na(site) & nzchar(site) & !is.na(date) & !is.na(depth)
  errors <- list()
  if (any(!usable)) {
    bad <- which(!usable)
    errors <- c(errors, list(.ldv_warning(
      path, sprintf("rows %s", .first_rows(bad)),
      sprintf(paste("Dropped %d row(s) with missing Site, unparseable Date",
                    "or non-numeric Depth (cm)"), length(bad)))))
  }
  if (!any(usable)) {
    return(DomainResult$new(data = NULL, errors = c(errors, list(
      ValidationError(
        domain = "LDV", severity = "error", file = as.character(path),
        sheet = .ldv_raw_sheet, location = "sheet",
        message = "No usable depth measurements found")))))
  }

  idx <- which(usable)
  keys <- paste(site[idx], as.integer(date[idx]), sep = "\r")
  rows <- lapply(split(idx, keys), function(g) {
    d <- depth[g]
    m <- mean(d)
    # n < 2 has no sample sd; a zero mean has no defined CV.
    cv <- if (length(d) < 2L || is.na(m) || m == 0) NA_real_ else
      stats::sd(d) / m * 100
    seas <- season[g]
    seas <- seas[!is.na(seas)]
    data.frame(Site = site[g[1L]], Date = date[g[1L]],
               Season = if (length(seas) == 0L) NA_character_ else seas[1L],
               CV_pct = cv,
               stringsAsFactors = FALSE, check.names = FALSE)
  })

  out <- do.call(rbind, rows)
  out <- out[order(out$Date, out$Site), LDV_COLUMNS, drop = FALSE]
  rownames(out) <- NULL
  DomainResult$new(data = list(LDV = out), errors = errors)
}

# --- fallback path: read the pre-summarised "LDV Summary" tab -----------------

.ldv_from_summary <- function(path) {
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
    return(.ldv_error(path, missing_cols_msg(missing)))
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
  out$Season[out$Season %in% NA_TOKENS] <- NA_character_
  out <- out[, LDV_COLUMNS, drop = FALSE]
  rownames(out) <- NULL
  DomainResult$new(data = list(LDV = out))
}
