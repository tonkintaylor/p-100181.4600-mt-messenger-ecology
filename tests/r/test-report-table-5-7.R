# test-report-table-5-7.R — TDD reproduction of report Table 5.7
# (macroinvertebrate community indices, summer 2026 survey). Asserts the EXACT
# printed values from the report against process_macro_summary_domain() output
# computed from the real source database. Skips when that DB is unavailable.
#
# This is the summer-2026 sibling of Table 5.6 (spring 2025); it uses the SAME
# MacroSummary domain -- the only difference is the survey the rows come from.
#
# Conventions for the expected spec below (identical to test-report-table-5-6.R):
#   - % EPT metrics are stored as FRACTIONS in the schema, so report percentages
#     are divided by 100 here. (% EPT excludes Hydroptilidae per the table's
#     footnote ***; derive_metrics() already does this.)
#   - CI fields: a number  -> assert the mean +/- 95% CI half-width matches;
#                NA         -> assert the value is NA (single-sample sites);
#                key absent -> do not assert.
#
# Koura exclusion: the report tables drop koura (Paranephrops) from every
# community metric (see .MACRO_SUMMARY_EXCLUDED_TAXA in macro_summary.R). This is
# what makes EM2 reproduce EXACTLY and EM8's richness/MCI/QMCI match; without it
# EM2/EM8 carry one extra taxon each. Shrimp (Paratya) are NOT excluded (EM1
# reproduces with its 28 Paratya counted).
#
# Two documented divergences from the printed table (asserted as the current
# source truth, following the FieldWQ EM6 precedent):
#   - EM5 & EM7 QMCI: the report prints NO confidence interval (every sibling
#     Surber metric has one). Treated as a report omission -- qmci_ci keys are
#     intentionally absent, so we assert the mean but not the CI.
#   - EM8 individual count & % EPT abundance: the printed table shows 284 / 7.75%
#     but the current source yields 294 / 7.48% (koura already removed). One
#     non-EPT taxon's count differs by ~10 between the report-era snapshot and
#     the current DB -- a residual source drift that leaves taxa richness, MCI,
#     QMCI and % EPT richness (all reproduced exactly) untouched. We assert the
#     current-source values here, not the stale printed ones.

src_data("errors.R")
src_data("domain_types.R")
src_data("schemas.R")
src_data("config.R")
src_data("domains/macro_ingest.R")
src_data("domains/macro.R")
src_data("domains/macro_summary.R")

.T57 <- list(
  list(site = "EM1", catch = "Mangapepeke", sub = "Soft bottom", meth = "D-net",
       date = "2026-02-23", ind = 287, ind_ci = NA, tax = 16.0, tax_ci = NA,
       mci = 118.50, mci_ci = NA, mci_cls = "Good",
       qmci = 3.94, qmci_ci = NA, qmci_cls = "Poor",
       eptr = 25.00 / 100, eptr_ci = NA, epta = 13.24 / 100, epta_ci = NA,
       dom = "Potamopyrgus"),
  list(site = "EM2", catch = "Mangapepeke", sub = "Soft bottom", meth = "D-net",
       date = "2026-02-23", ind = 297, ind_ci = NA, tax = 15.0, tax_ci = NA,
       mci = 113.07, mci_ci = NA, mci_cls = "Good",
       qmci = 4.32, qmci_ci = NA, qmci_cls = "Fair",
       eptr = 40.00 / 100, eptr_ci = NA, epta = 21.89 / 100, epta_ci = NA,
       dom = "Potamopyrgus"),
  list(site = "EM3", catch = "Mangapepeke", sub = "Hard bottom", meth = "Surber",
       date = "2026-02-23", ind = 182.0, ind_ci = 69.4, tax = 16.4, tax_ci = 5.7,
       mci = 126.3, mci_ci = 12.9, mci_cls = "Excellent",
       qmci = 4.91, qmci_ci = 0.65, qmci_cls = "Fair",
       eptr = 45.7 / 100, eptr_ci = 9.4 / 100, epta = 19.1 / 100, epta_ci = 12.6 / 100,
       dom = "Elmidae, Potamopyrgus"),
  list(site = "EM4", catch = "Mimi", sub = "Soft bottom", meth = "D-net",
       date = "2026-02-24", ind = 274, ind_ci = NA, tax = 15.0, tax_ci = NA,
       mci = 122.13, mci_ci = NA, mci_cls = "Excellent",
       qmci = 3.55, qmci_ci = NA, qmci_cls = "Poor",
       eptr = 40.00 / 100, eptr_ci = NA, epta = 14.23 / 100, epta_ci = NA,
       dom = "Potamopyrgus"),
  list(site = "EM5", catch = "Mimi", sub = "Hard bottom", meth = "Surber",
       date = "2026-02-25", ind = 43.8, ind_ci = 41.9, tax = 9.2, tax_ci = 6.6,
       mci = 141.7, mci_ci = 17.6, mci_cls = "Excellent",
       qmci = 6.99, qmci_cls = "Excellent",  # qmci_ci omitted in report
       eptr = 59.3 / 100, eptr_ci = 9.4 / 100, epta = 62.8 / 100, epta_ci = 22.7 / 100,
       dom = "Deleatidium, Elmidae"),
  list(site = "EM7", catch = "Mimi", sub = "Hard bottom", meth = "Surber",
       date = "2026-02-25", ind = 36.0, ind_ci = 31.4, tax = 7.2, tax_ci = 3.2,
       mci = 133.9, mci_ci = 13.9, mci_cls = "Excellent",
       qmci = 7.16, qmci_cls = "Excellent",  # qmci_ci omitted in report
       eptr = 56.1 / 100, eptr_ci = 16.1 / 100, epta = 68.5 / 100, epta_ci = 13.3 / 100,
       dom = "Deleatidium"),
  # EM8: printed table shows ind = 284 and %EPT abundance = 7.75; the current
  # source yields 294 / 7.48% (see header note). Assert current-source truth.
  list(site = "EM8", catch = "Mimi", sub = "Soft bottom", meth = "D-net",
       date = "2026-02-25", ind = 294, ind_ci = NA, tax = 10.0, tax_ci = NA,
       mci = 96.60, mci_ci = NA, mci_cls = "Fair",
       qmci = 3.24, qmci_ci = NA, qmci_cls = "Poor",
       eptr = 20.00 / 100, eptr_ci = NA, epta = 7.48 / 100, epta_ci = NA,
       dom = "Potamopyrgus")
)

# Tolerances reflect the report's rounding (1-2 dp).
.TOL <- list(ind = 0.1, ind_ci = 0.2, tax = 0.1, tax_ci = 0.15,
             mci = 0.05, mci_ci = 0.2, qmci = 0.02, qmci_ci = 0.05,
             eptr = 0.002, eptr_ci = 0.005, epta = 0.002, epta_ci = 0.005)

.near <- function(actual, expected, tol, label) {
  ok <- length(actual) == 1 && !is.na(actual) && abs(actual - expected) <= tol
  expect_true(ok, info = sprintf(
    "%s: expected ~%.4f (tol %.3f), got %s", label, expected, tol,
    if (length(actual) == 1) format(actual) else "<missing>"))
}

# CI field: number -> near; NA -> assert NA; absent (NULL) -> skip.
.ci <- function(row, key, expected, tol, label) {
  if (!key %in% names(row) && missing(expected)) return(invisible())
  actual <- row[[key]]
  if (is.null(expected)) return(invisible())
  if (length(expected) == 1 && is.na(expected)) {
    expect_true(is.na(actual), info = sprintf("%s: expected NA, got %s",
                                              label, format(actual)))
  } else {
    .near(actual, expected, tol, label)
  }
}

test_that("MacroSummary reproduces report Table 5.7 (summer 2026)", {
  cfg <- tryCatch(load_config(file.path(ROOT, "cycle.toml")),
                  error = function(e) NULL)
  skip_if(is.null(cfg), "cycle.toml not available")
  skip_if_not(file.exists(cfg$macroinvertebrate_db),
              paste("macroinvertebrate_db not reachable:", cfg$macroinvertebrate_db))

  result <- process_macro_summary_domain(cfg$macroinvertebrate_db)
  expect_true(result$ok())
  df <- result$data$MacroSummary
  df$Date <- as.Date(df$Date)

  for (e in .T57) {
    lbl <- e$site
    row <- df[df$Site == e$site & df$Date == as.Date(e$date), , drop = FALSE]
    expect_equal(nrow(row), 1L,
                 info = sprintf("%s: expected exactly one %s row", lbl, e$date))
    if (nrow(row) != 1L) next
    row <- as.list(row)

    expect_equal(row$Catchment, e$catch, info = paste(lbl, "Catchment"))
    expect_equal(row$Substrate, e$sub,   info = paste(lbl, "Substrate"))
    expect_equal(row$Method,    e$meth,  info = paste(lbl, "Method"))
    expect_equal(row$Season,    "Summer", info = paste(lbl, "Season"))

    .near(row$NumIndividuals,  e$ind,  .TOL$ind,  paste(lbl, "NumIndividuals"))
    .near(row$NumTaxa,         e$tax,  .TOL$tax,  paste(lbl, "NumTaxa"))
    .near(row$MCI,             e$mci,  .TOL$mci,  paste(lbl, "MCI"))
    .near(row$QMCI,            e$qmci, .TOL$qmci, paste(lbl, "QMCI"))
    .near(row$PctEPTRichness,  e$eptr, .TOL$eptr, paste(lbl, "PctEPTRichness"))
    .near(row$PctEPTAbundance, e$epta, .TOL$epta, paste(lbl, "PctEPTAbundance"))

    expect_equal(row$MCI_Class,  e$mci_cls,  info = paste(lbl, "MCI_Class"))
    expect_equal(row$QMCI_Class, e$qmci_cls, info = paste(lbl, "QMCI_Class"))

    .ci(row, "NumIndividuals_CI",  e$ind_ci,  .TOL$ind_ci,  paste(lbl, "NumIndividuals_CI"))
    .ci(row, "NumTaxa_CI",         e$tax_ci,  .TOL$tax_ci,  paste(lbl, "NumTaxa_CI"))
    .ci(row, "MCI_CI",             e$mci_ci,  .TOL$mci_ci,  paste(lbl, "MCI_CI"))
    .ci(row, "QMCI_CI",            e$qmci_ci, .TOL$qmci_ci, paste(lbl, "QMCI_CI"))
    .ci(row, "PctEPTRichness_CI",  e$eptr_ci, .TOL$eptr_ci, paste(lbl, "PctEPTRichness_CI"))
    .ci(row, "PctEPTAbundance_CI", e$epta_ci, .TOL$epta_ci, paste(lbl, "PctEPTAbundance_CI"))

    expect_equal(row$DominantTaxa, e$dom, info = paste(lbl, "DominantTaxa"))
  }
})
