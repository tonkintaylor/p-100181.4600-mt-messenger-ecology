src_data("errors.R"); src_data("schemas.R"); src_data("domains/clarity.R")

# ---------------------------------------------------------------------------
# Helper: write a "Clarity Data" sheet to a temp xlsx and return the path.
# ---------------------------------------------------------------------------
clarity_xlsx <- function(df) {
  tmp <- tempfile(fileext = ".xlsx")
  openxlsx::write.xlsx(list("Clarity Data" = df), tmp)
  tmp
}

# Minimal valid source data (all optional cols absent).
minimal_df <- function() {
  data.frame(
    Site             = c("EM4", "CM2"),
    Date             = as.Date(c("2026-04-23", "2026-04-23")),
    `Clarity (mm)`   = c(1200, 990),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
}

# ---------------------------------------------------------------------------
# 1. Happy path — 10 columns, correct names
# ---------------------------------------------------------------------------
test_that("happy path produces DomainResult with 10-column Clarity data frame", {
  path   <- clarity_xlsx(minimal_df())
  result <- process_clarity_domain(path)

  expect_true(result$ok())
  expect_false(is.null(result$data))
  clarity <- result$data$Clarity
  expect_equal(ncol(clarity), 10L)
  expect_equal(names(clarity), CLARITY_COLUMNS)
})

# ---------------------------------------------------------------------------
# 2. Typo rename: "NTU-Continous Sensor" → "NTU-Continuous Sensor"
# ---------------------------------------------------------------------------
test_that("source typo NTU-Continous Sensor is renamed to NTU-Continuous Sensor", {
  df <- data.frame(
    Site                 = c("EM4"),
    Date                 = as.Date("2026-04-23"),
    `Clarity (mm)`       = c(1200),
    `NTU-Continous Sensor` = c(5.54),  # <-- typo column name
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  path   <- clarity_xlsx(df)
  result <- process_clarity_domain(path)

  expect_true(result$ok())
  clarity <- result$data$Clarity
  expect_true("NTU-Continuous Sensor" %in% names(clarity))
  expect_false("NTU-Continous Sensor" %in% names(clarity))
})

# ---------------------------------------------------------------------------
# 3. Missing required column → error result
# ---------------------------------------------------------------------------
test_that("missing required column Clarity (mm) returns an error result", {
  df <- data.frame(
    Site = c("EM4"),
    Date = as.Date("2026-04-23"),
    stringsAsFactors = FALSE
  )
  path   <- clarity_xlsx(df)
  result <- process_clarity_domain(path)

  expect_false(result$ok())
  expect_null(result$data)
  expect_equal(length(result$errors), 1L)
  err <- result$errors[[1]]
  expect_equal(err$domain, "Clarity")
  expect_equal(err$severity, "error")
  expect_match(err$message, "Missing required columns")
})

# ---------------------------------------------------------------------------
# 4. Missing optional columns are filled with NA of the correct type
# ---------------------------------------------------------------------------
test_that("missing optional columns are filled with NA (numeric or character)", {
  path   <- clarity_xlsx(minimal_df())
  result <- process_clarity_domain(path)

  expect_true(result$ok())
  clarity <- result$data$Clarity

  # All optional numeric cols should be NA_real_
  optional_numeric <- setdiff(
    CLARITY_COLUMNS,
    c("Site", "Date", "Clarity (mm)", "Comments")
  )
  for (col in optional_numeric) {
    expect_true(all(is.na(clarity[[col]])),
                label = paste("expected all NA in", col))
    expect_true(is.numeric(clarity[[col]]),
                label = paste("expected numeric NA in", col))
  }

  # Comments should be NA_character_
  expect_true(all(is.na(clarity[["Comments"]])))
  expect_true(is.character(clarity[["Comments"]]))
})

# ---------------------------------------------------------------------------
# 5a. Non-breaking-space stripping in numeric column (mirrors TestClarityNonBreakingSpace)
# ---------------------------------------------------------------------------
test_that("non-breaking spaces in Clarity (mm) are stripped before numeric coercion", {
  # Build "Clarity (mm)" values with trailing U+00A0 (non-breaking space)
  nbsp <- " "
  df <- data.frame(
    Site             = c("EM4", "CM2", "CM4"),
    Date             = as.Date(c("2026-04-23", "2026-04-23", "2026-04-22")),
    `Clarity (mm)`   = c(paste0("1200", nbsp), paste0("990", nbsp), paste0("930", nbsp)),
    `NTU-Continuous Sensor` = c(5.54, 9.87, 9.59),
    `NTU-Lab`        = c(3.90, 7.80, 15.00),
    `NTU-Fieldmeter` = c(2.8, 3.9, 7.0),
    `pH-Fieldmeter`  = c(8.27, 8.16, 8.44),
    `pH-Lab`         = c(7.6, 7.6, 7.6),
    `TSS-Lab`        = c(3.0, 7.0, 12.0),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  path   <- clarity_xlsx(df)
  result <- process_clarity_domain(path)

  expect_true(result$ok())
  clarity <- result$data$Clarity
  expect_equal(clarity[["Clarity (mm)"]], c(1200.0, 990.0, 930.0))
})

# ---------------------------------------------------------------------------
# 5b. Normal numeric values are not affected by the nbsp strip
# ---------------------------------------------------------------------------
test_that("normal numeric Clarity (mm) values are unaffected by nbsp stripping", {
  df <- data.frame(
    Site           = c("EM1", "EM2"),
    Date           = as.Date(c("2025-01-21", "2025-01-22")),
    `Clarity (mm)` = c(850, 720.5),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  path   <- clarity_xlsx(df)
  result <- process_clarity_domain(path)

  expect_true(result$ok())
  clarity <- result$data$Clarity
  expect_equal(clarity[["Clarity (mm)"]], c(850.0, 720.5))
})

# ---------------------------------------------------------------------------
# 6. Sheet not found → error result
# ---------------------------------------------------------------------------
test_that("excel file with no Clarity Data sheet returns an error result", {
  tmp <- tempfile(fileext = ".xlsx")
  openxlsx::write.xlsx(list("WrongSheet" = data.frame(x = 1)), tmp)

  result <- process_clarity_domain(tmp)

  expect_false(result$ok())
  expect_null(result$data)
  expect_equal(length(result$errors), 1L)
  err <- result$errors[[1]]
  expect_equal(err$domain, "Clarity")
  expect_equal(err$severity, "error")
  expect_match(err$message, "Clarity Data")
})

# ---------------------------------------------------------------------------
# 7. Site column is character; Date column is Date
# ---------------------------------------------------------------------------
test_that("Site is character and Date is Date class in output", {
  path   <- clarity_xlsx(minimal_df())
  result <- process_clarity_domain(path)

  expect_true(result$ok())
  clarity <- result$data$Clarity
  expect_true(is.character(clarity$Site))
  expect_true(inherits(clarity$Date, "Date"))
})
