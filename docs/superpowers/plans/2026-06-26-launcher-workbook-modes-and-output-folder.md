# Launcher Workbook Modes & Single Output Folder — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the launcher either build the data workbook from the two source databases *or* run figures/tables from an existing workbook, collapse the three output paths into one output folder, and move fish data into the workbook so it is self-sufficient.

**Architecture:** The integration seam is unchanged — collect paths → write a temp `cycle.toml` → shell out to the bundled R pipeline. What changes: (a) a new `Fish` domain so the data-build stage writes a `Fish` sheet and the figure stage reads fish from the workbook (not the live DB); (b) `config.R` treats the input DBs as optional; (c) the launcher gains a build-vs-workbook mode toggle and a single output folder from which `figures/`, `tables/`, and the built workbook are derived.

**Tech Stack:** R (testthat, readxl, openxlsx, dplyr, tidyr, lubridate, R6, RcppTOML, withr) for the pipeline; Windows PowerShell 5.1 + WinForms + Pester 5 for the launcher.

## Global Constraints

- **Platform:** Windows; Windows PowerShell 5.1 (`powershell.exe`). Launcher tests use **Pester 5**.
- **R:** pinned 4.5 (`DESCRIPTION` `Config/R/Version`); renv-activated by the scripts themselves.
- **Fish sheet date column is named `Date`** (not `Date retrieved`) — consistent with every other sheet, which keeps the writer/golden test helpers working unchanged.
- **`FISH_COLUMNS` (exact, in order):** `c("Site", "Catchment", "Date", "Species category (for abundance)", "Number")`.
- **`Fish` is appended last in `SHEET_ORDER`.**
- **Build-mode workbook filename:** `MtMessengerEcologyData.xlsx`, written at the **root** of the output folder.
- **Output subfolders are lowercase:** `figures/` and `tables/`.
- **Mode values are the literal strings `'Databases'` and `'Workbook'`** everywhere (settings, resolver, config writer, preflight).
- **Do NOT touch** `src/mgen/**` or the Python `schemas.py` — the launcher runs the R pipeline only; the R/Python schema divergence (R has `Fish`, Python does not) is intentional and documented in the spec.
- **`cycle.toml` paths use forward slashes** (backslash→`/` conversion stays).
- **R tests run with:** `Rscript -e "library(readxl);library(openxlsx);library(dplyr);library(tidyr);library(lubridate); testthat::test_dir('tests/r', filter='<FILTER>', stop_on_failure=TRUE)"` (the `filter` is the part of the filename between `test-` and `.R`). Omit `filter=` to run all.
- **Launcher tests run with:** `powershell.exe -NoProfile -File launcher\tests\Invoke-Pester.ps1` (installs Pester 5 once, runs the whole suite). Per-file during development: `powershell.exe -NoProfile -Command "Import-Module Pester -MinimumVersion 5.0.0; Invoke-Pester -Path launcher\tests\<File>.Tests.ps1 -Output Detailed"`.

---

## Part 1 — Pipeline: fish in the data workbook (R)

### Task 1: Add the `Fish` schema

**Files:**
- Modify: `src/r/data/schemas.R`
- Test: `tests/r/test-schemas.R`

**Interfaces:**
- Produces: `FISH_COLUMNS` (character vector), `"Fish"` appended to `SHEET_ORDER`, and `SCHEMA_MAP[["Fish"]] == FISH_COLUMNS`.

- [ ] **Step 1: Update the schema test to expect `Fish`**

In `tests/r/test-schemas.R`, replace the `SHEET_ORDER` assertion and add a `FISH_COLUMNS` assertion. The full updated `test_that` body:

```r
test_that("schema column vectors match the Python contract", {
  expect_equal(MACRO1_COLUMNS,
               c("Site","Date","Period","EPTrich","EPTabun","QMCI","Season"))
  expect_identical(MACRO_COLUMNS, MACRO1_COLUMNS)
  expect_equal(MACRO_SPECIES_COLUMNS,
               c("Phase","Date","Site","Taxa","Species","Tally","is_additional"))
  expect_equal(SEDIMENT_COLUMNS,
               c("Site","Date","Period","SAM1","SAM3","Season"))
  expect_equal(RPD_COLUMNS,
               c("Site","Date","Count","Mean","StdDev","CI_Lower","CI_Upper"))
  expect_equal(LDV_COLUMNS, c("Site","Date","Season","CV_pct"))
  # Fish is an R-only sheet (no Python schemas.py counterpart).
  expect_equal(FISH_COLUMNS,
               c("Site","Catchment","Date","Species category (for abundance)","Number"))
  expect_equal(SHEET_ORDER,
               c("Macro","Macro1","MacroSpecies","Sediment",
                 "SedimentSize","Clarity","RPD","LDV","Fish"))
  expect_equal(length(SEDIMENT_SIZE_COLUMNS), 14L)
  expect_equal(SEDIMENT_SIZE_COLUMNS[5], "Clay/silt (<0.06 mm)")
  expect_setequal(names(SCHEMA_MAP), SHEET_ORDER)
})
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `Rscript -e "library(readxl);library(openxlsx);library(dplyr);library(tidyr);library(lubridate); testthat::test_dir('tests/r', filter='schemas', stop_on_failure=TRUE)"`
Expected: FAIL — `object 'FISH_COLUMNS' not found` (and/or `SHEET_ORDER` mismatch).

- [ ] **Step 3: Add the schema to `schemas.R`**

After the `LDV_COLUMNS` definition (around line 29), add:

```r
# Fish: R-only sheet carrying the raw trapping rows the figure stage needs.
# No Python schemas.py counterpart (the Python pipeline reads fish live).
FISH_COLUMNS <- c(
  "Site", "Catchment", "Date", "Species category (for abundance)", "Number"
)
```

Append `"Fish"` to `SHEET_ORDER`:

```r
SHEET_ORDER <- c(
  "Macro", "Macro1", "MacroSpecies", "Sediment",
  "SedimentSize", "Clarity", "RPD", "LDV", "Fish"
)
```

Add the `Fish` entry to `SCHEMA_MAP`:

```r
SCHEMA_MAP <- list(
  Macro = MACRO_COLUMNS,
  Macro1 = MACRO1_COLUMNS,
  MacroSpecies = MACRO_SPECIES_COLUMNS,
  Sediment = SEDIMENT_COLUMNS,
  SedimentSize = SEDIMENT_SIZE_COLUMNS,
  Clarity = CLARITY_COLUMNS,
  RPD = RPD_COLUMNS,
  LDV = LDV_COLUMNS,
  Fish = FISH_COLUMNS
)
```

- [ ] **Step 4: Run the test, verify it passes**

Run: `Rscript -e "library(readxl);library(openxlsx);library(dplyr);library(tidyr);library(lubridate); testthat::test_dir('tests/r', filter='schemas', stop_on_failure=TRUE)"`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/r/data/schemas.R tests/r/test-schemas.R
git commit -m "feat(pipeline): add Fish sheet schema"
```

---

### Task 2: Fish domain module

**Files:**
- Create: `src/r/data/domains/fish.R`
- Test: `tests/r/test-domain-fish.R`

**Interfaces:**
- Consumes: `FISH_COLUMNS` (Task 1), `DomainResult`/`ValidationError` (`errors.R`).
- Produces: `process_fish_domain(path)` → a `DomainResult` whose `$data$Fish` is a data frame with `names() == FISH_COLUMNS`, `Date` of class `Date`, `Number` numeric; on a missing sheet or missing required column it returns `$ok() == FALSE` with one error of `domain == "Fish"`.

- [ ] **Step 1: Write the failing test**

Create `tests/r/test-domain-fish.R`:

```r
src_data("errors.R"); src_data("schemas.R"); src_data("domains/fish.R")

# Write a "Fish Trapping" sheet to a temp xlsx and return the path.
fish_xlsx <- function(df) {
  tmp <- tempfile(fileext = ".xlsx")
  openxlsx::write.xlsx(list("Fish Trapping" = df), tmp)
  tmp
}

minimal_df <- function() {
  data.frame(
    Site                                = c("EM1", "EM3"),
    Catchment                           = c("Mangapepeke", "Mangapepeke"),
    `Date retrieved`                    = as.Date(c("2024-02-01", "2024-02-01")),
    `Species category (for abundance)`  = c("B", "E"),
    Number                              = c(5, 2),
    check.names = FALSE, stringsAsFactors = FALSE
  )
}

test_that("happy path produces a DomainResult with FISH_COLUMNS in order", {
  result <- process_fish_domain(fish_xlsx(minimal_df()))
  expect_true(result$ok())
  expect_false(is.null(result$data))
  fish <- result$data$Fish
  expect_equal(names(fish), FISH_COLUMNS)
  expect_equal(nrow(fish), 2L)
})

test_that("Date is Date class, Number numeric, Site character", {
  fish <- process_fish_domain(fish_xlsx(minimal_df()))$data$Fish
  expect_true(inherits(fish$Date, "Date"))
  expect_true(is.numeric(fish$Number))
  expect_true(is.character(fish$Site))
})

test_that("the source 'Date retrieved' column is mapped to 'Date'", {
  fish <- process_fish_domain(fish_xlsx(minimal_df()))$data$Fish
  expect_true("Date" %in% names(fish))
  expect_false("Date retrieved" %in% names(fish))
})

test_that("missing required column returns an error result", {
  df <- minimal_df(); df[["Number"]] <- NULL
  result <- process_fish_domain(fish_xlsx(df))
  expect_false(result$ok())
  expect_null(result$data)
  expect_equal(length(result$errors), 1L)
  expect_equal(result$errors[[1]]$domain, "Fish")
  expect_match(result$errors[[1]]$message, "Missing required columns")
})

test_that("excel file with no Fish Trapping sheet returns an error result", {
  tmp <- tempfile(fileext = ".xlsx")
  openxlsx::write.xlsx(list("WrongSheet" = data.frame(x = 1)), tmp)
  result <- process_fish_domain(tmp)
  expect_false(result$ok())
  expect_equal(result$errors[[1]]$domain, "Fish")
  expect_match(result$errors[[1]]$message, "Fish Trapping")
})
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `Rscript -e "library(readxl);library(openxlsx);library(dplyr);library(tidyr);library(lubridate); testthat::test_dir('tests/r', filter='domain-fish', stop_on_failure=TRUE)"`
Expected: FAIL — `could not find function "process_fish_domain"` (the file doesn't exist yet).

- [ ] **Step 3: Write the domain module**

Create `src/r/data/domains/fish.R`:

```r
# fish.R — fish trapping from the Aquatic Monitoring Database "Fish Trapping".
# Writes the raw rows the figure stage aggregates; the source "Date retrieved"
# column is mapped to a generic "Date" for consistency with the other sheets.

.fish_source_sheet <- "Fish Trapping"
.fish_required <- c("Site", "Catchment", "Date retrieved",
                    "Species category (for abundance)", "Number")

.fish_error <- function(path, message) {
  DomainResult$new(data = NULL, errors = list(ValidationError(
    domain = "Fish", severity = "error", file = as.character(path),
    sheet = .fish_source_sheet, location = "sheet", message = message)))
}

process_fish_domain <- function(path) {
  df <- suppressWarnings(suppressMessages(tryCatch(
    readxl::read_excel(path, sheet = .fish_source_sheet),
    error = function(e) e)))
  if (inherits(df, "error")) {
    return(.fish_error(path, sprintf("Sheet '%s' not found or unreadable in %s",
                                     .fish_source_sheet, path)))
  }
  names(df) <- trimws(names(df))
  missing <- setdiff(.fish_required, names(df))
  if (length(missing) > 0) {
    return(.fish_error(path, sprintf("Missing required columns: %s",
      paste0("[", paste(sprintf("'%s'", sort(missing)), collapse = ", "), "]"))))
  }

  out <- data.frame(
    Site      = as.character(df[["Site"]]),
    Catchment = as.character(df[["Catchment"]]),
    Date      = as.Date(df[["Date retrieved"]]),
    `Species category (for abundance)` =
      as.character(df[["Species category (for abundance)"]]),
    Number    = suppressWarnings(as.numeric(df[["Number"]])),
    check.names = FALSE, stringsAsFactors = FALSE
  )
  out <- out[, FISH_COLUMNS, drop = FALSE]
  DomainResult$new(data = list(Fish = out))
}
```

- [ ] **Step 4: Run the test, verify it passes**

Run: `Rscript -e "library(readxl);library(openxlsx);library(dplyr);library(tidyr);library(lubridate); testthat::test_dir('tests/r', filter='domain-fish', stop_on_failure=TRUE)"`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add src/r/data/domains/fish.R tests/r/test-domain-fish.R
git commit -m "feat(pipeline): add Fish domain ingest from aquatic DB"
```

---

### Task 3: Wire fish into the data-build stage

**Files:**
- Modify: `src/r/data/pipeline.R`
- Modify: `src/r/run_data.R:35-39` (module source list) and `:44-58` (validate block)
- Test: `tests/r/test-pipeline-integration.R`

**Interfaces:**
- Consumes: `process_fish_domain` (Task 2), `FISH_COLUMNS`/`SHEET_ORDER` (Task 1).
- Produces: `run_pipeline(config)` now assembles a `Fish` sheet into the written workbook; `run_data.R --validate` includes the fish domain.

- [ ] **Step 1: Update the integration test to expect `Fish`**

In `tests/r/test-pipeline-integration.R`, add the fish module to the `src_data` block (after the `macro_species` line):

```r
src_data("domains/fish.R")
```

Replace the `results <- list(...)` assignment with one that includes fish:

```r
  results <- list(
    process_macro_domain(cfg$macroinvertebrate_db),
    process_macro_species_domain(cfg$macroinvertebrate_db),
    process_sediment_domain(cfg$aquatic_monitoring_db),
    process_sediment_size_domain(cfg$aquatic_monitoring_db),
    process_clarity_domain(cfg$aquatic_monitoring_db),
    process_rpd_domain(cfg$aquatic_monitoring_db),
    process_ldv_domain(cfg$aquatic_monitoring_db),
    process_fish_domain(cfg$aquatic_monitoring_db)
  )
```

Replace the golden-compare loop (the `for (sheet in SHEET_ORDER) ...` block) with one that skips `Fish` (the golden file has no `Fish` sheet) and asserts the fish schema directly:

```r
  golden <- golden_path()
  # Fish has no golden counterpart (the Python pipeline reads fish live and
  # writes no Fish sheet); compare it on schema + non-emptiness instead.
  for (sheet in setdiff(SHEET_ORDER, "Fish")) {
    compare_sheet_to_golden(combined[[sheet]], sheet, golden)
  }
  fish <- combined[["Fish"]]
  expect_equal(names(fish), FISH_COLUMNS)
  expect_gt(nrow(fish), 0)
```

- [ ] **Step 2: Run the integration test, verify it fails (or skips)**

Run: `Rscript -e "library(readxl);library(openxlsx);library(dplyr);library(tidyr);library(lubridate); testthat::test_dir('tests/r', filter='pipeline-integration', stop_on_failure=TRUE)"`
Expected: FAIL with `could not find function "process_fish_domain"` **if** the real DBs in `cycle.toml` are reachable. If the DBs are not reachable the test **skips** — in that case this task's gate is Task 2's unit tests plus the `run_data.R --validate` smoke in Step 4; note the skip and continue.

- [ ] **Step 3: Wire fish into `pipeline.R` and `run_data.R`**

In `src/r/data/pipeline.R`, add fish to the `results` list in `run_pipeline`:

```r
  results <- list(
    process_macro_domain(config$macroinvertebrate_db),
    process_macro_species_domain(config$macroinvertebrate_db),
    process_sediment_domain(config$aquatic_monitoring_db),
    process_sediment_size_domain(config$aquatic_monitoring_db),
    process_clarity_domain(config$aquatic_monitoring_db),
    process_rpd_domain(config$aquatic_monitoring_db),
    process_ldv_domain(config$aquatic_monitoring_db),
    process_fish_domain(config$aquatic_monitoring_db)
  )
```

In `src/r/run_data.R`, add `"domains/fish.R"` to the module source vector (line 35-39) — append it after `"domains/macro_species.R"` and before `"pipeline.R"`:

```r
  for (m in c("schemas.R","domain_types.R","errors.R","validation.R","config.R",
              "writer.R","domains/clarity.R","domains/ldv.R","domains/rpd.R",
              "domains/sediment_ingest.R","domains/sediment.R",
              "domains/sediment_size.R","domains/macro_ingest.R","domains/macro.R",
              "domains/macro_species.R","domains/fish.R","pipeline.R")) src1(m)
```

In the `if (validate_only)` block of `run_data.R`, add fish to the `results` list:

```r
    results <- list(
      process_macro_domain(cfg$macroinvertebrate_db),
      process_macro_species_domain(cfg$macroinvertebrate_db),
      process_sediment_domain(cfg$aquatic_monitoring_db),
      process_sediment_size_domain(cfg$aquatic_monitoring_db),
      process_clarity_domain(cfg$aquatic_monitoring_db),
      process_rpd_domain(cfg$aquatic_monitoring_db),
      process_ldv_domain(cfg$aquatic_monitoring_db),
      process_fish_domain(cfg$aquatic_monitoring_db))
```

- [ ] **Step 4: Run the integration + entrypoint tests, verify they pass**

Run: `Rscript -e "library(readxl);library(openxlsx);library(dplyr);library(tidyr);library(lubridate); testthat::test_dir('tests/r', filter='pipeline-integration', stop_on_failure=TRUE)"`
Expected: PASS (or SKIP if DBs unreachable — acceptable).

Run: `Rscript -e "library(readxl);library(openxlsx);library(dplyr);library(tidyr);library(lubridate); testthat::test_dir('tests/r', filter='entrypoints', stop_on_failure=TRUE)"`
Expected: PASS (the `--validate` empty-xlsx case still exits 1; the real-DB case passes or skips).

- [ ] **Step 5: Commit**

```bash
git add src/r/data/pipeline.R src/r/run_data.R tests/r/test-pipeline-integration.R
git commit -m "feat(pipeline): build a Fish sheet into the data workbook"
```

---

### Task 4: Read fish from the workbook in the figure stage

**Files:**
- Modify: `src/r/helpers/data_loading.R` (add a `Fish` branch to `load_all_data`)
- Modify: `src/r/helpers/fish_plots.R` (use the `Date` column, not `Date retrieved`)
- Modify: `src/r/run_all.R:90` and `:343-357` (read fish from `data$Fish`, drop the live-DB read)

**Interfaces:**
- Consumes: a workbook `Fish` sheet with `FISH_COLUMNS` (Tasks 1–3).
- Produces: `load_all_data()` returns `data$Fish` (or no key if absent); `plot_fish_by_catchment(data$Fish, dir)` renders fish plots from the workbook; `run_all.R` skips fish cleanly when `data$Fish` is `NULL`.

- [ ] **Step 1: Add a `Fish` branch to `load_all_data`**

In `src/r/helpers/data_loading.R`, inside `load_all_data`, after the `LDV` branch (around line 77) and before the `Community` derivation, add:

```r
  # --- Fish (raw trapping rows; aggregated at plot time) ---
  if ("Fish" %in% sheets) {
    data$Fish <- read_excel(xlsx_path, sheet = "Fish") |>
      clean_colnames() |>
      mutate(Date = as.Date(Date))
  }
```

- [ ] **Step 2: Point the fish plots at the `Date` column**

In `src/r/helpers/fish_plots.R`, in `compute_fish_catch_per_night`, update the filter and the `mutate` so the function reads the workbook's `Date` column instead of `Date retrieved`. Replace the `df <- fish_df |> filter(...) |> mutate(...)` block with:

```r
  df <- fish_df |>
    filter(`Species category (for abundance)` %in% valid_cats,
           !is.na(Date),
           !is.na(Number)) |>
    mutate(
      Category = FISH_CATEGORY_LABELS[`Species category (for abundance)`]
    )
```

(The `Date = `Date retrieved`` line is removed; `Date` already exists. Everything downstream — the `group_by(Date, Site, Catchment, ...)` calls — is unchanged.)

- [ ] **Step 3: Read fish from the workbook in `run_all.R`**

In `src/r/run_all.R`, delete the `aquatic_db_path` assignment (line ~90):

```r
aquatic_db_path <- if (!is.null(cfg)) cfg$aquatic_monitoring_db else NULL
```

Replace the Fish Trapping section (the `if (!is.null(aquatic_db_path)) { ... }` block, ~line 347-357) with a workbook-sourced version:

```r
message("--- Fish Trapping Plots ---")
if (!is.null(data$Fish)) {
  plot_fish_by_catchment(data$Fish, fish_fig_dir)
} else {
  message("  Skipped: no Fish sheet in the data workbook")
}
```

- [ ] **Step 4: Verify with the figure-stage tests**

Run: `Rscript -e "library(readxl);library(openxlsx);library(dplyr);library(tidyr);library(lubridate); testthat::test_dir('tests/r', filter='clarity-plots', stop_on_failure=TRUE)"`
Expected: PASS (sanity check that the helper-loading path still parses; fish-specific plotting has no unit test — it is covered by the manual smoke run in Task 10).

Then run the full R suite to confirm nothing regressed:

Run: `Rscript -e "library(readxl);library(openxlsx);library(dplyr);library(tidyr);library(lubridate); testthat::test_dir('tests/r', stop_on_failure=TRUE)"`
Expected: PASS (real-DB integration tests may SKIP).

- [ ] **Step 5: Commit**

```bash
git add src/r/helpers/data_loading.R src/r/helpers/fish_plots.R src/r/run_all.R
git commit -m "feat(pipeline): read fish from the data workbook in the figure stage"
```

---

## Part 2 — R config: optional input databases

### Task 5: Relax `load_config` so the input DBs are optional

**Files:**
- Modify: `src/r/data/config.R`
- Test: `tests/r/test-config.R`

**Interfaces:**
- Produces: `load_config(path)` returns `macroinvertebrate_db`/`aquatic_monitoring_db` as `NULL` when absent from `[input]`; still errors when `[output].data_xlsx` is missing or when a *provided* DB path does not exist.

- [ ] **Step 1: Write the failing test**

In `tests/r/test-config.R`, add a test for the workbook-mode config (no `[input]` section):

```r
test_that("load_config succeeds with no [input] section (workbook mode)", {
  d <- withr::local_tempdir()
  out <- file.path(d, "Data.xlsx")
  toml <- file.path(d, "cycle.toml")
  writeLines(c(
    "[output]",
    sprintf('data_xlsx = "%s"', gsub("\\\\", "\\\\\\\\", out)),
    sprintf('figures_dir = "%s"', gsub("\\\\", "\\\\\\\\", file.path(d, "figures"))),
    sprintf('tables_dir = "%s"', gsub("\\\\", "\\\\\\\\", file.path(d, "tables")))
  ), toml)
  cfg <- load_config(toml)
  expect_null(cfg$macroinvertebrate_db)
  expect_null(cfg$aquatic_monitoring_db)
  expect_equal(cfg$figures_dir, file.path(d, "figures"))
  expect_equal(cfg$tables_dir, file.path(d, "tables"))
})
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `Rscript -e "library(readxl);library(openxlsx);library(dplyr);library(tidyr);library(lubridate); testthat::test_dir('tests/r', filter='config', stop_on_failure=TRUE)"`
Expected: FAIL — `load_config` raises `config_error` "Missing required key: [input].macroinvertebrate_db".

- [ ] **Step 3: Make the input DBs optional**

In `src/r/data/config.R`, replace the body of `load_config` from the `for (key in ...)` required-key loop through the existence-check loop with:

```r
  if (is.null(output[["data_xlsx"]])) {
    config_error("Missing required key: [output].data_xlsx")
  }

  # Input DBs are optional: present in build mode, absent in workbook mode.
  macro_db <- if (!is.null(input[["macroinvertebrate_db"]]))
    normalizePath(input[["macroinvertebrate_db"]], mustWork = FALSE) else NULL
  aquatic_db <- if (!is.null(input[["aquatic_monitoring_db"]]))
    normalizePath(input[["aquatic_monitoring_db"]], mustWork = FALSE) else NULL
  data_xlsx <- normalizePath(output[["data_xlsx"]], mustWork = FALSE)

  figures_dir <- output[["figures_dir"]]
  if (is.null(figures_dir)) figures_dir <- file.path(dirname(data_xlsx), "Figures")
  tables_dir <- output[["tables_dir"]]
  if (is.null(tables_dir)) tables_dir <- file.path(figures_dir, "Tables")

  # Only existence-check DBs that were actually provided.
  for (path in Filter(Negate(is.null), list(macro_db, aquatic_db))) {
    if (!file.exists(path)) {
      config_error(sprintf("Input file not found: %s", path))
    }
  }
```

(The trailing `list(...)` return value is unchanged.)

- [ ] **Step 4: Run the config tests, verify they pass**

Run: `Rscript -e "library(readxl);library(openxlsx);library(dplyr);library(tidyr);library(lubridate); testthat::test_dir('tests/r', filter='config', stop_on_failure=TRUE)"`
Expected: PASS — including the existing "errors on missing input file" test (a *provided* nonexistent DB still errors).

- [ ] **Step 5: Commit**

```bash
git add src/r/data/config.R tests/r/test-config.R
git commit -m "feat(pipeline): make input DBs optional in load_config"
```

---

## Part 3 — Launcher engine

### Task 6: Output-path resolver

**Files:**
- Create: `launcher/engine/RunPaths.ps1`
- Test: `launcher/tests/RunPaths.Tests.ps1`

**Interfaces:**
- Produces: `Resolve-RunPaths -Mode <Databases|Workbook> -OutputDir <dir> [-MacroDb] [-AquaticDb] [-DataWorkbook]` → a `[hashtable]` with keys `Mode, MacroDb, AquaticDb, OutputDir, DataXlsx, FiguresDir, TablesDir`. In `Databases` mode `DataXlsx = <OutputDir>\MtMessengerEcologyData.xlsx`; in `Workbook` mode `DataXlsx = <DataWorkbook>`. `FiguresDir = <OutputDir>\figures`, `TablesDir = <OutputDir>\tables` in both.

- [ ] **Step 1: Write the failing test**

Create `launcher/tests/RunPaths.Tests.ps1`:

```powershell
BeforeAll { . "$PSScriptRoot/../engine/RunPaths.ps1" }
Describe 'Resolve-RunPaths' {
    It 'derives figures/tables and the built workbook in Databases mode' {
        $p = Resolve-RunPaths -Mode 'Databases' -OutputDir 'C:\out' `
            -MacroDb 'T:\m.xlsx' -AquaticDb 'T:\q.xlsx'
        $p.FiguresDir | Should -Be (Join-Path 'C:\out' 'figures')
        $p.TablesDir  | Should -Be (Join-Path 'C:\out' 'tables')
        $p.DataXlsx   | Should -Be (Join-Path 'C:\out' 'MtMessengerEcologyData.xlsx')
        $p.MacroDb    | Should -Be 'T:\m.xlsx'
    }
    It 'uses the selected workbook as DataXlsx in Workbook mode' {
        $p = Resolve-RunPaths -Mode 'Workbook' -OutputDir 'C:\out' `
            -DataWorkbook 'D:\existing\Data.xlsx'
        $p.DataXlsx   | Should -Be 'D:\existing\Data.xlsx'
        $p.FiguresDir | Should -Be (Join-Path 'C:\out' 'figures')
        $p.TablesDir  | Should -Be (Join-Path 'C:\out' 'tables')
    }
    It 'rejects an unknown mode' {
        { Resolve-RunPaths -Mode 'Nope' -OutputDir 'C:\out' } | Should -Throw
    }
}
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `powershell.exe -NoProfile -File launcher\tests\Invoke-Pester.ps1`
Expected: FAIL — `RunPaths.ps1` not found / `Resolve-RunPaths` not recognized. (First run also installs Pester 5.)

- [ ] **Step 3: Write the resolver**

Create `launcher/engine/RunPaths.ps1`:

```powershell
function Resolve-RunPaths {
    param(
        [Parameter(Mandatory)][ValidateSet('Databases','Workbook')][string]$Mode,
        [Parameter(Mandatory)][string]$OutputDir,
        [string]$MacroDb = '',
        [string]$AquaticDb = '',
        [string]$DataWorkbook = ''
    )
    $figures = Join-Path $OutputDir 'figures'
    $tables  = Join-Path $OutputDir 'tables'
    $dataXlsx = if ($Mode -eq 'Workbook') {
        $DataWorkbook
    } else {
        Join-Path $OutputDir 'MtMessengerEcologyData.xlsx'
    }
    @{
        Mode       = $Mode
        MacroDb    = $MacroDb
        AquaticDb  = $AquaticDb
        OutputDir  = $OutputDir
        DataXlsx   = $dataXlsx
        FiguresDir = $figures
        TablesDir  = $tables
    }
}
```

- [ ] **Step 4: Run the test, verify it passes**

Run: `powershell.exe -NoProfile -File launcher\tests\Invoke-Pester.ps1`
Expected: PASS for the `Resolve-RunPaths` describe block (other suites still pass too, since this task adds a file only).

- [ ] **Step 5: Commit**

```bash
git add launcher/engine/RunPaths.ps1 launcher/tests/RunPaths.Tests.ps1
git commit -m "feat(launcher): add Resolve-RunPaths output-path resolver"
```

---

### Task 7: Mode-aware `cycle.toml` writer

**Files:**
- Modify: `launcher/engine/ConfigWriter.ps1`
- Test: `launcher/tests/ConfigWriter.Tests.ps1`

**Interfaces:**
- Consumes: a `Paths` hashtable shaped like `Resolve-RunPaths` output (Task 6).
- Produces: `New-CycleTomlContent -Mode <..> [-MacroDb] [-AquaticDb] -DataXlsx -FiguresDir -TablesDir` → TOML text. In `Databases` mode it emits an `[input]` section with both DBs; in `Workbook` mode it emits **no** `[input]` section. `[output]` always carries `data_xlsx`, `figures_dir`, `tables_dir` (forward-slashed). `Write-CycleToml -Paths <hashtable>` writes it to a temp file and returns the path.

- [ ] **Step 1: Rewrite the ConfigWriter tests**

Replace the whole contents of `launcher/tests/ConfigWriter.Tests.ps1` with:

```powershell
BeforeAll { . "$PSScriptRoot/../engine/ConfigWriter.ps1" }
Describe 'New-CycleTomlContent (Databases mode)' {
    It 'emits [input] with both DBs and [output] with all three paths' {
        $c = New-CycleTomlContent -Mode 'Databases' -MacroDb 'T:\a\m.xlsx' `
            -AquaticDb 'T:\a\q.xlsx' -DataXlsx 'C:\out\MtMessengerEcologyData.xlsx' `
            -FiguresDir 'C:\out\figures' -TablesDir 'C:\out\tables'
        $c | Should -Match '\[input\]'
        $c | Should -Match 'macroinvertebrate_db = "T:/a/m.xlsx"'
        $c | Should -Match 'aquatic_monitoring_db = "T:/a/q.xlsx"'
        $c | Should -Match '\[output\]'
        $c | Should -Match 'data_xlsx = "C:/out/MtMessengerEcologyData.xlsx"'
        $c | Should -Match 'figures_dir = "C:/out/figures"'
        $c | Should -Match 'tables_dir = "C:/out/tables"'
        $c | Should -Not -Match '\\'
    }
}
Describe 'New-CycleTomlContent (Workbook mode)' {
    It 'omits [input] and points data_xlsx at the selected workbook' {
        $c = New-CycleTomlContent -Mode 'Workbook' `
            -DataXlsx 'D:\existing\Data.xlsx' `
            -FiguresDir 'C:\out\figures' -TablesDir 'C:\out\tables'
        $c | Should -Not -Match '\[input\]'
        $c | Should -Not -Match 'macroinvertebrate_db'
        $c | Should -Match '\[output\]'
        $c | Should -Match 'data_xlsx = "D:/existing/Data.xlsx"'
    }
}
Describe 'Write-CycleToml' {
    It 'writes a readable temp file from a resolved paths hashtable' {
        $paths = @{ Mode='Databases'; MacroDb='T:\m.xlsx'; AquaticDb='T:\q.xlsx';
                    DataXlsx='C:\o\MtMessengerEcologyData.xlsx';
                    FiguresDir='C:\o\figures'; TablesDir='C:\o\tables'; OutputDir='C:\o' }
        $p = Write-CycleToml -Paths $paths -Path (Join-Path $TestDrive 'cycle.toml')
        Test-Path $p | Should -BeTrue
        (Get-Content -Raw $p) | Should -Match 'aquatic_monitoring_db = "T:/q.xlsx"'
    }
}
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `powershell.exe -NoProfile -Command "Import-Module Pester -MinimumVersion 5.0.0; Invoke-Pester -Path launcher\tests\ConfigWriter.Tests.ps1 -Output Detailed"`
Expected: FAIL — `New-CycleTomlContent` has no `-Mode` parameter.

- [ ] **Step 3: Rewrite the ConfigWriter engine**

Replace the contents of `launcher/engine/ConfigWriter.ps1` with:

```powershell
function ConvertTo-TomlPath {
    param([Parameter(Mandatory)][string]$Path)
    return ($Path -replace '\\', '/')
}

function New-CycleTomlContent {
    param(
        [Parameter(Mandatory)][ValidateSet('Databases','Workbook')][string]$Mode,
        [string]$MacroDb,
        [string]$AquaticDb,
        [Parameter(Mandatory)][string]$DataXlsx,
        [Parameter(Mandatory)][string]$FiguresDir,
        [Parameter(Mandatory)][string]$TablesDir
    )
    $lines = New-Object System.Collections.Generic.List[string]
    if ($Mode -eq 'Databases') {
        $lines.Add('[input]')
        $lines.Add("macroinvertebrate_db = `"$(ConvertTo-TomlPath $MacroDb)`"")
        $lines.Add("aquatic_monitoring_db = `"$(ConvertTo-TomlPath $AquaticDb)`"")
        $lines.Add('')
    }
    $lines.Add('[output]')
    $lines.Add("data_xlsx = `"$(ConvertTo-TomlPath $DataXlsx)`"")
    $lines.Add("figures_dir = `"$(ConvertTo-TomlPath $FiguresDir)`"")
    $lines.Add("tables_dir = `"$(ConvertTo-TomlPath $TablesDir)`"")
    return (($lines -join "`r`n") + "`r`n")
}

function Write-CycleToml {
    param(
        [Parameter(Mandatory)][hashtable]$Paths,
        [string]$Path = (Join-Path ([System.IO.Path]::GetTempPath()) ("cycle-" + [guid]::NewGuid().ToString('N') + ".toml"))
    )
    $content = New-CycleTomlContent -Mode $Paths.Mode -MacroDb $Paths.MacroDb `
        -AquaticDb $Paths.AquaticDb -DataXlsx $Paths.DataXlsx `
        -FiguresDir $Paths.FiguresDir -TablesDir $Paths.TablesDir
    [System.IO.File]::WriteAllText($Path, $content, (New-Object System.Text.UTF8Encoding($false)))
    return $Path
}
```

- [ ] **Step 4: Run the test, verify it passes**

Run: `powershell.exe -NoProfile -Command "Import-Module Pester -MinimumVersion 5.0.0; Invoke-Pester -Path launcher\tests\ConfigWriter.Tests.ps1 -Output Detailed"`
Expected: PASS (all three describe blocks).

- [ ] **Step 5: Commit**

```bash
git add launcher/engine/ConfigWriter.ps1 launcher/tests/ConfigWriter.Tests.ps1
git commit -m "feat(launcher): make cycle.toml writer mode-aware"
```

---

### Task 8: Mode-aware output preflight

**Files:**
- Modify: `launcher/engine/OutputPreflight.ps1`
- Test: `launcher/tests/OutputPreflight.Tests.ps1`

**Interfaces:**
- Consumes: `Test-FileLocked` (unchanged, same file).
- Produces: `Test-OutputWritable -Mode <Databases|Workbook> -OutputDir <dir> -DataXlsx <path>` → `[pscustomobject]@{ Ok; Problems }`. Checks: the output folder exists or its parent exists; in `Databases` mode the built workbook is not locked; in `Workbook` mode the selected workbook exists and is not locked.

- [ ] **Step 1: Rewrite the OutputPreflight tests**

Replace the `Describe 'Test-OutputWritable'` block in `launcher/tests/OutputPreflight.Tests.ps1` with (keep the existing `Describe 'Test-FileLocked'` block as-is):

```powershell
Describe 'Test-OutputWritable' {
    It 'is Ok in Databases mode when the output folder exists and the workbook is free' {
        $out = Join-Path $TestDrive 'out'; New-Item -ItemType Directory -Path $out | Out-Null
        (Test-OutputWritable -Mode 'Databases' -OutputDir $out `
            -DataXlsx (Join-Path $out 'MtMessengerEcologyData.xlsx')).Ok | Should -BeTrue
    }
    It 'is Ok in Databases mode when the output folder is missing but its parent exists' {
        $parent = Join-Path $TestDrive 'p'; New-Item -ItemType Directory -Path $parent | Out-Null
        $out = Join-Path $parent 'new-out'
        (Test-OutputWritable -Mode 'Databases' -OutputDir $out `
            -DataXlsx (Join-Path $out 'MtMessengerEcologyData.xlsx')).Ok | Should -BeTrue
    }
    It 'flags a locked built workbook with an Excel message (Databases mode)' {
        $out = Join-Path $TestDrive 'out2'; New-Item -ItemType Directory -Path $out | Out-Null
        $xlsx = Join-Path $out 'MtMessengerEcologyData.xlsx'; Set-Content -LiteralPath $xlsx -Value 'x'
        $s = [System.IO.File]::Open($xlsx, 'Open', 'ReadWrite', 'None')
        try {
            $r = Test-OutputWritable -Mode 'Databases' -OutputDir $out -DataXlsx $xlsx
            $r.Ok | Should -BeFalse
            ($r.Problems -join ' ') | Should -Match 'open in Excel'
        } finally { $s.Close(); $s.Dispose() }
    }
    It 'flags a missing input workbook (Workbook mode)' {
        $out = Join-Path $TestDrive 'out3'; New-Item -ItemType Directory -Path $out | Out-Null
        $r = Test-OutputWritable -Mode 'Workbook' -OutputDir $out `
            -DataXlsx (Join-Path $TestDrive 'nope.xlsx')
        $r.Ok | Should -BeFalse
        ($r.Problems -join ' ') | Should -Match 'not found'
    }
    It 'is Ok in Workbook mode when the workbook exists and is free' {
        $out = Join-Path $TestDrive 'out4'; New-Item -ItemType Directory -Path $out | Out-Null
        $wb = Join-Path $TestDrive 'Data.xlsx'; Set-Content -LiteralPath $wb -Value 'x'
        (Test-OutputWritable -Mode 'Workbook' -OutputDir $out -DataXlsx $wb).Ok | Should -BeTrue
    }
}
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `powershell.exe -NoProfile -Command "Import-Module Pester -MinimumVersion 5.0.0; Invoke-Pester -Path launcher\tests\OutputPreflight.Tests.ps1 -Output Detailed"`
Expected: FAIL — `Test-OutputWritable` has no `-Mode`/`-OutputDir` parameters.

- [ ] **Step 3: Rewrite `Test-OutputWritable`**

In `launcher/engine/OutputPreflight.ps1`, keep `Test-FileLocked` unchanged and replace the `Test-OutputWritable` function with:

```powershell
function Test-OutputWritable {
    param(
        [Parameter(Mandatory)][ValidateSet('Databases','Workbook')][string]$Mode,
        [Parameter(Mandatory)][string]$OutputDir,
        [Parameter(Mandatory)][string]$DataXlsx
    )
    $problems = New-Object System.Collections.Generic.List[string]

    # Output folder must exist, or its parent must exist so it can be created.
    if (-not (Test-Path -LiteralPath $OutputDir)) {
        $parent = [System.IO.Path]::GetDirectoryName($OutputDir)
        if (-not $parent -or -not (Test-Path -LiteralPath $parent)) {
            $problems.Add("Output folder cannot be created (parent does not exist): $OutputDir")
        }
    }

    if ($Mode -eq 'Workbook') {
        if (-not (Test-Path -LiteralPath $DataXlsx -PathType Leaf)) {
            $problems.Add("Data workbook not found: $DataXlsx")
        } elseif (Test-FileLocked -Path $DataXlsx) {
            $problems.Add("$([System.IO.Path]::GetFileName($DataXlsx)) is open in Excel - close it and try again.")
        }
    } else {
        # Databases mode: the workbook is produced; only a stale lock blocks us.
        if (Test-FileLocked -Path $DataXlsx) {
            $problems.Add("$([System.IO.Path]::GetFileName($DataXlsx)) is open in Excel - close it and try again.")
        }
    }

    return [pscustomobject]@{
        Ok       = ($problems.Count -eq 0)
        Problems = $problems.ToArray()
    }
}
```

- [ ] **Step 4: Run the test, verify it passes**

Run: `powershell.exe -NoProfile -Command "Import-Module Pester -MinimumVersion 5.0.0; Invoke-Pester -Path launcher\tests\OutputPreflight.Tests.ps1 -Output Detailed"`
Expected: PASS (both describe blocks).

- [ ] **Step 5: Commit**

```bash
git add launcher/engine/OutputPreflight.ps1 launcher/tests/OutputPreflight.Tests.ps1
git commit -m "feat(launcher): make output preflight mode-aware (single output folder)"
```

---

### Task 9: Settings for the new fields

**Files:**
- Modify: `launcher/engine/LauncherSettings.ps1`
- Test: `launcher/tests/LauncherSettings.Tests.ps1`

**Interfaces:**
- Produces: `Get-LauncherSettings -Path` returns an object with keys `Mode, MacroDb, AquaticDb, DataWorkbook, OutputDir`; `Mode` defaults to `'Databases'`, the rest blank; corrupt/missing file → defaults. `Save-LauncherSettings -Path -Settings <hashtable>` round-trips those keys.

- [ ] **Step 1: Rewrite the settings tests**

Replace the contents of `launcher/tests/LauncherSettings.Tests.ps1` with:

```powershell
BeforeAll { . "$PSScriptRoot/../engine/LauncherSettings.ps1" }
Describe 'LauncherSettings' {
    It 'returns defaults (Mode=Databases, blanks) when the file is missing' {
        $s = Get-LauncherSettings -Path (Join-Path $TestDrive 'none.json')
        $s.Mode | Should -Be 'Databases'
        $s.MacroDb | Should -BeNullOrEmpty
        $s.OutputDir | Should -BeNullOrEmpty
        $s.DataWorkbook | Should -BeNullOrEmpty
    }
    It 'round-trips saved settings including Mode' {
        $p = Join-Path $TestDrive 'settings.json'
        Save-LauncherSettings -Path $p -Settings @{ Mode='Workbook'; MacroDb='m'; AquaticDb='q';
            DataWorkbook='d.xlsx'; OutputDir='C:\out' }
        $s = Get-LauncherSettings -Path $p
        $s.Mode | Should -Be 'Workbook'
        $s.DataWorkbook | Should -Be 'd.xlsx'
        $s.OutputDir | Should -Be 'C:\out'
    }
    It 'falls back to defaults on a corrupt file' {
        $p = Join-Path $TestDrive 'bad.json'; Set-Content -LiteralPath $p -Value '{ not json'
        $s = Get-LauncherSettings -Path $p
        $s.Mode | Should -Be 'Databases'
        $s.MacroDb | Should -BeNullOrEmpty
    }
}
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `powershell.exe -NoProfile -Command "Import-Module Pester -MinimumVersion 5.0.0; Invoke-Pester -Path launcher\tests\LauncherSettings.Tests.ps1 -Output Detailed"`
Expected: FAIL — `Mode` property is absent / defaults to the old key set.

- [ ] **Step 3: Update the settings defaults**

In `launcher/engine/LauncherSettings.ps1`, change the `$default` in `Get-LauncherSettings` to the new key set (note `Mode` defaults to `'Databases'`, not blank):

```powershell
function Get-LauncherSettings {
    param([Parameter(Mandatory)][string]$Path)
    $default = [ordered]@{ Mode = 'Databases'; MacroDb = ''; AquaticDb = '';
                           DataWorkbook = ''; OutputDir = '' }
    if (-not (Test-Path -LiteralPath $Path)) { return [pscustomobject]$default }
    try {
        $json = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        foreach ($k in @($default.Keys)) {
            if (($json.PSObject.Properties.Name -contains $k) -and $json.$k) {
                $default[$k] = [string]$json.$k
            }
        }
        return [pscustomobject]$default
    } catch {
        return [pscustomobject]$default
    }
}
```

(`Save-LauncherSettings` is unchanged — it serialises whatever hashtable it is given.)

- [ ] **Step 4: Run the test, verify it passes**

Run: `powershell.exe -NoProfile -Command "Import-Module Pester -MinimumVersion 5.0.0; Invoke-Pester -Path launcher\tests\LauncherSettings.Tests.ps1 -Output Detailed"`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add launcher/engine/LauncherSettings.ps1 launcher/tests/LauncherSettings.Tests.ps1
git commit -m "feat(launcher): persist Mode + DataWorkbook + OutputDir settings"
```

---

## Part 4 — Launcher view + docs

### Task 10: Rewrite the launcher form (mode toggle + single output folder)

**Files:**
- Modify: `launcher/launcher.ps1`
- Modify: `launcher/README.md`

**Interfaces:**
- Consumes: `Resolve-RunPaths` (Task 6), `Write-CycleToml` (Task 7), `Test-OutputWritable` (Task 8), `Get-/Save-LauncherSettings` (Task 9), plus the existing `Get-LauncherRscript`, `Start-Job`/`ProcessRunner`, `Get-RunStatus`.
- Produces: a WinForms window with a Build/Workbook radio toggle, the matching input pickers, and a single Output-folder picker; **Run** invokes `run_pipeline.R` (Databases) or `run_all.R --config` (Workbook); **Check inputs** runs `run_data.R --validate` (Databases) or a file-level workbook check (Workbook). There is **no automated test** for the view — the gate is a parse check plus a manual smoke run.

> **Note on `run_all.R` invocation:** in Workbook mode, Run calls the bundled `pipeline\src\r\run_all.R` with a single `--config=<toml>` argument; `run_all.R` reads `data_xlsx`/`figures_dir`/`tables_dir` from that TOML.
>
> **Note on Check inputs (Workbook mode):** a lightweight, R-free check — the workbook exists, has an `.xlsx` extension, and is not locked (reuse `Test-FileLocked`). Full sheet validation happens at Run when `run_all.R` loads the workbook and errors clearly if a sheet is malformed.

- [ ] **Step 1: Replace the path-row construction and add the mode toggle**

In `launcher/launcher.ps1`, replace the five `New-PathRow` calls (lines ~65-69) and add radio buttons + an output-folder row. Replace the block from the `New-PathRow` definition's consumers through the figures/tables rows with:

```powershell
# --- Input mode toggle ---
$grpInput = New-Object System.Windows.Forms.GroupBox
$grpInput.Text = 'Input'; $grpInput.Location = '12,8'; $grpInput.Size = '736,150'

$rbDatabases = New-Object System.Windows.Forms.RadioButton
$rbDatabases.Text = 'Build data workbook from databases'
$rbDatabases.Location = '10,20'; $rbDatabases.Size = '320,20'; $rbDatabases.Checked = $true
$rbWorkbook = New-Object System.Windows.Forms.RadioButton
$rbWorkbook.Text = 'Use an existing data workbook'
$rbWorkbook.Location = '10,92'; $rbWorkbook.Size = '320,20'
$grpInput.Controls.AddRange(@($rbDatabases, $rbWorkbook))
$form.Controls.Add($grpInput)

# Rows live inside the Input group; Y is relative to the group box.
$tbMacro    = New-PathRow $grpInput 'Macroinvertebrate DB'  46  'OpenXlsx'
$tbAquatic  = New-PathRow $grpInput 'Aquatic monitoring DB' 68  'OpenXlsx'
$tbWorkbook = New-PathRow $grpInput 'Data workbook (.xlsx)' 118 'OpenXlsx'

# --- Output folder ---
$tbOutput = New-PathRow $form 'Output folder' 172 'Folder'
```

Adjust `New-PathRow` so row labels/text/buttons sit correctly inside a group box — the function already positions controls relative to `$Parent`, so no change to the function body is required; only confirm the `$Y` offsets above place the macro/aquatic rows under the first radio and the workbook row under the second radio. Also bump the form height to accommodate the group box — change the form size line near the top to:

```powershell
$form.Size = New-Object System.Drawing.Size(780, 640)
```

and move the buttons/log/status down. Update their `Location`s:

```powershell
$btnCheck.Location = '210,212'
$btnRun.Location   = '578,212'
$log.Location      = '15,285'; $log.Size = '740,250'
$status.Location   = '15,548'
$btnCancel.Location = '672,578'
```

- [ ] **Step 2: Add a mode-toggle handler and update the busy/state helpers**

Add, after the controls are created, a function that enables only the active mode's rows, and wire it to both radios:

```powershell
function Update-ModeEnabled {
    $dbMode = $rbDatabases.Checked
    $tbMacro.Enabled    = $dbMode
    $tbAquatic.Enabled  = $dbMode
    $tbWorkbook.Enabled = -not $dbMode
}
$rbDatabases.Add_CheckedChanged({ Update-ModeEnabled })
$rbWorkbook.Add_CheckedChanged({ Update-ModeEnabled })
```

Update `Set-Busy` to disable the new controls (replace its `foreach` line and add the radios):

```powershell
function Set-Busy([bool]$busy) {
    $btnRun.Enabled = -not $busy; $btnCheck.Enabled = -not $busy; $btnCancel.Enabled = $busy
    $rbDatabases.Enabled = -not $busy; $rbWorkbook.Enabled = -not $busy
    foreach ($t in @($tbMacro,$tbAquatic,$tbWorkbook,$tbOutput)) { $t.Enabled = -not $busy }
    if (-not $busy) { Update-ModeEnabled }
}
```

- [ ] **Step 3: Replace the paths/state helpers**

Replace `Get-PathsHash` with a UI-state reader plus a resolver call. Replace the function with:

```powershell
function Get-UiState {
    $mode = if ($rbDatabases.Checked) { 'Databases' } else { 'Workbook' }
    @{ Mode = $mode; MacroDb = $tbMacro.Text; AquaticDb = $tbAquatic.Text
       DataWorkbook = $tbWorkbook.Text; OutputDir = $tbOutput.Text }
}
function Get-ResolvedPaths {
    $s = Get-UiState
    Resolve-RunPaths -Mode $s.Mode -OutputDir $s.OutputDir `
        -MacroDb $s.MacroDb -AquaticDb $s.AquaticDb -DataWorkbook $s.DataWorkbook
}
```

- [ ] **Step 4: Rewrite the Check / Run / settings wiring**

Define the bundled `run_all.R` path near the other path config (with `$RunPipeline`/`$RunData`):

```powershell
$RunAll = Join-Path $PipelineRoot 'src\r\run_all.R'
```

Replace the `$btnCheck.Add_Click` body:

```powershell
$btnCheck.Add_Click({
    $status.ForeColor = [System.Drawing.Color]::Black
    $resolved = Get-ResolvedPaths
    if ($resolved.Mode -eq 'Workbook') {
        $wb = $resolved.DataXlsx
        if (-not (Test-Path -LiteralPath $wb -PathType Leaf) -or
            [System.IO.Path]::GetExtension($wb) -ne '.xlsx') {
            $status.ForeColor = [System.Drawing.Color]::Red
            $status.Text = 'Select an existing .xlsx data workbook.'
            return
        }
        if (Test-FileLocked -Path $wb) {
            $status.ForeColor = [System.Drawing.Color]::Red
            $status.Text = "$([System.IO.Path]::GetFileName($wb)) is open in Excel - close it and try again."
            return
        }
        $status.ForeColor = [System.Drawing.Color]::Green
        $status.Text = 'Workbook looks readable. Click Run to generate figures and tables.'
        return
    }
    $status.Text = 'Checking inputs...'
    $log.Clear(); Set-Busy $true
    $cfg = Write-CycleToml -Paths $resolved
    Start-Job $script:RscriptPath @('--vanilla', $RunData, $cfg, '--validate')
    $timer.Start()
})
```

Replace the `$btnRun.Add_Click` body:

```powershell
$btnRun.Add_Click({
    $status.ForeColor = [System.Drawing.Color]::Black
    $resolved = Get-ResolvedPaths
    $pf = Test-OutputWritable -Mode $resolved.Mode -OutputDir $resolved.OutputDir -DataXlsx $resolved.DataXlsx
    if (-not $pf.Ok) {
        $status.ForeColor = [System.Drawing.Color]::Red
        $status.Text = ($pf.Problems -join '  ')
        return
    }
    $status.Text = 'Running...'; $log.Clear(); Set-Busy $true
    $cfg = Write-CycleToml -Paths $resolved
    if ($resolved.Mode -eq 'Workbook') {
        Start-Job $script:RscriptPath @('--vanilla', $RunAll, "--config=$cfg")
    } else {
        Start-Job $script:RscriptPath @('--vanilla', $RunPipeline, $cfg)
    }
    $timer.Start()
})
```

In the drain timer's completion block, save the UI state on success and write the run log into the output folder. Replace the `Save-LauncherSettings ...` line and the run-log `try` block with:

```powershell
        if ($st.State -eq 'Succeeded') { Save-LauncherSettings -Path $SettingsPath -Settings (Get-UiState) }
        try {
            $stamp = (Get-Date).ToString('yyyy-MM-dd-HHmm')
            $logDir = $tbOutput.Text
            if ($logDir -and (Test-Path $logDir)) {
                Set-Content -LiteralPath (Join-Path $logDir "run-$stamp.log") -Value $sync.Log.ToString()
            }
        } catch { }
```

- [ ] **Step 5: Update startup to restore mode + fields**

Replace the startup settings-restore lines (the `$tbMacro.Text=$s.MacroDb; ...` block) with:

```powershell
$s = Get-LauncherSettings -Path $SettingsPath
if ($s.Mode -eq 'Workbook') { $rbWorkbook.Checked = $true } else { $rbDatabases.Checked = $true }
$tbMacro.Text = $s.MacroDb; $tbAquatic.Text = $s.AquaticDb
$tbWorkbook.Text = $s.DataWorkbook; $tbOutput.Text = $s.OutputDir
Update-ModeEnabled
```

- [ ] **Step 6: Parse-check the script**

Run: `powershell.exe -NoProfile -Command "$t=$null;$e=$null;[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path 'launcher\launcher.ps1'),[ref]$t,[ref]$e); if($e){$e|ForEach-Object{$_.Message}; exit 1} else {'parse ok'}"`
Expected: `parse ok` (no parser errors).

- [ ] **Step 7: Update the README**

In `launcher/README.md`, update the end-user steps and the "How it works" section to describe the two modes and the single output folder. Replace the step-3 bullet under "For end users" with:

```markdown
3. Launch it. Choose **Build data workbook from databases** and browse to the
   two input `.xlsx` databases, **or** choose **Use an existing data workbook**
   and pick a previously built workbook. Pick an **Output folder** (the app
   creates `figures\` and `tables\` inside it, and in build mode writes
   `MtMessengerEcologyData.xlsx` there). Click **Check inputs**, then **Run**.
```

In the "How it works (brief)" section, replace the "A **Run** writes the 5 paths…" bullet with:

```markdown
- A **Run** writes the chosen paths to a temp `cycle.toml`. In *Build* mode it
  invokes `run_pipeline.R` (data workbook → figures + tables); in *Workbook*
  mode it invokes `run_all.R --config` (figures + tables from the selected
  workbook). **Check inputs** runs `run_data.R --validate` in Build mode, and a
  quick file check on the workbook in Workbook mode.
- Output is a single folder containing `MtMessengerEcologyData.xlsx` (build
  mode), `figures\`, and `tables\`. Fish trapping figures come from a `Fish`
  sheet now written into the data workbook.
```

- [ ] **Step 8: Manual smoke run (staged app)**

Stage and run locally (needs R installed for the build step, per the README):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tasks\build_launcher.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File build\launcher-app\launcher.ps1
```

Verify manually:
1. **Build mode:** pick the two DBs + an empty output folder → Check inputs passes → Run → the folder ends up with `MtMessengerEcologyData.xlsx`, `figures\` (including `figures\Fish\fish_*.jpeg`), and `tables\`.
2. **Workbook mode:** select the `MtMessengerEcologyData.xlsx` just produced + a fresh output folder → Run → `figures\` + `tables\` regenerate, **including fish figures**, without re-reading the DBs.
3. Toggling the radio greys the inactive rows; remembered mode + paths restore on relaunch.

- [ ] **Step 9: Commit**

```bash
git add launcher/launcher.ps1 launcher/README.md
git commit -m "feat(launcher): build/workbook mode toggle + single output folder"
```

---

## Self-Review

**Spec coverage:**
- Fish in the workbook (domain, schema, writer, validate, figure-stage read) → Tasks 1–4. ✓
- Optional input DBs in `config.R` → Task 5. ✓
- Mode toggle UI + single output folder → Tasks 6–10. ✓
- `cycle.toml` shape per mode → Task 7. ✓
- Preflight per mode → Task 8. ✓
- Settings (Mode + new keys) → Task 9. ✓
- Check inputs adapts to mode; Run picks entrypoint; run log in output folder → Task 10. ✓
- Python `schemas.py` untouched → Global Constraints + Task 1 comment. ✓
- Build-mode workbook name, lowercase `figures`/`tables`, forward slashes → Global Constraints, Tasks 6–7. ✓

**Placeholder scan:** No TBD/TODO; every code step shows complete code. The only deferred item — exact fish columns — was resolved to a concrete `FISH_COLUMNS` in Global Constraints and Task 1. ✓

**Type/name consistency:** `Resolve-RunPaths` returns keys `Mode/MacroDb/AquaticDb/OutputDir/DataXlsx/FiguresDir/TablesDir`; `New-CycleTomlContent`/`Test-OutputWritable` consume exactly those; `Get-UiState`/settings use `Mode/MacroDb/AquaticDb/DataWorkbook/OutputDir`; `FISH_COLUMNS` identical in `schemas.R`, the domain reorder, and all tests; `Fish` appended to `SHEET_ORDER` consistently. ✓
