test_that("schema column vectors match the Python contract", {
  # testthat::test_file() changes working directory; find project root
  if (!file.exists("src/r/data/schemas.R")) {
    wd <- getwd()
    while (!file.exists(file.path(wd, ".git"))) {
      new_wd <- dirname(wd)
      if (new_wd == wd) break
      wd <- new_wd
    }
    setwd(wd)
  }
  source("src/r/data/schemas.R", local = TRUE)
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
  expect_equal(SHEET_ORDER,
               c("Macro","Macro1","MacroSpecies","Sediment",
                 "SedimentSize","Clarity","RPD","LDV"))
  expect_equal(length(SEDIMENT_SIZE_COLUMNS), 14L)
  expect_equal(SEDIMENT_SIZE_COLUMNS[5], "Clay/silt (<0.06 mm)")
  expect_setequal(names(SCHEMA_MAP), SHEET_ORDER)
})
