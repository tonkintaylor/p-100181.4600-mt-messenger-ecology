src_data("domains/macro_ingest.R")

# ---------------------------------------------------------------------------
# Helper: build a synthetic RawData sheet as openxlsx workbook.
#
# Structure (no header row; data starts at Excel row 1):
#   Row 1  (r=1): QA row      — cols A,B,C,D blank; sample cols can hold QA values
#   Row 2  (r=2): Season row  — sample cols hold season labels
#   Row 3  (r=3): Date row    — sample cols hold dates (text ISO or numeric serial)
#   Row 4  (r=4): Site row    — sample cols hold site names
#   Row 5  (r=5): Replicate   — sample cols hold replicate number or blank
#   Row 6+ (r=6+): taxa rows  — col A=TaxonGroup, B=Taxon, C=MCI, D=MCI_sb, E+=counts
#   Then:  marker row         — col B = "Number of Taxa"
#   Then:  metric rows        — col B = metric name, E+=numeric values
#
# All values are written as character (col_types="text" on read).
# We write with colNames=FALSE so no header row is added.
# ---------------------------------------------------------------------------
build_macro_xlsx <- function(
    seasons      = c("Baseline", "Construction"),
    dates        = c("2023-03-01", "2024-06-15"),
    sites        = c("EM3", "EM5"),
    replicates   = c("1", ""),       # blank = unreplicated
    taxa         = list(
      list(group = "Mayflies",  taxon = "Acanthophlebia", mci = "7",   mci_sb = "9.6",
           counts = c("2", "0")),
      list(group = "Stoneflies", taxon = "Zelandoperla",  mci = "10",  mci_sb = "8.0",
           counts = c("1", "3"))
    ),
    metrics      = list(
      list(name = "MCI Value",  values = c("100", "80"))
    ),
    sheet        = "RawData",
    omit_marker  = FALSE
) {
  n_samples <- length(seasons)
  # Columns: A(1), B(2), C(3), D(4), E(5)...(4+n_samples)
  n_cols <- 4L + n_samples

  # Build a character matrix; all cells start empty
  make_row <- function(...) {
    vals <- c(...)
    length(vals) <- n_cols
    vals[is.na(vals)] <- ""
    as.character(vals)
  }

  # 5 header rows
  hdr_qa      <- make_row("", "",  "", "",  rep("", n_samples))
  hdr_season  <- make_row("", "",  "", "",  seasons)
  hdr_date    <- make_row("", "",  "", "",  dates)
  hdr_site    <- make_row("", "",  "", "",  sites)
  hdr_rep     <- make_row("", "",  "", "",  replicates)

  # taxa rows
  taxa_rows <- lapply(taxa, function(t) {
    make_row(t$group, t$taxon, t$mci, t$mci_sb, t$counts)
  })

  # marker row (col B = "Number of Taxa")
  marker_row <- if (!omit_marker) {
    list(make_row("", "Number of Taxa", "", "", rep("", n_samples)))
  } else {
    list()
  }

  # metric rows
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

# ---------------------------------------------------------------------------
# Minimal fixture used across most tests
# ---------------------------------------------------------------------------
minimal_macro_path <- function() {
  build_macro_xlsx()
}

# ===========================================================================
# 1. Bundle structure
# ===========================================================================

test_that("ingest_raw_data returns a list with four named elements", {
  path   <- minimal_macro_path()
  result <- ingest_raw_data(path)
  expect_type(result, "list")
  expect_named(result, c("sample_metadata", "taxa_counts", "metric_rows", "mci_scores"),
               ignore.order = FALSE)
})

test_that("sample_metadata is a non-empty data.frame", {
  result <- ingest_raw_data(minimal_macro_path())
  expect_s3_class(result$sample_metadata, "data.frame")
  expect_gt(nrow(result$sample_metadata), 0L)
})

test_that("taxa_counts is a non-empty data.frame", {
  result <- ingest_raw_data(minimal_macro_path())
  expect_s3_class(result$taxa_counts, "data.frame")
  expect_gt(nrow(result$taxa_counts), 0L)
})

test_that("metric_rows is a non-empty data.frame", {
  result <- ingest_raw_data(minimal_macro_path())
  expect_s3_class(result$metric_rows, "data.frame")
  expect_gt(nrow(result$metric_rows), 0L)
})

test_that("mci_scores is a non-empty data.frame", {
  result <- ingest_raw_data(minimal_macro_path())
  expect_s3_class(result$mci_scores, "data.frame")
  expect_gt(nrow(result$mci_scores), 0L)
})

# ===========================================================================
# 2. sample_metadata — header parsing
# ===========================================================================

test_that("sample_metadata has expected columns", {
  result <- ingest_raw_data(minimal_macro_path())
  expect_true(all(c("sample_id", "Season", "Date", "Site", "Replicate") %in%
                    names(result$sample_metadata)))
})

test_that("sample_metadata has one row per sample column", {
  path   <- build_macro_xlsx(seasons = c("Baseline", "Construction", "Routine"),
                             dates   = c("2023-01-01", "2024-01-01", "2025-01-01"),
                             sites   = c("EM3", "EM5", "EM7"),
                             replicates = c("1", "2", ""))
  result <- ingest_raw_data(path)
  expect_equal(nrow(result$sample_metadata), 3L)
})

test_that("sample_metadata Season values match fixture", {
  result <- ingest_raw_data(minimal_macro_path())
  expect_equal(result$sample_metadata$Season, c("Baseline", "Construction"))
})

test_that("sample_metadata Site values are trimmed", {
  path   <- build_macro_xlsx(sites = c("EM3 ", " EM5"))
  result <- ingest_raw_data(path)
  expect_equal(result$sample_metadata$Site, c("EM3", "EM5"))
})

test_that("sample_metadata Site supports spaces in names like 'MMA 6'", {
  path   <- build_macro_xlsx(sites = c("MMA 6", "MMA 6b"))
  result <- ingest_raw_data(path)
  expect_equal(result$sample_metadata$Site, c("MMA 6", "MMA 6b"))
})

test_that("sample_metadata Date column is class Date", {
  result <- ingest_raw_data(minimal_macro_path())
  expect_s3_class(result$sample_metadata$Date, "Date")
})

test_that("sample_metadata Date parses text ISO dates correctly", {
  path   <- build_macro_xlsx(dates = c("2023-03-01", "2024-06-15"))
  result <- ingest_raw_data(path)
  expect_equal(result$sample_metadata$Date,
               as.Date(c("2023-03-01", "2024-06-15")))
})

test_that("sample_metadata Date parses Excel serial numbers correctly", {
  # Excel serial 45016 = 2023-03-17 (1899-12-30 origin)
  expected_date <- as.Date(45016, origin = "1899-12-30")
  path   <- build_macro_xlsx(dates = c("45016", "2024-06-15"))
  result <- ingest_raw_data(path)
  expect_equal(result$sample_metadata$Date[1], expected_date)
})

test_that("sample_metadata Replicate is integer", {
  result <- ingest_raw_data(minimal_macro_path())
  expect_type(result$sample_metadata$Replicate, "integer")
})

test_that("sample_metadata Replicate numeric values are correct", {
  path   <- build_macro_xlsx(replicates = c("1", "3"))
  result <- ingest_raw_data(path)
  expect_equal(result$sample_metadata$Replicate, c(1L, 3L))
})

test_that("sample_metadata Replicate is NA for blank cells", {
  path   <- build_macro_xlsx(replicates = c("1", ""))
  result <- ingest_raw_data(path)
  expect_equal(result$sample_metadata$Replicate[1], 1L)
  expect_true(is.na(result$sample_metadata$Replicate[2]))
})

test_that("sample_metadata sample_id is 1-based column index", {
  # With 2 sample columns, sample_ids should be 5 and 6 (1-based)
  result <- ingest_raw_data(minimal_macro_path())
  expect_equal(result$sample_metadata$sample_id, c(5L, 6L))
})

test_that("sample_metadata sample_id with 3 samples is 5,6,7", {
  path   <- build_macro_xlsx(seasons    = c("B", "C", "R"),
                             dates      = c("2023-01-01", "2024-01-01", "2025-01-01"),
                             sites      = c("EM3", "EM5", "EM7"),
                             replicates = c("1", "2", ""))
  result <- ingest_raw_data(path)
  expect_equal(result$sample_metadata$sample_id, c(5L, 6L, 7L))
})

# ===========================================================================
# 3. taxa_counts — taxa block extraction
# ===========================================================================

test_that("taxa_counts has TaxonGroup and Taxon columns", {
  result <- ingest_raw_data(minimal_macro_path())
  expect_true("TaxonGroup" %in% names(result$taxa_counts))
  expect_true("Taxon" %in% names(result$taxa_counts))
})

test_that("taxa_counts row count matches fixture taxa", {
  result <- ingest_raw_data(minimal_macro_path())
  expect_equal(nrow(result$taxa_counts), 2L)  # two taxa in minimal fixture
})

test_that("taxa_counts first row is Acanthophlebia (Mayflies)", {
  result <- ingest_raw_data(minimal_macro_path())
  expect_equal(result$taxa_counts$Taxon[1], "Acanthophlebia")
  expect_equal(result$taxa_counts$TaxonGroup[1], "Mayflies")
})

test_that("taxa_counts does NOT include marker or metric rows", {
  result <- ingest_raw_data(minimal_macro_path())
  taxon_vals <- result$taxa_counts$Taxon
  expect_false("Number of Taxa" %in% taxon_vals)
  expect_false("MCI Value" %in% taxon_vals)
})

test_that("taxa_counts sample columns are keyed by character sample_id", {
  result <- ingest_raw_data(minimal_macro_path())
  # sample_ids are 5 and 6; column names "5" and "6" should be present
  expect_true("5" %in% names(result$taxa_counts))
  expect_true("6" %in% names(result$taxa_counts))
})

test_that("taxa_counts sample columns have correct count of columns", {
  result <- ingest_raw_data(minimal_macro_path())
  # TaxonGroup + Taxon + 2 sample cols = 4
  expect_equal(ncol(result$taxa_counts), 4L)
})

test_that("taxa_counts sample values are integer type", {
  result <- ingest_raw_data(minimal_macro_path())
  expect_type(result$taxa_counts[["5"]], "integer")
  expect_type(result$taxa_counts[["6"]], "integer")
})

test_that("taxa_counts sample values match fixture counts", {
  result <- ingest_raw_data(minimal_macro_path())
  # Acanthophlebia: counts = c("2", "0")
  expect_equal(result$taxa_counts[["5"]][1], 2L)
  expect_equal(result$taxa_counts[["6"]][1], 0L)
  # Zelandoperla: counts = c("1", "3")
  expect_equal(result$taxa_counts[["5"]][2], 1L)
  expect_equal(result$taxa_counts[["6"]][2], 3L)
})

test_that("taxa_counts blank count cells become NA integer", {
  path <- build_macro_xlsx(
    taxa = list(
      list(group = "Mayflies", taxon = "Acanthophlebia", mci = "7", mci_sb = "9.6",
           counts = c("", "5"))
    )
  )
  result <- ingest_raw_data(path)
  expect_true(is.na(result$taxa_counts[["5"]][1]))
  expect_equal(result$taxa_counts[["6"]][1], 5L)
})

# ===========================================================================
# 4. mci_scores
# ===========================================================================

test_that("mci_scores has columns Taxon, MCI, MCI_sb", {
  result <- ingest_raw_data(minimal_macro_path())
  expect_equal(sort(names(result$mci_scores)), sort(c("Taxon", "MCI", "MCI_sb")))
})

test_that("mci_scores row count matches taxa_counts row count", {
  result <- ingest_raw_data(minimal_macro_path())
  expect_equal(nrow(result$mci_scores), nrow(result$taxa_counts))
})

test_that("mci_scores MCI and MCI_sb are numeric", {
  result <- ingest_raw_data(minimal_macro_path())
  expect_type(result$mci_scores$MCI, "double")
  expect_type(result$mci_scores$MCI_sb, "double")
})

test_that("mci_scores Acanthophlebia has MCI=7 and MCI_sb=9.6", {
  result <- ingest_raw_data(minimal_macro_path())
  row    <- result$mci_scores[result$mci_scores$Taxon == "Acanthophlebia", ]
  expect_equal(nrow(row), 1L)
  expect_equal(row$MCI, 7.0, tolerance = 1e-9)
  expect_equal(row$MCI_sb, 9.6, tolerance = 1e-9)
})

test_that("mci_scores blank MCI cells become NA", {
  path <- build_macro_xlsx(
    taxa = list(
      list(group = "Mayflies", taxon = "TaxonNoMCI", mci = "", mci_sb = "",
           counts = c("1", "2"))
    )
  )
  result <- ingest_raw_data(path)
  expect_true(is.na(result$mci_scores$MCI[1]))
  expect_true(is.na(result$mci_scores$MCI_sb[1]))
})

# ===========================================================================
# 5. metric_rows
# ===========================================================================

test_that("metric_rows has Metric column", {
  result <- ingest_raw_data(minimal_macro_path())
  expect_true("Metric" %in% names(result$metric_rows))
})

test_that("metric_rows first row has Metric = 'Number of Taxa'", {
  result <- ingest_raw_data(minimal_macro_path())
  expect_equal(result$metric_rows$Metric[1], "Number of Taxa")
})

test_that("metric_rows contains additional metric rows from fixture", {
  result <- ingest_raw_data(minimal_macro_path())
  expect_true("MCI Value" %in% result$metric_rows$Metric)
})

test_that("metric_rows sample columns are keyed by character sample_id", {
  result <- ingest_raw_data(minimal_macro_path())
  expect_true("5" %in% names(result$metric_rows))
  expect_true("6" %in% names(result$metric_rows))
})

test_that("metric_rows sample values are numeric", {
  result <- ingest_raw_data(minimal_macro_path())
  expect_type(result$metric_rows[["5"]], "double")
  expect_type(result$metric_rows[["6"]], "double")
})

test_that("metric_rows sample values match fixture values", {
  result <- ingest_raw_data(minimal_macro_path())
  # MCI Value row: values = c("100", "80")
  mci_row <- result$metric_rows[result$metric_rows$Metric == "MCI Value", ]
  expect_equal(mci_row[["5"]], 100.0, tolerance = 1e-9)
  expect_equal(mci_row[["6"]], 80.0, tolerance = 1e-9)
})

test_that("metric_rows column count equals 1 (Metric) + n_samples", {
  result <- ingest_raw_data(minimal_macro_path())
  # 1 Metric col + 2 sample cols = 3
  expect_equal(ncol(result$metric_rows), 3L)
})

# ===========================================================================
# 6. Error handling — mirrors TestIngestErrorHandling in test_macro_ingest.py
# ===========================================================================

test_that("raises ingest_error for missing file", {
  expect_error(
    ingest_raw_data(tempfile(fileext = ".xlsx")),
    class = "ingest_error"
  )
})

test_that("missing file error message mentions the path", {
  fake_path <- tempfile(fileext = ".xlsx")
  err <- tryCatch(ingest_raw_data(fake_path), error = function(e) e)
  expect_s3_class(err, "ingest_error")
  # message should reference the path (or at least say Cannot read)
  expect_match(conditionMessage(err), "Cannot read 'RawData' sheet", fixed = TRUE)
})

test_that("raises ingest_error when RawData sheet is missing", {
  tmp <- tempfile(fileext = ".xlsx")
  wb  <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Other")
  openxlsx::writeData(wb, "Other", data.frame(x = 1))
  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)

  expect_error(ingest_raw_data(tmp), class = "ingest_error")
})

test_that("missing RawData sheet error message mentions 'RawData'", {
  tmp <- tempfile(fileext = ".xlsx")
  wb  <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Other")
  openxlsx::writeData(wb, "Other", data.frame(x = 1))
  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)

  err <- tryCatch(ingest_raw_data(tmp), error = function(e) e)
  expect_match(conditionMessage(err), "Cannot read 'RawData' sheet", fixed = TRUE)
})

test_that("raises ingest_error when 'Number of Taxa' marker is absent", {
  path <- build_macro_xlsx(omit_marker = TRUE)
  expect_error(ingest_raw_data(path), class = "ingest_error")
})

test_that("missing marker error message mentions 'Number of Taxa'", {
  path <- build_macro_xlsx(omit_marker = TRUE)
  err  <- tryCatch(ingest_raw_data(path), error = function(e) e)
  expect_s3_class(err, "ingest_error")
  expect_match(conditionMessage(err), "Number of Taxa", fixed = TRUE)
})

test_that("missing marker error message mentions 'marker not found'", {
  path <- build_macro_xlsx(omit_marker = TRUE)
  err  <- tryCatch(ingest_raw_data(path), error = function(e) e)
  expect_match(conditionMessage(err), "marker not found", fixed = TRUE)
})

# ===========================================================================
# 7. Replicate coercion edge cases
# ===========================================================================

test_that("replicate stored as float string '3.0' coerces to 3L", {
  path   <- build_macro_xlsx(replicates = c("3.0", "1"))
  result <- ingest_raw_data(path)
  expect_equal(result$sample_metadata$Replicate[1], 3L)
})

test_that("replicate 'NA' string coerces to NA integer", {
  path   <- build_macro_xlsx(replicates = c("NA", "1"))
  result <- ingest_raw_data(path)
  expect_true(is.na(result$sample_metadata$Replicate[1]))
})

# ===========================================================================
# 8. Marker detection — only first occurrence used
# ===========================================================================

test_that("when multiple marker rows present only first splits the block", {
  # Build a fixture with two 'Number of Taxa' rows in metrics section
  path <- build_macro_xlsx(
    metrics = list(
      list(name = "Number of Taxa", values = c("5", "7")),  # second marker occurrence
      list(name = "MCI Value",      values = c("100", "80"))
    )
  )
  result <- ingest_raw_data(path)
  # taxa_counts should still only have our 2 taxa (marker in header block doesn't appear)
  expect_equal(nrow(result$taxa_counts), 2L)
  # metric_rows first row is "Number of Taxa"
  expect_equal(result$metric_rows$Metric[1], "Number of Taxa")
})

# ===========================================================================
# 9. taxa_counts lookup by sample_id (key convention check)
# ===========================================================================

test_that("taxa_counts can be accessed by as.character(sample_id)", {
  result <- ingest_raw_data(minimal_macro_path())
  sid    <- result$sample_metadata$sample_id[1]  # 5L
  col    <- result$taxa_counts[[as.character(sid)]]
  expect_false(is.null(col))
  expect_equal(col[1], 2L)  # Acanthophlebia count in first sample
})
