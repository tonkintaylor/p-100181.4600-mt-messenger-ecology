src_data("errors.R")
src_data("domain_types.R")
src_data("schemas.R")
src_data("domains/macro_ingest.R")
src_data("domains/macro_species.R")

# ---------------------------------------------------------------------------
# Helper: build a synthetic RawData xlsx (reuses approach from test-macro-ingest.R)
# ---------------------------------------------------------------------------
build_macro_xlsx_sp <- function(
    seasons    = c("Baseline", "Construction"),
    dates      = c("2020-01-01", "2024-06-15"),
    sites      = c("EM3", "EM5"),
    replicates = c("1", ""),
    taxa       = list(
      list(group = "Mayflies",   taxon = "Deleatidium",  mci = "8",  mci_sb = "7.0",
           counts = c("5", "3")),
      list(group = "Stoneflies", taxon = "Zelandoperla", mci = "10", mci_sb = "8.0",
           counts = c("0", "2"))
    ),
    metrics    = list(
      list(name = "MCI Value", values = c("100", "80"))
    ),
    sheet      = "RawData",
    omit_marker = FALSE
) {
  n_samples <- length(seasons)
  n_cols    <- 4L + n_samples

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
    taxa_rows,
    marker_row,
    metric_rows
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

# Default fixture path (analogous to example_macro_db in Python tests)
# dates: 2020-01-01 <= BASELINE_END (2022-03-31) -> Baseline
#        2024-06-15 > BASELINE_END               -> Construction
minimal_sp_path <- function() build_macro_xlsx_sp()

# ===========================================================================
# 1. Return type and basic structure
#    Mirrors: test_returns_domain_result, test_result_is_ok,
#             test_result_contains_macro_species_key
# ===========================================================================

test_that("process_macro_species_domain returns a DomainResult", {
  result <- process_macro_species_domain(minimal_sp_path())
  expect_s3_class(result, "DomainResult")
})

test_that("result is ok when data contains non-zero tallies", {
  result <- process_macro_species_domain(minimal_sp_path())
  expect_true(result$ok())
})

test_that("result data contains MacroSpecies key", {
  result <- process_macro_species_domain(minimal_sp_path())
  expect_true("MacroSpecies" %in% names(result$data))
})

# ===========================================================================
# 2. Column contract
#    Mirrors: test_has_correct_columns, test_has_correct_dtypes
# ===========================================================================

test_that("MacroSpecies has exactly MACRO_SPECIES_COLUMNS in order", {
  result <- process_macro_species_domain(minimal_sp_path())
  df <- result$data$MacroSpecies
  expect_equal(names(df), MACRO_SPECIES_COLUMNS)
})

test_that("Tally column is integer type", {
  result <- process_macro_species_domain(minimal_sp_path())
  df <- result$data$MacroSpecies
  expect_type(df$Tally, "integer")
})

test_that("is_additional column is logical type", {
  result <- process_macro_species_domain(minimal_sp_path())
  df <- result$data$MacroSpecies
  expect_type(df$is_additional, "logical")
})

test_that("Date column is Date class", {
  result <- process_macro_species_domain(minimal_sp_path())
  df <- result$data$MacroSpecies
  expect_s3_class(df$Date, "Date")
})

# ===========================================================================
# 3. Sparse format — only non-zero tallies emitted
#    Mirrors: test_no_zero_tallies, test_no_nan_tallies
# ===========================================================================

test_that("no zero tallies are emitted (sparse format)", {
  result <- process_macro_species_domain(minimal_sp_path())
  df <- result$data$MacroSpecies
  expect_true(all(df$Tally > 0L))
})

test_that("no NA tallies are present", {
  # fixture has one blank count ("") in some variant; minimal has 0, not NA
  result <- process_macro_species_domain(minimal_sp_path())
  df <- result$data$MacroSpecies
  expect_false(any(is.na(df$Tally)))
})

test_that("NA counts (blank cells) are excluded as well as zeros", {
  path <- build_macro_xlsx_sp(
    taxa = list(
      list(group = "Mayflies", taxon = "Deleatidium", mci = "8", mci_sb = "7",
           counts = c("", "3"))  # blank → NA integer → excluded
    )
  )
  result <- process_macro_species_domain(path)
  df <- result$data$MacroSpecies
  expect_true(all(df$Tally > 0L))
  expect_equal(nrow(df), 1L)  # only sample 2, taxon 1
})

# ===========================================================================
# 4. Phase derivation (Baseline vs Construction by date)
#    Mirrors: test_phase_values_are_seasons (values subset check)
# ===========================================================================

test_that("Phase is Baseline when date <= BASELINE_END", {
  path <- build_macro_xlsx_sp(
    seasons = c("Routine"),
    dates   = c("2020-01-01"),  # <= 2022-03-31
    sites   = c("EM3"),
    replicates = c("1"),
    taxa = list(
      list(group = "Mayflies", taxon = "Deleatidium", mci = "8", mci_sb = "7",
           counts = c("5"))
    ),
    metrics = list(list(name = "MCI Value", values = c("100")))
  )
  result <- process_macro_species_domain(path)
  df <- result$data$MacroSpecies
  expect_equal(unique(df$Phase), "Baseline")
})

test_that("Phase is Construction when date > BASELINE_END", {
  path <- build_macro_xlsx_sp(
    seasons = c("Routine"),
    dates   = c("2024-06-15"),  # > 2022-03-31
    sites   = c("EM3"),
    replicates = c("1"),
    taxa = list(
      list(group = "Mayflies", taxon = "Deleatidium", mci = "8", mci_sb = "7",
           counts = c("5"))
    ),
    metrics = list(list(name = "MCI Value", values = c("100")))
  )
  result <- process_macro_species_domain(path)
  df <- result$data$MacroSpecies
  expect_equal(unique(df$Phase), "Construction")
})

test_that("Phase is exactly on boundary date still Baseline", {
  path <- build_macro_xlsx_sp(
    seasons = c("Routine"),
    dates   = c("2022-03-31"),  # exactly BASELINE_END
    sites   = c("EM3"),
    replicates = c("1"),
    taxa = list(
      list(group = "Mayflies", taxon = "Deleatidium", mci = "8", mci_sb = "7",
           counts = c("5"))
    ),
    metrics = list(list(name = "MCI Value", values = c("100")))
  )
  result <- process_macro_species_domain(path)
  df <- result$data$MacroSpecies
  expect_equal(unique(df$Phase), "Baseline")
})

test_that("Phase values are only Baseline or Construction (never raw Season labels)", {
  result <- process_macro_species_domain(minimal_sp_path())
  df <- result$data$MacroSpecies
  expect_true(all(df$Phase %in% c("Baseline", "Construction")))
})

# ===========================================================================
# 5. is_additional flag
#    Mirrors: is_additional = (lowercased Season == "incident")
# ===========================================================================

test_that("is_additional is FALSE for non-incident seasons", {
  # minimal fixture uses Baseline/Construction seasons
  result <- process_macro_species_domain(minimal_sp_path())
  df <- result$data$MacroSpecies
  expect_false(any(df$is_additional))
})

test_that("is_additional is TRUE when Season is 'Incident' (case insensitive)", {
  path <- build_macro_xlsx_sp(
    seasons = c("Incident"),
    dates   = c("2024-06-15"),
    sites   = c("EM3"),
    replicates = c("1"),
    taxa = list(
      list(group = "Mayflies", taxon = "Deleatidium", mci = "8", mci_sb = "7",
           counts = c("5"))
    ),
    metrics = list(list(name = "MCI Value", values = c("100")))
  )
  result <- process_macro_species_domain(path)
  df <- result$data$MacroSpecies
  expect_true(all(df$is_additional))
})

test_that("is_additional is TRUE for lowercase 'incident'", {
  path <- build_macro_xlsx_sp(
    seasons = c("incident"),
    dates   = c("2024-06-15"),
    sites   = c("EM3"),
    replicates = c("1"),
    taxa = list(
      list(group = "Mayflies", taxon = "Deleatidium", mci = "8", mci_sb = "7",
           counts = c("5"))
    ),
    metrics = list(list(name = "MCI Value", values = c("100")))
  )
  result <- process_macro_species_domain(path)
  df <- result$data$MacroSpecies
  expect_true(all(df$is_additional))
})

test_that("is_additional is mixed when seasons differ", {
  path <- build_macro_xlsx_sp(
    seasons = c("Incident", "Routine"),
    dates   = c("2024-01-01", "2024-06-15"),
    sites   = c("EM3", "EM5"),
    replicates = c("1", ""),
    taxa = list(
      list(group = "Mayflies", taxon = "Deleatidium", mci = "8", mci_sb = "7",
           counts = c("5", "3"))
    ),
    metrics = list(list(name = "MCI Value", values = c("100", "80")))
  )
  result <- process_macro_species_domain(path)
  df <- result$data$MacroSpecies
  expect_true(any(df$is_additional))
  expect_true(any(!df$is_additional))
})

# ===========================================================================
# 6. Taxa and Species columns populated
#    Mirrors: test_taxa_column_populated, test_species_column_populated
# ===========================================================================

test_that("Taxa (TaxonGroup) column is fully populated (no NA, no empty string)", {
  result <- process_macro_species_domain(minimal_sp_path())
  df <- result$data$MacroSpecies
  expect_false(any(is.na(df$Taxa)))
  expect_false(any(trimws(df$Taxa) == ""))
})

test_that("Species (Taxon) column is fully populated (no NA, no empty string)", {
  result <- process_macro_species_domain(minimal_sp_path())
  df <- result$data$MacroSpecies
  expect_false(any(is.na(df$Species)))
  expect_false(any(trimws(df$Species) == ""))
})

# ===========================================================================
# 7. Row count — only non-zero rows emitted
# ===========================================================================

test_that("row count equals number of (sample, taxon) pairs with tally > 0", {
  # Fixture: Deleatidium: 5, 3 (both > 0); Zelandoperla: 0, 2 (one zero)
  # Expected rows: Deleatidium×sample1, Deleatidium×sample2, Zelandoperla×sample2 = 3
  result <- process_macro_species_domain(minimal_sp_path())
  df <- result$data$MacroSpecies
  expect_equal(nrow(df), 3L)
})

# ===========================================================================
# 8. Empty / error paths
#    Mirrors: test_all_zero_counts_returns_error, test_invalid_path_returns_error,
#             test_invalid_path_error_references_domain
# ===========================================================================

test_that("all-zero tallies yields error DomainResult", {
  path <- build_macro_xlsx_sp(
    taxa = list(
      list(group = "Mayflies", taxon = "Deleatidium", mci = "8", mci_sb = "7",
           counts = c("0", "0"))
    )
  )
  result <- process_macro_species_domain(path)
  expect_false(result$ok())
  expect_true(length(result$errors) > 0)
  expect_true(any(grepl("No non-zero taxa counts", vapply(result$errors,
                         function(e) e$message, character(1)))))
})

test_that("non-existent file returns error DomainResult", {
  result <- process_macro_species_domain(tempfile(fileext = ".xlsx"))
  expect_false(result$ok())
  expect_true(length(result$errors) > 0)
})

test_that("error for invalid path references MacroSpecies domain", {
  result <- process_macro_species_domain(tempfile(fileext = ".xlsx"))
  expect_equal(result$errors[[1]]$domain, "MacroSpecies")
})

test_that("error message for invalid path mentions failed read", {
  result <- process_macro_species_domain(tempfile(fileext = ".xlsx"))
  expect_match(result$errors[[1]]$message, "Failed to read RawData")
})

# ===========================================================================
# 9. Tally values are correct
# ===========================================================================

test_that("Tally values match source counts exactly", {
  result <- process_macro_species_domain(minimal_sp_path())
  df <- result$data$MacroSpecies
  # Deleatidium in sample1 = 5, sample2 = 3; Zelandoperla sample2 = 2
  expect_true(5L %in% df$Tally)
  expect_true(3L %in% df$Tally)
  expect_true(2L %in% df$Tally)
  # zero should never appear
  expect_false(0L %in% df$Tally)
})

# ===========================================================================
# 10. Site trimming preserved
# ===========================================================================

test_that("Site values in output are trimmed", {
  path <- build_macro_xlsx_sp(
    sites = c("EM3 ", " EM5"),
    taxa = list(
      list(group = "Mayflies", taxon = "Deleatidium", mci = "8", mci_sb = "7",
           counts = c("5", "3"))
    ),
    metrics = list(list(name = "MCI Value", values = c("100", "80")))
  )
  result <- process_macro_species_domain(path)
  df <- result$data$MacroSpecies
  expect_false(any(grepl("^ | $", df$Site)))
})
