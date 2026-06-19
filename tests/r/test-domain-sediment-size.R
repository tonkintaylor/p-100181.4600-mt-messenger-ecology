src_data("errors.R"); src_data("domain_types.R"); src_data("schemas.R"); src_data("domains/sediment_ingest.R"); src_data("domains/sediment_size.R")

# ---------------------------------------------------------------------------
# Fixture helpers — reproduce readxl's quirky column-name behaviour:
#   source period header " " → readxl strips to "" (empty string)
#   source site header "Site " → readxl strips to "Site"
# The grain-size columns keep their literal names.
# ---------------------------------------------------------------------------
sediment_size_xlsx <- function(df) {
  tmp <- tempfile(fileext = ".xlsx")
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Sediment")
  openxlsx::writeData(wb, "Sediment", x = df, colNames = TRUE)
  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)
  tmp
}

# Build a minimal valid source data frame with all 10 grain-size columns.
# First column name is "" (empty string) — the period column.
minimal_sed_size_df <- function(period = "Construction",
                                site   = "EM4",
                                date   = as.Date("2023-06-15"),
                                season = "Spring") {
  df <- data.frame(
    period_val = period,
    Site       = site,
    Date       = date,
    Season     = season,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  names(df)[1] <- ""  # empty string — what readxl returns for the space-header col
  for (col in GRAIN_SIZE_SOURCE_COLUMNS) {
    df[[col]] <- 10.0
  }
  df
}

# ---------------------------------------------------------------------------
# Integration tests: happy path (mirrors TestProcessSedimentSizeDomainIntegration)
# ---------------------------------------------------------------------------
test_that("happy path: returns DomainResult with ok() == TRUE", {
  path   <- sediment_size_xlsx(minimal_sed_size_df())
  result <- process_sediment_size_domain(path)
  expect_true(result$ok())
})

test_that("data key is 'SedimentSize'", {
  path   <- sediment_size_xlsx(minimal_sed_size_df())
  result <- process_sediment_size_domain(path)
  expect_true("SedimentSize" %in% names(result$data))
})

test_that("columns match SEDIMENT_SIZE_COLUMNS schema", {
  path   <- sediment_size_xlsx(minimal_sed_size_df())
  result <- process_sediment_size_domain(path)
  df     <- result$data$SedimentSize
  expect_equal(names(df), SEDIMENT_SIZE_COLUMNS)
})

test_that("column order is exactly SEDIMENT_SIZE_COLUMNS (14 cols)", {
  path   <- sediment_size_xlsx(minimal_sed_size_df())
  result <- process_sediment_size_domain(path)
  df     <- result$data$SedimentSize
  expect_length(names(df), 14L)
  expect_equal(names(df), SEDIMENT_SIZE_COLUMNS)
})

test_that("Site is character class", {
  path   <- sediment_size_xlsx(minimal_sed_size_df())
  result <- process_sediment_size_domain(path)
  df     <- result$data$SedimentSize
  expect_true(is.character(df$Site))
})

test_that("Date is Date class", {
  path   <- sediment_size_xlsx(minimal_sed_size_df())
  result <- process_sediment_size_domain(path)
  df     <- result$data$SedimentSize
  expect_true(inherits(df$Date, "Date"))
})

test_that("all 10 grain-size columns are numeric", {
  path   <- sediment_size_xlsx(minimal_sed_size_df())
  result <- process_sediment_size_domain(path)
  df     <- result$data$SedimentSize
  grain_cols <- SEDIMENT_SIZE_COLUMNS[5:14]
  for (col in grain_cols) {
    expect_true(is.numeric(df[[col]]), info = paste("column:", col))
  }
})

test_that("grain-size string value is coerced to numeric", {
  df_src <- minimal_sed_size_df()
  df_src[["Clay/silt (<0.06 mm)"]] <- "25.5"
  path   <- sediment_size_xlsx(df_src)
  result <- process_sediment_size_domain(path)
  df     <- result$data$SedimentSize
  expect_equal(df[["Clay/silt (<0.06 mm)"]], 25.5)
})

test_that("non-numeric grain-size string becomes NA", {
  df_src <- minimal_sed_size_df()
  df_src[["Bedrock"]] <- "n/a"
  path   <- sediment_size_xlsx(df_src)
  result <- process_sediment_size_domain(path)
  df     <- result$data$SedimentSize
  expect_true(is.na(df$Bedrock))
})

test_that("NA grain-size value is preserved (not dropped)", {
  df_src <- minimal_sed_size_df()
  df_src[["Sand (>0.06-2 mm)"]] <- NA_real_
  path   <- sediment_size_xlsx(df_src)
  result <- process_sediment_size_domain(path)
  df     <- result$data$SedimentSize
  expect_true(is.na(df[["Sand (>0.06-2 mm)"]]))
  expect_equal(nrow(df), 1L)
})

test_that("grain-size values are non-negative", {
  path   <- sediment_size_xlsx(minimal_sed_size_df())
  result <- process_sediment_size_domain(path)
  df     <- result$data$SedimentSize
  grain_cols <- SEDIMENT_SIZE_COLUMNS[5:14]
  for (col in grain_cols) {
    vals <- df[[col]]
    expect_true(all(vals[!is.na(vals)] >= 0), info = paste("column:", col))
  }
})

test_that("Period column passes through from read_sediment_sheet", {
  path   <- sediment_size_xlsx(minimal_sed_size_df(period = "Construction", season = "Spring"))
  result <- process_sediment_size_domain(path)
  df     <- result$data$SedimentSize
  expect_equal(df$Period, "Routine Construction")
})

test_that("Baseline period passes through", {
  path   <- sediment_size_xlsx(minimal_sed_size_df(period = "Baseline", season = "Spring"))
  result <- process_sediment_size_domain(path)
  df     <- result$data$SedimentSize
  expect_equal(df$Period, "Baseline")
})

test_that("Incident period (Additional season) passes through", {
  path   <- sediment_size_xlsx(
    minimal_sed_size_df(period = "Construction", season = "Additional - Flood",
                        date = as.Date("2023-06-15"))
  )
  result <- process_sediment_size_domain(path)
  df     <- result$data$SedimentSize
  expect_equal(df$Period, "Incident")
})

test_that("Season column passes through from read_sediment_sheet", {
  path   <- sediment_size_xlsx(minimal_sed_size_df(season = "Spring"))
  result <- process_sediment_size_domain(path)
  df     <- result$data$SedimentSize
  expect_equal(df$Season, "Spring")
})

test_that("Summer season passes through", {
  path   <- sediment_size_xlsx(minimal_sed_size_df(season = "Summer 2024"))
  result <- process_sediment_size_domain(path)
  df     <- result$data$SedimentSize
  expect_equal(df$Season, "Summer")
})

test_that("Site values are stripped of whitespace", {
  path   <- sediment_size_xlsx(minimal_sed_size_df(site = "EM4 "))
  result <- process_sediment_size_domain(path)
  df     <- result$data$SedimentSize
  expect_equal(df$Site, "EM4")
})

test_that("rownames are reset to NULL", {
  rows <- data.frame(
    period_val = c("Construction", "Baseline"),
    Site       = c("EM4", "EM5"),
    Date       = c(as.Date("2023-06-15"), as.Date("2022-01-01")),
    Season     = c("Spring", "Spring"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  names(rows)[1] <- ""
  for (col in GRAIN_SIZE_SOURCE_COLUMNS) {
    rows[[col]] <- c(10.0, 20.0)
  }
  path   <- sediment_size_xlsx(rows)
  result <- process_sediment_size_domain(path)
  df     <- result$data$SedimentSize
  expect_equal(rownames(df), as.character(seq_len(nrow(df))))
})

test_that("multi-row fixture: correct Period and Season per row", {
  rows <- data.frame(
    period_val = c("Construction", "Baseline",    "Construction",       "Construction"),
    Site       = c("EM4",          "EM5",         "EM7",                "EM8"),
    Date       = c(as.Date("2023-06-15"), as.Date("2022-01-10"),
                   as.Date("2023-10-01"), as.Date("2023-11-01")),
    Season     = c("Spring",       "Spring",      "Additional - Flood", "Summer 2023"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  names(rows)[1] <- ""
  for (col in GRAIN_SIZE_SOURCE_COLUMNS) {
    rows[[col]] <- c(5.0, 6.0, 7.0, 8.0)
  }
  path   <- sediment_size_xlsx(rows)
  result <- process_sediment_size_domain(path)
  df     <- result$data$SedimentSize
  expect_equal(df$Period, c("Routine Construction", "Baseline", "Incident", "Routine Construction"))
  expect_equal(df$Season, c("Spring", "Spring", "Spring", "Summer"))
})

# ---------------------------------------------------------------------------
# Error paths (mirrors TestProcessSedimentSizeDomainErrors)
# ---------------------------------------------------------------------------
test_that("missing file returns error result (not ok)", {
  result <- process_sediment_size_domain(file.path(tempdir(), "nonexistent_size_99999.xlsx"))
  expect_false(result$ok())
  expect_null(result$data)
})

test_that("missing file error has correct structure", {
  result <- process_sediment_size_domain(file.path(tempdir(), "nonexistent_size_99999.xlsx"))
  expect_length(result$errors, 1L)
  err <- result$errors[[1]]
  expect_equal(err$domain, "SedimentSize")
  expect_equal(err$severity, "error")
})

test_that("file exists but no Sediment sheet returns error result", {
  tmp <- tempfile(fileext = ".xlsx")
  openxlsx::write.xlsx(list("WrongSheet" = data.frame(x = 1)), tmp)
  result <- process_sediment_size_domain(tmp)
  expect_false(result$ok())
  expect_null(result$data)
})

test_that("missing Sediment sheet error has correct structure", {
  tmp <- tempfile(fileext = ".xlsx")
  openxlsx::write.xlsx(list("WrongSheet" = data.frame(x = 1)), tmp)
  result <- process_sediment_size_domain(tmp)
  expect_length(result$errors, 1L)
  err <- result$errors[[1]]
  expect_equal(err$domain, "SedimentSize")
  expect_equal(err$severity, "error")
})

test_that("Sediment sheet with missing required base columns returns error result", {
  df <- data.frame(BadCol = 1:3, stringsAsFactors = FALSE)
  tmp <- tempfile(fileext = ".xlsx")
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Sediment")
  openxlsx::writeData(wb, "Sediment", x = df)
  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)
  result <- process_sediment_size_domain(tmp)
  expect_false(result$ok())
  expect_null(result$data)
})

test_that("sheet has base columns but no grain-size columns returns error result", {
  df <- data.frame(
    period_val = "Baseline",
    Site       = "EM1",
    Date       = as.Date("2020-01-01"),
    Season     = "Spring",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  names(df)[1] <- ""
  path   <- sediment_size_xlsx(df)
  result <- process_sediment_size_domain(path)
  expect_false(result$ok())
  expect_null(result$data)
})

test_that("missing grain-size columns error message lists the missing column", {
  # Sheet has base columns + 9 grain cols but not Clay/silt
  df <- data.frame(
    period_val = "Baseline",
    Site       = "EM1",
    Date       = as.Date("2020-01-01"),
    Season     = "Spring",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  names(df)[1] <- ""
  for (col in GRAIN_SIZE_SOURCE_COLUMNS[-1]) {
    df[[col]] <- 5.0
  }
  path   <- sediment_size_xlsx(df)
  result <- process_sediment_size_domain(path)
  expect_false(result$ok())
  err <- result$errors[[1]]
  expect_match(err$message, "Clay/silt (<0.06 mm)", fixed = TRUE)
})

test_that("error result has correct ValidationError domain=SedimentSize, severity=error", {
  result <- process_sediment_size_domain(file.path(tempdir(), "nonexistent_size_xyz.xlsx"))
  err <- result$errors[[1]]
  expect_equal(err$domain, "SedimentSize")
  expect_equal(err$severity, "error")
  expect_equal(err$sheet, "Sediment")
  expect_equal(err$location, "sheet")
})
