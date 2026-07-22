# test-report-tables.R — unit tests for the report-rendering layer
# (src/r/reporting/report_tables.R). These exercise the wide-table builders on
# synthetic tidy input, so they need no database. Focus: the macro community-
# indices builder must number surveys per the report (spring 2025 = Table 5.6,
# summer 2026 = Table 5.7) and skip surveys that have no report table number.

source(file.path(ROOT, "src", "r", "reporting", "report_tables.R"))

# Minimal MacroSummary-shaped frame: one row per Site x survey. Only the columns
# the builder reads are populated; Year/Season drive the survey grouping.
.macro_row <- function(site, season, year, date) data.frame(
  Catchment = "Mangapepeke", Site = site, Substrate = "Soft bottom",
  Method = "D-net", Date = as.Date(date), Season = season, Year = year,
  NumIndividuals = 100, NumIndividuals_CI = NA_real_,
  NumTaxa = 12, NumTaxa_CI = NA_real_,
  MCI = 118.5, MCI_CI = NA_real_, MCI_Class = "Good",
  QMCI = 4.2, QMCI_CI = NA_real_, QMCI_Class = "Fair",
  PctEPTRichness = 0.25, PctEPTRichness_CI = NA_real_,
  PctEPTAbundance = 0.13, PctEPTAbundance_CI = NA_real_,
  DominantTaxa = "Potamopyrgus",
  stringsAsFactors = FALSE, check.names = FALSE)

.macro_df <- rbind(
  .macro_row("EM1", "Spring", 2018L, "2018-10-25"),  # old survey -> no number
  .macro_row("EM2", "Spring", 2018L, "2018-10-25"),
  .macro_row("EM1", "Spring", 2025L, "2025-11-24"),  # Table 5.6
  .macro_row("EM2", "Spring", 2025L, "2025-11-24"),
  .macro_row("EM1", "Summer", 2026L, "2026-02-23"),  # Table 5.7
  .macro_row("EM2", "Summer", 2026L, "2026-02-23"))

test_that("rt_macro_summary numbers 5.6/5.7 by survey and skips unnumbered surveys", {
  sections <- rt_macro_summary(.macro_df)

  # Only the two numbered surveys render (Spring 2018 is dropped).
  expect_equal(length(sections), 2L)

  titles <- vapply(sections, function(s) s$title, character(1))
  # Ascending report-table-number order: 5.6 (spring 2025) then 5.7 (summer 2026).
  expect_equal(titles[1], "Table 5.6 — Macroinvertebrate community metrics, Spring 2025")
  expect_equal(titles[2], "Table 5.7 — Macroinvertebrate community metrics, Summer 2026")
})

test_that("rt_macro_summary lays out metrics as rows and sites as columns", {
  sections <- rt_macro_summary(.macro_df)
  tbl <- sections[[2]]$table  # Table 5.7 (summer 2026)

  expect_equal(names(tbl)[1], "Variable")
  expect_true(all(c("EM1", "EM2") %in% names(tbl)))
  expect_equal(tbl$Variable[1], "Catchment")
  expect_true("Dominant taxa" %in% tbl$Variable)
  expect_equal(tbl$EM1[tbl$Variable == "Dominant taxa"], "Potamopyrgus")
  # % EPT richness is stored as a fraction and printed x100.
  expect_equal(tbl$EM1[tbl$Variable == "% EPT richness"], "25.0")
})

test_that("rt_macro_summary returns nothing when no survey has a report number", {
  old_only <- .macro_df[.macro_df$Year == 2018L, , drop = FALSE]
  expect_equal(length(rt_macro_summary(old_only)), 0L)
})

# Value in a "Variable"-keyed table (fish/fieldwq).
.vcell <- function(tbl, var, col) tbl[[col]][tbl$Variable == var]

# ---- Table 5.8 fish ----
test_that("rt_fish pivots species/derived rows x site-cols; 0 counts blank", {
  df <- data.frame(
    Catchment = "Mangapepeke", Site = "EM1", Season = "Spring", Year = 2025L,
    LongfinEel = 3, ShortfinEel = 0, CommonBully = 0, RedfinBully = 49,
    BandedKokopu = 41, GiantKokopu = 1, Inanga = 0, UnidBully = 0,
    UnidKokopu = 14, UnidEel = 0, Koura = 4,
    Shrimp = "Common", TotalFish = 108, TaxaRichness = 5,
    CPUE_fykes = 10.17, CPUE_GMTs = 3.92,
    stringsAsFactors = FALSE, check.names = FALSE)
  t <- rt_fish(df)[[1]]$table
  expect_equal(.vcell(t, "Longfin eel", "EM1"), "3")
  expect_equal(.vcell(t, "Shortfin eel", "EM1"), "")   # zero -> blank
  expect_equal(.vcell(t, "Kōura", "EM1"), "4")
  expect_equal(.vcell(t, "Shrimp", "EM1"), "Common")
  expect_equal(.vcell(t, "Total fish caught*", "EM1"), "108")
  expect_equal(.vcell(t, "CPUE (fykes)", "EM1"), "10.17")
})

# ---- Appendix B3 field WQ ----
test_that("rt_field_wq: Catchment banner header sits above the Site row", {
  df <- data.frame(
    Catchment = "Mangapepeke", Site = "EM1", Season = "Spring", Year = 2025L,
    Date = as.Date("2025-11-24"), TimeTaken = "12:30", WaterTempC = 13.9,
    pH = NA_real_, SpecCond = 162.2, DO_mgL = 10.47, DO_pctSat = 101.7,
    stringsAsFactors = FALSE, check.names = FALSE)
  t <- rt_field_wq(df)[[1]]$table
  # Row 1 (the column-name row) is the Catchment banner; corner cell "Catchment".
  expect_equal(names(t)[1], "Catchment")
  expect_equal(names(t)[2], "Mangapepeke")
  # Row 2 is the Site header (EM1, EM2, ...) directly beneath the catchment.
  expect_equal(t[[1]][1], "Site")
  expect_equal(t[[2]][1], "EM1")
  # Measurement rows follow, addressed via the first (label) column.
  lbl <- t[[1]]
  v <- t[[2]]
  expect_equal(v[lbl == "Time taken"], "12:30")
  expect_equal(v[lbl == "pH"], "–")            # not recorded
  expect_equal(v[lbl == "Water temperature (°C)"], "13.9")
  expect_equal(v[lbl == "DO (mg/L)"], "10.47")
})

# ---- Appendix B1 Table 3 sediment (long input, no Year column) ----
test_that("rt_sediment_summary pivots long->wide; Year derived from Date", {
  df <- data.frame(
    Site = c("EM1", "EM1"), Date = as.Date(c("2025-11-24", "2025-11-24")),
    Period = "Routine Construction", Season = c("Spring", "Spring"),
    Protocol = c("SAM1", "SAM3"),
    Variable = c("Average sediment cover (%)", "Clay/silt (<0.06 mm)"),
    Value = c(8.86, 8), stringsAsFactors = FALSE, check.names = FALSE)
  secs <- rt_sediment_summary(df)
  expect_length(secs, 1L)
  expect_match(secs[[1]]$title, "Appendix B1 Table 3")
  expect_match(secs[[1]]$title, "Spring 2025")
  t <- secs[[1]]$table
  expect_equal(names(t), c("Protocol", "Variable", "EM1"))
  # Date row sits directly below the site-name header (top body row).
  expect_equal(t$Variable[1], "Date")
  expect_equal(t$EM1[t$Variable == "Date"], "24/11/2025")
  expect_equal(t$EM1[t$Variable == "Average sediment cover (%)"], "9")  # 8.86 -> 9
  expect_equal(t$EM1[t$Variable == "Clay/silt (<0.06 mm)"], "8")
})

# ---- Appendix B1 Table 4 RPD (site x season matrix) ----
test_that("rt_rpd_summary builds a site x season matrix with Mean (±CI)", {
  df <- data.frame(
    Site = c("EM1", "EM1"), Season = c("Spring", "Summer"),
    Year = c(2024L, 2025L), N = c(3, 3), Mean = c(38.7, 42.2),
    CI95 = c(41.7, 42.9), stringsAsFactors = FALSE, check.names = FALSE)
  secs <- rt_rpd_summary(df)
  expect_length(secs, 1L)
  t <- secs[[1]]$table
  expect_equal(names(t), c("Site", "Spring 2024", "Summer 2025"))
  expect_equal(t[["Spring 2024"]][t$Site == "EM1"], "38.7 (±41.7)")
})

# ---- Appendix B2 macro sample (taxa x sample-column matrix) ----
test_that("rt_macro_sample builds taxa rows x Site.Replicate columns", {
  df <- data.frame(
    Season = "Spring", Year = 2025L, Date = as.Date("2025-11-24"),
    Site = c("EM3", "EM1"), Replicate = c(1L, NA),
    TaxaGroup = c("Beetles", "Beetles"), Species = c("Elmidae", "Elmidae"),
    MCI = c(6, 6), MCI_sb = c(7.2, 7.2), Count = c(74L, 13L),
    stringsAsFactors = FALSE, check.names = FALSE)
  t <- rt_macro_sample(df)[[1]]$table
  expect_true(all(c("TaxaGroup", "Species", "MCI", "MCI-sb", "EM1", "EM3.1") %in% names(t)))
  # Date row sits directly below the sample-name header (top body row).
  expect_equal(t$TaxaGroup[1], "Date")
  expect_equal(t$EM1[t$TaxaGroup == "Date"], "24/11/2025")
  expect_equal(t$EM3.1[t$TaxaGroup == "Date"], "24/11/2025")
  expect_equal(t$EM1[t$Species == "Elmidae"], "13")
  expect_equal(t$EM3.1[t$Species == "Elmidae"], "74")
  expect_equal(t$MCI[t$Species == "Elmidae"], "6.0")
})

# ---- ordering + HTML ----
test_that("split_seasons orders most-recent first", {
  df <- data.frame(Season = c("Spring", "Summer"), Year = c(2025L, 2026L),
                   Site = "EM1", stringsAsFactors = FALSE)
  s <- split_seasons(df)
  expect_equal(s[[1]]$Year, 2026L)   # Summer 2026 newest
  expect_equal(s[[2]]$Year, 2025L)
})

test_that(".rt_sheet_name derives a valid, unique worksheet name", {
  # Trailing "Season Year" is preferred.
  expect_equal(.rt_sheet_name("Table 5.6 — Macro metrics, Spring 2025"),
               "Spring 2025")
  expect_equal(.rt_sheet_name("Appendix B3 — Spot water quality, Summer 2026"),
               "Summer 2026")
  # No season/year -> text after the em dash, sanitized and <= 31 chars.
  nm <- .rt_sheet_name("Appendix B1 Table 4 — Mean residual pool depth (RPD)")
  expect_lte(nchar(nm), 31L)
  expect_false(grepl("[:\\\\/?*\\[\\]]", nm))
  # De-duplicates against names already used in the workbook.
  expect_equal(.rt_sheet_name("x, Spring 2025", used = "Spring 2025"),
               "Spring 2025 (2)")
})

test_that("render_report_tables_xlsx writes one .xlsx per table type, tabbed", {
  # MacroSummary with both surveys -> one file (community metrics), one tab per
  # table (Spring 2025 = 5.6, Summer 2026 = 5.7).
  tmp_xlsx <- tempfile(fileext = ".xlsx")
  openxlsx::write.xlsx(list(MacroSummary = .macro_df), tmp_xlsx)
  out_dir <- tempfile("rt_out_")
  paths <- render_report_tables_xlsx(tmp_xlsx, out_dir)

  expect_length(paths, 1L)  # only one table type is present in the workbook
  expect_true(file.exists(paths[1]))
  expect_match(basename(paths[1]),
               "Macroinvertebrate_community_metrics\\.xlsx$")
  expect_setequal(readxl::excel_sheets(paths[1]),
                  c("Spring 2025", "Summer 2026"))
  # Each tab holds the pivoted (Variable x sites) content.
  back <- as.data.frame(readxl::read_excel(paths[1], sheet = "Spring 2025"))
  expect_equal(names(back)[1], "Variable")
  expect_true("Dominant taxa" %in% back$Variable)
})
