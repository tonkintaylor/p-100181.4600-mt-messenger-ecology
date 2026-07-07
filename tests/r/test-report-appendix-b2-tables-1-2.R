# test-report-appendix-b2-tables-1-2.R — reproduction of report Appendix B2
# Tables 1 (Spring 2025) & 2 (Summer 2026): the raw macroinvertebrate count
# matrices. Verified against process_macro_sample_domain() output from the real
# database. Skips when the DB is unavailable.
#
# These are ~1500-cell raw dumps; rather than transcribe every (mostly blank)
# cell, the test verifies: (a) the sample columns + dates per season, (b) the
# MCI/MCI-sb tolerance scores per taxon, and (c) precise counts for the abundant
# taxa whose leading columns are unambiguous -- covering all five replicate
# columns of EM3 in each season.

src_data("errors.R")
src_data("domain_types.R")
src_data("schemas.R")
src_data("config.R")
src_data("domains/macro_ingest.R")
src_data("domains/macro.R")
src_data("domains/macro_sample.R")

# Count for one (season, year, site, replicate, species); NA if no such row.
.cnt <- function(df, season, year, site, rep, sp) {
  sel <- df$Season == season & df$Year == year & df$Site == site &
    df$Species == sp &
    (if (is.na(rep)) is.na(df$Replicate) else
      (!is.na(df$Replicate) & df$Replicate == rep))
  if (sum(sel) == 1L) df$Count[sel] else NA_integer_
}

# MCI/MCI-sb tolerance scores per taxon, from the appendix header columns.
.MCI <- list(
  Coloburiscus = c(9, 8.1), Deleatidium = c(8, 5.6), Ichthybotus = c(8, 9.2),
  Neozephlebia = c(7, 7.6), Zephlebia = c(7, 8.8), Acroperla = c(5, 5.1),
  Austroperla = c(9, 8.4), Archichauliodes = c(7, 7.3), Elmidae = c(6, 7.2),
  Austrosimulium = c(3, 3.9), Nothodixa = c(4, 9.3), Orthocladiinae = c(2, 3.2),
  Polypedilum = c(3, 8.0), Psilochorema = c(8, 7.8), Triplectides = c(5, 5.7),
  Oligochaeta = c(1, 3.8), Potamopyrgus = c(4, 2.1))

test_that("MacroSampleData reproduces report Appendix B2 Tables 1 & 2", {
  cfg <- tryCatch(load_config(file.path(ROOT, "cycle.toml")),
                  error = function(e) NULL)
  skip_if(is.null(cfg), "cycle.toml not available")
  skip_if_not(file.exists(cfg$macroinvertebrate_db),
              paste("macroinvertebrate_db not reachable:", cfg$macroinvertebrate_db))

  result <- process_macro_sample_domain(cfg$macroinvertebrate_db)
  expect_true(result$ok())
  df <- result$data$MacroSampleData
  df$Date <- as.Date(df$Date)

  # --- (a) sample columns + dates per season ---
  samp <- function(season, year) {
    s <- df[df$Season == season & df$Year == year, ]
    unique(data.frame(Site = s$Site, Replicate = s$Replicate,
                      Date = as.character(s$Date), stringsAsFactors = FALSE))
  }
  spring <- samp("Spring", 2025)
  summer <- samp("Summer", 2026)
  expect_equal(nrow(spring), 19L)   # 4 single + 3x5 replicated
  expect_equal(nrow(summer), 19L)
  # Replicated (Surber) sites carry reps 1-5; single sites carry NA.
  for (s in c("EM3", "EM5", "EM7")) {
    expect_setequal(spring$Replicate[spring$Site == s], 1:5)
    expect_setequal(summer$Replicate[summer$Site == s], 1:5)
  }
  for (s in c("EM1", "EM2", "EM4", "EM8")) {
    expect_true(all(is.na(spring$Replicate[spring$Site == s])))
  }
  # Dates.
  expect_equal(unique(spring$Date[spring$Site == "EM1"]), "2025-11-24")
  expect_equal(unique(spring$Date[spring$Site == "EM4"]), "2025-11-17")
  expect_equal(unique(spring$Date[spring$Site == "EM5"]), "2025-11-18")
  expect_equal(unique(summer$Date[summer$Site == "EM1"]), "2026-02-23")
  expect_equal(unique(summer$Date[summer$Site == "EM4"]), "2026-02-24")
  expect_equal(unique(summer$Date[summer$Site == "EM5"]), "2026-02-25")

  # --- (b) MCI/MCI-sb tolerance scores per taxon ---
  # Scope to the two reported seasons so future data cannot affect this check.
  reported <- df[(df$Season == "Spring" & df$Year == 2025) |
                 (df$Season == "Summer" & df$Year == 2026), ]
  for (sp in names(.MCI)) {
    rows <- reported[reported$Species == sp, ]
    expect_gt(nrow(rows), 0)
    expect_setequal(rows$MCI, .MCI[[sp]][1])
    expect_setequal(rows$MCI_sb, .MCI[[sp]][2])
  }

  # --- (c) precise count spot-checks (abundant taxa; all EM3 replicates) ---
  # Spring 2025
  sp_expect <- list(
    Austrosimulium = c(EM1_NA=38, EM2_NA=22, EM3_1=75, EM3_2=44, EM3_3=168,
                       EM3_4=34, EM3_5=76, EM4_NA=47),
    Potamopyrgus   = c(EM1_NA=30, EM2_NA=109, EM3_1=37, EM3_2=56, EM3_3=105,
                       EM3_4=52, EM3_5=200, EM4_NA=10),
    Elmidae        = c(EM1_NA=13, EM2_NA=3, EM3_1=74, EM3_2=105, EM3_3=28,
                       EM3_4=41, EM3_5=21))
  check <- function(season, year, spec) {
    for (sp in names(spec)) for (k in names(spec[[sp]])) {
      parts <- strsplit(k, "_")[[1]]
      site <- parts[1]; rep <- if (parts[2] == "NA") NA else as.integer(parts[2])
      lbl <- sprintf("%s %d %s %s %s", season, year, site, parts[2], sp)
      expect_equal(.cnt(df, season, year, site, rep, sp),
                   as.integer(spec[[sp]][[k]]), info = lbl)
    }
  }
  check("Spring", 2025, sp_expect)

  # Summer 2026
  su_expect <- list(
    Austrosimulium = c(EM1_NA=17, EM2_NA=30, EM3_1=11, EM3_2=13, EM3_3=13,
                       EM3_4=25, EM3_5=8),
    Potamopyrgus   = c(EM1_NA=138, EM2_NA=131, EM3_1=58, EM3_2=48, EM3_3=26,
                       EM3_4=2, EM3_5=56, EM4_NA=186))
  check("Summer", 2026, su_expect)
})
