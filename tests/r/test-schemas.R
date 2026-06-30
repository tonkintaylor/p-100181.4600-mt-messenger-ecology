src_data("schemas.R")

test_that("schema column vectors match the Python contract", {
  expect_equal(MACRO1_COLUMNS,
               c("Site","Date","Period","EPTrich","EPTabun","QMCI","Season"))
  expect_identical(MACRO_COLUMNS, MACRO1_COLUMNS)
  expect_equal(MACRO_SPECIES_COLUMNS,
               c("Phase","Date","Site","Taxa","Species","Tally","is_additional"))
  expect_equal(SEDIMENT_COLUMNS,
               c("Site","Date","Period","SAM1","SAM3","Season"))
  expect_equal(RPD_COLUMNS,
               c("Site","Date","Count","Mean","StdDev","CI_Lower","CI_Upper"))
  expect_equal(LDV_COLUMNS, c("Site","Date","Season","CV_pct"))
  # Fish is an R-only sheet (no Python schemas.py counterpart).
  expect_equal(FISH_COLUMNS,
               c("Site","Catchment","Date","Species category (for abundance)","Number"))
  expect_equal(SHEET_ORDER,
               c("Macro","Macro1","MacroSpecies","Sediment",
                 "SedimentSize","Clarity","RPD","LDV","Fish"))
  expect_equal(length(SEDIMENT_SIZE_COLUMNS), 14L)
  expect_equal(SEDIMENT_SIZE_COLUMNS[5], "Clay/silt (<0.06 mm)")
  expect_setequal(names(SCHEMA_MAP), SHEET_ORDER)
})
