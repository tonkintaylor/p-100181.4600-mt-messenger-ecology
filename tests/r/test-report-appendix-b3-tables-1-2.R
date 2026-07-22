# test-report-appendix-b3-tables-1-2.R — reproduction of report Appendix B3
# Tables 1 (Spring 2025) & 2 (Summer 2026): spot water-quality readings.
# Verified against process_field_wq_domain() output from the real database.
# Skips when the DB is unavailable.
#
# Data-quality notes (see memory / domain comments):
#  - EM2 summer DO (mg/L): the source originally held 88.5 (a data-entry error;
#    a misplaced decimal, inconsistent with its 87% saturation). The author
#    corrected the source value to 8.85 in the 2026 regeneration review, so the
#    expected value below is now 8.85. (The printed report still shows the old
#    88.5 and should be regenerated.)
#  - EM6 summer 2026: the source originally had a year typo (2025-02-25) which has
#    now been corrected to 2026-02-25, so EM6 appears in Summer 2026. The report's
#    PRINTED EM6 cells are corrupted (times in the conductivity/DO-%sat fields,
#    dashes for pH/DO); the pipeline yields the correct source values instead, so
#    EM6's expected values below are the true readings, not the printed garbage.

src_data("errors.R")
src_data("domain_types.R")
src_data("schemas.R")
src_data("config.R")
src_data("domains/field_wq.R")

# value order: date, time (NA=not recorded), temp, pH, cond, DO mg/L, DO %sat.
.SPRING <- list(
  EM1 = list("2025-11-24", "12:30", 13.9, NA,   162.2, 10.47, 101.7),
  EM2 = list("2025-11-24", "11:00", 13.8, NA,   182.0, 10.64, 102.2),
  EM3 = list("2025-11-24", "15:30", 17.3, NA,   202.2, 9.76,  101.8),
  EM4 = list("2025-11-17", NA,      10.9, 6.94, 141.8, 8.60,  78.2),
  EM6 = list("2025-11-17", NA,      11.3, 6.89, 117.7, 11.34, 105.0),
  EM7 = list("2025-11-17", NA,      13.0, 7.11, 375.9, 11.05, 105.0),
  EM8 = list("2025-11-17", NA,      12.2, 7.06, 146.8, 10.13, 95.2))
.SUMMER <- list(
  EM1 = list("2026-02-23", "15:07", 13.8, 7.36, 159.2, 9.20,  88.8),
  EM2 = list("2026-02-23", "13:25", 14.3, 7.46, 191.6, 8.85, 87.0),  # DO corrected in source (was 88.50)
  EM3 = list("2026-02-23", "09:55", 12.5, 6.98, 217.5, 9.69,  91.5),
  EM4 = list("2026-02-25", NA,      12.6, 7.23, 136.2, 7.78,  73.0),
  # EM6: correct source values (report printed corrupted cells for this site).
  EM6 = list("2026-02-25", "11:45", 12.7, 7.13, 143.6, 8.03,  75.6),
  EM7 = list("2026-02-25", NA,      15.8, 7.60, 421.3, 7.48,  76.0),
  EM8 = list("2026-02-25", NA,      13.2, NA,   118.6, 8.92,  83.8))

.num <- function(actual, expected, label) {
  if (is.na(expected)) {
    expect_true(is.na(actual), info = paste(label, "expected NA"))
  } else {
    expect_true(length(actual) == 1 && !is.na(actual) &&
                  abs(actual - expected) <= 1e-6,
                info = sprintf("%s: expected %g, got %s", label, expected,
                               if (length(actual) == 1) format(actual) else "<missing>"))
  }
}

check_season <- function(df, spec, season, year) {
  for (site in names(spec)) {
    e <- spec[[site]]
    lbl <- sprintf("%s %s %d", site, season, year)
    row <- df[df$Site == site & df$Season == season & df$Year == year, ,
              drop = FALSE]
    expect_equal(nrow(row), 1L, info = paste(lbl, "row count"))
    if (nrow(row) != 1L) next
    row <- as.list(row)
    expect_equal(as.character(row$Date), e[[1]], info = paste(lbl, "Date"))
    if (is.na(e[[2]])) expect_true(is.na(row$TimeTaken), info = paste(lbl, "Time"))
    else expect_equal(row$TimeTaken, e[[2]], info = paste(lbl, "Time"))
    .num(row$WaterTempC, e[[3]], paste(lbl, "WaterTempC"))
    .num(row$pH,         e[[4]], paste(lbl, "pH"))
    .num(row$SpecCond,   e[[5]], paste(lbl, "SpecCond"))
    .num(row$DO_mgL,     e[[6]], paste(lbl, "DO_mgL"))
    .num(row$DO_pctSat,  e[[7]], paste(lbl, "DO_pctSat"))
  }
}

test_that("FieldWQ reproduces report Appendix B3 Tables 1 & 2", {
  cfg <- tryCatch(load_config(file.path(ROOT, "cycle.toml")),
                  error = function(e) NULL)
  skip_if(is.null(cfg), "cycle.toml not available")
  skip_if_not(file.exists(cfg$aquatic_monitoring_db),
              paste("aquatic_monitoring_db not reachable:", cfg$aquatic_monitoring_db))

  result <- process_field_wq_domain(cfg$aquatic_monitoring_db)
  expect_true(result$ok())
  df <- result$data$FieldWQ
  df$Date <- as.Date(df$Date)

  check_season(df, .SPRING, "Spring", 2025)
  check_season(df, .SUMMER, "Summer", 2026)

  # Catchment grouping (derived) matches the appendix headers.
  expect_equal(unique(df$Catchment[df$Site == "EM1"]), "Mangapepeke")
  expect_equal(unique(df$Catchment[df$Site == "EM6"]), "Mimi")
})
