# test-report-table-5-6.R — TDD reproduction of report Table 5.6
# (macroinvertebrate community metrics, spring 2025). Asserts the EXACT printed
# values from the report against process_macro_summary_domain() output computed
# from the real source database. Skips when that DB is unavailable.
#
# EXCEPTION — DominantTaxa: the author's "within 10%" co-dominance rule (2026
# regeneration review) is a SHARE-gap rule: a second taxon is reported only if
# its percentage of the whole sample is within 10 percentage points of the top
# taxon's percentage (macro_summary.R .MACRO_DOMINANT_PCT_GAP = 0.10). Under it
# ANY site's dominant taxa may differ from the printed table, and the exact
# values must be re-derived against the source DB (not reachable here). So exact
# dominant-taxa checks are gated behind .DOM_EXACT (FALSE): the test asserts a
# dominant taxon is produced. Set .DOM_EXACT <- TRUE after re-deriving.
#
# Conventions for the expected spec below:
#   - % EPT metrics are stored as FRACTIONS in the schema, so report percentages
#     are divided by 100 here.
#   - CI fields: a number  -> assert the mean +/- 95% CI half-width matches;
#                NA         -> assert the value is NA (single-sample sites);
#                key absent -> do not assert (see EM3 MCI note).
#   - EM3's MCI shows NO confidence interval in the printed report even though
#     every other EM3 (Surber) metric does. The author confirmed (2026
#     regeneration review) this was a report OMISSION: the CI should be shown,
#     and any site with a 5-replicate mean should carry one. The domain already
#     computes it, so we assert EM3's MCI CI is PRESENT (`mci_ci = "present"`);
#     there is no printed value to assert exactly.

src_data("errors.R")
src_data("domain_types.R")
src_data("schemas.R")
src_data("config.R")
src_data("domains/macro_ingest.R")
src_data("domains/macro.R")
src_data("domains/macro_summary.R")

.T56 <- list(
  list(site = "EM1", catch = "Mangapepeke", sub = "Soft bottom", meth = "D-net",
       date = "2025-11-24", ind = 162, ind_ci = NA, tax = 15.0, tax_ci = NA,
       mci = 128.00, mci_ci = NA, mci_cls = "Excellent",
       qmci = 5.13, qmci_ci = NA, qmci_cls = "Good",
       eptr = 40.00 / 100, eptr_ci = NA, epta = 16.67 / 100, epta_ci = NA,
       dom = "pending"),  # share-gap rule: re-derive exact value from DB
  list(site = "EM2", catch = "Mangapepeke", sub = "Soft bottom", meth = "D-net",
       date = "2025-11-24", ind = 217, ind_ci = NA, tax = 13.0, tax_ci = NA,
       mci = 126.92, mci_ci = NA, mci_cls = "Excellent",
       qmci = 4.48, qmci_ci = NA, qmci_cls = "Fair",
       eptr = 46.15 / 100, eptr_ci = NA, epta = 23.96 / 100, epta_ci = NA,
       dom = "Potamopyrgus"),
  list(site = "EM3", catch = "Mangapepeke", sub = "Hard bottom", meth = "Surber",
       date = "2025-11-24", ind = 268.8, ind_ci = 84.8, tax = 14.2, tax_ci = 2.4,
       mci = 121.53, mci_ci = "present", mci_cls = "Excellent",  # report omitted CI; author says show it
       qmci = 4.39, qmci_ci = 0.64, qmci_cls = "Fair",
       eptr = 52.2 / 100, eptr_ci = 5.6 / 100, epta = 8.7 / 100, epta_ci = 6.0 / 100,
       dom = "pending"),  # share-gap rule: re-derive exact value from DB
  list(site = "EM4", catch = "Mimi", sub = "Soft bottom", meth = "D-net",
       date = "2025-11-17", ind = 223, ind_ci = NA, tax = 18.0, tax_ci = NA,
       mci = 121.18, mci_ci = NA, mci_cls = "Excellent",
       qmci = 6.41, qmci_ci = NA, qmci_cls = "Excellent",
       eptr = 44.44 / 100, eptr_ci = NA, epta = 32.74 / 100, epta_ci = NA,
       dom = "pending"),  # share-gap rule: re-derive exact value from DB
  list(site = "EM5", catch = "Mimi", sub = "Hard bottom", meth = "Surber",
       date = "2025-11-18", ind = 21.8, ind_ci = 15.0, tax = 7.2, tax_ci = 4.2,
       mci = 143.2, mci_ci = 19.4, mci_cls = "Excellent",
       qmci = 7.27, qmci_ci = 0.67, qmci_cls = "Excellent",
       eptr = 49.1 / 100, eptr_ci = 37.0 / 100, epta = 52.7 / 100, epta_ci = 40.4 / 100,
       dom = "Deleatidium"),
  list(site = "EM7", catch = "Mimi", sub = "Hard bottom", meth = "Surber",
       date = "2025-11-17", ind = 29.8, ind_ci = 36.0, tax = 9.8, tax_ci = 6.3,
       mci = 120.5, mci_ci = 12.0, mci_cls = "Excellent",
       qmci = 5.40, qmci_ci = 1.32, qmci_cls = "Good",
       eptr = 54.5 / 100, eptr_ci = 12.0 / 100, epta = 47.1 / 100, epta_ci = 13.7 / 100,
       dom = "Orthocladiinae"),
  list(site = "EM8", catch = "Mimi", sub = "Soft bottom", meth = "D-net",
       date = "2025-11-17", ind = 223, ind_ci = NA, tax = 16.0, tax_ci = NA,
       mci = 125.73, mci_ci = NA, mci_cls = "Excellent",
       qmci = 6.27, qmci_ci = NA, qmci_cls = "Excellent",
       eptr = 31.25 / 100, eptr_ci = NA, epta = 46.19 / 100, epta_ci = NA,
       dom = "pending")  # share-gap rule: re-derive exact value from DB
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

# CI field expectations: a number asserts near; NA asserts the value is NA; the
# string "present" asserts any non-NA value; an absent (NULL) key is skipped.
.ci <- function(row, key, expected, tol, label) {
  if (!key %in% names(row) && missing(expected)) return(invisible())
  actual <- row[[key]]
  if (is.null(expected)) return(invisible())
  if (identical(expected, "present")) {
    expect_true(length(actual) == 1 && !is.na(actual), info = sprintf(
      "%s: expected a value, got %s", label,
      if (length(actual) == 1) format(actual) else "<missing>"))
    return(invisible())
  }
  if (length(expected) == 1 && is.na(expected)) {
    expect_true(is.na(actual), info = sprintf("%s: expected NA, got %s",
                                              label, format(actual)))
  } else {
    .near(actual, expected, tol, label)
  }
}

# Gate for exact dominant-taxa checks (see header). FALSE while the share-gap
# per-site values are pending re-derivation from the source DB.
.DOM_EXACT <- FALSE

test_that("MacroSummary reproduces report Table 5.6 (spring 2025)", {
  cfg <- tryCatch(load_config(file.path(ROOT, "cycle.toml")),
                  error = function(e) NULL)
  skip_if(is.null(cfg), "cycle.toml not available")
  skip_if_not(file.exists(cfg$macroinvertebrate_db),
              paste("macroinvertebrate_db not reachable:", cfg$macroinvertebrate_db))

  result <- process_macro_summary_domain(cfg$macroinvertebrate_db)
  expect_true(result$ok())
  df <- result$data$MacroSummary
  df$Date <- as.Date(df$Date)

  for (e in .T56) {
    lbl <- e$site
    row <- df[df$Site == e$site & df$Date == as.Date(e$date), , drop = FALSE]
    expect_equal(nrow(row), 1L,
                 info = sprintf("%s: expected exactly one %s row", lbl, e$date))
    if (nrow(row) != 1L) next
    row <- as.list(row)

    expect_equal(row$Catchment, e$catch, info = paste(lbl, "Catchment"))
    expect_equal(row$Substrate, e$sub,   info = paste(lbl, "Substrate"))
    expect_equal(row$Method,    e$meth,  info = paste(lbl, "Method"))

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

    if (isTRUE(.DOM_EXACT)) {
      expect_equal(row$DominantTaxa, e$dom, info = paste(lbl, "DominantTaxa"))
    } else {
      # Share-gap rule: exact dominant taxa depend on per-taxon shares from the
      # source DB (not reachable here), so assert only that one is produced.
      expect_true(nzchar(row$DominantTaxa),
                  info = paste(lbl, "DominantTaxa present (pending)"))
    }
  }
})
