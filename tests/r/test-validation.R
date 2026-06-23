src_data("errors.R")
src_data("validation.R")

test_that("check_required_columns passes when all present", {
  df <- data.frame(Site = "EM1", Date = as.Date("2024-01-01"))
  expect_length(check_required_columns(df, c("Site", "Date"),
                domain = "M", file = "f", sheet = "s"), 0)
})

test_that("check_required_columns reports sorted missing columns", {
  df <- data.frame(Site = "EM1")
  errs <- check_required_columns(df, c("Site", "Date", "QMCI"),
                                 domain = "M", file = "f", sheet = "s")
  expect_length(errs, 1)
  expect_match(errs[[1]]$message, "Date")
  expect_match(errs[[1]]$message, "QMCI")
  expect_equal(errs[[1]]$location, "header")
})

test_that("check_required_columns with empty expected returns empty", {
  df <- data.frame(A = 1)
  expect_length(check_required_columns(df, c(),
                domain = "test", file = "f.xlsx", sheet = "Sheet1"), 0)
})

test_that("check_no_nulls passes when no nulls present", {
  df <- data.frame(A = c(1, 2, 3), B = c("x", "y", "z"))
  expect_length(check_no_nulls(df, c("A", "B"),
                domain = "test", file = "f.xlsx", sheet = "Sheet1"), 0)
})

test_that("check_no_nulls flags NA cells and reports source rows", {
  df <- data.frame(QMCI = c(1, NA, 3, NA))
  errs <- check_no_nulls(df, "QMCI", domain = "M", file = "f", sheet = "s")
  expect_length(errs, 1)
  expect_match(errs[[1]]$message, "2 null")
})

test_that("check_no_nulls returns error with row indices", {
  df <- data.frame(A = c(1, NA, 3), B = c(NA, NA, "z"))
  errs <- check_no_nulls(df, c("A", "B"), domain = "test", file = "f.xlsx", sheet = "Sheet1")
  expect_length(errs, 2)
  # Column A has 1 null
  a_error <- errs[[which(vapply(errs, function(e) grepl("'A'", e$location), logical(1)))]]
  expect_match(a_error$message, "1 null")
  # Column B has 2 nulls
  b_error <- errs[[which(vapply(errs, function(e) grepl("'B'", e$location), logical(1)))]]
  expect_match(b_error$message, "2 null")
})

test_that("check_no_nulls skips missing columns", {
  df <- data.frame(A = c(1, 2))
  errs <- check_no_nulls(df, c("A", "NonExistent"),
                domain = "test", file = "f.xlsx", sheet = "Sheet1")
  expect_length(errs, 0)
})

test_that("check_no_nulls shows first five rows only", {
  df <- data.frame(A = rep(NA, 10))
  errs <- check_no_nulls(df, "A", domain = "test", file = "f.xlsx", sheet = "Sheet1")
  expect_length(errs, 1)
  expect_match(errs[[1]]$location, "rows \\[0, 1, 2, 3, 4\\]")
})

test_that("check_value_range within range returns empty", {
  df <- data.frame(val = c(0.0, 50.0, 100.0))
  errs <- check_value_range(df, "val", min_val = 0, max_val = 100,
                            domain = "test", file = "f.xlsx", sheet = "S")
  expect_length(errs, 0)
})

test_that("check_value_range below minimum returns error", {
  df <- data.frame(val = c(-1.0, 5.0, 10.0))
  errs <- check_value_range(df, "val", min_val = 0,
                            domain = "test", file = "f.xlsx", sheet = "S")
  expect_length(errs, 1)
  expect_match(errs[[1]]$message, "below minimum")
})

test_that("check_value_range above maximum returns error", {
  df <- data.frame(val = c(50.0, 101.0))
  errs <- check_value_range(df, "val", max_val = 100,
                            domain = "test", file = "f.xlsx", sheet = "S")
  expect_length(errs, 1)
  expect_match(errs[[1]]$message, "above maximum")
})

test_that("check_value_range missing column returns empty", {
  df <- data.frame(other = c(1, 2, 3))
  errs <- check_value_range(df, "val", min_val = 0, max_val = 100,
                            domain = "test", file = "f.xlsx", sheet = "S")
  expect_length(errs, 0)
})

test_that("check_value_range flags non-numeric and out-of-range", {
  df <- data.frame(x = c("1", "abc", "5", "999"))
  errs <- check_value_range(df, "x", min_val = 0, max_val = 100,
                            domain = "M", file = "f", sheet = "s")
  expect_true(any(vapply(errs, function(e) grepl("non-numeric", e$message), logical(1))))
  expect_true(any(vapply(errs, function(e) grepl("above maximum", e$message), logical(1))))
})

test_that("check_value_range non-numeric values detected", {
  df <- data.frame(val = c(1.0, "N/A", ">10", 5.0))
  errs <- check_value_range(df, "val", min_val = 0, max_val = 100,
                            domain = "test", file = "f.xlsx", sheet = "S")
  expect_true(any(vapply(errs, function(e) grepl("non-numeric", tolower(e$message)), logical(1))))
  non_numeric_error <- errs[[which(vapply(errs, function(e) grepl("non-numeric", tolower(e$message)), logical(1)))[1]]]
  expect_match(non_numeric_error$message, "2")  # 2 non-numeric values
})

test_that("check_value_range partial bounds", {
  df <- data.frame(val = c(50.0))

  # No bounds
  errs <- check_value_range(df, "val", min_val = NULL, max_val = NULL,
                            domain = "test", file = "f.xlsx", sheet = "S")
  expect_length(errs, 0)

  # Max only
  errs <- check_value_range(df, "val", min_val = NULL, max_val = 100,
                            domain = "test", file = "f.xlsx", sheet = "S")
  expect_length(errs, 0)

  # Min only
  errs <- check_value_range(df, "val", min_val = 0, max_val = NULL,
                            domain = "test", file = "f.xlsx", sheet = "S")
  expect_length(errs, 0)
})
