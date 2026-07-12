src_data("errors.R")
src_data("domain_types.R")
src_data("schemas.R")
src_data("domains/macro_ingest.R")
src_data("domains/macro.R")
src_data("domains/macro_summary.R")

# ---------------------------------------------------------------------------
# Build a synthetic macro xlsx with one hard-bottom site (EM3, 5 Surber
# replicates) and one soft-bottom site (EM1, single D-net sample), both on the
# same date. Layout mirrors the RawData contract in macro_ingest.R.
# ---------------------------------------------------------------------------
TAXA <- list(
  list(group = "Mayflies",    taxon = "Deleatidium", mci = "8", mci_sb = "7"),
  list(group = "Stoneflies",  taxon = "Zelandobius", mci = "5", mci_sb = "4"),
  list(group = "Caddisflies", taxon = "Hudsonema",   mci = "6", mci_sb = "5"),
  list(group = "Oligochaeta", taxon = "Oligochaeta", mci = "1", mci_sb = "1")
)
# Columns E..J: EM3 rep1..5, then EM1. Rows are per-taxon counts.
COUNTS <- list(
  Deleatidium = c(10, 12,  8, 11,  9, 10),
  Zelandobius = c( 3,  2,  4,  3,  2,  3),
  Hudsonema   = c( 2,  1,  3,  2,  2,  2),
  Oligochaeta = c( 8,  4,  6,  5,  7,  8)
)

build_summary_xlsx <- function() {
  sites      <- c("EM3", "EM3", "EM3", "EM3", "EM3", "EM1")
  replicates <- c("1", "2", "3", "4", "5", "")
  seasons    <- rep("Construction", 6)
  dates      <- rep("2025-11-24", 6)
  n_cols <- 4L + 6L

  make_row <- function(...) {
    vals <- c(...)
    length(vals) <- n_cols
    vals[is.na(vals)] <- ""
    as.character(vals)
  }

  hdr_qa     <- make_row("", "", "", "")
  hdr_season <- make_row("", "", "", "", seasons)
  hdr_date   <- make_row("", "", "", "", dates)
  hdr_site   <- make_row("", "", "", "", sites)
  hdr_rep    <- make_row("", "", "", "", replicates)

  taxa_rows <- lapply(TAXA, function(t) {
    make_row(t$group, t$taxon, t$mci, t$mci_sb, COUNTS[[t$taxon]])
  })
  marker_row <- make_row("", "Number of Taxa", "", "")

  all_rows <- c(list(hdr_qa, hdr_season, hdr_date, hdr_site, hdr_rep),
                taxa_rows, list(marker_row))
  df <- as.data.frame(do.call(rbind, all_rows), stringsAsFactors = FALSE)

  tmp <- tempfile(fileext = ".xlsx")
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "RawData")
  openxlsx::writeData(wb, "RawData", x = df, colNames = FALSE)
  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)
  tmp
}

# ===========================================================================
# Quality-class banding (Stark & Maxted 2007)
# ===========================================================================

test_that("MCI class bands at boundaries", {
  expect_equal(.macro_mci_class(120), "Excellent")
  expect_equal(.macro_mci_class(119.99), "Good")
  expect_equal(.macro_mci_class(100), "Good")
  expect_equal(.macro_mci_class(99.99), "Fair")
  expect_equal(.macro_mci_class(80), "Fair")
  expect_equal(.macro_mci_class(79.99), "Poor")
  expect_true(is.na(.macro_mci_class(NA_real_)))
})

test_that("QMCI class bands at boundaries", {
  expect_equal(.macro_qmci_class(6), "Excellent")
  expect_equal(.macro_qmci_class(5.99), "Good")
  expect_equal(.macro_qmci_class(5), "Good")
  expect_equal(.macro_qmci_class(4.99), "Fair")
  expect_equal(.macro_qmci_class(4), "Fair")
  expect_equal(.macro_qmci_class(3.99), "Poor")
  expect_true(is.na(.macro_qmci_class(NA_real_)))
})

test_that("CI half-width is NA for n < 2 and matches t-formula otherwise", {
  expect_true(is.na(.macro_ci95(c(5))))
  expect_true(is.na(.macro_ci95(numeric(0))))
  v <- c(1, 2, 3, 4, 5)
  expected <- stats::qt(0.975, df = 4) * stats::sd(v) / sqrt(5)
  expect_equal(.macro_ci95(v), expected, tolerance = 1e-12)
})

# ===========================================================================
# process_macro_summary_domain
# ===========================================================================

test_that("returns a DomainResult with the MacroSummary sheet + schema columns", {
  result <- process_macro_summary_domain(build_summary_xlsx())
  expect_s3_class(result, "DomainResult")
  expect_true(result$ok())
  expect_true("MacroSummary" %in% names(result$data))
  expect_equal(names(result$data$MacroSummary), MACRO_SUMMARY_COLUMNS)
  expect_equal(nrow(result$data$MacroSummary), 2L)  # one row per Site x Date
})

test_that("soft-bottom site (EM1): point estimates, NA CIs, sb tolerance variant", {
  df <- process_macro_summary_domain(build_summary_xlsx())$data$MacroSummary
  em1 <- df[df$Site == "EM1", ]

  # Site metadata joined from SITE_LEGEND.
  expect_equal(em1$Catchment, "Mangapepeke")
  expect_equal(em1$Substrate, "Soft bottom")
  expect_equal(em1$Method, "D-net")
  expect_equal(em1$Season, "Spring")           # November -> Spring
  expect_equal(em1$Year, 2025L)                # calendar year of the survey date

  # Counts: Deleatidium 10, Zelandobius 3, Hudsonema 2, Oligochaeta 8 (total 23).
  expect_equal(em1$NumIndividuals, 23)
  expect_equal(em1$NumTaxa, 4)
  # Soft-bottom uses MCI-sb: mean(7,4,5,1)*20 = 85 -> Fair.
  expect_equal(em1$MCI, 85)
  expect_equal(em1$MCI_Class, "Fair")
  # QMCI-sb = (10*7 + 3*4 + 2*5 + 8*1)/23 = 100/23 -> Fair.
  expect_equal(em1$QMCI, 100 / 23, tolerance = 1e-7)
  expect_equal(em1$QMCI_Class, "Fair")
  expect_equal(em1$PctEPTRichness, 3 / 4, tolerance = 1e-7)
  expect_equal(em1$PctEPTAbundance, 15 / 23, tolerance = 1e-7)
  # Dominant taxa > 20% of abundance, ordered by abundance desc.
  expect_equal(em1$DominantTaxa, "Deleatidium, Oligochaeta")

  # Single sample -> every CI is NA.
  for (col in c("NumIndividuals_CI", "NumTaxa_CI", "MCI_CI",
                "QMCI_CI", "PctEPTRichness_CI", "PctEPTAbundance_CI")) {
    expect_true(is.na(em1[[col]]), info = col)
  }
})

test_that("hard-bottom site (EM3): replicate mean + non-zero CI, standard variant", {
  df <- process_macro_summary_domain(build_summary_xlsx())$data$MacroSummary
  em3 <- df[df$Site == "EM3", ]

  expect_equal(em3$Substrate, "Hard bottom")
  expect_equal(em3$Method, "Surber")

  # Mean individuals across reps: (23+19+21+21+20)/5 = 20.8; counts vary -> CI>0.
  expect_equal(em3$NumIndividuals, 20.8, tolerance = 1e-7)
  expect_gt(em3$NumIndividuals_CI, 0)

  # All four taxa present in every replicate -> standard MCI = mean(8,5,6,1)*20
  # = 100 in each rep, so mean 100 (Good) with zero spread.
  expect_equal(em3$MCI, 100, tolerance = 1e-7)
  expect_equal(em3$MCI_Class, "Good")
  expect_equal(em3$MCI_CI, 0, tolerance = 1e-9)

  # QMCI varies across reps (count-weighted) -> CI strictly positive.
  expect_gt(em3$QMCI_CI, 0)
  expect_equal(em3$DominantTaxa, "Deleatidium, Oligochaeta")
})

test_that("invalid path returns an error result", {
  result <- process_macro_summary_domain(tempfile(fileext = ".xlsx"))
  expect_false(result$ok())
  expect_gt(length(result$errors), 0L)
})
