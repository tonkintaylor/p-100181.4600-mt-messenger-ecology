src_data("domain_types.R")

test_that("domain constants match the Python contract", {
  expect_equal(BASELINE_END, as.Date("2022-03-31"))
  expect_setequal(SITES_WITHOUT_REPLICATES, c("EM1", "EM2", "EM4", "EM8"))
  expect_true(all(c("MMA 6", "MMA 6b") %in% VALID_SITES))
  expect_setequal(VALID_PERIODS, c("Baseline", "Construction"))
  expect_setequal(VALID_SEASONS,
                  c("Baseline", "Construction", "Routine", "Additional"))
})

test_that("SITE_LEGEND is internally consistent", {
  # Soft-bottom sites must match the replicate-lacking set exactly, since the
  # two encode the same partition (D-net/MCI-sb <-> no Surber replicates).
  soft <- SITE_LEGEND$Site[SITE_LEGEND$Substrate == "Soft bottom"]
  expect_setequal(soft, SITES_WITHOUT_REPLICATES)

  # Substrate and sampling method are locked together.
  expect_true(all(SITE_LEGEND$Method[SITE_LEGEND$Substrate == "Soft bottom"] == "D-net"))
  expect_true(all(SITE_LEGEND$Method[SITE_LEGEND$Substrate == "Hard bottom"] == "Surber"))

  # Every legend site is a recognised monitoring site.
  expect_true(all(SITE_LEGEND$Site %in% VALID_SITES))

  # Controlled vocabularies.
  expect_setequal(SITE_LEGEND$Catchment, c("Mangapepeke", "Mimi"))
  expect_setequal(SITE_LEGEND$Substrate, c("Soft bottom", "Hard bottom"))
})
