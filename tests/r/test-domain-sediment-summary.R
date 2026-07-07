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

test_that("returns a DomainResult with SedimentSummary + schema columns", {
  result <- process_sediment_summary_domain(sediment_source_xlsx())
  expect_s3_class(result, "DomainResult")
  expect_true(result$ok())
  expect_equal(names(result$data$SedimentSummary), SEDIMENT_SUMMARY_COLUMNS)
  expect_equal(nrow(result$data$SedimentSummary), 2L)
})

test_that("joins SAM (Sediment) and fractions (SedimentSize) per row", {
  df <- process_sediment_summary_domain(sediment_source_xlsx())$data$SedimentSummary
  a <- as.list(df[df$Site == "EM_A", ])
  b <- as.list(df[df$Site == "EM_B", ])

  # SAM columns come from the Sediment sheet.
  expect_equal(a$SAM1, 12.5)
  expect_equal(a$SAM3, 8.3)
  expect_equal(b$SAM1, 20)
  # Fractions come from the SedimentSize sheet, aligned to the right row:
  # row A gets i (1..10), row B gets i+10 (11..20).
  expect_equal(a[["Clay/silt (<0.06 mm)"]], 1)   # first fraction
  expect_equal(a[["Bedrock"]], 10)               # last fraction
  expect_equal(b[["Clay/silt (<0.06 mm)"]], 11)
  expect_equal(b[["Bedrock"]], 20)

  # Period/Season pass through the ingest normalisation.
  expect_equal(a$Period, "Routine Construction")
  expect_equal(a$Season, "Spring")
  expect_equal(b$Period, "Baseline")
  expect_equal(b$Season, "Summer")
})

test_that("row count matches the source (join is 1:1)", {
  df <- process_sediment_summary_domain(sediment_source_xlsx())$data$SedimentSummary
  expect_equal(nrow(df), 2L)
})

test_that("missing 'Sediment' sheet returns an error result", {
  tmp <- tempfile(fileext = ".xlsx")
  openxlsx::write.xlsx(list("Other" = data.frame(x = 1)), tmp)
  result <- process_sediment_summary_domain(tmp)
  expect_false(result$ok())
  expect_null(result$data)
  expect_equal(result$errors[[length(result$errors)]]$domain, "SedimentSummary")
})
