src_data("errors.R")

test_that("ValidationError formats with the arrow layout", {
  e <- ValidationError("Clarity", "error", "db.xlsx", "Clarity Data",
                       "header", "Missing required columns: ['Site']")
  expect_equal(format(e),
    "[ERROR] db.xlsx → Clarity Data → header: Missing required columns: ['Site']")
})

test_that("DomainResult ok() is FALSE when an error-severity error is present", {
  r <- DomainResult$new(data = NULL)
  expect_true(r$ok())
  r$add_error(ValidationError("D", "warning", "f", "s", "l", "m"))
  expect_true(r$ok())  # warnings do not fail
  r$add_error(ValidationError("D", "error", "f", "s", "l", "m"))
  expect_false(r$ok())
})

test_that("DomainResult holds named data frames", {
  df <- data.frame(a = 1)
  r <- DomainResult$new(data = list(Clarity = df))
  expect_true(r$ok())
  expect_equal(r$data$Clarity, df)
})
