src_data("errors.R"); src_data("schemas.R")
# ldv.R reuses .rpd_parse_date() and .first_rows(); all are sourced together
# at runtime (see the module list in src/r/run_data.R).
src_data("validation.R")
src_data("domains/rpd.R"); src_data("domains/ldv.R")

# ---------------------------------------------------------------------------
# Helper: write an "LDV Summary" sheet with 13 filler rows then the real
# header+data, so read_excel(skip=13) reads the header as column names.
# Strategy: write a single data frame where the first 13 rows are fillers
# and row 14 is the real data, with header at row 1 as "junk1"..."junk4".
# Instead, we use openxlsx workbook to write filler rows manually.
# ---------------------------------------------------------------------------
ldv_xlsx <- function(df, extra_rows = NULL) {
  # Build workbook manually so we can put 13 junk rows before the real header.
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "LDV Summary")

  # Write 13 filler rows (row indices 1-13) in column A
  for (i in seq_len(13)) {
    openxlsx::writeData(wb, "LDV Summary", x = paste0("filler row ", i),
                        startRow = i, startCol = 1, colNames = FALSE)
  }

  # Write real header + data starting at row 14 (with colNames = TRUE)
  openxlsx::writeData(wb, "LDV Summary", x = df, startRow = 14, colNames = TRUE)

  tmp <- tempfile(fileext = ".xlsx")
  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)
  tmp
}

# Minimal valid LDV data frame (source column names)
minimal_ldv_df <- function() {
  data.frame(
    Site    = c("EM4", "CM2"),
    Date    = as.Date(c("2026-01-15", "2026-03-10")),
    Season  = c("Winter", "Autumn"),
    `CV (%)` = c(12.5, 8.3),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
}

# ---------------------------------------------------------------------------
# 1. Happy path — 13 filler rows, then header + data
# ---------------------------------------------------------------------------
test_that("happy path produces DomainResult with LDV_COLUMNS data frame", {
  path   <- ldv_xlsx(minimal_ldv_df())
  result <- process_ldv_domain(path)

  expect_true(result$ok())
  expect_false(is.null(result$data))
  ldv <- result$data$LDV
  expect_equal(names(ldv), LDV_COLUMNS)
  expect_equal(nrow(ldv), 2L)
  expect_equal(ldv$Site, c("EM4", "CM2"))
  expect_equal(ldv$CV_pct, c(12.5, 8.3))
})

# ---------------------------------------------------------------------------
# 2. Output column types: Site/Season character, Date Date, CV_pct numeric
# ---------------------------------------------------------------------------
test_that("output column types are correct", {
  path   <- ldv_xlsx(minimal_ldv_df())
  result <- process_ldv_domain(path)

  expect_true(result$ok())
  ldv <- result$data$LDV
  expect_true(is.character(ldv$Site))
  expect_true(inherits(ldv$Date, "Date"))
  expect_true(is.character(ldv$Season))
  expect_true(is.numeric(ldv$CV_pct))
})

# ---------------------------------------------------------------------------
# 3. Missing source column → error DomainResult
# ---------------------------------------------------------------------------
test_that("missing CV (%) column returns an error result", {
  df <- data.frame(
    Site   = c("EM4"),
    Date   = as.Date("2026-01-15"),
    Season = c("Winter"),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  path   <- ldv_xlsx(df)
  result <- process_ldv_domain(path)

  expect_false(result$ok())
  expect_null(result$data)
  expect_equal(length(result$errors), 1L)
  err <- result$errors[[1]]
  expect_equal(err$domain, "LDV")
  expect_equal(err$severity, "error")
  expect_match(err$message, "Missing required columns")
  expect_match(err$message, "CV")
})

# ---------------------------------------------------------------------------
# 4. Trailing blank-Site rows are dropped
# ---------------------------------------------------------------------------
test_that("rows with NA or blank Site are dropped", {
  df <- data.frame(
    Site    = c("EM4", NA, ""),
    Date    = as.Date(c("2026-01-15", "2026-03-10", "2026-04-01")),
    Season  = c("Winter", "Autumn", "Spring"),
    `CV (%)` = c(12.5, 8.3, 5.1),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  path   <- ldv_xlsx(df)
  result <- process_ldv_domain(path)

  expect_true(result$ok())
  ldv <- result$data$LDV
  expect_equal(nrow(ldv), 1L)
  expect_equal(ldv$Site, "EM4")
})

# ---------------------------------------------------------------------------
# 5. Unparseable Date row is dropped
# ---------------------------------------------------------------------------
test_that("rows with unparseable Date are dropped", {
  df <- data.frame(
    Site    = c("EM4", "CM2"),
    Date    = c("2026-01-15", "not-a-date"),
    Season  = c("Winter", "Autumn"),
    `CV (%)` = c(12.5, 8.3),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  path   <- ldv_xlsx(df)
  result <- process_ldv_domain(path)

  expect_true(result$ok())
  ldv <- result$data$LDV
  expect_equal(nrow(ldv), 1L)
  expect_equal(ldv$Site, "EM4")
})

# ---------------------------------------------------------------------------
# 6. Sheet not found → error result
# ---------------------------------------------------------------------------
test_that("excel file with no LDV Summary sheet returns an error result", {
  tmp <- tempfile(fileext = ".xlsx")
  openxlsx::write.xlsx(list("WrongSheet" = data.frame(x = 1)), tmp)

  result <- process_ldv_domain(tmp)

  expect_false(result$ok())
  expect_null(result$data)
  expect_equal(length(result$errors), 1L)
  err <- result$errors[[1]]
  expect_equal(err$domain, "LDV")
  expect_equal(err$severity, "error")
  expect_match(err$message, "LDV Summary")
})

# ---------------------------------------------------------------------------
# 7b. Source "N/A" Season string is coerced to NA (matches Python golden)
#
# The source "LDV Summary" sheet records "N/A" in the Season column for dates
# that fall outside a monitoring season. The Python pipeline (pandas) treats
# "N/A" as a missing value and writes a blank cell. The R port must do the
# same so its output matches the golden Data_*.xlsx byte-for-byte.
# ---------------------------------------------------------------------------
test_that("'N/A' Season string is coerced to NA", {
  df <- data.frame(
    Site    = c("EM3", "EM7"),
    Date    = as.Date(c("2024-08-22", "2024-11-06")),
    Season  = c("N/A", "Spring"),
    `CV (%)` = c(58.44, 75.38),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  path   <- ldv_xlsx(df)
  result <- process_ldv_domain(path)

  expect_true(result$ok())
  ldv <- result$data$LDV
  expect_true(is.na(ldv$Season[1]))
  expect_equal(ldv$Season[2], "Spring")
})

# ---------------------------------------------------------------------------
# 7. Output has exactly LDV_COLUMNS in that order
# ---------------------------------------------------------------------------
test_that("output has exactly LDV_COLUMNS columns in correct order", {
  path   <- ldv_xlsx(minimal_ldv_df())
  result <- process_ldv_domain(path)

  expect_true(result$ok())
  ldv <- result$data$LDV
  expect_equal(ncol(ldv), length(LDV_COLUMNS))
  expect_equal(names(ldv), LDV_COLUMNS)
})

# ===========================================================================
# Raw "LDV" sheet — CV% derived from per-measurement depths
#
# The source database carries a raw "LDV" sheet with one row per depth
# measurement (100 per survey: Order, Timing, Season, Year, Date, Site, Number,
# Depth (cm), QA). Deriving CV% from it means the ecology team no longer has to
# maintain the "LDV Summary" tab by hand.
# ===========================================================================

# Helper: write a raw "LDV" sheet, optionally preceded by `title_rows` filler
# rows so header-row detection is exercised.
ldv_raw_xlsx <- function(df, title_rows = 0L, extra_sheets = NULL) {
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "LDV")
  for (i in seq_len(title_rows)) {
    openxlsx::writeData(wb, "LDV", x = paste0("title row ", i),
                        startRow = i, startCol = 1, colNames = FALSE)
  }
  openxlsx::writeData(wb, "LDV", x = df, startRow = title_rows + 1L,
                      colNames = TRUE)
  for (nm in names(extra_sheets)) {
    openxlsx::addWorksheet(wb, nm)
    openxlsx::writeData(wb, nm, x = extra_sheets[[nm]], colNames = TRUE)
  }
  tmp <- tempfile(fileext = ".xlsx")
  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)
  tmp
}

# Build raw measurement rows for one survey, mirroring the source columns.
ldv_raw_rows <- function(site, date, season, depths, year = NULL) {
  data.frame(
    Order  = seq_along(depths),
    Timing = "Routine",
    Season = season,
    Year   = if (is.null(year)) as.integer(format(as.Date(date), "%Y")) else year,
    Date   = as.Date(date),
    Site   = site,
    Number = seq_along(depths),
    `Depth (cm)` = depths,
    QA     = NA_character_,
    check.names = FALSE, stringsAsFactors = FALSE)
}

# n depths with EXACTLY the given mean and sample sd: half at mean - h, half at
# mean + h, where h = sd * sqrt((n-1)/n). Lets us calibrate the derived CV
# against the published summary values without needing the raw 100 depths.
ldv_depths_with <- function(mean_cm, sd_cm, n = 100L) {
  h <- sd_cm * sqrt((n - 1) / n)
  c(rep(mean_cm - h, n / 2), rep(mean_cm + h, n / 2))
}

# ---------------------------------------------------------------------------
# 8. Raw sheet: CV% is derived per Site x Date
# ---------------------------------------------------------------------------
test_that("raw LDV sheet derives CV% per Site x Date", {
  df <- rbind(
    ldv_raw_rows("EM3", "2024-08-22", "N/A", c(30, 37, 25, 21, 24)),
    ldv_raw_rows("EM7", "2024-11-06", "Spring", c(10, 20, 30, 40)))
  result <- process_ldv_domain(ldv_raw_xlsx(df))

  expect_true(result$ok())
  ldv <- result$data$LDV
  expect_equal(names(ldv), LDV_COLUMNS)
  expect_equal(nrow(ldv), 2L)
  expect_equal(ldv$Site, c("EM3", "EM7"))

  em3 <- c(30, 37, 25, 21, 24)
  expect_equal(ldv$CV_pct[1], sd(em3) / mean(em3) * 100)
  em7 <- c(10, 20, 30, 40)
  expect_equal(ldv$CV_pct[2], sd(em7) / mean(em7) * 100)
})

# ---------------------------------------------------------------------------
# 9. Calibration against the published "LDV Summary" values
#
# Each case supplies 100 depths whose mean and sample sd equal the mean/Std Dev
# printed in the source summary tab; the derived CV must match that tab's own
# CV (%) to within the 2 dp rounding of the printed inputs (~0.05).
#
# These are the surveys the report authors supplied from the summary tab on
# 2026-07-29, covering both catchments, both seasons and the seasonless
# ("N/A") baseline survey.
# ---------------------------------------------------------------------------
test_that("derived CV reproduces the published LDV Summary values", {
  published <- list(
    list(site = "EM1", date = "2024-11-06", season = "Spring",
         mean = 17.68, sd = 10.32, cv = 58.38),
    list(site = "EM1", date = "2025-02-26", season = "Summer",
         mean = 15.33, sd = 12.00, cv = 78.32),
    list(site = "EM1", date = "2025-11-24", season = "Spring",
         mean = 20.12, sd = 13.18, cv = 65.52),
    list(site = "EM1", date = "2026-02-23", season = "Summer",
         mean = 19.86, sd = 14.45, cv = 72.77),
    list(site = "EM2", date = "2024-11-06", season = "Spring",
         mean = 47.77, sd = 16.55, cv = 34.65),
    list(site = "EM2", date = "2025-02-26", season = "Summer",
         mean = 36.17, sd = 15.94, cv = 44.08),
    list(site = "EM2", date = "2025-11-24", season = "Spring",
         mean = 47.04, sd = 20.15, cv = 42.84),
    list(site = "EM2", date = "2026-02-23", season = "Summer",
         mean = 43.06, sd = 19.12, cv = 44.41),
    list(site = "EM3", date = "2024-08-22", season = "N/A",
         mean = 26.82, sd = 15.67, cv = 58.44),
    list(site = "EM3", date = "2024-11-06", season = "Spring",
         mean = 25.17, sd = 18.97, cv = 75.38))

  df <- do.call(rbind, lapply(published, function(p)
    ldv_raw_rows(p$site, p$date, p$season,
                 ldv_depths_with(p$mean, p$sd))))
  result <- process_ldv_domain(ldv_raw_xlsx(df))

  expect_true(result$ok())
  ldv <- result$data$LDV
  expect_equal(nrow(ldv), length(published))

  for (p in published) {
    row <- ldv[ldv$Site == p$site & ldv$Date == as.Date(p$date), ]
    expect_equal(nrow(row), 1L)
    expect_lt(abs(row$CV_pct - p$cv), 0.05)
  }
})

# ---------------------------------------------------------------------------
# 10. Grouping is Site x Date, not Site x Season
#
# EM3 has two surveys in 2024 — 22/08 (Season "N/A") and 06/11 (Spring) — and
# the summary tab lists them as separate rows.
# ---------------------------------------------------------------------------
test_that("two surveys for one site in one year produce two rows", {
  df <- rbind(
    ldv_raw_rows("EM3", "2024-08-22", "N/A", c(30, 37, 25, 21, 24)),
    ldv_raw_rows("EM3", "2024-11-06", "Spring", c(18, 24, 31, 27, 22)))
  result <- process_ldv_domain(ldv_raw_xlsx(df))

  expect_true(result$ok())
  ldv <- result$data$LDV
  expect_equal(nrow(ldv), 2L)
  expect_equal(ldv$Date, as.Date(c("2024-08-22", "2024-11-06")))
  expect_true(is.na(ldv$Season[1]))       # "N/A" -> NA, as on the summary path
  expect_equal(ldv$Season[2], "Spring")
})

# ---------------------------------------------------------------------------
# 11. The raw sheet wins when both it and "LDV Summary" are present
# ---------------------------------------------------------------------------
test_that("raw LDV sheet takes precedence over LDV Summary", {
  raw <- ldv_raw_rows("EM3", "2024-08-22", "N/A", c(30, 37, 25, 21, 24))
  # A summary sheet whose CV disagrees with the raw depths; header at row 1 here
  # (its position is irrelevant — the raw path should be chosen regardless).
  summary_df <- data.frame(
    Site = "EM3", Date = as.Date("2024-08-22"), Season = "N/A",
    `CV (%)` = 999, check.names = FALSE, stringsAsFactors = FALSE)
  path <- ldv_raw_xlsx(raw, extra_sheets = list(`LDV Summary` = summary_df))

  result <- process_ldv_domain(path)

  expect_true(result$ok())
  em3 <- c(30, 37, 25, 21, 24)
  expect_equal(result$data$LDV$CV_pct, sd(em3) / mean(em3) * 100)
})

# ---------------------------------------------------------------------------
# 12. Header row is found even when title rows sit above it
# ---------------------------------------------------------------------------
test_that("raw sheet header is located below title rows", {
  df <- ldv_raw_rows("EM3", "2024-08-22", "N/A", c(30, 37, 25, 21, 24))
  result <- process_ldv_domain(ldv_raw_xlsx(df, title_rows = 4L))

  expect_true(result$ok())
  expect_equal(nrow(result$data$LDV), 1L)
  expect_equal(result$data$LDV$Site, "EM3")
})

# ---------------------------------------------------------------------------
# 13. Day-first text dates ("22/08/2024") parse as day-first
# ---------------------------------------------------------------------------
test_that("day-first text dates in the raw sheet parse correctly", {
  df <- ldv_raw_rows("EM3", "2024-08-22", "N/A", c(30, 37, 25, 21, 24))
  df$Date <- "22/08/2024"   # written as text, not an Excel date
  result <- process_ldv_domain(ldv_raw_xlsx(df))

  expect_true(result$ok())
  expect_equal(result$data$LDV$Date, as.Date("2024-08-22"))
})

# ---------------------------------------------------------------------------
# 14. A single measurement has no sample sd -> CV is NA (not an error)
# ---------------------------------------------------------------------------
test_that("survey with one measurement yields NA CV", {
  df <- ldv_raw_rows("EM3", "2024-08-22", "N/A", 30)
  result <- process_ldv_domain(ldv_raw_xlsx(df))

  expect_true(result$ok())
  expect_equal(nrow(result$data$LDV), 1L)
  expect_true(is.na(result$data$LDV$CV_pct))
})

# ---------------------------------------------------------------------------
# 15. Unusable rows are dropped with a warning; the survey still reports
# ---------------------------------------------------------------------------
test_that("rows with blank Site or non-numeric Depth warn but do not fail", {
  df <- ldv_raw_rows("EM3", "2024-08-22", "N/A", c(30, 37, 25, 21, 24))
  df[["Depth (cm)"]] <- as.character(df[["Depth (cm)"]])
  df[["Depth (cm)"]][2] <- "not a depth"
  df$Site[3] <- NA_character_
  result <- process_ldv_domain(ldv_raw_xlsx(df))

  expect_true(result$ok())                 # warnings do not block the pipeline
  expect_equal(length(result$errors), 1L)
  expect_equal(result$errors[[1]]$severity, "warning")
  expect_match(result$errors[[1]]$message, "Dropped 2 row")

  kept <- c(30, 21, 24)
  expect_equal(result$data$LDV$CV_pct, sd(kept) / mean(kept) * 100)
})

# ---------------------------------------------------------------------------
# 16. Raw sheet missing the Depth column → error naming it
# ---------------------------------------------------------------------------
test_that("raw sheet without Depth (cm) returns an error result", {
  df <- ldv_raw_rows("EM3", "2024-08-22", "N/A", c(30, 37))
  df[["Depth (cm)"]] <- NULL
  result <- process_ldv_domain(ldv_raw_xlsx(df))

  expect_false(result$ok())
  expect_null(result$data)
  err <- result$errors[[1]]
  expect_equal(err$domain, "LDV")
  expect_equal(err$sheet, "LDV")
  expect_match(err$message, "Depth \\(cm\\)")
})

# ---------------------------------------------------------------------------
# 17. The "LDV Summary" tab is NOT required: a workbook carrying only the raw
#     sheet runs, since the source database is expected to drop it eventually.
# ---------------------------------------------------------------------------
test_that("workbook without any LDV Summary tab still produces LDV data", {
  depths <- c(30, 37, 25, 21, 24)
  path <- ldv_raw_xlsx(ldv_raw_rows("EM3", "2024-08-22", "N/A", depths))
  expect_false("LDV Summary" %in% readxl::excel_sheets(path))

  result <- process_ldv_domain(path)

  expect_true(result$ok())
  expect_equal(nrow(result$data$LDV), 1L)
  expect_equal(result$data$LDV$CV_pct, sd(depths) / mean(depths) * 100)
})

# ---------------------------------------------------------------------------
# 18. Neither sheet present → the error names both, not just the fallback
# ---------------------------------------------------------------------------
test_that("error names both the raw and fallback sheets when neither exists", {
  tmp <- tempfile(fileext = ".xlsx")
  openxlsx::write.xlsx(list("WrongSheet" = data.frame(x = 1)), tmp)

  result <- process_ldv_domain(tmp)

  expect_false(result$ok())
  err <- result$errors[[1]]
  expect_match(err$message, "'LDV'")
  expect_match(err$message, "LDV Summary")
})
