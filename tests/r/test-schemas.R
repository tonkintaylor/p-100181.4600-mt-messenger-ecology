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
                 "SedimentSize","Clarity","RPD","LDV","Fish",
                 "MacroSummary","FishSummary","SedimentSummary","RpdSummary",
                 "MacroSampleData"))
  expect_equal(length(SEDIMENT_SIZE_COLUMNS), 14L)
  expect_equal(SEDIMENT_SIZE_COLUMNS[5], "Clay/silt (<0.06 mm)")
  expect_setequal(names(SCHEMA_MAP), SHEET_ORDER)
  # MacroSummary is an R-only report sheet (Table 5.6); no Python counterpart.
  expect_equal(MACRO_SUMMARY_COLUMNS,
               c("Catchment","Site","Substrate","Method","Date","Season",
                 "NumIndividuals","NumIndividuals_CI",
                 "NumTaxa","NumTaxa_CI",
                 "MCI","MCI_CI","MCI_Class",
                 "QMCI","QMCI_CI","QMCI_Class",
                 "PctEPTRichness","PctEPTRichness_CI",
                 "PctEPTAbundance","PctEPTAbundance_CI",
                 "DominantTaxa"))
  # FishSummary is an R-only report sheet (Table 5.8); no Python counterpart.
  expect_equal(FISH_SUMMARY_COLUMNS,
               c("Catchment","Site","Season","Year",
                 "LongfinEel","ShortfinEel","CommonBully","RedfinBully",
                 "BandedKokopu","GiantKokopu","Inanga",
                 "UnidBully","UnidKokopu","UnidEel","Koura",
                 "Shrimp","TotalFish","TaxaRichness","CPUE_fykes","CPUE_GMTs"))
  # SedimentSummary is an R-only report sheet (Appendix B1 Table 3): a join of
  # the Sediment (SAM1/SAM3) and SedimentSize (fraction) columns.
  expect_equal(SEDIMENT_SUMMARY_COLUMNS,
               c("Site","Date","Period","Season","SAM1","SAM3",
                 SEDIMENT_SIZE_COLUMNS[5:14]))
  expect_equal(length(SEDIMENT_SUMMARY_COLUMNS), 16L)
  # RpdSummary is an R-only report sheet (Appendix B1 Table 4).
  expect_equal(RPD_SUMMARY_COLUMNS,
               c("Site","Season","Year","N","Mean","CI95"))
  # MacroSampleData is an R-only raw count matrix (Appendix B2 Tables 1 & 2).
  expect_equal(MACRO_SAMPLE_COLUMNS,
               c("Season","Year","Date","Site","Replicate",
                 "TaxaGroup","Species","MCI","MCI_sb","Count"))
})
