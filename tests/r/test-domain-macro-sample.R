src_data("errors.R")
src_data("domain_types.R")
src_data("schemas.R")
src_data("domains/macro_ingest.R")
src_data("domains/macro.R")
src_data("domains/macro_sample.R")

# Build a synthetic RawData sheet: EM3 reps 1 & 2 (Surber) + EM1 (single sample).
# Layout mirrors the RawData contract in macro_ingest.R.
build_sample_xlsx <- function() {
  n_cols <- 4L + 3L
  mk <- function(...) { v <- c(...); length(v) <- n_cols; v[is.na(v)] <- ""; as.character(v) }
  rows <- list(
    mk("", "", "", ""),                                            # QA
    mk("", "", "", "", "Construction", "Construction", "Construction"),
    mk("", "", "", "", "2025-11-24", "2025-11-24", "2025-11-24"),
    mk("", "", "", "", "EM3", "EM3", "EM1"),                       # Site
    mk("", "", "", "", "1", "2", ""),                              # Replicate
    mk("Mayflies", "Deleatidium", "8", "5.6", "25", "21", "8"),
    mk("Beetles", "Elmidae", "6", "7.2", "74", "105", "13"),
    mk("Snails", "Potamopyrgus", "4", "2.1", "37", "56", ""),      # absent at EM1
    mk("", "Number of Taxa", "", "")                               # metrics marker
  )
  df <- as.data.frame(do.call(rbind, rows), stringsAsFactors = FALSE)
  tmp <- tempfile(fileext = ".xlsx")
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "RawData")
  openxlsx::writeData(wb, "RawData", x = df, colNames = FALSE)
  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)
  tmp
}

test_that("returns a DomainResult with MacroSampleData + schema columns", {
  result <- process_macro_sample_domain(build_sample_xlsx())
  expect_s3_class(result, "DomainResult")
  expect_true(result$ok())
  expect_equal(names(result$data$MacroSampleData), MACRO_SAMPLE_COLUMNS)
  # EM1: 2 taxa (Potamopyrgus absent); EM3 rep1: 3; EM3 rep2: 3 -> 8 rows.
  expect_equal(nrow(result$data$MacroSampleData), 8L)
})

test_that("season/year derived; zero counts filtered out", {
  df <- process_macro_sample_domain(build_sample_xlsx())$data$MacroSampleData
  expect_true(all(df$Season == "Spring"))
  expect_true(all(df$Year == 2025L))
  # Potamopyrgus present only at EM3 (count 0 at EM1 dropped).
  expect_setequal(df$Site[df$Species == "Potamopyrgus"], "EM3")
})

test_that("replicate is NA for the soft-bottom site, 1/2 for Surber reps", {
  df <- process_macro_sample_domain(build_sample_xlsx())$data$MacroSampleData
  expect_true(all(is.na(df$Replicate[df$Site == "EM1"])))
  expect_setequal(df$Replicate[df$Site == "EM3"], c(1L, 2L))
})

test_that("counts and MCI/MCI-sb tolerance scores are carried per taxon", {
  df <- process_macro_sample_domain(build_sample_xlsx())$data$MacroSampleData
  em3r1_elmidae <- df[df$Site == "EM3" & df$Replicate == 1 &
                        df$Species == "Elmidae", ]
  expect_equal(em3r1_elmidae$Count, 74L)
  expect_equal(em3r1_elmidae$MCI, 6)
  expect_equal(em3r1_elmidae$MCI_sb, 7.2)
  expect_equal(em3r1_elmidae$TaxaGroup, "Beetles")

  em1_del <- df[df$Site == "EM1" & df$Species == "Deleatidium", ]
  expect_equal(em1_del$Count, 8L)
  expect_equal(em1_del$MCI_sb, 5.6)

  # EM3 rep2 counts
  em3r2 <- df[df$Site == "EM3" & df$Replicate == 2, ]
  expect_equal(em3r2$Count[em3r2$Species == "Potamopyrgus"], 56L)
})

test_that("invalid path returns an error result", {
  result <- process_macro_sample_domain(tempfile(fileext = ".xlsx"))
  expect_false(result$ok())
  expect_gt(length(result$errors), 0L)
})
