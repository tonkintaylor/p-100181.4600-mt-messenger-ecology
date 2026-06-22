src_data("errors.R"); src_data("schemas.R")
# ldv.R reuses .rpd_parse_date(); both are sourced together at runtime.
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
