src_data("errors.R")
src_data("domain_types.R")
src_data("schemas.R")
src_data("domains/macro_ingest.R")
src_data("domains/macro.R")

# ---------------------------------------------------------------------------
# Shared synthetic data for derive_metrics tests (mirrors test_macro.py fixtures)
# ---------------------------------------------------------------------------
make_sample_taxa_counts <- function() {
  data.frame(
    TaxonGroup = c("Mayflies", "Mayflies", "Stoneflies", "Caddisflies", "Oligochaeta"),
    Taxon      = c("Deleatidium", "Coloburiscus", "Zelandobius", "Oxyethira", "Oligochaeta"),
    "4"        = c(10L, 5L, 3L, 2L, 8L),
    stringsAsFactors = FALSE, check.names = FALSE
  )
}

make_sample_mci_scores <- function() {
  data.frame(
    Taxon  = c("Deleatidium", "Coloburiscus", "Zelandobius", "Oxyethira", "Oligochaeta"),
    MCI    = c(8.0, 9.0, 5.0, 4.0, 1.0),
    MCI_sb = c(7.0, 8.0, 4.0, 3.0, 1.0),
    stringsAsFactors = FALSE
  )
}

# ---------------------------------------------------------------------------
# Helper: build a synthetic macro xlsx (reuses approach from test-macro-ingest.R)
# ---------------------------------------------------------------------------
build_macro_xlsx_domain <- function(
    seasons      = c("Baseline", "Construction"),
    dates        = c("2023-03-01", "2024-06-15"),
    sites        = c("EM3", "EM5"),
    replicates   = c("1", ""),
    taxa         = list(
      list(group = "Mayflies",  taxon = "Acanthophlebia", mci = "7",  mci_sb = "9.6",
           counts = c("2", "0")),
      list(group = "Stoneflies", taxon = "Zelandoperla",  mci = "10", mci_sb = "8.0",
           counts = c("1", "3"))
    ),
    metrics      = list(
      list(name = "MCI Value", values = c("100", "80"))
    ),
    sheet        = "RawData",
    omit_marker  = FALSE
) {
  n_samples <- length(seasons)
  n_cols <- 4L + n_samples

  make_row <- function(...) {
    vals <- c(...)
    length(vals) <- n_cols
    vals[is.na(vals)] <- ""
    as.character(vals)
  }

  hdr_qa     <- make_row("", "", "", "", rep("", n_samples))
  hdr_season <- make_row("", "", "", "", seasons)
  hdr_date   <- make_row("", "", "", "", dates)
  hdr_site   <- make_row("", "", "", "", sites)
  hdr_rep    <- make_row("", "", "", "", replicates)

  taxa_rows <- lapply(taxa, function(t) {
    make_row(t$group, t$taxon, t$mci, t$mci_sb, t$counts)
  })

  marker_row <- if (!omit_marker) {
    list(make_row("", "Number of Taxa", "", "", rep("", n_samples)))
  } else {
    list()
  }

  metric_rows <- lapply(metrics, function(m) {
    make_row("", m$name, "", "", m$values)
  })

  all_rows <- c(
    list(hdr_qa, hdr_season, hdr_date, hdr_site, hdr_rep),
    taxa_rows, marker_row, metric_rows
  )

  mat <- do.call(rbind, all_rows)
  df  <- as.data.frame(mat, stringsAsFactors = FALSE)

  tmp <- tempfile(fileext = ".xlsx")
  wb  <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, sheet)
  openxlsx::writeData(wb, sheet, x = df, colNames = FALSE)
  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)
  tmp
}

# ---------------------------------------------------------------------------
# Fixture for process_macro_domain tests: includes replicated + non-replicated
# sites, multiple period/season types.
#
# Sites: EM3 (replicated), EM1 (non-replicated / SITES_WITHOUT_REPLICATES)
# Dates that hit different normalise_period / normalise_season paths:
#   - 2018-10-25 Baseline (before BASELINE_END, Spring)
#   - 2022-10-17 Construction (after BASELINE_END, Spring)
#   - 2024-01-12 Additional (Incident + incident response)
#   - 2024-02-20 Construction (Summer)
# ---------------------------------------------------------------------------
make_full_macro_path <- function() {
  build_macro_xlsx_domain(
    seasons    = c("Baseline",    "Construction", "Additional",   "Construction"),
    dates      = c("2018-10-25",  "2022-10-17",   "2024-01-12",   "2024-02-20"),
    sites      = c("EM3",         "EM3",          "EM1",          "EM3"),
    replicates = c("1",           "1",            "",             "1"),
    taxa = list(
      list(group = "Mayflies",   taxon = "Deleatidium",  mci = "8",  mci_sb = "7",
           counts = c("10", "5", "3", "8")),
      list(group = "Stoneflies", taxon = "Zelandobius",  mci = "5",  mci_sb = "4",
           counts = c("3",  "2", "1", "2")),
      list(group = "Caddisflies",taxon = "Oxyethira",    mci = "4",  mci_sb = "3",
           counts = c("2",  "1", "0", "1")),
      list(group = "Oligochaeta",taxon = "Oligochaeta",  mci = "1",  mci_sb = "1",
           counts = c("8",  "4", "2", "4"))
    ),
    metrics = list(
      list(name = "MCI Value", values = c("80", "70", "60", "75"))
    )
  )
}

# ===========================================================================
# 1. normalise_period — mirrors TestNormalisePeriod in test_macro.py
# ===========================================================================

test_that("normalise_period: construction before cutoff → Baseline", {
  expect_equal(normalise_period("Construction", "2022-03-15"), "Baseline")
})

test_that("normalise_period: construction on cutoff → Baseline", {
  expect_equal(normalise_period("Construction", "2022-03-31"), "Baseline")
})

test_that("normalise_period: baseline on cutoff → Baseline", {
  expect_equal(normalise_period("Baseline", "2022-03-31"), "Baseline")
})

test_that("normalise_period: construction after cutoff → Routine Construction", {
  expect_equal(normalise_period("Construction", "2022-04-01"), "Routine Construction")
})

test_that("normalise_period: baseline after cutoff → Baseline", {
  expect_equal(normalise_period("Baseline", "2022-04-01"), "Baseline")
})

test_that("normalise_period: additional after cutoff → Incident", {
  expect_equal(normalise_period("Additional", "2022-04-01"), "Incident")
})

test_that("normalise_period: baseline well before cutoff → Baseline", {
  expect_equal(normalise_period("Baseline", "2018-10-25"), "Baseline")
})

test_that("normalise_period: NA date uses label map (Construction → Routine Construction)", {
  expect_equal(normalise_period("Construction", NA), "Routine Construction")
})

test_that("normalise_period: unmapped label defaults to Routine Construction", {
  expect_equal(normalise_period("UnknownPhase", "2023-06-01"), "Routine Construction")
})

# ===========================================================================
# 2. normalise_season
# ===========================================================================

test_that("normalise_season: Additional → incident response", {
  expect_equal(normalise_season("Additional", "2024-01-12"), "incident response")
})

test_that("normalise_season: October → Spring", {
  expect_equal(normalise_season("Construction", "2022-10-17"), "Spring")
})

test_that("normalise_season: November → Spring", {
  expect_equal(normalise_season("Construction", "2022-11-15"), "Spring")
})

test_that("normalise_season: December → Spring", {
  expect_equal(normalise_season("Construction", "2022-12-01"), "Spring")
})

test_that("normalise_season: February → Summer", {
  expect_equal(normalise_season("Construction", "2024-02-20"), "Summer")
})

test_that("normalise_season: January → Summer", {
  expect_equal(normalise_season("Construction", "2024-01-12"), "Summer")
})

# ===========================================================================
# 3. derive_metrics — mirrors TestDeriveMetrics in test_macro.py
# ===========================================================================

test_that("derive_metrics: Number of Taxa", {
  result <- derive_metrics(make_sample_taxa_counts(), make_sample_mci_scores(), "4")
  expect_equal(result[["Number of Taxa"]], 5L)
})

test_that("derive_metrics: Number of Individuals (10+5+3+2+8=28)", {
  result <- derive_metrics(make_sample_taxa_counts(), make_sample_mci_scores(), "4")
  expect_equal(result[["Number of Individuals"]], 28L)
})

test_that("derive_metrics: MCI = (27/5)*20 = 108", {
  result <- derive_metrics(make_sample_taxa_counts(), make_sample_mci_scores(), "4")
  # Scores: 8,9,5,4,1 → sum=27, count=5 → MCI=(27/5)*20=108
  expect_equal(result[["MCI"]], 108.0, tolerance = 1e-7)
})

test_that("derive_metrics: MCI-sb = (23/5)*20 = 92", {
  result <- derive_metrics(make_sample_taxa_counts(), make_sample_mci_scores(), "4")
  # Scores: 7,8,4,3,1 → sum=23, count=5 → MCI-sb=(23/5)*20=92
  expect_equal(result[["MCI-sb"]], 92.0, tolerance = 1e-7)
})

test_that("derive_metrics: QMCI = 156/28", {
  result <- derive_metrics(make_sample_taxa_counts(), make_sample_mci_scores(), "4")
  # 10*8 + 5*9 + 3*5 + 2*4 + 8*1 = 80+45+15+8+8 = 156 / 28
  expect_equal(result[["QMCI"]], 156 / 28, tolerance = 1e-7)
})

test_that("derive_metrics: QMCI-sb = 136/28", {
  result <- derive_metrics(make_sample_taxa_counts(), make_sample_mci_scores(), "4")
  # 10*7 + 5*8 + 3*4 + 2*3 + 8*1 = 70+40+12+6+8 = 136 / 28
  expect_equal(result[["QMCI-sb"]], 136 / 28, tolerance = 1e-7)
})

test_that("derive_metrics: EPT Richness = 3 (Oxyethira excluded as Hydroptilidae)", {
  result <- derive_metrics(make_sample_taxa_counts(), make_sample_mci_scores(), "4")
  # E=2 (Deleatidium+Coloburiscus), P=1 (Zelandobius), T=0 (Oxyethira excluded)
  expect_equal(result[["EPT Richness"]], 3L)
})

test_that("derive_metrics: EPT Abundance = 18 (excludes Oxyethira)", {
  result <- derive_metrics(make_sample_taxa_counts(), make_sample_mci_scores(), "4")
  # Mayflies(10+5) + Stoneflies(3) + Caddisflies excl Hydro(0) = 18
  expect_equal(result[["EPT Abundance"]], 18L)
})

test_that("derive_metrics: % EPT Abundance = 18/28", {
  result <- derive_metrics(make_sample_taxa_counts(), make_sample_mci_scores(), "4")
  expect_equal(result[["% EPT Abundance"]], 18 / 28, tolerance = 1e-7)
})

test_that("derive_metrics: % EPT Richness = 3/5", {
  result <- derive_metrics(make_sample_taxa_counts(), make_sample_mci_scores(), "4")
  expect_equal(result[["% EPT Richness"]], 3 / 5, tolerance = 1e-7)
})

test_that("derive_metrics: ASPM-MCI = mean(108/200, 3/29, 18/100)", {
  result <- derive_metrics(make_sample_taxa_counts(), make_sample_mci_scores(), "4")
  expected <- mean(c(108 / 200, 3 / 29, 18 / 100))
  expect_equal(result[["ASPM-MCI"]], expected, tolerance = 1e-7)
})

test_that("derive_metrics: E/P/T richness breakdown", {
  result <- derive_metrics(make_sample_taxa_counts(), make_sample_mci_scores(), "4")
  expect_equal(result[["E Richness"]], 2L)
  expect_equal(result[["P Richness"]], 1L)
  expect_equal(result[["T Richness"]], 0L)
})

test_that("derive_metrics: Hydroptilidae genus Paroxyethira also excluded", {
  taxa <- data.frame(
    TaxonGroup = c("Mayflies", "Caddisflies", "Caddisflies"),
    Taxon      = c("Deleatidium", "Paroxyethira", "Hudsonema"),
    "4"        = c(5L, 2L, 3L),
    stringsAsFactors = FALSE, check.names = FALSE
  )
  scores <- data.frame(
    Taxon  = c("Deleatidium", "Paroxyethira", "Hudsonema"),
    MCI    = c(8.0, 4.0, 6.0),
    MCI_sb = c(7.0, 3.0, 5.0),
    stringsAsFactors = FALSE
  )
  result <- derive_metrics(taxa, scores, "4")
  # T richness: Paroxyethira excluded → only Hudsonema counts → T=1
  expect_equal(result[["T Richness"]], 1L)
  # EPT Richness: E=1, P=0, T=1 = 2
  expect_equal(result[["EPT Richness"]], 2L)
  # EPT Abundance: Deleatidium(5) + Hudsonema(3) = 8 (Paroxyethira excluded)
  expect_equal(result[["EPT Abundance"]], 8L)
})

test_that("derive_metrics: zero-abundance taxa do not contribute", {
  taxa <- data.frame(
    TaxonGroup = c("Mayflies", "Stoneflies"),
    Taxon      = c("Deleatidium", "Zelandobius"),
    "4"        = c(5L, 0L),
    stringsAsFactors = FALSE, check.names = FALSE
  )
  scores <- data.frame(
    Taxon  = c("Deleatidium", "Zelandobius"),
    MCI    = c(8.0, 5.0),
    MCI_sb = c(7.0, 4.0),
    stringsAsFactors = FALSE
  )
  result <- derive_metrics(taxa, scores, "4")
  expect_equal(result[["Number of Taxa"]], 1L)
  expect_equal(result[["Number of Individuals"]], 5L)
  # Only Deleatidium present: MCI = (8/1)*20 = 160
  expect_equal(result[["MCI"]], 160.0, tolerance = 1e-7)
})

test_that("derive_metrics: all-NA counts → zero taxa, NaN MCI", {
  taxa <- data.frame(
    TaxonGroup = c("Mayflies"),
    Taxon      = c("Deleatidium"),
    "4"        = c(NA_integer_),
    stringsAsFactors = FALSE, check.names = FALSE
  )
  scores <- data.frame(
    Taxon  = c("Deleatidium"),
    MCI    = c(8.0),
    MCI_sb = c(7.0),
    stringsAsFactors = FALSE
  )
  result <- derive_metrics(taxa, scores, "4")
  expect_equal(result[["Number of Taxa"]], 0L)
  expect_equal(result[["Number of Individuals"]], 0L)
  expect_true(is.na(result[["MCI"]]))
})

test_that("derive_metrics: QMCI fillna(0) — taxon with NA MCI contributes abundance to denominator", {
  # Oligochaeta has NA MCI → should not contribute to numerator but should to denominator
  taxa <- data.frame(
    TaxonGroup = c("Mayflies", "Oligochaeta"),
    Taxon      = c("Deleatidium", "TaxonNoMCI"),
    "4"        = c(5L, 10L),
    stringsAsFactors = FALSE, check.names = FALSE
  )
  scores <- data.frame(
    Taxon  = c("Deleatidium", "TaxonNoMCI"),
    MCI    = c(8.0, NA_real_),
    MCI_sb = c(7.0, NA_real_),
    stringsAsFactors = FALSE
  )
  result <- derive_metrics(taxa, scores, "4")
  # QMCI = (5*8 + 10*0) / 15 = 40/15
  expect_equal(result[["QMCI"]], 40 / 15, tolerance = 1e-7)
  # QMCI-sb = (5*7 + 10*0) / 15 = 35/15
  expect_equal(result[["QMCI-sb"]], 35 / 15, tolerance = 1e-7)
})

# ===========================================================================
# 4. process_macro_domain — mirrors TestProcessMacroDomain in test_macro.py
# ===========================================================================

test_that("process_macro_domain: returns DomainResult", {
  path   <- make_full_macro_path()
  result <- process_macro_domain(path)
  expect_s3_class(result, "DomainResult")
})

test_that("process_macro_domain: result is ok (no error-level errors)", {
  path   <- make_full_macro_path()
  result <- process_macro_domain(path)
  expect_true(result$ok())
})

test_that("process_macro_domain: result contains Macro1 and Macro", {
  path   <- make_full_macro_path()
  result <- process_macro_domain(path)
  expect_true("Macro1" %in% names(result$data))
  expect_true("Macro"  %in% names(result$data))
})

test_that("process_macro_domain: Macro1 has correct columns", {
  path   <- make_full_macro_path()
  result <- process_macro_domain(path)
  expect_equal(names(result$data$Macro1), MACRO1_COLUMNS)
})

test_that("process_macro_domain: Macro has correct columns", {
  path   <- make_full_macro_path()
  result <- process_macro_domain(path)
  expect_equal(names(result$data$Macro), MACRO1_COLUMNS)
})

test_that("process_macro_domain: Macro1 has rows", {
  path   <- make_full_macro_path()
  result <- process_macro_domain(path)
  expect_gt(nrow(result$data$Macro1), 0L)
})

test_that("process_macro_domain: Macro excludes SITES_WITHOUT_REPLICATES", {
  path   <- make_full_macro_path()
  result <- process_macro_domain(path)
  sites_in_macro <- unique(result$data$Macro$Site)
  expect_false(any(sites_in_macro %in% SITES_WITHOUT_REPLICATES))
})

test_that("process_macro_domain: Macro has fewer rows than Macro1", {
  path   <- make_full_macro_path()
  result <- process_macro_domain(path)
  expect_lt(nrow(result$data$Macro), nrow(result$data$Macro1))
})

test_that("process_macro_domain: QMCI-sb used for non-replicate sites (EM1)", {
  path   <- make_full_macro_path()
  result <- process_macro_domain(path)
  macro1 <- result$data$Macro1

  # EM1 is in SITES_WITHOUT_REPLICATES
  non_rep <- macro1[macro1$Site %in% SITES_WITHOUT_REPLICATES, , drop = FALSE]
  expect_gt(nrow(non_rep), 0L)
  expect_true(all(!is.na(non_rep$QMCI)))

  # Verify it used QMCI-sb by computing directly
  bundle     <- ingest_raw_data(path)
  meta_lookup <- bundle$sample_metadata
  for (i in seq_len(nrow(meta_lookup))) {
    m    <- meta_lookup[i, ]
    site <- trimws(as.character(m$Site))
    if (site %in% SITES_WITHOUT_REPLICATES) {
      metrics <- derive_metrics(bundle$taxa_counts, bundle$mci_scores,
                                as.character(m$sample_id))
      pipeline_row <- macro1[macro1$Site == site &
                               macro1$Date == as.Date(m$Date), , drop = FALSE]
      expect_equal(pipeline_row$QMCI[1], metrics[["QMCI-sb"]], tolerance = 1e-9)
      # Also confirm it differs from the non-sb value
      if (!is.na(metrics[["QMCI"]]) && !is.na(metrics[["QMCI-sb"]])) {
        if (abs(metrics[["QMCI"]] - metrics[["QMCI-sb"]]) > 1e-12) {
          expect_false(isTRUE(all.equal(pipeline_row$QMCI[1], metrics[["QMCI"]],
                                        tolerance = 1e-9)))
        }
      }
      break
    }
  }
})

test_that("process_macro_domain: period normalises to Baseline for 2018-10-25", {
  path   <- make_full_macro_path()
  result <- process_macro_domain(path)
  macro1 <- result$data$Macro1
  baseline_rows <- macro1[macro1$Date == as.Date("2018-10-25"), , drop = FALSE]
  expect_gt(nrow(baseline_rows), 0L)
  expect_true(all(baseline_rows$Period == "Baseline"))
})

test_that("process_macro_domain: period normalises to Routine Construction for 2022-10-17", {
  path   <- make_full_macro_path()
  result <- process_macro_domain(path)
  macro1 <- result$data$Macro1
  construction_rows <- macro1[macro1$Date == as.Date("2022-10-17"), , drop = FALSE]
  expect_gt(nrow(construction_rows), 0L)
  expect_true(all(construction_rows$Period == "Routine Construction"))
})

test_that("process_macro_domain: period normalises to Incident for 2024-01-12 (Additional)", {
  path   <- make_full_macro_path()
  result <- process_macro_domain(path)
  macro1 <- result$data$Macro1
  incident_rows <- macro1[macro1$Date == as.Date("2024-01-12"), , drop = FALSE]
  expect_gt(nrow(incident_rows), 0L)
  expect_true(all(incident_rows$Period == "Incident"))
})

test_that("process_macro_domain: season Spring for October dates", {
  path   <- make_full_macro_path()
  result <- process_macro_domain(path)
  macro1 <- result$data$Macro1
  # Convert Date to Date class if not already
  macro1$Date <- as.Date(macro1$Date)
  oct_rows <- macro1[as.integer(format(macro1$Date, "%m")) == 10, , drop = FALSE]
  expect_gt(nrow(oct_rows), 0L)
  expect_true(all(oct_rows$Season == "Spring"))
})

test_that("process_macro_domain: season Summer for February dates", {
  path   <- make_full_macro_path()
  result <- process_macro_domain(path)
  macro1 <- result$data$Macro1
  macro1$Date <- as.Date(macro1$Date)
  feb_rows <- macro1[as.integer(format(macro1$Date, "%m")) == 2, , drop = FALSE]
  expect_gt(nrow(feb_rows), 0L)
  expect_true(all(feb_rows$Season == "Summer"))
})

test_that("process_macro_domain: season incident response for Additional monitoring", {
  path   <- make_full_macro_path()
  result <- process_macro_domain(path)
  macro1 <- result$data$Macro1
  incident_rows <- macro1[macro1$Period == "Incident", , drop = FALSE]
  expect_gt(nrow(incident_rows), 0L)
  expect_true(all(incident_rows$Season == "incident response"))
})

test_that("process_macro_domain: invalid path returns error result", {
  result <- process_macro_domain(tempfile(fileext = ".xlsx"))
  expect_false(result$ok())
  expect_gt(length(result$errors), 0L)
})
