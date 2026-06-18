src_data("domain_types.R")

test_that("domain constants match the Python contract", {
  expect_equal(BASELINE_END, as.Date("2022-03-31"))
  expect_setequal(SITES_WITHOUT_REPLICATES, c("EM1", "EM2", "EM4", "EM8"))
  expect_true(all(c("MMA 6", "MMA 6b") %in% VALID_SITES))
  expect_setequal(VALID_PERIODS, c("Baseline", "Construction"))
  expect_setequal(VALID_SEASONS,
                  c("Baseline", "Construction", "Routine", "Additional"))
})
