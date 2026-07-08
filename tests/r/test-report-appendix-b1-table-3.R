# test-report-appendix-b1-table-3.R — reproduction of report Appendix B1 Table 3
# (deposited sediment cover SAM1, fine-sediment SAM3, and the 10 substrate
# fractions) for EM1/EM3/EM5/EM7 in Spring 2025 (Nov-25) and Summer 2026
# (Feb-26). Asserts the exact printed values against process_sediment_summary_
# domain() output from the real database. Skips when that DB is unavailable.
#
# Appendix values are rounded percentages, so numeric comparisons use a 0.5
# tolerance against the raw stored values.

src_data("errors.R")
src_data("domain_types.R")
src_data("schemas.R")
src_data("validation.R")
src_data("config.R")
src_data("domains/sediment_ingest.R")
src_data("domains/sediment.R")
src_data("domains/sediment_size.R")
src_data("domains/sediment_summary.R")

# Each entry: SAM1, SAM3, and the 10 fractions (in SEDIMENT_SIZE column order),
# transcribed from Appendix B1 Table 3. ym = source Date year-month.
.APX <- list(
  list(site="EM1", ym="2025-11", sam1=9,  sam3=18, fr=c(8,10,7,12,33,27,2,0,0,1)),
  list(site="EM1", ym="2026-02", sam1=39, sam3=21, fr=c(20,1,17,19,28,15,0,0,0,0)),
  list(site="EM3", ym="2025-11", sam1=14, sam3=22, fr=c(12,10,7,13,24,29,3,1,0,1)),
  list(site="EM3", ym="2026-02", sam1=36, sam3=32, fr=c(25,7,17,24,19,8,0,0,0,0)),
  list(site="EM5", ym="2025-11", sam1=42, sam3=4,  fr=c(4,0,14,13,19,21,11,4,3,11)),
  list(site="EM5", ym="2026-02", sam1=47, sam3=8,  fr=c(8,0,3,5,21,24,15,3,2,19)),
  list(site="EM7", ym="2025-11", sam1=33, sam3=4,  fr=c(1,3,10,12,27,29,16,2,0,0)),
  list(site="EM7", ym="2026-02", sam1=69, sam3=23, fr=c(21,2,8,12,34,20,1,0,0,2))
)

# The 12 Variable labels in report order, aligned to (sam1, sam3, fr[1..10]).
.VARS <- c("Average sediment cover (%)", "Fine sediment cover (<2 mm)",
           SEDIMENT_SIZE_COLUMNS[5:14])

.near <- function(actual, expected, label, tol = 0.5) {
  ok <- length(actual) == 1 && !is.na(actual) && abs(actual - expected) <= tol
  expect_true(ok, info = sprintf("%s: expected ~%g (tol %g), got %s",
    label, expected, tol, if (length(actual) == 1) format(actual) else "<missing>"))
}

test_that("SedimentSummary reproduces report Appendix B1 Table 3", {
  cfg <- tryCatch(load_config(file.path(ROOT, "cycle.toml")),
                  error = function(e) NULL)
  skip_if(is.null(cfg), "cycle.toml not available")
  skip_if_not(file.exists(cfg$aquatic_monitoring_db),
              paste("aquatic_monitoring_db not reachable:", cfg$aquatic_monitoring_db))

  result <- process_sediment_summary_domain(cfg$aquatic_monitoring_db)
  expect_true(result$ok())
  df <- result$data$SedimentSummary
  df$ym <- format(as.Date(df$Date), "%Y-%m")

  for (e in .APX) {
    lbl <- paste(e$site, e$ym)
    site_rows <- df[df$Site == e$site & df$ym == e$ym, , drop = FALSE]
    # Expect all 12 measurement rows for this site x season.
    expect_equal(nrow(site_rows), length(.VARS),
                 info = paste(lbl, "measurement-row count"))
    expected <- c(e$sam1, e$sam3, e$fr)   # aligned to .VARS
    for (i in seq_along(.VARS)) {
      value <- site_rows$Value[site_rows$Variable == .VARS[i]]
      .near(value, expected[i], paste(lbl, .VARS[i]))
    }
  }
})
