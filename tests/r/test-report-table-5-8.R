# test-report-table-5-8.R — reproduction of report Table 5.8 (freshwater fish
# surveys, 2025-2026: Spring 2025 + Summer 2026). Asserts the printed values for
# counts, totals, CPUE and shrimp against process_fish_summary_domain() output
# from the real database. Skips when that DB is unavailable.
#
# TaxaRichness (rich=) follows the author-confirmed GROUP rule (eel/bully/kokopu
# collapse to one taxon each; Inanga, koura and shrimp count once), which the
# 2026 regeneration review adopted over the printed values. It therefore differs
# from the printed Table 5.8 at three cells -- EM8 Spring, EM1 Summer and EM6
# Summer, printed as 4 but made 5 by the group rule (incl. shrimp).
#
# Two other report cells are internally inconsistent with the report's own
# totals and are asserted at the data-consistent value (see inline notes) --
# flagged for author confirmation:
#   - EM2 Spring TaxaRichness: report prints 4; the group rule yields 5.
#   - EM2 Summer "Unid. eel sp.": report prints 1, but the data (and the
#     report's own total of 560) contain no unidentified eel there.
#     Author's instruction: go with what the data says (assert 0).
#
# Two 2026-review changes make some printed cells no longer reproducible here;
# their exact expected values must be re-derived against the source DB:
#   - CPUE is now count-based (divides by nets recorded, not fixed 6/12), so it
#     matches the printed values only once the data records a "no catch" row for
#     every empty net. Exact CPUE checks are gated behind .CPUE_EXACT until the
#     data QA + re-derivation is done; meanwhile CPUE is only asserted present.
#   - "Unidentified galaxiid" is now its own column (UnidGalaxiid), no longer
#     folded into UnidKokopu. If the data contains any, the UnidKokopu counts
#     below drop and UnidGalaxiid appears -> re-derive those cells.

src_data("errors.R")
src_data("domain_types.R")
src_data("schemas.R")
src_data("config.R")
src_data("domains/fish_summary.R")

.SPECIES_COLS <- c("LongfinEel", "ShortfinEel", "CommonBully", "RedfinBully",
                   "BandedKokopu", "GiantKokopu", "Inanga",
                   "UnidBully", "UnidKokopu", "UnidGalaxiid", "UnidEel", "Koura")

# CPUE basis changed to count-based (see header). Flip to TRUE once the CPUE
# values above are re-derived from a QA'd DB run to re-enable exact checks.
.CPUE_EXACT <- FALSE

# Each entry: non-zero species counts (others default 0), shrimp label, total,
# richness, and the two CPUE values, transcribed from Table 5.8.
.T58 <- list(
  # ---- Spring 2025 ----
  list(site="EM1", season="Spring", year=2025L, catch="Mangapepeke",
       counts=c(LongfinEel=3, RedfinBully=49, BandedKokopu=41, GiantKokopu=1, UnidKokopu=14, Koura=4),
       shrimp="Uncommon", total=108, rich=5, fykes=10.17, gmts=3.92),
  list(site="EM2", season="Spring", year=2025L, catch="Mangapepeke",
       counts=c(LongfinEel=15, CommonBully=8, RedfinBully=115, BandedKokopu=6, Inanga=527, UnidKokopu=2),
       shrimp="Common", total=673, rich=5, fykes=83.50, gmts=14.33),  # group rule=5; report prints 4
  list(site="EM3", season="Spring", year=2025L, catch="Mangapepeke",
       counts=c(LongfinEel=5, RedfinBully=99, BandedKokopu=19, GiantKokopu=1, Inanga=1, UnidKokopu=31, UnidEel=2, Koura=1),
       shrimp="Uncommon", total=158, rich=6, fykes=18.00, gmts=4.17),
  list(site="EM4", season="Spring", year=2025L, catch="Mimi",
       counts=c(LongfinEel=5, RedfinBully=51, BandedKokopu=9, GiantKokopu=1, UnidKokopu=2, Koura=2),
       shrimp="Common", total=68, rich=5, fykes=7.50, gmts=1.92),
  list(site="EM6", season="Spring", year=2025L, catch="Mimi",
       counts=c(LongfinEel=4, RedfinBully=59, BandedKokopu=7, GiantKokopu=1, UnidKokopu=1, UnidEel=2, Koura=2),
       shrimp="Common", total=74, rich=5, fykes=6.67, gmts=2.83),
  list(site="EM8", season="Spring", year=2025L, catch="Mimi",
       counts=c(LongfinEel=5, RedfinBully=30, GiantKokopu=1, UnidKokopu=7, UnidEel=5, Koura=2),
       shrimp="Common", total=48, rich=5, fykes=5.17, gmts=1.42),  # group rule=5; report prints 4
  # ---- Summer 2026 ----
  list(site="EM1", season="Summer", year=2026L, catch="Mangapepeke",
       counts=c(LongfinEel=5, RedfinBully=65, BandedKokopu=39, UnidKokopu=5, Koura=1),
       shrimp="Uncommon", total=114, rich=5, fykes=12.00, gmts=3.50),  # group rule=5; report prints 4
  list(site="EM2", season="Summer", year=2026L, catch="Mangapepeke",
       counts=c(LongfinEel=5, CommonBully=2, RedfinBully=184, Inanga=369, Koura=2),
       shrimp="Common", total=560, rich=5, fykes=56.50, gmts=18.42),  # report prints UnidEel=1 (anomaly)
  list(site="EM3", season="Summer", year=2026L, catch="Mangapepeke",
       counts=c(LongfinEel=5, RedfinBully=93, BandedKokopu=32, GiantKokopu=2, Inanga=15, UnidKokopu=8),
       shrimp="Uncommon", total=155, rich=5, fykes=14.67, gmts=5.58),
  list(site="EM4", season="Summer", year=2026L, catch="Mimi",
       counts=c(LongfinEel=3, RedfinBully=80, BandedKokopu=12, GiantKokopu=2, UnidKokopu=2, Koura=2),
       shrimp="Uncommon", total=99, rich=5, fykes=9.50, gmts=3.50),
  list(site="EM6", season="Summer", year=2026L, catch="Mimi",
       counts=c(LongfinEel=2, RedfinBully=32, BandedKokopu=11, UnidKokopu=4, Koura=3),
       shrimp="Uncommon", total=49, rich=5, fykes=4.83, gmts=1.67),  # group rule=5; report prints 4
  list(site="EM8", season="Summer", year=2026L, catch="Mimi",
       counts=c(RedfinBully=70, BandedKokopu=2, GiantKokopu=2, UnidKokopu=1, Koura=8),
       shrimp="Uncommon", total=75, rich=4, fykes=3.83, gmts=4.33)
)

test_that("FishSummary reproduces report Table 5.8 (2025-2026)", {
  cfg <- tryCatch(load_config(file.path(ROOT, "cycle.toml")),
                  error = function(e) NULL)
  skip_if(is.null(cfg), "cycle.toml not available")
  skip_if_not(file.exists(cfg$aquatic_monitoring_db),
              paste("aquatic_monitoring_db not reachable:", cfg$aquatic_monitoring_db))

  result <- process_fish_summary_domain(cfg$aquatic_monitoring_db)
  expect_true(result$ok())
  df <- result$data$FishSummary

  for (e in .T58) {
    lbl <- sprintf("%s %s %d", e$site, e$season, e$year)
    row <- df[df$Site == e$site & df$Season == e$season & df$Year == e$year, ,
              drop = FALSE]
    expect_equal(nrow(row), 1L, info = paste(lbl, "row count"))
    if (nrow(row) != 1L) next
    row <- as.list(row)

    expect_equal(row$Catchment, e$catch, info = paste(lbl, "Catchment"))

    for (col in .SPECIES_COLS) {
      expected <- if (col %in% names(e$counts)) unname(e$counts[[col]]) else 0
      expect_equal(row[[col]], expected, info = paste(lbl, col))
    }

    expect_equal(row$Shrimp, e$shrimp, info = paste(lbl, "Shrimp"))
    expect_equal(row$TotalFish, e$total, info = paste(lbl, "TotalFish"))
    expect_equal(row$TaxaRichness, as.integer(e$rich),
                 info = paste(lbl, "TaxaRichness"))
    if (isTRUE(.CPUE_EXACT)) {
      expect_equal(row$CPUE_fykes, e$fykes, tolerance = 0.01,
                   info = paste(lbl, "CPUE_fykes"))
      expect_equal(row$CPUE_GMTs, e$gmts, tolerance = 0.01,
                   info = paste(lbl, "CPUE_GMTs"))
    } else {
      # Count-based CPUE pending re-derivation; assert only that it is produced.
      expect_false(is.null(row$CPUE_fykes), info = paste(lbl, "CPUE_fykes present"))
      expect_false(is.null(row$CPUE_GMTs), info = paste(lbl, "CPUE_GMTs present"))
    }
  }
})
