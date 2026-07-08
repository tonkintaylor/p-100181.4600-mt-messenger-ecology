src_data("errors.R")
src_data("domain_types.R")
src_data("schemas.R")
src_data("domains/sediment_ingest.R")
src_data("domains/sediment.R")
src_data("domains/sediment_size.R")
src_data("domains/sediment_summary.R")

# Build a synthetic "Sediment" source sheet with SAM + grain-size columns.
# The period column header is "" (what readxl returns for the space-header col).
sediment_source_xlsx <- function() {
  df <- data.frame(
    period_val = c("Construction", "Baseline"),
    Site       = c("EM_A", "EM_B"),
    Date       = as.Date(c("2023-06-15", "2022-01-10")),
    Season     = c("Spring", "Summer 2022"),
    stringsAsFactors = FALSE, check.names = FALSE)
  names(df)[1] <- ""
  df[[SOURCE_SAM1_COL]] <- c(12.5, 20)
  df[[SOURCE_SAM3_COL]] <- c(8.3, 15)
  # Distinct grain-size values per row to check join alignment.
  for (i in seq_along(GRAIN_SIZE_SOURCE_COLUMNS)) {
    df[[GRAIN_SIZE_SOURCE_COLUMNS[i]]] <- c(i, i + 10)
  }
  tmp <- tempfile(fileext = ".xlsx")
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Sediment")
  openxlsx::writeData(wb, "Sediment", x = df, colNames = TRUE)
  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)
  tmp
}

# Value for one (site, Variable) in the long-format sheet.
val <- function(df, site, variable) {
  df$Value[df$Site == site & df$Variable == variable]
}

test_that("returns a DomainResult with SedimentSummary + schema columns", {
  result <- process_sediment_summary_domain(sediment_source_xlsx())
  expect_s3_class(result, "DomainResult")
  expect_true(result$ok())
  expect_equal(names(result$data$SedimentSummary), SEDIMENT_SUMMARY_COLUMNS)
  # Long format: 2 sites x (SAM1 + SAM3 fine cover + 10 fractions) = 24 rows.
  expect_equal(nrow(result$data$SedimentSummary), 24L)
})

test_that("pivots SAM (Sediment) and fractions (SedimentSize) to long rows", {
  df <- process_sediment_summary_domain(sediment_source_xlsx())$data$SedimentSummary

  # SAM values come from the Sediment sheet, tagged with the right Protocol.
  expect_equal(val(df, "EM_A", "Average sediment cover (%)"), 12.5)
  expect_equal(val(df, "EM_A", "Fine sediment cover (<2 mm)"), 8.3)
  expect_equal(val(df, "EM_B", "Average sediment cover (%)"), 20)
  # Fractions come from SedimentSize (row A = i, row B = i+10).
  expect_equal(val(df, "EM_A", "Clay/silt (<0.06 mm)"), 1)
  expect_equal(val(df, "EM_A", "Bedrock"), 10)
  expect_equal(val(df, "EM_B", "Clay/silt (<0.06 mm)"), 11)
  expect_equal(val(df, "EM_B", "Bedrock"), 20)
})

test_that("Protocol tags SAM1 for cover and SAM3 for fine cover + fractions", {
  df <- process_sediment_summary_domain(sediment_source_xlsx())$data$SedimentSummary
  a <- df[df$Site == "EM_A", ]
  expect_equal(a$Protocol[a$Variable == "Average sediment cover (%)"], "SAM1")
  expect_equal(a$Protocol[a$Variable == "Fine sediment cover (<2 mm)"], "SAM3")
  expect_equal(a$Protocol[a$Variable == "Clay/silt (<0.06 mm)"], "SAM3")
  expect_equal(a$Protocol[a$Variable == "Bedrock"], "SAM3")
  # Exactly one SAM1 row per site; the other 11 are SAM3.
  expect_equal(sum(a$Protocol == "SAM1"), 1L)
  expect_equal(sum(a$Protocol == "SAM3"), 11L)

  # Period/Season pass through the ingest normalisation (same on every row).
  expect_true(all(a$Period == "Routine Construction"))
  expect_true(all(a$Season == "Spring"))
  b <- df[df$Site == "EM_B", ]
  expect_true(all(b$Period == "Baseline"))
  expect_true(all(b$Season == "Summer"))
})

test_that("missing 'Sediment' sheet returns an error result", {
  tmp <- tempfile(fileext = ".xlsx")
  openxlsx::write.xlsx(list("Other" = data.frame(x = 1)), tmp)
  result <- process_sediment_summary_domain(tmp)
  expect_false(result$ok())
  expect_null(result$data)
  expect_equal(result$errors[[length(result$errors)]]$domain, "SedimentSummary")
})
