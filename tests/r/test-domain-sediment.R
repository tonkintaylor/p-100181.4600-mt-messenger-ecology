src_data("errors.R"); src_data("domain_types.R"); src_data("schemas.R"); src_data("domains/sediment_ingest.R"); src_data("domains/sediment.R")

# ---------------------------------------------------------------------------
# Fixture helpers — reproduce readxl's quirky column-name behaviour:
#   source period header " " → readxl strips to "" (empty string)
#   source site header "Site " → readxl strips to "Site"
# openxlsx also strips whitespace when writing, so writing "" and "Site"
# round-trips correctly through the write → read path.
# ---------------------------------------------------------------------------
sediment_domain_xlsx <- function(df) {
  tmp <- tempfile(fileext = ".xlsx")
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Sediment")
  openxlsx::writeData(wb, "Sediment", x = df, colNames = TRUE)
  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)
  tmp
}

# Build a minimal valid source data frame with SAM columns present.
# First column name is "" (empty string) — the period column.
# "Site" column is the site column.
minimal_sed_domain_df <- function(period = "Construction",
                                  site   = "EM4",
                                  date   = as.Date("2023-06-15"),
                                  season = "Spring",
                                  sam1   = 12.5,
                                  sam3   = 8.3) {
  df <- data.frame(
    period_val = period,
    Site       = site,
    Date       = date,
    Season     = season,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  names(df)[1] <- ""   # empty string — what readxl returns for the space-header col
  df[[SOURCE_SAM1_COL]] <- sam1
  df[[SOURCE_SAM3_COL]] <- sam3
  df
}

# ---------------------------------------------------------------------------
# Integration tests: happy path
# ---------------------------------------------------------------------------
test_that("happy path: returns DomainResult with ok() == TRUE", {
  path   <- sediment_domain_xlsx(minimal_sed_domain_df())
  result <- process_sediment_domain(path)
  expect_true(result$ok())
})

test_that("happy path: data key is 'Sediment'", {
  path   <- sediment_domain_xlsx(minimal_sed_domain_df())
  result <- process_sediment_domain(path)
  expect_true("Sediment" %in% names(result$data))
})

test_that("columns match SEDIMENT_COLUMNS schema", {
  path   <- sediment_domain_xlsx(minimal_sed_domain_df())
  result <- process_sediment_domain(path)
  df     <- result$data$Sediment
  expect_equal(names(df), SEDIMENT_COLUMNS)
})

test_that("column order is exactly SEDIMENT_COLUMNS", {
  path   <- sediment_domain_xlsx(minimal_sed_domain_df())
  result <- process_sediment_domain(path)
  df     <- result$data$Sediment
  expect_equal(names(df), c("Site", "Date", "Period", "SAM1", "SAM3", "Season"))
})

test_that("Site is character class", {
  path   <- sediment_domain_xlsx(minimal_sed_domain_df())
  result <- process_sediment_domain(path)
  df     <- result$data$Sediment
  expect_true(is.character(df$Site))
})

test_that("Date is Date class", {
  path   <- sediment_domain_xlsx(minimal_sed_domain_df())
  result <- process_sediment_domain(path)
  df     <- result$data$Sediment
  expect_true(inherits(df$Date, "Date"))
})

test_that("SAM1 is numeric", {
  path   <- sediment_domain_xlsx(minimal_sed_domain_df(sam1 = 12.5))
  result <- process_sediment_domain(path)
  df     <- result$data$Sediment
  expect_true(is.numeric(df$SAM1))
})

test_that("SAM3 is numeric", {
  path   <- sediment_domain_xlsx(minimal_sed_domain_df(sam3 = 8.3))
  result <- process_sediment_domain(path)
  df     <- result$data$Sediment
  expect_true(is.numeric(df$SAM3))
})

test_that("SAM1 numeric coerce: string value is converted", {
  df   <- minimal_sed_domain_df()
  df[[SOURCE_SAM1_COL]] <- "15.7"
  path   <- sediment_domain_xlsx(df)
  result <- process_sediment_domain(path)
  out    <- result$data$Sediment
  expect_equal(out$SAM1, 15.7)
})

test_that("SAM3 numeric coerce: non-numeric string becomes NA", {
  df   <- minimal_sed_domain_df()
  df[[SOURCE_SAM3_COL]] <- "n/a"
  path   <- sediment_domain_xlsx(df)
  result <- process_sediment_domain(path)
  out    <- result$data$Sediment
  expect_true(is.na(out$SAM3))
})

test_that("NA SAM1 is preserved (not dropped)", {
  df   <- minimal_sed_domain_df()
  df[[SOURCE_SAM1_COL]] <- NA_real_
  path   <- sediment_domain_xlsx(df)
  result <- process_sediment_domain(path)
  out    <- result$data$Sediment
  expect_true(is.na(out$SAM1))
  expect_equal(nrow(out), 1L)
})

test_that("Period column values are passed through from read_sediment_sheet", {
  path   <- sediment_domain_xlsx(minimal_sed_domain_df(period = "Construction", season = "Spring"))
  result <- process_sediment_domain(path)
  df     <- result$data$Sediment
  expect_equal(df$Period, "Routine Construction")
})

test_that("Baseline period passes through", {
  path   <- sediment_domain_xlsx(minimal_sed_domain_df(period = "Baseline", season = "Spring"))
  result <- process_sediment_domain(path)
  df     <- result$data$Sediment
  expect_equal(df$Period, "Baseline")
})

test_that("Incident period passes through (Additional season)", {
  path   <- sediment_domain_xlsx(
    minimal_sed_domain_df(period = "Construction", season = "Additional - Flood",
                          date = as.Date("2023-06-15"))
  )
  result <- process_sediment_domain(path)
  df     <- result$data$Sediment
  expect_equal(df$Period, "Incident")
})

test_that("Season column values are passed through from read_sediment_sheet", {
  path   <- sediment_domain_xlsx(minimal_sed_domain_df(season = "Spring"))
  result <- process_sediment_domain(path)
  df     <- result$data$Sediment
  expect_equal(df$Season, "Spring")
})

test_that("Summer season passes through", {
  path   <- sediment_domain_xlsx(minimal_sed_domain_df(season = "Summer 2024"))
  result <- process_sediment_domain(path)
  df     <- result$data$Sediment
  expect_equal(df$Season, "Summer")
})

test_that("Site values are stripped of whitespace", {
  path   <- sediment_domain_xlsx(minimal_sed_domain_df(site = "EM4 "))
  result <- process_sediment_domain(path)
  df     <- result$data$Sediment
  expect_equal(df$Site, "EM4")
})

test_that("rownames are reset to NULL (no row labels)", {
  rows <- data.frame(
    period_val = c("Construction", "Baseline"),
    Site       = c("EM4", "EM5"),
    Date       = c(as.Date("2023-06-15"), as.Date("2022-01-01")),
    Season     = c("Spring", "Spring"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  names(rows)[1] <- ""
  rows[[SOURCE_SAM1_COL]] <- c(10.0, 20.0)
  rows[[SOURCE_SAM3_COL]] <- c(5.0, 6.0)
  path   <- sediment_domain_xlsx(rows)
  result <- process_sediment_domain(path)
  df     <- result$data$Sediment
  expect_equal(rownames(df), as.character(seq_len(nrow(df))))
})

# ---------------------------------------------------------------------------
# Multi-row: period and season combos
# ---------------------------------------------------------------------------
test_that("multi-row fixture: correct Period and Season per row", {
  df <- data.frame(
    period_val = c("Construction", "Baseline",    "Construction",       "Construction"),
    Site       = c("EM4",          "EM5",         "EM7",                "EM8"),
    Date       = c(as.Date("2023-06-15"), as.Date("2022-01-10"),
                   as.Date("2023-10-01"), as.Date("2023-11-01")),
    Season     = c("Spring",       "Spring",      "Additional - Flood", "Summer 2023"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  names(df)[1] <- ""
  df[[SOURCE_SAM1_COL]] <- c(10.0, 11.0, 12.0, 13.0)
  df[[SOURCE_SAM3_COL]] <- c(5.0,  6.0,  7.0,  8.0)

  path   <- sediment_domain_xlsx(df)
  result <- process_sediment_domain(path)
  out    <- result$data$Sediment

  expect_equal(out$Period, c("Routine Construction", "Baseline", "Incident", "Routine Construction"))
  expect_equal(out$Season, c("Spring", "Spring", "Spring", "Summer"))
})

# ---------------------------------------------------------------------------
# Error paths — mirrors TestProcessSedimentDomainErrors from Python
# ---------------------------------------------------------------------------
test_that("missing file returns error result (not ok)", {
  result <- process_sediment_domain(file.path(tempdir(), "nonexistent_99999.xlsx"))
  expect_false(result$ok())
  expect_null(result$data)
})

test_that("missing file error has correct structure", {
  result <- process_sediment_domain(file.path(tempdir(), "nonexistent_99999.xlsx"))
  expect_length(result$errors, 1L)
  err <- result$errors[[1]]
  expect_equal(err$domain, "Sediment")
  expect_equal(err$severity, "error")
})

test_that("file exists but no Sediment sheet returns error result", {
  tmp <- tempfile(fileext = ".xlsx")
  openxlsx::write.xlsx(list("WrongSheet" = data.frame(x = 1)), tmp)
  result <- process_sediment_domain(tmp)
  expect_false(result$ok())
  expect_null(result$data)
})

test_that("missing Sediment sheet error has correct structure", {
  tmp <- tempfile(fileext = ".xlsx")
  openxlsx::write.xlsx(list("WrongSheet" = data.frame(x = 1)), tmp)
  result <- process_sediment_domain(tmp)
  expect_length(result$errors, 1L)
  err <- result$errors[[1]]
  expect_equal(err$domain, "Sediment")
  expect_equal(err$severity, "error")
})

test_that("Sediment sheet with missing required base columns returns error result", {
  df <- data.frame(BadCol = 1:3, stringsAsFactors = FALSE)
  tmp <- tempfile(fileext = ".xlsx")
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Sediment")
  openxlsx::writeData(wb, "Sediment", x = df)
  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)
  result <- process_sediment_domain(tmp)
  expect_false(result$ok())
  expect_null(result$data)
})

test_that("sheet has base columns but no SAM score columns returns error result", {
  # Build a fixture with base columns but no SAM columns.
  # Period col header is "" (empty string), Site is "Site".
  df <- data.frame(
    period_val = "Baseline",
    Site       = "EM1",
    Date       = as.Date("2020-01-01"),
    Season     = "Spring",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  names(df)[1] <- ""
  path   <- sediment_domain_xlsx(df)
  result <- process_sediment_domain(path)
  expect_false(result$ok())
  expect_null(result$data)
})

test_that("missing SAM1 column produces error mentioning the column name", {
  # Sheet has SAM3 but not SAM1.
  df <- data.frame(
    period_val = "Baseline",
    Site       = "EM1",
    Date       = as.Date("2020-01-01"),
    Season     = "Spring",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  names(df)[1] <- ""
  df[[SOURCE_SAM3_COL]] <- 8.0
  path   <- sediment_domain_xlsx(df)
  result <- process_sediment_domain(path)
  expect_false(result$ok())
  err <- result$errors[[1]]
  expect_match(err$message, SOURCE_SAM1_COL, fixed = TRUE)
})

test_that("missing SAM3 column produces error mentioning the column name", {
  # Sheet has SAM1 but not SAM3.
  df <- data.frame(
    period_val = "Baseline",
    Site       = "EM1",
    Date       = as.Date("2020-01-01"),
    Season     = "Spring",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  names(df)[1] <- ""
  df[[SOURCE_SAM1_COL]] <- 12.0
  path   <- sediment_domain_xlsx(df)
  result <- process_sediment_domain(path)
  expect_false(result$ok())
  err <- result$errors[[1]]
  expect_match(err$message, SOURCE_SAM3_COL, fixed = TRUE)
})

test_that("error result has correct ValidationError domain=Sediment, severity=error", {
  result <- process_sediment_domain(file.path(tempdir(), "nonexistent_xyz.xlsx"))
  err <- result$errors[[1]]
  expect_equal(err$domain, "Sediment")
  expect_equal(err$severity, "error")
  expect_equal(err$sheet, "Sediment")
  expect_equal(err$location, "sheet")
})

