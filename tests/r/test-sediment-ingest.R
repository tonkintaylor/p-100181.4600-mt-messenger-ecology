src_data("errors.R"); src_data("domain_types.R"); src_data("domains/sediment_ingest.R")

# ---------------------------------------------------------------------------
# Helper: write a "Sediment" sheet that round-trips through openxlsx/readxl
# faithfully reproducing the source file's quirky column layout.
#
# The real source workbook has a period column whose header is a single space
# (" "). readxl::read_excel(..., .name_repair="minimal") strips whitespace-only
# names to "" (empty string). Likewise "Site " (trailing space) becomes "Site".
# openxlsx also strips leading/trailing whitespace when writing column headers,
# so we write "" and "Site" and they survive the round-trip unchanged.
# ---------------------------------------------------------------------------
sediment_xlsx <- function(df) {
  tmp <- tempfile(fileext = ".xlsx")
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Sediment")
  openxlsx::writeData(wb, "Sediment", x = df, colNames = TRUE)
  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)
  tmp
}

# Minimal valid source data with the column names as readxl returns them:
#   "" for the period column (source: " "), "Site" for the site column (source: "Site ").
minimal_sed_df <- function(period = "Construction",
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
  names(df)[1] <- ""  # empty string — matches what readxl returns for the space-header col
  df
}

# ---------------------------------------------------------------------------
# 1. Constants are exported with correct values
# ---------------------------------------------------------------------------
test_that("SOURCE_SAM1_COL constant is correct", {
  expect_equal(SOURCE_SAM1_COL, "SAM1 %fine cover")
})

test_that("SOURCE_SAM3_COL constant is correct", {
  expect_equal(SOURCE_SAM3_COL, "SAM3 (%Fine Cover)")
})

test_that("GRAIN_SIZE_SOURCE_COLUMNS has 10 entries", {
  expect_length(GRAIN_SIZE_SOURCE_COLUMNS, 10L)
})

test_that("GRAIN_SIZE_SOURCE_COLUMNS first entry is Clay/silt", {
  expect_equal(GRAIN_SIZE_SOURCE_COLUMNS[[1]], "Clay/silt (<0.06 mm)")
})

test_that("GRAIN_SIZE_SOURCE_COLUMNS last entry is Bedrock", {
  expect_equal(GRAIN_SIZE_SOURCE_COLUMNS[[10]], "Bedrock")
})

# ---------------------------------------------------------------------------
# 2. Quirky header round-trip: empty-named period col and "Site" survive read
# ---------------------------------------------------------------------------
test_that("read_sediment_sheet reads the empty-named period column and 'Site' column", {
  path <- sediment_xlsx(minimal_sed_df())
  df   <- read_sediment_sheet(path)
  # The empty-named column is present (readxl strips the space to "")
  expect_true("" %in% names(df))
  # "Site" column is present
  expect_true("Site" %in% names(df))
})

# ---------------------------------------------------------------------------
# 3. Site is trimmed (trailing whitespace in data values stripped)
# ---------------------------------------------------------------------------
test_that("Site output column has trailing whitespace stripped from data values", {
  df   <- minimal_sed_df(site = "EM4 ")   # extra trailing space in data value
  path <- sediment_xlsx(df)
  out  <- read_sediment_sheet(path)
  expect_equal(out$Site, "EM4")
})

# ---------------------------------------------------------------------------
# 4. Date is coerced to Date class
# ---------------------------------------------------------------------------
test_that("Date column is Date class", {
  path <- sediment_xlsx(minimal_sed_df())
  out  <- read_sediment_sheet(path)
  expect_true(inherits(out$Date, "Date"))
})

# ---------------------------------------------------------------------------
# 5. Period rules
# ---------------------------------------------------------------------------
test_that("default period is Routine Construction", {
  path <- sediment_xlsx(minimal_sed_df(period = "Construction", season = "Spring",
                                       date = as.Date("2023-06-15")))
  out  <- read_sediment_sheet(path)
  expect_equal(out$Period, "Routine Construction")
})

test_that("period_raw == Baseline maps to Baseline", {
  path <- sediment_xlsx(minimal_sed_df(period = "Baseline", season = "Spring",
                                       date = as.Date("2023-06-15")))
  out  <- read_sediment_sheet(path)
  expect_equal(out$Period, "Baseline")
})

test_that("season starting with Additional maps to Incident", {
  path <- sediment_xlsx(minimal_sed_df(period = "Construction",
                                       season = "Additional - Flood",
                                       date = as.Date("2023-06-15")))
  out  <- read_sediment_sheet(path)
  expect_equal(out$Period, "Incident")
})

test_that("BASELINE_END override: date <= BASELINE_END forces Baseline regardless of source label", {
  # Even if source says Construction + Additional → Incident, date override wins.
  path <- sediment_xlsx(minimal_sed_df(period = "Construction",
                                       season = "Additional - Flood",
                                       date = as.Date("2022-03-31")))
  out  <- read_sediment_sheet(path)
  expect_equal(out$Period, "Baseline")
})

test_that("date just after BASELINE_END does NOT trigger Baseline override", {
  path <- sediment_xlsx(minimal_sed_df(period = "Construction",
                                       season = "Spring",
                                       date = as.Date("2022-04-01")))
  out  <- read_sediment_sheet(path)
  expect_equal(out$Period, "Routine Construction")
})

# ---------------------------------------------------------------------------
# 6. Season rules
# ---------------------------------------------------------------------------
test_that("default season is Spring", {
  path <- sediment_xlsx(minimal_sed_df(season = "Spring"))
  out  <- read_sediment_sheet(path)
  expect_equal(out$Season, "Spring")
})

test_that("season containing Summer maps to Summer", {
  path <- sediment_xlsx(minimal_sed_df(season = "Summer 2024"))
  out  <- read_sediment_sheet(path)
  expect_equal(out$Season, "Summer")
})

test_that("season Additional - Summer maps to Summer and Incident period", {
  # Period → Incident (Additional prefix), Season → Summer (Summer substring)
  path <- sediment_xlsx(minimal_sed_df(season = "Additional - Summer",
                                       date = as.Date("2023-06-15")))
  out  <- read_sediment_sheet(path)
  expect_equal(out$Season, "Summer")
  expect_equal(out$Period, "Incident")
})

# ---------------------------------------------------------------------------
# 7. Multi-row fixture: all period / season combos in one sheet
# ---------------------------------------------------------------------------
test_that("multi-row fixture produces correct Period and Season per row", {
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

  path <- sediment_xlsx(df)
  out  <- read_sediment_sheet(path)

  # Row 1: Construction + Spring + date after BASELINE_END → Routine Construction / Spring
  # Row 2: Baseline + Spring + date before BASELINE_END → Baseline (both rules agree) / Spring
  # Row 3: Construction + Additional → Incident; date after BASELINE_END → Incident / Spring
  # Row 4: Construction + Spring + Summer in season + date after BASELINE_END → RC / Summer
  expect_equal(out$Period, c("Routine Construction", "Baseline", "Incident", "Routine Construction"))
  expect_equal(out$Season, c("Spring", "Spring", "Spring", "Summer"))
})

# ---------------------------------------------------------------------------
# 8. Missing sheet → stop() raised
# ---------------------------------------------------------------------------
test_that("missing Sediment sheet raises an error via stop()", {
  tmp <- tempfile(fileext = ".xlsx")
  openxlsx::write.xlsx(list("WrongSheet" = data.frame(x = 1)), tmp)
  expect_error(read_sediment_sheet(tmp), regexp = "Sediment")
})

# ---------------------------------------------------------------------------
# 9. Missing required columns → stop() raised
# ---------------------------------------------------------------------------
test_that("missing required columns raises an error via stop()", {
  df <- data.frame(BadCol = 1:3, stringsAsFactors = FALSE)
  tmp <- tempfile(fileext = ".xlsx")
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Sediment")
  openxlsx::writeData(wb, "Sediment", x = df)
  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)
  expect_error(read_sediment_sheet(tmp), regexp = "Missing required columns")
})

test_that("absent empty-named period column raises an error", {
  # Build a fixture that has all required columns EXCEPT the empty-named period col
  df <- data.frame(
    Site       = "EM4",
    Date       = as.Date("2023-06-15"),
    Season     = "Spring",
    SAM1_grain = 10.5,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  path <- sediment_xlsx(df)
  expect_error(read_sediment_sheet(path), "Missing required columns")
})

# ---------------------------------------------------------------------------
# 10. sediment_make_error returns a DomainResult with the correct error
# ---------------------------------------------------------------------------
test_that("sediment_make_error returns DomainResult with correct ValidationError", {
  result <- sediment_make_error("Sediment", "/some/path.xlsx", "test message")
  expect_false(result$ok())
  expect_null(result$data)
  expect_length(result$errors, 1L)
  err <- result$errors[[1]]
  expect_equal(err$domain, "Sediment")
  expect_equal(err$severity, "error")
  expect_equal(err$sheet, "Sediment")
  expect_equal(err$location, "sheet")
  expect_equal(err$message, "test message")
  expect_equal(err$file, "/some/path.xlsx")
})

test_that("sediment_make_error works for SedimentSize domain", {
  result <- sediment_make_error("SedimentSize", "/other/path.xlsx", "bad cols")
  err <- result$errors[[1]]
  expect_equal(err$domain, "SedimentSize")
})
