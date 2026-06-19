src_data("errors.R"); src_data("schemas.R"); src_data("domains/rpd.R")

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
# 3. Count coercion via round(as.numeric(...)) then as.integer
# ---------------------------------------------------------------------------
test_that("Count is coerced to integer via round", {
  df <- minimal_rpd_df()
  df$Count <- c(4.7, 3.2)  # non-integer numerics
  path   <- rpd_xlsx(df)
  result <- process_rpd_domain(path)

  expect_true(result$ok())
  rpd <- result$data$RPD
  expect_true(is.integer(rpd$Count))
  expect_equal(rpd$Count, c(5L, 3L))
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
