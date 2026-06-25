src_data("errors.R"); src_data("schemas.R"); src_data("domains/fish.R")

# Write a "Fish Trapping" sheet to a temp xlsx and return the path.
fish_xlsx <- function(df) {
  tmp <- tempfile(fileext = ".xlsx")
  openxlsx::write.xlsx(list("Fish Trapping" = df), tmp)
  tmp
}

minimal_df <- function() {
  data.frame(
    Site                                = c("EM1", "EM3"),
    Catchment                           = c("Mangapepeke", "Mangapepeke"),
    `Date retrieved`                    = as.Date(c("2024-02-01", "2024-02-01")),
    `Species category (for abundance)`  = c("B", "E"),
    Number                              = c(5, 2),
    check.names = FALSE, stringsAsFactors = FALSE
  )
}

test_that("happy path produces a DomainResult with FISH_COLUMNS in order", {
  result <- process_fish_domain(fish_xlsx(minimal_df()))
  expect_true(result$ok())
  expect_false(is.null(result$data))
  fish <- result$data$Fish
  expect_equal(names(fish), FISH_COLUMNS)
  expect_equal(nrow(fish), 2L)
})

test_that("Date is Date class, Number numeric, Site character", {
  fish <- process_fish_domain(fish_xlsx(minimal_df()))$data$Fish
  expect_true(inherits(fish$Date, "Date"))
  expect_true(is.numeric(fish$Number))
  expect_true(is.character(fish$Site))
})

test_that("the source 'Date retrieved' column is mapped to 'Date'", {
  fish <- process_fish_domain(fish_xlsx(minimal_df()))$data$Fish
  expect_true("Date" %in% names(fish))
  expect_false("Date retrieved" %in% names(fish))
})

test_that("missing required column returns an error result", {
  df <- minimal_df(); df[["Number"]] <- NULL
  result <- process_fish_domain(fish_xlsx(df))
  expect_false(result$ok())
  expect_null(result$data)
  expect_equal(length(result$errors), 1L)
  expect_equal(result$errors[[1]]$domain, "Fish")
  expect_match(result$errors[[1]]$message, "Missing required columns")
})

test_that("excel file with no Fish Trapping sheet returns an error result", {
  tmp <- tempfile(fileext = ".xlsx")
  openxlsx::write.xlsx(list("WrongSheet" = data.frame(x = 1)), tmp)
  result <- process_fish_domain(tmp)
  expect_false(result$ok())
  expect_equal(result$errors[[1]]$domain, "Fish")
  expect_match(result$errors[[1]]$message, "Fish Trapping")
})
