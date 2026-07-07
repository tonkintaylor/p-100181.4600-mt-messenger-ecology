# test-report-appendix-b1-table-4.R — reproduction of report Appendix B1 Table 4
# (mean residual pool depth +/- 95% CI, since August 2024). Asserts the exact
# printed Mean (+/- CI) per Site x Season against process_rpd_summary_domain()
# output from the real database. Skips when that DB is unavailable.
# "-" cells (no survey that season) are asserted to produce no row.

src_data("errors.R")
src_data("domain_types.R")
src_data("schemas.R")
src_data("validation.R")
src_data("config.R")
src_data("domains/rpd.R")
src_data("domains/rpd_summary.R")

# The six report columns, in order.
.COLS <- list(
  c("Winter", "2024"), c("Spring", "2024"), c("Summer", "2025"),
  c("Spring", "2025"), c("Summer", "2026"), c("Autumn", "2026"))

# Per site: one entry per column -- NULL for "-", else c(mean, ci95).
.T4 <- list(
  EM1 = list(NULL, c(38.7,41.7), c(42.2,42.9), c(36.5,36.7), c(48.1,20.0), NULL),
  EM2 = list(NULL, c(66.7,47.3), c(78.7,62.1), c(69.5,117.5), c(78.8,78.0), NULL),
  EM3 = list(c(57.5,27.4), c(56.7,18.3), c(52.7,35.2), c(49.8,34.9), c(44.2,45.9), c(55.3,5.2)),
  EM4 = list(NULL, c(74.7,31.1), c(82.7,32.0), c(71.8,54.7), c(82.0,60.0), NULL),
  EM5 = list(NULL, NULL, c(30.2,13.3), c(23.8,19.8), c(29.8,19.1), NULL),
  EM7 = list(NULL, c(27.8,7.2), c(23.9,12.5), c(21.7,17.8), c(27.7,28.8), c(23.0,10.8)),
  EM8 = list(NULL, c(38.0,43.3), c(70.5,86.8), c(64.7,136.3), c(64.0,114.6), NULL)
)

.near <- function(actual, expected, label, tol = 0.1) {
  ok <- length(actual) == 1 && !is.na(actual) && abs(actual - expected) <= tol
  expect_true(ok, info = sprintf("%s: expected ~%g (tol %g), got %s",
    label, expected, tol, if (length(actual) == 1) format(actual) else "<missing>"))
}

test_that("RpdSummary reproduces report Appendix B1 Table 4", {
  cfg <- tryCatch(load_config(file.path(ROOT, "cycle.toml")),
                  error = function(e) NULL)
  skip_if(is.null(cfg), "cycle.toml not available")
  skip_if_not(file.exists(cfg$aquatic_monitoring_db),
              paste("aquatic_monitoring_db not reachable:", cfg$aquatic_monitoring_db))

  result <- process_rpd_summary_domain(cfg$aquatic_monitoring_db)
  expect_true(result$ok())
  df <- result$data$RpdSummary

  for (site in names(.T4)) {
    cells <- .T4[[site]]
    for (i in seq_along(.COLS)) {
      season <- .COLS[[i]][1]; year <- as.integer(.COLS[[i]][2])
      lbl <- sprintf("%s %s %d", site, season, year)
      row <- df[df$Site == site & df$Season == season & df$Year == year, ,
                drop = FALSE]
      expected <- cells[[i]]
      if (is.null(expected)) {
        expect_equal(nrow(row), 0L, info = paste(lbl, "should be absent (-)"))
      } else {
        expect_equal(nrow(row), 1L, info = paste(lbl, "row count"))
        if (nrow(row) != 1L) next
        .near(row$Mean, expected[1], paste(lbl, "Mean"))
        .near(row$CI95, expected[2], paste(lbl, "CI95"))
      }
    }
  }
})
