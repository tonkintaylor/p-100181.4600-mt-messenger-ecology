src_data("errors.R"); src_data("schemas.R")
# rpd.R uses find_header_row()/.first_rows() from validation.R; both are sourced
# together at runtime (see the module list in src/r/run_data.R).
src_data("validation.R"); src_data("domains/rpd.R")

# ---------------------------------------------------------------------------
# Helper: write an "RPD Summary" sheet with 3 filler rows then the real
# header+data at row 4, so read_excel(skip=3) reads header as column names.
# ---------------------------------------------------------------------------
rpd_xlsx <- function(df) {
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "RPD Summary")

  # Write 3 filler rows (row indices 1-3) in column A
  for (i in seq_len(3)) {
    openxlsx::writeData(wb, "RPD Summary", x = paste0("filler row ", i),
                        startRow = i, startCol = 1, colNames = FALSE)
  }

  # Write real header + data starting at row 4 (with colNames = TRUE)
  openxlsx::writeData(wb, "RPD Summary", x = df, startRow = 4, colNames = TRUE)

  tmp <- tempfile(fileext = ".xlsx")
  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)
  tmp
}

# Minimal valid RPD data frame (source column names)
minimal_rpd_df <- function() {
  data.frame(
    Site         = c("EM4", "CM2"),
    Date         = as.Date(c("2026-01-15", "2026-03-10")),
    Count        = c(5L, 3L),
    `Mean (cm)`  = c(12.5, 8.3),
    `Std Dev`    = c(1.2, 0.9),
    `CI Lower`   = c(11.1, 7.5),
    `CI Upper`   = c(13.9, 9.1),
    check.names  = FALSE,
    stringsAsFactors = FALSE
  )
}

# ---------------------------------------------------------------------------
# 1. Happy path — 3 filler rows, then header + data
# ---------------------------------------------------------------------------
test_that("happy path produces DomainResult with RPD_COLUMNS data frame", {
  path   <- rpd_xlsx(minimal_rpd_df())
  result <- process_rpd_domain(path)

  expect_true(result$ok())
  expect_false(is.null(result$data))
  rpd <- result$data$RPD
  expect_equal(names(rpd), RPD_COLUMNS)
  expect_equal(nrow(rpd), 2L)
  expect_equal(rpd$Site, c("EM4", "CM2"))
  expect_equal(rpd$Mean, c(12.5, 8.3))
  expect_equal(rpd$StdDev, c(1.2, 0.9))
  expect_equal(rpd$CI_Lower, c(11.1, 7.5))
  expect_equal(rpd$CI_Upper, c(13.9, 9.1))
})

# ---------------------------------------------------------------------------
# 2. Output column types correct
# ---------------------------------------------------------------------------
test_that("output column types are correct", {
  path   <- rpd_xlsx(minimal_rpd_df())
  result <- process_rpd_domain(path)

  expect_true(result$ok())
  rpd <- result$data$RPD
  expect_true(is.character(rpd$Site))
  expect_true(inherits(rpd$Date, "Date"))
  expect_true(is.integer(rpd$Count))
  expect_true(is.numeric(rpd$Mean))
  expect_true(is.numeric(rpd$StdDev))
  expect_true(is.numeric(rpd$CI_Lower))
  expect_true(is.numeric(rpd$CI_Upper))
})

# ---------------------------------------------------------------------------
# 3. Count coercion via trunc(as.numeric(...)) then as.integer
# ---------------------------------------------------------------------------
# Matches pandas .astype("Int64"), which truncates toward zero (not rounds).
# Real RPD counts are whole numbers; the fractional inputs here only assert
# the coercion rule.
test_that("Count is coerced to integer via truncation toward zero", {
  df <- minimal_rpd_df()
  df$Count <- c(4.7, 3.2)  # non-integer numerics
  path   <- rpd_xlsx(df)
  result <- process_rpd_domain(path)

  expect_true(result$ok())
  rpd <- result$data$RPD
  expect_true(is.integer(rpd$Count))
  expect_equal(rpd$Count, c(4L, 3L))
})

# ---------------------------------------------------------------------------
# 4. Missing source column → error DomainResult
# ---------------------------------------------------------------------------
test_that("missing 'Mean (cm)' column returns an error result", {
  df <- data.frame(
    Site       = c("EM4"),
    Date       = as.Date("2026-01-15"),
    Count      = c(5L),
    `Std Dev`  = c(1.2),
    `CI Lower` = c(11.1),
    `CI Upper` = c(13.9),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  path   <- rpd_xlsx(df)
  result <- process_rpd_domain(path)

  expect_false(result$ok())
  expect_null(result$data)
  expect_equal(length(result$errors), 1L)
  err <- result$errors[[1]]
  expect_equal(err$domain, "RPD")
  expect_equal(err$severity, "error")
  expect_match(err$message, "Missing required columns")
  expect_match(err$message, "Mean")
})

# ---------------------------------------------------------------------------
# 5. Trailing blank-Site rows are dropped
# ---------------------------------------------------------------------------
test_that("rows with NA or blank Site are dropped", {
  df <- data.frame(
    Site        = c("EM4", NA, ""),
    Date        = as.Date(c("2026-01-15", "2026-03-10", "2026-04-01")),
    Count       = c(5L, 3L, 2L),
    `Mean (cm)` = c(12.5, 8.3, 5.0),
    `Std Dev`   = c(1.2, 0.9, 0.5),
    `CI Lower`  = c(11.1, 7.5, 4.5),
    `CI Upper`  = c(13.9, 9.1, 5.5),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  path   <- rpd_xlsx(df)
  result <- process_rpd_domain(path)

  expect_true(result$ok())
  rpd <- result$data$RPD
  expect_equal(nrow(rpd), 1L)
  expect_equal(rpd$Site, "EM4")
})

# ---------------------------------------------------------------------------
# 6. Unparseable Date rows are dropped
# ---------------------------------------------------------------------------
test_that("rows with unparseable Date are dropped", {
  df <- data.frame(
    Site        = c("EM4", "CM2"),
    Date        = c("2026-01-15", "not-a-date"),
    Count       = c(5L, 3L),
    `Mean (cm)` = c(12.5, 8.3),
    `Std Dev`   = c(1.2, 0.9),
    `CI Lower`  = c(11.1, 7.5),
    `CI Upper`  = c(13.9, 9.1),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  path   <- rpd_xlsx(df)
  result <- process_rpd_domain(path)

  expect_true(result$ok())
  rpd <- result$data$RPD
  expect_equal(nrow(rpd), 1L)
  expect_equal(rpd$Site, "EM4")
  expect_equal(rpd$Mean, 12.5)
})

# ---------------------------------------------------------------------------
# 7. Sheet not found → error result
# ---------------------------------------------------------------------------
test_that("excel file with no RPD Summary sheet returns an error result", {
  tmp <- tempfile(fileext = ".xlsx")
  openxlsx::write.xlsx(list("WrongSheet" = data.frame(x = 1)), tmp)

  result <- process_rpd_domain(tmp)

  expect_false(result$ok())
  expect_null(result$data)
  expect_equal(length(result$errors), 1L)
  err <- result$errors[[1]]
  expect_equal(err$domain, "RPD")
  expect_equal(err$severity, "error")
  expect_match(err$message, "RPD Summary")
})

# ---------------------------------------------------------------------------
# 8. Output has exactly RPD_COLUMNS in that order
# ---------------------------------------------------------------------------
test_that("output has exactly RPD_COLUMNS columns in correct order", {
  path   <- rpd_xlsx(minimal_rpd_df())
  result <- process_rpd_domain(path)

  expect_true(result$ok())
  rpd <- result$data$RPD
  expect_equal(ncol(rpd), length(RPD_COLUMNS))
  expect_equal(names(rpd), RPD_COLUMNS)
})

# ===========================================================================
# Raw "Residual pool depths" sheet — count/mean/sd/CI derived per Site x Date
#
# The source sheet carries one row per POOL: Order, Timing, Season, Year, Date,
# Site, Pool Number, Maximum pool depth (cm), Crest depth (cm), Residual pool
# depth (cm), QA Notes. Aggregating it means the ecology team no longer has to
# maintain the "RPD Summary" tab by hand, and that tab is not required at all.
# ===========================================================================

RPD_RAW_SHEET <- "Residual pool depths"

# Helper: write a raw measurement sheet, optionally preceded by `title_rows`
# filler rows so header-row detection is exercised.
rpd_raw_xlsx <- function(df, title_rows = 0L, extra_sheets = NULL) {
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, RPD_RAW_SHEET)
  for (i in seq_len(title_rows)) {
    openxlsx::writeData(wb, RPD_RAW_SHEET, x = paste0("title row ", i),
                        startRow = i, startCol = 1, colNames = FALSE)
  }
  openxlsx::writeData(wb, RPD_RAW_SHEET, x = df, startRow = title_rows + 1L,
                      colNames = TRUE)
  for (nm in names(extra_sheets)) {
    openxlsx::addWorksheet(wb, nm)
    openxlsx::writeData(wb, nm, x = extra_sheets[[nm]], colNames = TRUE)
  }
  tmp <- tempfile(fileext = ".xlsx")
  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)
  tmp
}

# One row per pool, mirroring the source columns. `depths` are the residual pool
# depths; crest depth is fixed and maximum pool depth back-calculated from it, so
# the source's own "residual = maximum - crest" relationship holds.
rpd_raw_rows <- function(site, date, depths, season = "Spring", crest = 10) {
  data.frame(
    Order  = seq_along(depths),
    Timing = "Construction",
    Season = season,
    Year   = as.integer(format(as.Date(date), "%Y")),
    Date   = as.Date(date),
    Site   = site,
    `Pool Number` = seq_along(depths),
    `Maximum pool depth (cm)` = depths + crest,
    `Crest depth (cm)` = crest,
    `Residual pool depth (cm)` = depths,
    `QA Notes` = NA_character_,
    check.names = FALSE, stringsAsFactors = FALSE)
}

# ---------------------------------------------------------------------------
# 9. Raw sheet: Count/Mean/StdDev/CI derived per Site x Date
# ---------------------------------------------------------------------------
test_that("raw sheet derives count, mean, sd and t-based CI per Site x Date", {
  a <- c(30, 37, 25, 21, 24)
  b <- c(44, 51, 39)
  df <- rbind(rpd_raw_rows("EM3", "2024-08-22", a),
              rpd_raw_rows("EM7", "2024-11-06", b))
  result <- process_rpd_domain(rpd_raw_xlsx(df))

  expect_true(result$ok())
  rpd <- result$data$RPD
  expect_equal(names(rpd), RPD_COLUMNS)
  expect_equal(nrow(rpd), 2L)
  expect_equal(rpd$Site, c("EM3", "EM7"))
  expect_equal(rpd$Count, c(length(a), length(b)))
  expect_equal(rpd$Mean, c(mean(a), mean(b)))
  expect_equal(rpd$StdDev, c(sd(a), sd(b)))

  half <- function(v) {
    qt(0.975, df = length(v) - 1L) * sd(v) / sqrt(length(v))
  }
  expect_equal(rpd$CI_Lower, c(mean(a) - half(a), mean(b) - half(b)))
  expect_equal(rpd$CI_Upper, c(mean(a) + half(a), mean(b) + half(b)))
})

# ---------------------------------------------------------------------------
# 9b. The CI is t-based, NOT the z (1.96) approximation the "RPD Summary" tab
#     stores. On the small pool counts these surveys produce the difference is
#     large, so this pins the convention rather than just the formula.
# ---------------------------------------------------------------------------
test_that("CI uses the t distribution, not a 1.96 z multiplier", {
  d <- c(46, 50, 18)
  result <- process_rpd_domain(rpd_raw_xlsx(rpd_raw_rows("EM8", "2024-11-04", d)))

  rpd <- result$data$RPD
  t_half <- qt(0.975, df = length(d) - 1L) * sd(d) / sqrt(length(d))
  z_half <- 1.96 * sd(d) / sqrt(length(d))

  expect_equal(rpd$CI_Upper - rpd$Mean, t_half)
  # t(0.975, 2) = 4.303, so the t interval is well over twice the z interval.
  expect_gt(t_half, z_half * 2)
  expect_false(isTRUE(all.equal(rpd$CI_Upper - rpd$Mean, z_half)))
})

# ---------------------------------------------------------------------------
# 10. Count is an integer count of measurements, not a coerced source value
# ---------------------------------------------------------------------------
test_that("raw Count is the number of usable measurements", {
  df <- rpd_raw_rows("EM3", "2024-08-22", seq_len(100))
  result <- process_rpd_domain(rpd_raw_xlsx(df))

  expect_true(result$ok())
  expect_equal(result$data$RPD$Count, 100L)
  expect_true(is.integer(result$data$RPD$Count))
})

# ---------------------------------------------------------------------------
# 11. Two surveys for one site in one year produce two rows (Site x Date)
# ---------------------------------------------------------------------------
test_that("raw sheet groups by Site x Date", {
  df <- rbind(
    rpd_raw_rows("EM3", "2024-08-22", c(30, 37, 25), season = "N/A"),
    rpd_raw_rows("EM3", "2024-11-06", c(18, 24, 31), season = "Spring"))
  result <- process_rpd_domain(rpd_raw_xlsx(df))

  expect_true(result$ok())
  rpd <- result$data$RPD
  expect_equal(nrow(rpd), 2L)
  expect_equal(rpd$Date, as.Date(c("2024-08-22", "2024-11-06")))
})

# ---------------------------------------------------------------------------
# 12. The raw sheet wins when both it and "RPD Summary" are present
# ---------------------------------------------------------------------------
test_that("raw sheet takes precedence over RPD Summary", {
  depths <- c(30, 37, 25, 21, 24)
  summary_df <- data.frame(
    Site = "EM3", Date = as.Date("2024-08-22"), Count = 999L,
    `Mean (cm)` = 999, `Std Dev` = 999, `CI Lower` = 999, `CI Upper` = 999,
    check.names = FALSE, stringsAsFactors = FALSE)
  path <- rpd_raw_xlsx(rpd_raw_rows("EM3", "2024-08-22", depths),
                       extra_sheets = list(`RPD Summary` = summary_df))

  result <- process_rpd_domain(path)

  expect_true(result$ok())
  expect_equal(result$data$RPD$Mean, mean(depths))
  expect_equal(result$data$RPD$Count, length(depths))
})

# ---------------------------------------------------------------------------
# 13. Header row is found even when title rows sit above it
# ---------------------------------------------------------------------------
test_that("raw sheet header is located below title rows", {
  df <- rpd_raw_rows("EM3", "2024-08-22", c(30, 37, 25))
  result <- process_rpd_domain(rpd_raw_xlsx(df, title_rows = 6L))

  expect_true(result$ok())
  expect_equal(nrow(result$data$RPD), 1L)
  expect_equal(result$data$RPD$Site, "EM3")
})

# ---------------------------------------------------------------------------
# 14. Day-first text dates parse day-first, not as year 0022
# ---------------------------------------------------------------------------
test_that("day-first text dates in the raw sheet parse correctly", {
  df <- rpd_raw_rows("EM3", "2024-08-22", c(30, 37, 25))
  df$Date <- "22/08/2024"   # written as text, not an Excel date
  result <- process_rpd_domain(rpd_raw_xlsx(df))

  expect_true(result$ok())
  expect_equal(result$data$RPD$Date, as.Date("2024-08-22"))
})

# ---------------------------------------------------------------------------
# 15. A single measurement has no sample sd -> StdDev and CI are NA
# ---------------------------------------------------------------------------
test_that("survey with one measurement yields NA sd and CI", {
  result <- process_rpd_domain(rpd_raw_xlsx(
    rpd_raw_rows("EM3", "2024-08-22", 30)))

  expect_true(result$ok())
  rpd <- result$data$RPD
  expect_equal(rpd$Count, 1L)
  expect_equal(rpd$Mean, 30)
  expect_true(is.na(rpd$StdDev))
  expect_true(is.na(rpd$CI_Lower))
  expect_true(is.na(rpd$CI_Upper))
})

# ---------------------------------------------------------------------------
# 16. Unusable rows are dropped with a warning; the survey still reports
# ---------------------------------------------------------------------------
test_that("rows with blank Site or non-numeric depth warn but do not fail", {
  depth_col <- "Residual pool depth (cm)"
  df <- rpd_raw_rows("EM3", "2024-08-22", c(30, 37, 25, 21, 24))
  df[[depth_col]] <- as.character(df[[depth_col]])
  df[[depth_col]][2] <- "not a depth"
  df$Site[3] <- NA_character_
  result <- process_rpd_domain(rpd_raw_xlsx(df))

  expect_true(result$ok())            # warnings do not block the pipeline
  expect_equal(length(result$errors), 1L)
  expect_equal(result$errors[[1]]$severity, "warning")
  expect_match(result$errors[[1]]$message, "Dropped 2 row")

  kept <- c(30, 21, 24)
  expect_equal(result$data$RPD$Count, length(kept))
  expect_equal(result$data$RPD$Mean, mean(kept))
})

# ---------------------------------------------------------------------------
# 17. Residual depth is reconstructed from maximum - crest when the sheet's own
#     residual column is absent (that is how the sheet derives it).
# ---------------------------------------------------------------------------
test_that("residual depth falls back to maximum minus crest depth", {
  depths <- c(46, 50, 18)
  df <- rpd_raw_rows("EM8", "2024-11-04", depths, crest = 37)
  df[["Residual pool depth (cm)"]] <- NULL
  result <- process_rpd_domain(rpd_raw_xlsx(df))

  expect_true(result$ok())
  expect_equal(result$data$RPD$Mean, mean(depths))
  expect_equal(result$data$RPD$StdDev, sd(depths))
})

# ---------------------------------------------------------------------------
# 18. No resolvable depth column at all → error naming the residual column
# ---------------------------------------------------------------------------
test_that("raw sheet with no depth columns returns an error result", {
  df <- rpd_raw_rows("EM3", "2024-08-22", c(30, 37))
  for (col in c("Residual pool depth (cm)", "Maximum pool depth (cm)",
                "Crest depth (cm)")) {
    df[[col]] <- NULL
  }
  result <- process_rpd_domain(rpd_raw_xlsx(df))

  expect_false(result$ok())
  expect_null(result$data)
  err <- result$errors[[1]]
  expect_equal(err$domain, "RPD")
  expect_equal(err$sheet, RPD_RAW_SHEET)
  expect_match(err$message, "Residual pool depth")
})

# ---------------------------------------------------------------------------
# 19. Depth column names are matched by prefix, so a reworded unit suffix (or
#     none at all) still resolves.
# ---------------------------------------------------------------------------
test_that("residual depth column is matched by prefix, not exact name", {
  depths <- c(46, 50, 18)
  df <- rpd_raw_rows("EM8", "2024-11-04", depths)
  names(df)[names(df) == "Residual pool depth (cm)"] <- "Residual pool depth"
  result <- process_rpd_domain(rpd_raw_xlsx(df))

  expect_true(result$ok())
  expect_equal(result$data$RPD$Mean, mean(depths))
})

# ---------------------------------------------------------------------------
# 20. The "RPD Summary" tab is NOT required: a workbook carrying only the raw
#     sheet runs, since the source database is expected to drop it eventually.
# ---------------------------------------------------------------------------
test_that("workbook without any RPD Summary tab still produces RPD data", {
  depths <- c(46, 50, 18)
  path <- rpd_raw_xlsx(rpd_raw_rows("EM8", "2024-11-04", depths))
  expect_false("RPD Summary" %in% readxl::excel_sheets(path))

  result <- process_rpd_domain(path)

  expect_true(result$ok())
  expect_equal(nrow(result$data$RPD), 1L)
  expect_equal(result$data$RPD$Count, length(depths))
})

# ---------------------------------------------------------------------------
# 21. Neither sheet present → the error names both, not just the fallback
# ---------------------------------------------------------------------------
test_that("error names both the raw and fallback sheets when neither exists", {
  tmp <- tempfile(fileext = ".xlsx")
  openxlsx::write.xlsx(list("WrongSheet" = data.frame(x = 1)), tmp)

  result <- process_rpd_domain(tmp)

  expect_false(result$ok())
  err <- result$errors[[1]]
  expect_match(err$message, "Residual pool depths")
  expect_match(err$message, "RPD Summary")
})

# ---------------------------------------------------------------------------
# 18. Appendix B1 Table 4 is unaffected: rpd_summary.R consumes only
#     Count/Mean/StdDev, so a raw-derived RPD sheet feeds it identically.
# ---------------------------------------------------------------------------
test_that("raw-derived Count/Mean/StdDev match the summary tab's own values", {
  depths <- c(30, 37, 25, 21, 24)
  raw <- process_rpd_domain(rpd_raw_xlsx(
    rpd_raw_rows("EM3", "2024-08-22", depths)))$data$RPD
  # The same survey as the summary tab records it -- including its z-based CI.
  z_half <- 1.96 * sd(depths) / sqrt(length(depths))
  summary_equiv <- process_rpd_domain(rpd_xlsx(data.frame(
    Site = "EM3", Date = as.Date("2024-08-22"), Count = length(depths),
    `Mean (cm)` = mean(depths), `Std Dev` = sd(depths),
    `CI Lower` = mean(depths) - z_half, `CI Upper` = mean(depths) + z_half,
    check.names = FALSE, stringsAsFactors = FALSE)))$data$RPD

  # The three columns Appendix B1 Table 4 consumes are identical either way.
  expect_equal(raw$Count, summary_equiv$Count)
  expect_equal(raw$Mean, summary_equiv$Mean)
  expect_equal(raw$StdDev, summary_equiv$StdDev)
  # The CI columns are NOT: the fallback passes the sheet's z interval through,
  # while the raw path computes the wider t interval we want.
  expect_gt(raw$CI_Upper, summary_equiv$CI_Upper)
})
