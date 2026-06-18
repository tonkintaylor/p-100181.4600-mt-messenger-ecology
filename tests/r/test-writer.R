src_data("schemas.R")
src_data("writer.R")

make_minimal <- function() {
  mk <- function(cols) {
    df <- as.data.frame(setNames(
      lapply(cols, function(c) if (c == "Date") as.Date("2024-01-01") else NA), cols),
      stringsAsFactors = FALSE, check.names = FALSE)
    df[1, "Date"] <- as.Date("2024-01-01")
    df
  }
  setNames(lapply(SHEET_ORDER, function(s) mk(SCHEMA_MAP[[s]])), SHEET_ORDER)
}

test_that("write_data_xlsx writes sheets in SHEET_ORDER", {
  data <- make_minimal()
  out <- tempfile(fileext = ".xlsx")
  write_data_xlsx(data, out)
  expect_true(file.exists(out))
  expect_equal(readxl::excel_sheets(out), SHEET_ORDER)
})

test_that("write_data_xlsx refuses a missing sheet", {
  data <- make_minimal(); data[["Clarity"]] <- NULL
  expect_error(write_data_xlsx(data, tempfile(fileext = ".xlsx")),
               "Missing required sheets")
})

test_that("write_data_xlsx refuses a column mismatch", {
  data <- make_minimal()
  data[["Clarity"]] <- data[["Clarity"]][, -1, drop = FALSE]
  expect_error(write_data_xlsx(data, tempfile(fileext = ".xlsx")),
               "column mismatch")
})
