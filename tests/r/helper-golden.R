# helper-golden.R — compare a produced sheet against the golden file,
# mirroring tests/test_writer.py::_assert_sheet_matches_golden.

compare_sheet_to_golden <- function(actual_df, sheet_name, golden_path,
                                     tolerance = 1e-7) {
  expected <- readxl::read_excel(golden_path, sheet = sheet_name)
  names(expected) <- trimws(names(expected))

  # Compare dates as calendar dates.
  to_date <- function(x) as.Date(x)
  actual <- actual_df
  actual$Date <- to_date(actual$Date)
  expected$Date <- to_date(expected$Date)

  # Filter actual to dates present in golden.
  golden_dates <- unique(stats::na.omit(expected$Date))
  actual <- actual[actual$Date %in% golden_dates, , drop = FALSE]

  # Sort both by Date, Site.
  ord <- function(d) d[order(d$Date, d$Site), , drop = FALSE]
  actual <- ord(actual); expected <- ord(expected)
  rownames(actual) <- NULL; rownames(expected) <- NULL

  testthat::expect_equal(nrow(actual), nrow(expected),
    info = sprintf("%s: row count", sheet_name))
  testthat::expect_equal(names(actual), names(expected),
    info = sprintf("%s: columns", sheet_name))

  for (col in names(actual)) {
    a <- actual[[col]]; e <- expected[[col]]
    if (is.numeric(a) || is.numeric(e)) {
      testthat::expect_equal(as.numeric(a), as.numeric(e),
        tolerance = tolerance, info = sprintf("%s/%s", sheet_name, col))
    } else if (inherits(a, "Date") || col == "Date") {
      testthat::expect_equal(as.Date(a), as.Date(e),
        info = sprintf("%s/%s", sheet_name, col))
    } else {
      testthat::expect_equal(as.character(a), as.character(e),
        info = sprintf("%s/%s", sheet_name, col))
    }
  }
}
