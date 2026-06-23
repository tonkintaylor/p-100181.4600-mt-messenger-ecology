# Data Pipeline R Port — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Python `mgen` data pipeline with an R implementation that produces a byte-equivalent (value-equivalent on read-back) `MtMessengerEcologyData.xlsx`, leaving the R figure pipeline untouched, so the project becomes single-language (R + renv).

**Architecture:** Mirror `src/mgen/` one-for-one under `src/r/data/` using `source()`-based scripts (no R package). Each domain returns a `DomainResult` (R6); the orchestrator enforces a no-partial-output contract and writes the 8-sheet xlsx via `openxlsx`. Acceptance is gated on a golden-file diff against the existing `tests/assets/expected_Data.xlsx`, plus a full `testthat` port of the pytest suite.

**Tech Stack:** R 4.5, renv, `readxl` (read), `openxlsx` (write), `dplyr`/`tidyr`/`lubridate` (transforms), `R6` (result objects), `RcppTOML` (config), `testthat` 3e (tests).

**Reference spec:** `docs/superpowers/specs/2026-06-18-data-pipeline-r-port-design.md`

## How to read this plan

This is a **port**. For each module, the authoritative source of behavior is the named Python file in `src/mgen/`. Each task gives the exact R target file, the interface it must produce, complete R implementation code, and the gotchas that differ between pandas and R. Test tasks that say "mirror `test_X.py`" mean: re-express **every** `test_` function in that pytest file as a `test_that()` block with the same inputs and the same assertions (numeric comparisons use `tolerance = 1e-7`). Do not drop cases.

Execution order matters: foundation (Tasks 1–7) → domains (8–16) → orchestration (17–18) → Python removal (19). **The Python side stays runnable until Task 19** — do not delete it earlier, so you can cross-check R output against `uv run mgen data` at any point.

## Global Constraints

- R version floor: **4.5** (matches `renv.lock`).
- All R source is `source()`-d, not packaged. No `library()` calls inside `src/r/data/` modules — assume packages are attached by the entry script. Use explicit `pkg::fn()` for clarity in modules.
- Output sheet order is exactly: `Macro, Macro1, MacroSpecies, Sediment, SedimentSize, Clarity, RPD, LDV`.
- Output column names per sheet are **verbatim** from `src/mgen/shared/schemas.py` (including spaces and punctuation, e.g. `"Clarity (mm)"`, `"Clay/silt (<0.06 mm)"`).
- `BASELINE_END = 2022-03-31`. Samples dated on or before this are `Period = "Baseline"` regardless of source label.
- `SITES_WITHOUT_REPLICATES = {EM1, EM2, EM4, EM8}` use QMCI-sb and are excluded from the aggregated `Macro` sheet.
- Validation error row references use **1-based source-spreadsheet row numbers** (documented divergence from pandas' 0-based index).
- Golden numeric comparison tolerance: `1e-7` relative. Date columns compared as calendar dates (`as.Date`) to avoid tz/time artifacts.
- No change to `run_all.R` figure output. The intermediate `MtMessengerEcologyData.xlsx` remains the hand-off.
- Platform: Windows (paths, `Rscript.exe`).

---

## Phase 0 — Scaffolding & dependencies

### Task 1: Add R dependencies and create directories

**Files:**
- Modify: `DESCRIPTION` (add to `Imports`)
- Create: `src/r/data/` (dir), `tests/r/` (dir), `tests/r/assets/` (dir)

**Interfaces:**
- Produces: an renv environment with `R6`, `RcppTOML`, `testthat` installed and snapshotted; the directory skeleton later tasks write into.

- [ ] **Step 1: Add the three packages to `DESCRIPTION`**

Edit the `Imports:` field to append `R6`, `RcppTOML`, `testthat`:

```
Imports:
    readxl,
    dplyr,
    tidyr,
    ggplot2,
    vegan,
    indicspecies,
    ggrepel,
    zoo,
    patchwork,
    openxlsx,
    lubridate,
    R6,
    RcppTOML,
    testthat
```

- [ ] **Step 2: Install and snapshot**

Run:
```powershell
Rscript --vanilla -e "source('renv/activate.R'); renv::install(c('R6','RcppTOML','testthat')); renv::snapshot(prompt = FALSE)"
```
Expected: packages install; `renv.lock` updated to include all three.

- [ ] **Step 3: Create the directory skeleton**

Run:
```powershell
New-Item -ItemType Directory -Force src/r/data, src/r/data/domains, tests/r, tests/r/assets | Out-Null
```

- [ ] **Step 4: Copy the golden asset into the R test tree**

Run:
```powershell
Copy-Item tests/assets/expected_Data.xlsx tests/r/assets/expected_Data.xlsx
```
(The original stays put until Task 19 removes the Python tests.)

- [ ] **Step 5: Commit**

```bash
git add DESCRIPTION renv.lock tests/r/assets/expected_Data.xlsx
git commit -m "build: add R6/RcppTOML/testthat deps and R pipeline skeleton"
```

---

## Phase 1 — Foundation modules

### Task 2: Schemas (`schemas.R`)

**Files:**
- Create: `src/r/data/schemas.R`
- Test: `tests/r/test-schemas.R`
- Reference: `src/mgen/shared/schemas.py`, `src/mgen/writer.py` (SHEET_ORDER)

**Interfaces:**
- Produces: character vectors `MACRO1_COLUMNS`, `MACRO_COLUMNS`, `MACRO_SPECIES_COLUMNS`, `SEDIMENT_COLUMNS`, `CLARITY_COLUMNS`, `SEDIMENT_SIZE_COLUMNS`, `RPD_COLUMNS`, `LDV_COLUMNS`, `SHEET_ORDER`; named list `SCHEMA_MAP` (sheet → columns).

- [ ] **Step 1: Write the failing test** (`tests/r/test-schemas.R`)

```r
test_that("schema column vectors match the Python contract", {
  source("src/r/data/schemas.R", local = TRUE)
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
  expect_equal(SHEET_ORDER,
               c("Macro","Macro1","MacroSpecies","Sediment",
                 "SedimentSize","Clarity","RPD","LDV"))
  expect_equal(length(SEDIMENT_SIZE_COLUMNS), 14L)
  expect_equal(SEDIMENT_SIZE_COLUMNS[5], "Clay/silt (<0.06 mm)")
  expect_setequal(names(SCHEMA_MAP), SHEET_ORDER)
})
```

- [ ] **Step 2: Run it to verify it fails**

Run: `Rscript --vanilla -e "source('renv/activate.R'); testthat::test_file('tests/r/test-schemas.R')"`
Expected: FAIL — `cannot open file 'src/r/data/schemas.R'`.

- [ ] **Step 3: Write `src/r/data/schemas.R`**

```r
# schemas.R — output column contracts for Data.xlsx sheets.
# Verbatim from src/mgen/shared/schemas.py. Any change here is a breaking
# change for the R figure pipeline.

MACRO1_COLUMNS <- c("Site", "Date", "Period", "EPTrich", "EPTabun", "QMCI", "Season")
MACRO_COLUMNS <- MACRO1_COLUMNS

MACRO_SPECIES_COLUMNS <- c(
  "Phase", "Date", "Site", "Taxa", "Species", "Tally", "is_additional"
)

SEDIMENT_COLUMNS <- c("Site", "Date", "Period", "SAM1", "SAM3", "Season")

CLARITY_COLUMNS <- c(
  "Site", "Date", "NTU-Fieldmeter", "NTU-Continuous Sensor", "NTU-Lab",
  "pH-Fieldmeter", "pH-Lab", "TSS-Lab", "Clarity (mm)", "Comments"
)

SEDIMENT_SIZE_COLUMNS <- c(
  "Site", "Date", "Period", "Season",
  "Clay/silt (<0.06 mm)", "Sand (>0.06-2 mm)", "Small gravel (>2-8 mm)",
  "Small-med gravel (>8-16 mm)", "Med-large gravel (>16-32 mm)",
  "Large gravel (>32-64 mm)", "Small cobble (>64-128 mm)",
  "Large cobble (>128-256 mm)", "Boulders (>256 mm)", "Bedrock"
)

RPD_COLUMNS <- c("Site", "Date", "Count", "Mean", "StdDev", "CI_Lower", "CI_Upper")

LDV_COLUMNS <- c("Site", "Date", "Season", "CV_pct")

SHEET_ORDER <- c(
  "Macro", "Macro1", "MacroSpecies", "Sediment",
  "SedimentSize", "Clarity", "RPD", "LDV"
)

SCHEMA_MAP <- list(
  Macro = MACRO_COLUMNS,
  Macro1 = MACRO1_COLUMNS,
  MacroSpecies = MACRO_SPECIES_COLUMNS,
  Sediment = SEDIMENT_COLUMNS,
  SedimentSize = SEDIMENT_SIZE_COLUMNS,
  Clarity = CLARITY_COLUMNS,
  RPD = RPD_COLUMNS,
  LDV = LDV_COLUMNS
)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `Rscript --vanilla -e "source('renv/activate.R'); testthat::test_file('tests/r/test-schemas.R')"`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/r/data/schemas.R tests/r/test-schemas.R
git commit -m "feat(r): add output schema column contracts"
```

### Task 3: Domain constants (`domain_types.R`)

**Files:**
- Create: `src/r/data/domain_types.R`
- Test: `tests/r/test-domain-types.R`
- Reference: `src/mgen/shared/domain_types.py`

**Interfaces:**
- Produces: `BASELINE_END` (Date), `VALID_SITES`, `SITES_WITHOUT_REPLICATES`, `VALID_PERIODS`, `VALID_SEASONS` (character vectors).

- [ ] **Step 1: Write the failing test** (`tests/r/test-domain-types.R`)

```r
test_that("domain constants match the Python contract", {
  source("src/r/data/domain_types.R", local = TRUE)
  expect_equal(BASELINE_END, as.Date("2022-03-31"))
  expect_setequal(SITES_WITHOUT_REPLICATES, c("EM1", "EM2", "EM4", "EM8"))
  expect_true(all(c("MMA 6", "MMA 6b") %in% VALID_SITES))
  expect_setequal(VALID_PERIODS, c("Baseline", "Construction"))
  expect_setequal(VALID_SEASONS,
                  c("Baseline", "Construction", "Routine", "Additional"))
})
```

- [ ] **Step 2: Run to verify it fails** — `Rscript --vanilla -e "source('renv/activate.R'); testthat::test_file('tests/r/test-domain-types.R')"` → FAIL (file missing).

- [ ] **Step 3: Write `src/r/data/domain_types.R`**

```r
# domain_types.R — shared monitoring constants.

# Samples on or before this date are Baseline regardless of source label.
BASELINE_END <- as.Date("2022-03-31")

# "MMA 6"/"MMA 6b" contain a space — matches source database values.
VALID_SITES <- c("EM1", "EM2", "EM3", "EM4", "EM5", "EM7", "EM8", "MMA 6", "MMA 6b")

# Sites lacking replicates — use QMCI-sb and are excluded from aggregated Macro.
SITES_WITHOUT_REPLICATES <- c("EM1", "EM2", "EM4", "EM8")

VALID_PERIODS <- c("Baseline", "Construction")
VALID_SEASONS <- c("Baseline", "Construction", "Routine", "Additional")
```

- [ ] **Step 4: Run to verify it passes** → PASS.

- [ ] **Step 5: Commit**

```bash
git add src/r/data/domain_types.R tests/r/test-domain-types.R
git commit -m "feat(r): add shared domain constants"
```

### Task 4: Error types (`errors.R`)

**Files:**
- Create: `src/r/data/errors.R`
- Test: `tests/r/test-errors.R`
- Reference: `src/mgen/shared/errors.py`, `tests/test_errors.py`

**Interfaces:**
- Produces:
  - `ValidationError(domain, severity, file, sheet, location, message)` → classed list, `class = "ValidationError"`, with `format.ValidationError` / `print.ValidationError` giving `"[SEVERITY] file → sheet → location: message"`.
  - `DomainResult` R6 generator with fields `data` (named list of data.frames or NULL), `errors` (list of `ValidationError`); methods `add_error(e)`, `ok()` (TRUE iff no error has `severity == "error"`).

- [ ] **Step 1: Write the failing test** (`tests/r/test-errors.R`) — mirror `tests/test_errors.py`, plus:

```r
source("src/r/data/errors.R", local = TRUE)

test_that("ValidationError formats with the arrow layout", {
  e <- ValidationError("Clarity", "error", "db.xlsx", "Clarity Data",
                       "header", "Missing required columns: ['Site']")
  expect_equal(format(e),
    "[ERROR] db.xlsx → Clarity Data → header: Missing required columns: ['Site']")
})

test_that("DomainResult ok() is FALSE when an error-severity error is present", {
  r <- DomainResult$new(data = NULL)
  expect_true(r$ok())
  r$add_error(ValidationError("D", "warning", "f", "s", "l", "m"))
  expect_true(r$ok())  # warnings do not fail
  r$add_error(ValidationError("D", "error", "f", "s", "l", "m"))
  expect_false(r$ok())
})

test_that("DomainResult holds named data frames", {
  df <- data.frame(a = 1)
  r <- DomainResult$new(data = list(Clarity = df))
  expect_true(r$ok())
  expect_equal(r$data$Clarity, df)
})
```

- [ ] **Step 2: Run to verify it fails** → FAIL (file missing).

- [ ] **Step 3: Write `src/r/data/errors.R`**

```r
# errors.R — validation error type and per-domain result object.

ValidationError <- function(domain, severity, file, sheet, location, message) {
  stopifnot(severity %in% c("error", "warning"))
  structure(
    list(domain = domain, severity = severity, file = file,
         sheet = sheet, location = location, message = message),
    class = "ValidationError"
  )
}

format.ValidationError <- function(x, ...) {
  sprintf("[%s] %s → %s → %s: %s",
          toupper(x$severity), x$file, x$sheet, x$location, x$message)
}

print.ValidationError <- function(x, ...) {
  cat(format(x), "\n")
  invisible(x)
}

DomainResult <- R6::R6Class(
  "DomainResult",
  public = list(
    data = NULL,
    errors = NULL,
    initialize = function(data = NULL, errors = list()) {
      self$data <- data
      self$errors <- errors
    },
    add_error = function(e) {
      self$errors <- c(self$errors, list(e))
      invisible(self)
    },
    ok = function() {
      !any(vapply(self$errors,
                  function(e) identical(e$severity, "error"),
                  logical(1)))
    }
  )
)
```

Note: `→` is the `→` arrow; keep it as the escape so the file is ASCII-safe.

- [ ] **Step 4: Run to verify it passes** → PASS.

- [ ] **Step 5: Commit**

```bash
git add src/r/data/errors.R tests/r/test-errors.R
git commit -m "feat(r): add ValidationError and DomainResult"
```

### Task 5: Validation primitives (`validation.R`)

**Files:**
- Create: `src/r/data/validation.R`
- Test: `tests/r/test-validation.R`
- Reference: `src/mgen/shared/validation.py`, `tests/test_validation.py`

**Interfaces:**
- Consumes: `ValidationError` from `errors.R`.
- Produces (each returns a `list()` of `ValidationError`, possibly empty):
  - `check_required_columns(df, expected, domain, file, sheet)`
  - `check_no_nulls(df, columns, domain, file, sheet)`
  - `check_value_range(df, column, min_val = NULL, max_val = NULL, domain, file, sheet)`

- [ ] **Step 1: Write the failing test** (`tests/r/test-validation.R`) — mirror **every** case in `tests/test_validation.py`. Representative cases:

```r
source("src/r/data/errors.R", local = TRUE)
source("src/r/data/validation.R", local = TRUE)

test_that("check_required_columns reports sorted missing columns", {
  df <- data.frame(Site = "EM1")
  errs <- check_required_columns(df, c("Site", "Date", "QMCI"),
                                 domain = "M", file = "f", sheet = "s")
  expect_length(errs, 1)
  expect_match(errs[[1]]$message, "Date")
  expect_match(errs[[1]]$message, "QMCI")
  expect_equal(errs[[1]]$location, "header")
})

test_that("check_required_columns passes when all present", {
  df <- data.frame(Site = "EM1", Date = as.Date("2024-01-01"))
  expect_length(check_required_columns(df, c("Site", "Date"),
                domain = "M", file = "f", sheet = "s"), 0)
})

test_that("check_no_nulls flags NA cells and reports source rows", {
  df <- data.frame(QMCI = c(1, NA, 3, NA))
  errs <- check_no_nulls(df, "QMCI", domain = "M", file = "f", sheet = "s")
  expect_length(errs, 1)
  expect_match(errs[[1]]$message, "2 null")
})

test_that("check_value_range flags non-numeric and out-of-range", {
  df <- data.frame(x = c("1", "abc", "5", "999"))
  errs <- check_value_range(df, "x", min_val = 0, max_val = 100,
                            domain = "M", file = "f", sheet = "s")
  expect_true(any(vapply(errs, function(e) grepl("non-numeric", e$message), logical(1))))
  expect_true(any(vapply(errs, function(e) grepl("above maximum", e$message), logical(1))))
})
```

- [ ] **Step 2: Run to verify it fails** → FAIL (file missing).

- [ ] **Step 3: Write `src/r/data/validation.R`**

```r
# validation.R — shared validation primitives. Each returns list(ValidationError).
# Row references are 1-based source-spreadsheet rows (data row 1 = first data row).

.first_rows <- function(idx, n = 5) {
  # idx: integer positions (1-based) of offending rows. Return first n as text.
  paste0("[", paste(utils::head(idx, n) - 1, collapse = ", "), "]")
}

check_required_columns <- function(df, expected, domain, file, sheet) {
  missing <- setdiff(expected, names(df))
  if (length(missing) == 0) return(list())
  list(ValidationError(
    domain = domain, severity = "error", file = file, sheet = sheet,
    location = "header",
    message = sprintf("Missing required columns: %s",
                      paste0("[", paste(sprintf("'%s'", sort(missing)),
                                        collapse = ", "), "]"))
  ))
}

check_no_nulls <- function(df, columns, domain, file, sheet) {
  errs <- list()
  for (col in columns) {
    if (!col %in% names(df)) next
    null_mask <- is.na(df[[col]])
    if (any(null_mask)) {
      rows <- which(null_mask)
      errs <- c(errs, list(ValidationError(
        domain = domain, severity = "error", file = file, sheet = sheet,
        location = sprintf("column '%s', rows %s", col, .first_rows(rows)),
        message = sprintf("Found %d null values in required column '%s'",
                          sum(null_mask), col)
      )))
    }
  }
  errs
}

check_value_range <- function(df, column, min_val = NULL, max_val = NULL,
                              domain, file, sheet) {
  errs <- list()
  if (!column %in% names(df)) return(errs)
  raw <- df[[column]]
  series <- suppressWarnings(as.numeric(as.character(raw)))

  coerced_nans <- is.na(series) & !is.na(raw)
  if (any(coerced_nans)) {
    rows <- which(coerced_nans)
    errs <- c(errs, list(ValidationError(
      domain = domain, severity = "error", file = file, sheet = sheet,
      location = sprintf("column '%s', rows %s", column, .first_rows(rows)),
      message = sprintf("Found %d non-numeric values in column '%s'",
                        sum(coerced_nans), column)
    )))
  }
  if (!is.null(min_val)) {
    below <- !is.na(series) & series < min_val
    if (any(below)) {
      errs <- c(errs, list(ValidationError(
        domain = domain, severity = "error", file = file, sheet = sheet,
        location = sprintf("column '%s', rows %s", column, .first_rows(which(below))),
        message = sprintf("Values below minimum %s in column '%s'", min_val, column)
      )))
    }
  }
  if (!is.null(max_val)) {
    above <- !is.na(series) & series > max_val
    if (any(above)) {
      errs <- c(errs, list(ValidationError(
        domain = domain, severity = "error", file = file, sheet = sheet,
        location = sprintf("column '%s', rows %s", column, .first_rows(which(above))),
        message = sprintf("Values above maximum %s in column '%s'", max_val, column)
      )))
    }
  }
  errs
}
```

Gotcha: pandas reports 0-based `df.index`. Per Global Constraints we report source rows; `.first_rows` subtracts 1 from the 1-based `which()` position to match the Python integer values in existing messages. If a mirrored pytest assertion checks an exact index list, keep that exact expected value — the arithmetic above reproduces pandas' integers for a default RangeIndex.

- [ ] **Step 4: Run to verify it passes** → PASS.

- [ ] **Step 5: Commit**

```bash
git add src/r/data/validation.R tests/r/test-validation.R
git commit -m "feat(r): add validation primitives"
```

### Task 6: Config loader (`config.R`)

**Files:**
- Create: `src/r/data/config.R`
- Test: `tests/r/test-config.R`
- Reference: `src/mgen/config.py`, `tests/test_config.py`

**Interfaces:**
- Produces: `load_config(config_path)` → named list with `macroinvertebrate_db`, `aquatic_monitoring_db`, `data_xlsx`, `figures_dir`, `tables_dir`. Raises an error with class `"config_error"` (via `stop(structure(...))`) on missing file, missing required key, or missing input file.

- [ ] **Step 1: Write the failing test** (`tests/r/test-config.R`) — mirror `tests/test_config.py`. Representative cases (use `withr::local_tempdir()` and write fixture toml + dummy input files):

```r
source("src/r/data/config.R", local = TRUE)

write_toml <- function(dir, macro, aquatic, data_xlsx, extra = "") {
  path <- file.path(dir, "cycle.toml")
  writeLines(c(
    "[input]",
    sprintf('macroinvertebrate_db = "%s"', macro),
    sprintf('aquatic_monitoring_db = "%s"', aquatic),
    "[output]",
    sprintf('data_xlsx = "%s"', data_xlsx),
    extra
  ), path)
  path
}

test_that("load_config errors when the file is missing", {
  expect_error(load_config(tempfile()), class = "config_error")
})

test_that("load_config defaults figures_dir and tables_dir", {
  d <- withr::local_tempdir()
  macro <- file.path(d, "macro.xlsx"); file.create(macro)
  aquatic <- file.path(d, "aq.xlsx"); file.create(aquatic)
  out <- file.path(d, "out", "Data.xlsx")
  cfg <- load_config(write_toml(d, macro, aquatic, out))
  expect_equal(cfg$figures_dir, file.path(dirname(out), "Figures"))
  expect_equal(cfg$tables_dir, file.path(cfg$figures_dir, "Tables"))
})

test_that("load_config errors on missing input file", {
  d <- withr::local_tempdir()
  out <- file.path(d, "Data.xlsx")
  expect_error(
    load_config(write_toml(d, file.path(d, "nope.xlsx"),
                           file.path(d, "nope2.xlsx"), out)),
    class = "config_error")
})
```

(Install `withr` if not present: add to Task 1 deps if needed.)

- [ ] **Step 2: Run to verify it fails** → FAIL (file missing).

- [ ] **Step 3: Write `src/r/data/config.R`**

```r
# config.R — load and validate cycle.toml.

config_error <- function(msg) {
  stop(structure(class = c("config_error", "error", "condition"),
                 list(message = msg, call = NULL)))
}

load_config <- function(config_path) {
  if (!file.exists(config_path)) {
    config_error(sprintf("Config file not found: %s", config_path))
  }
  raw <- RcppTOML::parseTOML(config_path)
  input <- raw[["input"]]
  output <- raw[["output"]]
  if (is.null(input)) input <- list()
  if (is.null(output)) output <- list()

  for (key in c("macroinvertebrate_db", "aquatic_monitoring_db")) {
    if (is.null(input[[key]])) {
      config_error(sprintf("Missing required key: [input].%s", key))
    }
  }
  if (is.null(output[["data_xlsx"]])) {
    config_error("Missing required key: [output].data_xlsx")
  }

  macro_db <- input[["macroinvertebrate_db"]]
  aquatic_db <- input[["aquatic_monitoring_db"]]
  data_xlsx <- output[["data_xlsx"]]

  figures_dir <- output[["figures_dir"]]
  if (is.null(figures_dir)) figures_dir <- file.path(dirname(data_xlsx), "Figures")
  tables_dir <- output[["tables_dir"]]
  if (is.null(tables_dir)) tables_dir <- file.path(figures_dir, "Tables")

  for (path in c(macro_db, aquatic_db)) {
    if (!file.exists(path)) {
      config_error(sprintf("Input file not found: %s", path))
    }
  }

  list(
    macroinvertebrate_db = macro_db,
    aquatic_monitoring_db = aquatic_db,
    data_xlsx = data_xlsx,
    figures_dir = figures_dir,
    tables_dir = tables_dir
  )
}
```

- [ ] **Step 4: Run to verify it passes** → PASS.

- [ ] **Step 5: Commit**

```bash
git add src/r/data/config.R tests/r/test-config.R
git commit -m "feat(r): add cycle.toml config loader"
```

---

## Phase 2 — Golden harness & writer

### Task 7: Golden comparison helper + writer (`writer.R`)

**Files:**
- Create: `src/r/data/writer.R`, `tests/r/helper-golden.R`
- Test: `tests/r/test-writer.R`
- Reference: `src/mgen/writer.py`, `tests/test_writer.py` (esp. `TestGoldenFileComparison._assert_sheet_matches_golden`)

**Interfaces:**
- Produces:
  - `write_data_xlsx(data, output_path)` — validates all `SHEET_ORDER` sheets present, non-empty, columns match `SCHEMA_MAP`; writes via `openxlsx` in sheet order. Errors (base `stop`) on missing sheet / empty / column mismatch.
  - `compare_sheet_to_golden(actual_df, sheet_name, golden_path, tolerance = 1e-7)` (in `helper-golden.R`) — returns invisibly or signals a `testthat` expectation; replicates the Python filter-to-golden-dates + sort-by-Date+Site + tolerance-numeric / exact-string comparison.

- [ ] **Step 1: Write `tests/r/helper-golden.R`** (the harness, built first per spec)

```r
# helper-golden.R — compare a produced sheet against the golden file,
# mirroring tests/test_writer.py::_assert_sheet_matches_golden.

compare_sheet_to_golden <- function(actual_df, sheet_name, golden_path,
                                     tolerance = 1e-7) {
  expected <- readxl::read_excel(golden_path, sheet = sheet_name)
  names(expected) <- trimws(names(expected))

  # Compare dates as calendar dates.
  to_date <- function(x) as.Date(x)
  actual <- actual_df
  actual$Date <- to_date(actual$Date)
  expected$Date <- to_date(expected$Date)

  # Filter actual to dates present in golden.
  golden_dates <- unique(stats::na.omit(expected$Date))
  actual <- actual[actual$Date %in% golden_dates, , drop = FALSE]

  # Sort both by Date, Site.
  ord <- function(d) d[order(d$Date, d$Site), , drop = FALSE]
  actual <- ord(actual); expected <- ord(expected)
  rownames(actual) <- NULL; rownames(expected) <- NULL

  testthat::expect_equal(nrow(actual), nrow(expected),
    info = sprintf("%s: row count", sheet_name))
  testthat::expect_equal(names(actual), names(expected),
    info = sprintf("%s: columns", sheet_name))

  for (col in names(actual)) {
    a <- actual[[col]]; e <- expected[[col]]
    if (is.numeric(a) || is.numeric(e)) {
      testthat::expect_equal(as.numeric(a), as.numeric(e),
        tolerance = tolerance, info = sprintf("%s/%s", sheet_name, col))
    } else if (inherits(a, "Date") || col == "Date") {
      testthat::expect_equal(as.Date(a), as.Date(e),
        info = sprintf("%s/%s", sheet_name, col))
    } else {
      testthat::expect_equal(as.character(a), as.character(e),
        info = sprintf("%s/%s", sheet_name, col))
    }
  }
}
```

- [ ] **Step 2: Write the failing writer test** (`tests/r/test-writer.R`) — mirror the non-golden cases in `tests/test_writer.py` (sheet order, refuse-empty, column-mismatch, datetime dtype). The full-pipeline golden test is wired in Task 17.

```r
source("src/r/data/schemas.R", local = TRUE)
source("src/r/data/writer.R", local = TRUE)

make_minimal <- function() {
  mk <- function(cols) {
    df <- as.data.frame(setNames(
      lapply(cols, function(c) if (c == "Date") as.Date("2024-01-01") else NA), cols),
      stringsAsFactors = FALSE, check.names = FALSE)
    df[1, "Date"] <- as.Date("2024-01-01")
    df
  }
  setNames(lapply(SHEET_ORDER, function(s) mk(SCHEMA_MAP[[s]])), SHEET_ORDER)
}

test_that("write_data_xlsx writes sheets in SHEET_ORDER", {
  data <- make_minimal()
  out <- tempfile(fileext = ".xlsx")
  write_data_xlsx(data, out)
  expect_true(file.exists(out))
  expect_equal(readxl::excel_sheets(out), SHEET_ORDER)
})

test_that("write_data_xlsx refuses a missing sheet", {
  data <- make_minimal(); data[["Clarity"]] <- NULL
  expect_error(write_data_xlsx(data, tempfile(fileext = ".xlsx")),
               "Missing required sheets")
})

test_that("write_data_xlsx refuses a column mismatch", {
  data <- make_minimal()
  data[["Clarity"]] <- data[["Clarity"]][, -1, drop = FALSE]
  expect_error(write_data_xlsx(data, tempfile(fileext = ".xlsx")),
               "column mismatch")
})
```

- [ ] **Step 3: Run to verify it fails** → FAIL (`writer.R` missing).

- [ ] **Step 4: Write `src/r/data/writer.R`**

```r
# writer.R — write assembled data frames to the output xlsx.
# Knows Excel-format details, not domain logic.

write_data_xlsx <- function(data, output_path) {
  missing <- setdiff(SHEET_ORDER, names(data))
  if (length(missing) > 0) {
    stop(sprintf("Missing required sheets: %s",
                 paste(sort(missing), collapse = ", ")))
  }
  for (sheet_name in SHEET_ORDER) {
    df <- data[[sheet_name]]
    if (nrow(df) == 0) {
      stop(sprintf("Sheet '%s' is empty - refusing to write partial output",
                   sheet_name))
    }
    expected <- SCHEMA_MAP[[sheet_name]]
    if (!identical(names(df), expected)) {
      stop(sprintf("Sheet '%s' column mismatch: expected %s, got %s",
                   sheet_name, paste(expected, collapse = ","),
                   paste(names(df), collapse = ",")))
    }
  }
  dir.create(dirname(output_path), showWarnings = FALSE, recursive = TRUE)
  ordered <- data[SHEET_ORDER]
  openxlsx::write.xlsx(ordered, file = output_path, overwrite = TRUE)
  invisible(output_path)
}
```

Gotcha: ensure `Date` columns are R `Date`/`POSIXct` before this point so `openxlsx` writes Excel dates (not text/serial). Domains are responsible for that (Tasks 8–16).

- [ ] **Step 5: Run to verify it passes** → PASS.

- [ ] **Step 6: Commit**

```bash
git add src/r/data/writer.R tests/r/helper-golden.R tests/r/test-writer.R
git commit -m "feat(r): add xlsx writer and golden-file comparison helper"
```

---

## Phase 3 — Domain ports

Each domain task: write the failing test (mirror the named pytest file, or new tests where none exists), implement the R module by translating the named Python file, run to green, commit. All domains return `DomainResult`. Read the Python file in full before implementing.

### Task 8: Clarity domain (`domains/clarity.R`)

**Files:**
- Create: `src/r/data/domains/clarity.R`
- Test: `tests/r/test-domain-clarity.R`
- Reference: `src/mgen/domain/clarity.py`, `tests/test_domains/test_clarity.py`

**Interfaces:**
- Consumes: `errors.R`, `schemas.R`.
- Produces: `process_clarity_domain(path)` → `DomainResult` with `data$Clarity` (10 columns = `CLARITY_COLUMNS`). Source sheet `"Clarity Data"`; rename `"NTU-Continous Sensor"` → `"NTU-Continuous Sensor"` (source typo); required source cols `Site, Date, Clarity (mm)`; missing optional cols filled with NA of the right type; numeric coercion strips non-breaking spaces (`\xa0`).

- [ ] **Step 1: Write the failing test** — mirror **every** case in `tests/test_domains/test_clarity.py`, building source fixtures with `openxlsx::write.xlsx(list("Clarity Data" = df), tmp)`. Include: happy path produces 10 columns; typo rename; missing required column → error result; non-breaking-space stripping in a numeric column.

- [ ] **Step 2: Run to verify it fails** → FAIL.

- [ ] **Step 3: Implement `src/r/data/domains/clarity.R`**

```r
# clarity.R — water clarity from the Aquatic Monitoring Database "Clarity Data".

.clarity_source_sheet <- "Clarity Data"
.clarity_required <- c("Site", "Date", "Clarity (mm)")
.clarity_renames <- c("NTU-Continous Sensor" = "NTU-Continuous Sensor")

.clarity_error <- function(path, message) {
  DomainResult$new(data = NULL, errors = list(ValidationError(
    domain = "Clarity", severity = "error", file = as.character(path),
    sheet = .clarity_source_sheet, location = "sheet", message = message)))
}

process_clarity_domain <- function(path) {
  df <- tryCatch(
    readxl::read_excel(path, sheet = .clarity_source_sheet),
    error = function(e) e)
  if (inherits(df, "error")) {
    return(.clarity_error(path, sprintf("Sheet '%s' not found or unreadable in %s",
                                        .clarity_source_sheet, path)))
  }
  names(df) <- trimws(names(df))
  for (old in names(.clarity_renames)) {
    if (old %in% names(df)) names(df)[names(df) == old] <- .clarity_renames[[old]]
  }
  missing <- setdiff(.clarity_required, names(df))
  if (length(missing) > 0) {
    return(.clarity_error(path, sprintf("Missing required columns: %s",
      paste0("[", paste(sprintf("'%s'", sort(missing)), collapse = ", "), "]"))))
  }

  n <- nrow(df)
  coerce <- function(col) {
    if (col == "Date") return(as.Date(df[[col]]))
    if (!col %in% names(df)) {
      return(if (col == "Comments") rep(NA_character_, n) else rep(NA_real_, n))
    }
    if (col == "Comments" || col == "Site") return(as.character(df[[col]]))
    v <- df[[col]]
    if (!is.numeric(v)) v <- gsub(" ", "", trimws(as.character(v)))
    suppressWarnings(as.numeric(v))
  }
  out <- as.data.frame(setNames(lapply(CLARITY_COLUMNS, coerce), CLARITY_COLUMNS),
                       stringsAsFactors = FALSE, check.names = FALSE)
  DomainResult$new(data = list(Clarity = out))
}
```

Gotcha: ` ` is the non-breaking space the Python `\xa0` strips. `Site` is character; `Comments` is character; everything else between is numeric.

- [ ] **Step 4: Run to verify it passes** → PASS.

- [ ] **Step 5: Commit** — `git commit -m "feat(r): port clarity domain"`.

### Task 9: LDV domain (`domains/ldv.R`)

**Files:**
- Create: `src/r/data/domains/ldv.R`
- Test: `tests/r/test-domain-ldv.R` (**new** — no pytest equivalent exists)
- Reference: `src/mgen/domain/ldv.py`

**Interfaces:**
- Produces: `process_ldv_domain(path)` → `DomainResult` with `data$LDV` (cols `LDV_COLUMNS`). Source sheet `"LDV Summary"`, **skip first 13 rows**; source→output rename `{Site→Site, Date→Date, Season→Season, "CV (%)"→CV_pct}`; drop rows with NA Site, coerce Date/CV_pct, drop rows with unparseable Date.

- [ ] **Step 1: Write new tests** covering: happy path (build a "LDV Summary" sheet with 13 junk rows then a header + data via `openxlsx`); missing source column → error; trailing blank-Site rows dropped; unparseable Date row dropped.

- [ ] **Step 2: Run to verify it fails** → FAIL.

- [ ] **Step 3: Implement `src/r/data/domains/ldv.R`**

```r
# ldv.R — low-flow depth variability from "LDV Summary" (skip 13 header rows).

.ldv_sheet <- "LDV Summary"
.ldv_skip <- 13
.ldv_map <- c("Site" = "Site", "Date" = "Date", "Season" = "Season",
              "CV (%)" = "CV_pct")

.ldv_error <- function(path, message) {
  DomainResult$new(data = NULL, errors = list(ValidationError(
    domain = "LDV", severity = "error", file = as.character(path),
    sheet = .ldv_sheet, location = "sheet", message = message)))
}

process_ldv_domain <- function(path) {
  df <- tryCatch(
    readxl::read_excel(path, sheet = .ldv_sheet, skip = .ldv_skip),
    error = function(e) e)
  if (inherits(df, "error")) {
    return(.ldv_error(path, sprintf("Sheet '%s' not found or unreadable in %s",
                                    .ldv_sheet, path)))
  }
  names(df) <- trimws(names(df))
  missing <- setdiff(names(.ldv_map), names(df))
  if (length(missing) > 0) {
    return(.ldv_error(path, sprintf("Missing required columns: %s",
      paste0("[", paste(sprintf("'%s'", sort(missing)), collapse = ", "), "]"))))
  }
  out <- df[, names(.ldv_map), drop = FALSE]
  names(out) <- unname(.ldv_map[names(out)])
  out <- out[!is.na(out$Site) & trimws(as.character(out$Site)) != "", , drop = FALSE]
  out$Date <- suppressWarnings(as.Date(out$Date))
  out$CV_pct <- suppressWarnings(as.numeric(out$CV_pct))
  out <- out[!is.na(out$Date), , drop = FALSE]
  out$Site <- as.character(out$Site)
  out$Season <- as.character(out$Season)
  out <- out[, LDV_COLUMNS, drop = FALSE]
  rownames(out) <- NULL
  DomainResult$new(data = list(LDV = out))
}
```

- [ ] **Step 4: Run to verify it passes** → PASS.

- [ ] **Step 5: Commit** — `git commit -m "feat(r): port LDV domain"`.

### Task 10: RPD domain (`domains/rpd.R`)

**Files:**
- Create: `src/r/data/domains/rpd.R`
- Test: `tests/r/test-domain-rpd.R` (**new** — no pytest equivalent)
- Reference: `src/mgen/domain/rpd.py`

**Interfaces:**
- Produces: `process_rpd_domain(path)` → `DomainResult` with `data$RPD` (cols `RPD_COLUMNS`). Source sheet `"RPD Summary"`, **skip first 3 rows**; rename `{Site, Date, Count, "Mean (cm)"→Mean, "Std Dev"→StdDev, "CI Lower"→CI_Lower, "CI Upper"→CI_Upper}`; drop NA Site; `Count` integer; numeric coercion for Mean/StdDev/CI_*; drop unparseable Date.

- [ ] **Step 1: Write new tests** mirroring the LDV test shape (3 skip rows, rename, blank/NA-date drops, missing column error).

- [ ] **Step 2–5:** Implement `rpd.R` analogously to `ldv.R` with the RPD source map and 3-row skip; `Count` via `as.integer(round(as.numeric(...)))`. Run to green; commit `feat(r): port RPD domain`.

```r
# rpd.R — residual pool depth from "RPD Summary" (skip 3 header rows).
.rpd_sheet <- "RPD Summary"
.rpd_skip <- 3
.rpd_map <- c("Site" = "Site", "Date" = "Date", "Count" = "Count",
              "Mean (cm)" = "Mean", "Std Dev" = "StdDev",
              "CI Lower" = "CI_Lower", "CI Upper" = "CI_Upper")

.rpd_error <- function(path, message) {
  DomainResult$new(data = NULL, errors = list(ValidationError(
    domain = "RPD", severity = "error", file = as.character(path),
    sheet = .rpd_sheet, location = "sheet", message = message)))
}

process_rpd_domain <- function(path) {
  df <- tryCatch(readxl::read_excel(path, sheet = .rpd_sheet, skip = .rpd_skip),
                 error = function(e) e)
  if (inherits(df, "error")) {
    return(.rpd_error(path, sprintf("Sheet '%s' not found or unreadable in %s",
                                    .rpd_sheet, path)))
  }
  names(df) <- trimws(names(df))
  missing <- setdiff(names(.rpd_map), names(df))
  if (length(missing) > 0) {
    return(.rpd_error(path, sprintf("Missing required columns: %s",
      paste0("[", paste(sprintf("'%s'", sort(missing)), collapse = ", "), "]"))))
  }
  out <- df[, names(.rpd_map), drop = FALSE]
  names(out) <- unname(.rpd_map[names(out)])
  out <- out[!is.na(out$Site) & trimws(as.character(out$Site)) != "", , drop = FALSE]
  out$Date <- suppressWarnings(as.Date(out$Date))
  out$Count <- suppressWarnings(as.integer(round(as.numeric(out$Count))))
  for (col in c("Mean", "StdDev", "CI_Lower", "CI_Upper")) {
    out[[col]] <- suppressWarnings(as.numeric(out[[col]]))
  }
  out <- out[!is.na(out$Date), , drop = FALSE]
  out$Site <- as.character(out$Site)
  out <- out[, RPD_COLUMNS, drop = FALSE]
  rownames(out) <- NULL
  DomainResult$new(data = list(RPD = out))
}
```

### Task 11: Sediment ACL (`domains/sediment_ingest.R`)

**Files:**
- Create: `src/r/data/domains/sediment_ingest.R`
- Test: `tests/r/test-sediment-ingest.R`
- Reference: `src/mgen/domain/sediment_ingest.py`

**Interfaces:**
- Consumes: `domain_types.R` (`BASELINE_END`), `errors.R`.
- Produces:
  - constants `SOURCE_SAM1_COL = "SAM1 %fine cover"`, `SOURCE_SAM3_COL = "SAM3 (%Fine Cover)"`, `GRAIN_SIZE_SOURCE_COLUMNS` (the 10 names).
  - `read_sediment_sheet(path)` → data.frame with normalised `Site, Date, Period, Season` + SAM + grain-size cols. Raises error (base `stop`) on read failure / missing required cols.
  - `sediment_make_error(domain, path, message)` → `DomainResult`.
- Quirks: source Period column header is a single space `" "`; site column is `"Site "` (trailing space); Period rule: default `"Routine Construction"`, `period_raw == "Baseline"` → Baseline, `season_raw` starts with `"Additional"` → Incident; then `Date <= BASELINE_END` → Baseline. Season: default `"Spring"`, contains `"Summer"` → Summer. Date → as.Date.

- [ ] **Step 1: Write tests** mirroring `tests/test_domains/test_sediment.py`'s ingest-relevant cases plus quirks: the `" "` and `"Site "` headers; the Additional→Incident rule; the `BASELINE_END` override; Summer detection.

- [ ] **Step 2: Run to verify it fails** → FAIL.

- [ ] **Step 3: Implement `src/r/data/domains/sediment_ingest.R`**

```r
# sediment_ingest.R — ACL for the Aquatic Monitoring Database "Sediment" sheet.

SOURCE_SAM1_COL <- "SAM1 %fine cover"
SOURCE_SAM3_COL <- "SAM3 (%Fine Cover)"
GRAIN_SIZE_SOURCE_COLUMNS <- c(
  "Clay/silt (<0.06 mm)", "Sand (>0.06-2 mm)", "Small gravel (>2-8 mm)",
  "Small-med gravel (>8-16 mm)", "Med-large gravel (>16-32 mm)",
  "Large gravel (>32-64 mm)", "Small cobble (>64-128 mm)",
  "Large cobble (>128-256 mm)", "Boulders (>256 mm)", "Bedrock"
)
.sed_period_col <- " "
.sed_site_col <- "Site "
.sed_season_col <- "Season"
.sed_date_col <- "Date"
.sed_required <- c(.sed_period_col, .sed_site_col, .sed_season_col, .sed_date_col)

sediment_make_error <- function(domain, path, message) {
  DomainResult$new(data = NULL, errors = list(ValidationError(
    domain = domain, severity = "error", file = as.character(path),
    sheet = "Sediment", location = "sheet", message = message)))
}

read_sediment_sheet <- function(path) {
  df <- tryCatch(readxl::read_excel(path, sheet = "Sediment", .name_repair = "minimal"),
                 error = function(e) stop(sprintf(
                   "Sheet 'Sediment' not found or unreadable in %s", path)))
  missing <- setdiff(.sed_required, names(df))
  if (length(missing) > 0) {
    stop(sprintf("Missing required columns: %s",
      paste0("[", paste(sprintf("'%s'", sort(missing)), collapse = ", "), "]")))
  }
  period_raw <- trimws(as.character(df[[.sed_period_col]]))
  season_raw <- trimws(as.character(df[[.sed_season_col]]))

  Period <- rep("Routine Construction", nrow(df))
  Period[period_raw == "Baseline"] <- "Baseline"
  Period[startsWith(season_raw, "Additional")] <- "Incident"

  Season <- rep("Spring", nrow(df))
  Season[grepl("Summer", season_raw, fixed = TRUE)] <- "Summer"

  df$Site <- trimws(as.character(df[[.sed_site_col]]))
  df$Date <- as.Date(df[[.sed_date_col]])
  Period[!is.na(df$Date) & df$Date <= BASELINE_END] <- "Baseline"
  df$Period <- Period
  df$Season <- Season
  df
}
```

Gotcha: `.name_repair = "minimal"` keeps the literal `" "` and `"Site "` headers (default readxl would mangle a blank name).

- [ ] **Step 4: Run to verify it passes** → PASS.

- [ ] **Step 5: Commit** — `git commit -m "feat(r): port sediment ACL"`.

### Task 12: Sediment domain (`domains/sediment.R`)

**Files:**
- Create: `src/r/data/domains/sediment.R`
- Test: `tests/r/test-domain-sediment.R`
- Reference: `src/mgen/domain/sediment.py`, `tests/test_domains/test_sediment.py`

**Interfaces:**
- Consumes: `sediment_ingest.R`, `schemas.R`.
- Produces: `process_sediment_domain(path)` → `DomainResult` with `data$Sediment` (`SEDIMENT_COLUMNS`). Validates SAM columns exist; builds Site/Date/Period + SAM1/SAM3 (numeric coerce) + Season; enforces column order.

- [ ] **Step 1–5:** Mirror `tests/test_domains/test_sediment.py` (every case); implement:

```r
# sediment.R
process_sediment_domain <- function(path) {
  df <- tryCatch(read_sediment_sheet(path),
                 error = function(e) return(NULL))
  if (is.null(df)) {
    return(sediment_make_error("Sediment", path, "Failed to read Sediment sheet"))
  }
  for (col in c(SOURCE_SAM1_COL, SOURCE_SAM3_COL)) {
    if (!col %in% names(df)) {
      return(sediment_make_error("Sediment", path,
        sprintf("Missing required column: '%s'", col)))
    }
  }
  out <- data.frame(
    Site = df$Site, Date = df$Date, Period = df$Period,
    SAM1 = suppressWarnings(as.numeric(df[[SOURCE_SAM1_COL]])),
    SAM3 = suppressWarnings(as.numeric(df[[SOURCE_SAM3_COL]])),
    Season = df$Season, stringsAsFactors = FALSE, check.names = FALSE)
  out <- out[, SEDIMENT_COLUMNS, drop = FALSE]
  rownames(out) <- NULL
  DomainResult$new(data = list(Sediment = out))
}
```

Note: to reproduce the exact error message on read failure, capture the condition message rather than the generic text — mirror whatever `test_sediment.py` asserts. Commit `feat(r): port sediment domain`.

### Task 13: SedimentSize domain (`domains/sediment_size.R`)

**Files:**
- Create: `src/r/data/domains/sediment_size.R`
- Test: `tests/r/test-domain-sediment-size.R`
- Reference: `src/mgen/domain/sediment_size.py`, `tests/test_domains/test_sediment_size.py`

**Interfaces:**
- Produces: `process_sediment_size_domain(path)` → `DomainResult` with `data$SedimentSize` (`SEDIMENT_SIZE_COLUMNS`). Validates the 10 grain-size cols exist; numeric-coerces each; enforces column order.

- [ ] **Step 1–5:** Mirror `tests/test_domains/test_sediment_size.py`; implement:

```r
# sediment_size.R
process_sediment_size_domain <- function(path) {
  df <- tryCatch(read_sediment_sheet(path), error = function(e) return(NULL))
  if (is.null(df)) {
    return(sediment_make_error("SedimentSize", path, "Failed to read Sediment sheet"))
  }
  missing_grain <- setdiff(GRAIN_SIZE_SOURCE_COLUMNS, names(df))
  if (length(missing_grain) > 0) {
    return(sediment_make_error("SedimentSize", path,
      sprintf("Missing grain-size columns: %s",
        paste0("[", paste(sprintf("'%s'", missing_grain), collapse = ", "), "]"))))
  }
  out <- data.frame(Site = df$Site, Date = df$Date, Period = df$Period,
                    Season = df$Season, stringsAsFactors = FALSE, check.names = FALSE)
  for (col in GRAIN_SIZE_SOURCE_COLUMNS) {
    out[[col]] <- suppressWarnings(as.numeric(df[[col]]))
  }
  out <- out[, SEDIMENT_SIZE_COLUMNS, drop = FALSE]
  rownames(out) <- NULL
  DomainResult$new(data = list(SedimentSize = out))
}
```

Commit `feat(r): port sediment-size domain`.

### Task 14: Macro ACL (`domains/macro_ingest.R`)

**Files:**
- Create: `src/r/data/domains/macro_ingest.R`
- Test: `tests/r/test-macro-ingest.R`
- Reference: `src/mgen/domain/macro_ingest.py`, `tests/test_domains/test_macro_ingest.py`

**Interfaces:**
- Produces:
  - `ingest_raw_data(macro_db_path)` → list (`RawDataBundle`) with `sample_metadata` (data.frame: `sample_id` [1-based col index], `Season`, `Date`, `Site`, `Replicate`), `taxa_counts` (data.frame: `TaxonGroup`, `Taxon`, then one column per sample keyed by `sample_id` as character), `metric_rows`, `mci_scores` (`Taxon`, `MCI`, `MCI_sb`).
  - signals an error of class `"ingest_error"` on failure.
- Layout: sheet `"RawData"`, read with `col_names = FALSE` (no header). Rows 1–5 = QA, Season, Date, Site, Replicate. Data cols start at column 5 (1-based; Python `_DATA_COL_START = 4` is 0-based). Split taxa vs metrics at the first row (after the 5 header rows) whose column-B value trimmed equals `"Number of Taxa"`.

- [ ] **Step 1: Write tests** mirroring `tests/test_domains/test_macro_ingest.py` (every case): header parsing, marker split, taxa/metric separation, missing-marker error, replicate coercion. Build a synthetic RawData sheet with `openxlsx` (no header, object cells).

- [ ] **Step 2: Run to verify it fails** → FAIL.

- [ ] **Step 3: Implement `src/r/data/domains/macro_ingest.R`**

```r
# macro_ingest.R — ACL for the Macroinvertebrate Database "RawData" sheet.
# Column indices are 1-based here; Python uses 0-based (_DATA_COL_START=4 -> 5).

.macro_metrics_marker <- "Number of Taxa"
.macro_header_rows <- 5L
.macro_data_col_start <- 5L  # 1-based: A=1,B=2,C=3,D=4,E=5

ingest_error <- function(msg) {
  stop(structure(class = c("ingest_error", "error", "condition"),
                 list(message = msg, call = NULL)))
}

ingest_raw_data <- function(macro_db_path) {
  raw <- tryCatch(
    readxl::read_excel(macro_db_path, sheet = "RawData",
                       col_names = FALSE, col_types = "text"),
    error = function(e) ingest_error(
      sprintf("Cannot read 'RawData' sheet from %s: %s", macro_db_path,
              conditionMessage(e))))
  raw <- as.data.frame(raw, stringsAsFactors = FALSE, check.names = FALSE)
  ncol_raw <- ncol(raw)
  sample_cols <- seq.int(.macro_data_col_start, ncol_raw)  # 1-based indices

  # --- sample metadata from rows 2..5 (Season, Date, Site, Replicate) ---
  hdr <- function(r) unlist(raw[r, sample_cols], use.names = FALSE)
  meta <- data.frame(
    sample_id = sample_cols,
    Season = as.character(hdr(2)),
    Date = as.Date(suppressWarnings(as.numeric(hdr(3))), origin = "1899-12-30"),
    Site = trimws(as.character(hdr(4))),
    Replicate = suppressWarnings(as.integer(round(as.numeric(hdr(5))))),
    stringsAsFactors = FALSE
  )
  # Date cells may be text dates rather than Excel serials; fall back to parse.
  bad <- is.na(meta$Date)
  if (any(bad)) meta$Date[bad] <- suppressWarnings(as.Date(hdr(3)[bad]))

  # --- split data rows at the metrics marker ---
  data_block <- raw[(.macro_header_rows + 1L):nrow(raw), , drop = FALSE]
  rownames(data_block) <- NULL
  col_b <- trimws(as.character(data_block[[2]]))
  marker <- which(col_b == .macro_metrics_marker)
  if (length(marker) == 0) {
    ingest_error(paste0("'", .macro_metrics_marker,
      "' marker not found in column B. The RawData sheet structure may have changed."))
  }
  split_at <- marker[1]
  taxa_block <- data_block[seq_len(split_at - 1L), , drop = FALSE]
  metric_block <- data_block[split_at:nrow(data_block), , drop = FALSE]

  # --- taxa counts: TaxonGroup, Taxon, then one Int column per sample ---
  taxa_counts <- data.frame(
    TaxonGroup = as.character(taxa_block[[1]]),
    Taxon = as.character(taxa_block[[2]]),
    stringsAsFactors = FALSE, check.names = FALSE)
  for (ci in sample_cols) {
    taxa_counts[[as.character(ci)]] <-
      suppressWarnings(as.integer(round(as.numeric(taxa_block[[ci]]))))
  }

  mci_scores <- data.frame(
    Taxon = as.character(taxa_block[[2]]),
    MCI = suppressWarnings(as.numeric(taxa_block[[3]])),
    MCI_sb = suppressWarnings(as.numeric(taxa_block[[4]])),
    stringsAsFactors = FALSE, check.names = FALSE)

  metric_rows <- data.frame(
    Metric = trimws(as.character(metric_block[[2]])),
    stringsAsFactors = FALSE, check.names = FALSE)
  for (ci in sample_cols) {
    metric_rows[[as.character(ci)]] <- suppressWarnings(as.numeric(metric_block[[ci]]))
  }

  list(sample_metadata = meta, taxa_counts = taxa_counts,
       metric_rows = metric_rows, mci_scores = mci_scores)
}
```

Gotcha: `read_excel(col_types = "text")` returns all cells as character (mirrors pandas `dtype=object`), so date/numeric coercion is explicit and controlled. Excel serial-date origin is `1899-12-30`. Sample columns are keyed by their 1-based index as a **character** name so `taxa_counts[[as.character(sample_id)]]` works in the metric step.

- [ ] **Step 4: Run to verify it passes** → PASS.

- [ ] **Step 5: Commit** — `git commit -m "feat(r): port macroinvertebrate RawData ACL"`.

### Task 15: Macro domain (`domains/macro.R`)

**Files:**
- Create: `src/r/data/domains/macro.R`
- Test: `tests/r/test-domain-macro.R`
- Reference: `src/mgen/domain/macro.py`, `tests/test_domains/test_macro.py`

**Interfaces:**
- Consumes: `macro_ingest.R`, `domain_types.R`, `schemas.R`, `errors.R`.
- Produces:
  - `derive_metrics(taxa_counts, mci_scores, sample_col)` → named list with at least `% EPT Richness`, `% EPT Abundance`, `QMCI`, `QMCI-sb` (and the rest from the Python dict). `sample_col` is the **character** key of the sample column in `taxa_counts`.
  - `normalise_period(raw_season, date)`, `normalise_season(raw_season, date)`.
  - `process_macro_domain(macro_db_path)` → `DomainResult` with `data$Macro1` and `data$Macro`.
- Formulas (translate exactly from `macro.py`): EPT groups = {Mayflies, Stoneflies, Caddisflies}; Trichoptera excludes Hydroptilidae genera {Oxyethira, Paroxyethira}; QMCI uses `fillna(0)` on MCI in the numerator; QMCI routing: `SITES_WITHOUT_REPLICATES` use `QMCI-sb`. `Macro` sheet = mean of EPTrich/EPTabun/QMCI grouped by Site/Date/Period/Season over replicated sites only.

- [ ] **Step 1: Write tests** mirroring **every** case in `tests/test_domains/test_macro.py` — especially `derive_metrics` numeric cases (use `tolerance = 1e-7`), the Hydroptilidae exclusion, QMCI vs QMCI-sb routing, period/season normalisation incl. the `BASELINE_END` override and `"Additional"` → `"incident response"`.

- [ ] **Step 2: Run to verify it fails** → FAIL.

- [ ] **Step 3: Implement `src/r/data/domains/macro.R`**

```r
# macro.R — macroinvertebrate metric derivation + Macro1/Macro assembly.

.EPT_GROUPS <- c("Mayflies", "Stoneflies", "Caddisflies")
.HYDROPTILIDAE_GENERA <- c("Oxyethira", "Paroxyethira")
.ASPM_MCI_MAX <- 200
.ASPM_EPT_RICHNESS_MAX <- 29
.ASPM_EPT_ABUNDANCE_MAX <- 100
.PERIOD_MAP <- c("Baseline" = "Baseline", "Construction" = "Routine Construction",
                 "Additional" = "Incident")
.SPRING_MONTHS <- c(10, 11, 12)

derive_metrics <- function(taxa_counts, mci_scores, sample_col) {
  key <- as.character(sample_col)
  merged <- merge(
    taxa_counts[, c("TaxonGroup", "Taxon", key)],
    mci_scores, by = "Taxon", all.x = TRUE, sort = FALSE)
  counts <- merged[[key]]; counts[is.na(counts)] <- 0; counts <- as.numeric(counts)
  present <- counts > 0

  num_taxa <- sum(present)
  num_individuals <- sum(counts)

  mci_vals <- merged$MCI[present]; mci_vals <- mci_vals[!is.na(mci_vals)]
  mci <- if (length(mci_vals) > 0) sum(mci_vals) / length(mci_vals) * 20 else NA_real_
  mci_sb_vals <- merged$MCI_sb[present]; mci_sb_vals <- mci_sb_vals[!is.na(mci_sb_vals)]
  mci_sb <- if (length(mci_sb_vals) > 0) sum(mci_sb_vals)/length(mci_sb_vals)*20 else NA_real_

  mci0 <- merged$MCI; mci0[is.na(mci0)] <- 0
  mci_sb0 <- merged$MCI_sb; mci_sb0[is.na(mci_sb0)] <- 0
  qmci <- if (num_individuals > 0) sum(counts * mci0) / num_individuals else NA_real_
  qmci_sb <- if (num_individuals > 0) sum(counts * mci_sb0) / num_individuals else NA_real_

  is_ept <- merged$TaxonGroup %in% .EPT_GROUPS
  is_e <- merged$TaxonGroup == "Mayflies"
  is_p <- merged$TaxonGroup == "Stoneflies"
  is_t <- is_ept & !is_e & !is_p
  is_hydro <- trimws(merged$Taxon) %in% .HYDROPTILIDAE_GENERA
  is_t_excl <- is_t & !is_hydro

  e_rich <- sum(counts[is_e] > 0)
  p_rich <- sum(counts[is_p] > 0)
  t_rich <- sum(counts[is_t_excl] > 0)
  ept_rich <- e_rich + p_rich + t_rich
  ept_abun <- sum(counts[is_e | is_p | is_t_excl])

  pct_ept_abun <- if (num_individuals > 0) ept_abun / num_individuals else NA_real_
  pct_ept_rich <- if (num_taxa > 0) ept_rich / num_taxa else NA_real_
  aspm_mci <- if (!is.na(mci)) mean(c(mci/.ASPM_MCI_MAX,
    ept_rich/.ASPM_EPT_RICHNESS_MAX, ept_abun/.ASPM_EPT_ABUNDANCE_MAX)) else NA_real_

  list(`Number of Taxa` = as.integer(num_taxa),
       `Number of Individuals` = as.integer(num_individuals),
       MCI = mci, `MCI-sb` = mci_sb, QMCI = qmci, `QMCI-sb` = qmci_sb,
       `EPT Abundance` = as.integer(ept_abun),
       `E Richness` = as.integer(e_rich), `P Richness` = as.integer(p_rich),
       `T Richness` = as.integer(t_rich), `EPT Richness` = as.integer(ept_rich),
       `% EPT Abundance` = pct_ept_abun, `% EPT Richness` = pct_ept_rich,
       `ASPM-MCI` = aspm_mci)
}

normalise_period <- function(raw_season, date) {
  d <- as.Date(date)
  if (!is.na(d) && d <= BASELINE_END) return("Baseline")
  p <- .PERIOD_MAP[[raw_season]]
  if (is.null(p)) return("Routine Construction")
  p
}

normalise_season <- function(raw_season, date) {
  if (identical(raw_season, "Additional")) return("incident response")
  m <- as.integer(format(as.Date(date), "%m"))
  if (m %in% .SPRING_MONTHS) "Spring" else "Summer"
}

.macro_error <- function(file_name, sheet, location, message, severity = "error") {
  ValidationError(domain = "macroinvertebrate", severity = severity,
                  file = file_name, sheet = sheet, location = location,
                  message = message)
}

process_macro_domain <- function(macro_db_path) {
  file_name <- basename(macro_db_path)
  errors <- list()
  bundle <- tryCatch(ingest_raw_data(macro_db_path),
    error = function(e) e)
  if (inherits(bundle, "error")) {
    return(DomainResult$new(data = NULL, errors = list(.macro_error(
      file_name, "RawData", "file",
      sprintf("Failed to read RawData: %s", conditionMessage(bundle))))))
  }
  meta <- bundle$sample_metadata
  rows <- list()
  for (i in seq_len(nrow(meta))) {
    m <- meta[i, ]
    sid <- as.character(m$sample_id)
    metrics <- tryCatch(derive_metrics(bundle$taxa_counts, bundle$mci_scores, sid),
      error = function(e) e)
    if (inherits(metrics, "error")) {
      errors <- c(errors, list(.macro_error(file_name, "RawData",
        sprintf("sample_col=%s", sid),
        sprintf("Failed to derive metrics: %s", conditionMessage(metrics)),
        severity = "warning")))
      next
    }
    site <- trimws(as.character(m$Site))
    qmci_value <- if (site %in% SITES_WITHOUT_REPLICATES) metrics[["QMCI-sb"]] else metrics[["QMCI"]]
    raw_season <- trimws(as.character(m$Season))
    rows[[length(rows) + 1L]] <- data.frame(
      Site = site, Date = as.Date(m$Date),
      Period = normalise_period(raw_season, m$Date),
      EPTrich = metrics[["% EPT Richness"]],
      EPTabun = metrics[["% EPT Abundance"]],
      QMCI = qmci_value,
      Season = normalise_season(raw_season, m$Date),
      stringsAsFactors = FALSE, check.names = FALSE)
  }
  if (length(rows) == 0) {
    return(DomainResult$new(data = NULL, errors = c(errors, list(.macro_error(
      file_name, "RawData", "data", "No sample data could be processed")))))
  }
  macro1 <- do.call(rbind, rows)[, MACRO1_COLUMNS, drop = FALSE]
  rownames(macro1) <- NULL

  replicated <- macro1[!(macro1$Site %in% SITES_WITHOUT_REPLICATES), , drop = FALSE]
  agg <- stats::aggregate(
    cbind(EPTrich, EPTabun, QMCI) ~ Site + Date + Period + Season,
    data = replicated, FUN = mean, na.action = stats::na.pass)
  macro <- agg[, MACRO1_COLUMNS, drop = FALSE]
  rownames(macro) <- NULL

  DomainResult$new(data = list(Macro1 = macro1, Macro = macro), errors = errors)
}
```

Gotcha: the `Macro` aggregation must group by Site/Date/Period/Season and mean the three metrics — confirm against the golden `Macro` sheet in Task 17; if row order differs, the golden helper sorts by Date+Site so order is not load-bearing, but grouping keys must match exactly.

- [ ] **Step 4: Run to verify it passes** → PASS.

- [ ] **Step 5: Commit** — `git commit -m "feat(r): port macroinvertebrate domain"`.

### Task 16: MacroSpecies domain (`domains/macro_species.R`)

**Files:**
- Create: `src/r/data/domains/macro_species.R`
- Test: `tests/r/test-domain-macro-species.R`
- Reference: `src/mgen/domain/macro_species.py`, `tests/test_domains/test_macro_species.py`

**Interfaces:**
- Consumes: `macro_ingest.R`, `domain_types.R`, `schemas.R`, `errors.R`.
- Produces: `process_macro_species_domain(macro_db_path)` → `DomainResult` with `data$MacroSpecies` (`MACRO_SPECIES_COLUMNS`, `Tally` integer, `is_additional` logical). Long format, one row per (sample × taxon) where tally > 0. `Phase` = "Baseline" if `Date <= BASELINE_END` else "Construction"; `is_additional` = source season (lowercased) == "incident".

- [ ] **Step 1: Write tests** mirroring **every** case in `tests/test_domains/test_macro_species.py`: only non-zero tallies emitted; Phase derivation; is_additional flag; empty → error.

- [ ] **Step 2: Run to verify it fails** → FAIL.

- [ ] **Step 3: Implement `src/r/data/domains/macro_species.R`**

```r
# macro_species.R — pivot taxa counts to sparse long format.

process_macro_species_domain <- function(macro_db_path) {
  file_name <- basename(macro_db_path)
  err <- function(loc, msg, sev = "error") ValidationError(
    domain = "MacroSpecies", severity = sev, file = file_name,
    sheet = "RawData", location = loc, message = msg)

  bundle <- tryCatch(ingest_raw_data(macro_db_path), error = function(e) e)
  if (inherits(bundle, "error")) {
    return(DomainResult$new(data = NULL, errors = list(
      err("file", sprintf("Failed to read RawData: %s", conditionMessage(bundle))))))
  }
  meta <- bundle$sample_metadata
  taxa_groups <- bundle$taxa_counts$TaxonGroup
  taxa_names <- bundle$taxa_counts$Taxon

  out <- list()
  for (i in seq_len(nrow(meta))) {
    m <- meta[i, ]
    sid <- as.character(m$sample_id)
    counts <- bundle$taxa_counts[[sid]]
    date <- as.Date(m$Date)
    site <- trimws(as.character(m$Site))
    is_additional <- tolower(as.character(m$Season)) == "incident"
    phase <- if (!is.na(date) && date <= BASELINE_END) "Baseline" else "Construction"
    keep <- which(!is.na(counts) & counts > 0)
    for (j in keep) {
      out[[length(out) + 1L]] <- data.frame(
        Phase = phase, Date = date, Site = site,
        Taxa = as.character(taxa_groups[j]), Species = as.character(taxa_names[j]),
        Tally = as.integer(counts[j]), is_additional = is_additional,
        stringsAsFactors = FALSE, check.names = FALSE)
    }
  }
  if (length(out) == 0) {
    return(DomainResult$new(data = NULL, errors = list(
      err("all samples", "No non-zero taxa counts found"))))
  }
  df <- do.call(rbind, out)[, MACRO_SPECIES_COLUMNS, drop = FALSE]
  df$Tally <- as.integer(df$Tally)
  rownames(df) <- NULL
  DomainResult$new(data = list(MacroSpecies = df))
}
```

- [ ] **Step 4: Run to verify it passes** → PASS.

- [ ] **Step 5: Commit** — `git commit -m "feat(r): port macro-species domain"`.

---

## Phase 4 — Orchestration, entry points, golden gate

### Task 17: Pipeline orchestrator + golden integration test (`pipeline.R`)

**Files:**
- Create: `src/r/data/pipeline.R`
- Test: extend `tests/r/test-writer.R` with the golden full-pipeline test; create `tests/r/test-pipeline-integration.R`
- Reference: `src/mgen/pipeline.py`, `tests/test_pipeline_integration.py`, `tests/test_writer.py::TestGoldenFileComparison`

**Interfaces:**
- Consumes: all domain modules, `writer.R`, `config.R`, `errors.R`.
- Produces: `run_pipeline(config)` → list `list(success = logical, errors = list(ValidationError))`. Runs all 7 domain processors in order (macro, macro_species, sediment, sediment_size, clarity, rpd, ldv); if any has an error-severity error, returns `success = FALSE` and writes nothing; else merges all `data` and calls `write_data_xlsx`.

- [ ] **Step 1: Write `src/r/data/pipeline.R`**

```r
# pipeline.R — run all domains; enforce no-partial-output; write combined xlsx.

run_pipeline <- function(config) {
  results <- list(
    process_macro_domain(config$macroinvertebrate_db),
    process_macro_species_domain(config$macroinvertebrate_db),
    process_sediment_domain(config$aquatic_monitoring_db),
    process_sediment_size_domain(config$aquatic_monitoring_db),
    process_clarity_domain(config$aquatic_monitoring_db),
    process_rpd_domain(config$aquatic_monitoring_db),
    process_ldv_domain(config$aquatic_monitoring_db)
  )
  all_errors <- do.call(c, lapply(results, function(r) r$errors))
  if (is.null(all_errors)) all_errors <- list()

  if (!all(vapply(results, function(r) r$ok(), logical(1)))) {
    return(list(success = FALSE, errors = all_errors))
  }
  combined <- list()
  for (r in results) if (!is.null(r$data)) combined <- c(combined, r$data)
  write_data_xlsx(combined, config$data_xlsx)
  list(success = TRUE, errors = all_errors)
}
```

- [ ] **Step 2: Write the golden integration test** (`tests/r/test-pipeline-integration.R`)

This needs the real source databases (paths from `cycle.toml`) OR a committed fixture. Mirror what `tests/test_pipeline_integration.py` uses for inputs. If that test reads fixtures under `tests/assets/`, point the R test at the copies; if it reads the live `cycle.toml` DBs, guard with `skip_if_not(file.exists(...))`.

```r
# Sources: load every module, then run all domains and compare to golden.
modules <- c("schemas.R","domain_types.R","errors.R","validation.R","config.R",
  "writer.R","domains/clarity.R","domains/ldv.R","domains/rpd.R",
  "domains/sediment_ingest.R","domains/sediment.R","domains/sediment_size.R",
  "domains/macro_ingest.R","domains/macro.R","domains/macro_species.R","pipeline.R")
for (m in modules) source(file.path("src/r/data", m), local = TRUE)
source("tests/r/helper-golden.R", local = TRUE)

GOLDEN <- "tests/r/assets/expected_Data.xlsx"

test_that("full pipeline matches the golden file on every sheet", {
  # Resolve the real source DBs from cycle.toml; skip if unavailable.
  cfg <- tryCatch(load_config("cycle.toml"), error = function(e) NULL)
  skip_if(is.null(cfg), "cycle.toml inputs not available in this environment")

  results <- list(
    process_macro_domain(cfg$macroinvertebrate_db),
    process_macro_species_domain(cfg$macroinvertebrate_db),
    process_sediment_domain(cfg$aquatic_monitoring_db),
    process_sediment_size_domain(cfg$aquatic_monitoring_db),
    process_clarity_domain(cfg$aquatic_monitoring_db),
    process_rpd_domain(cfg$aquatic_monitoring_db),
    process_ldv_domain(cfg$aquatic_monitoring_db))
  expect_true(all(vapply(results, function(r) r$ok(), logical(1))))

  combined <- list()
  for (r in results) if (!is.null(r$data)) combined <- c(combined, r$data)
  for (sheet in c("Macro","Macro1","MacroSpecies","Sediment","SedimentSize")) {
    compare_sheet_to_golden(combined[[sheet]], sheet, GOLDEN)
  }
})
```

Note: the golden file only covers the 5 sheets with row-count notes (`docs/golden-file-notes.md`); compare those. Clarity/RPD/LDV are validated by their unit tests.

- [ ] **Step 3: Run the integration test against the real DBs**

Run: `Rscript --vanilla -e "source('renv/activate.R'); library(readxl); library(openxlsx); library(dplyr); library(tidyr); library(lubridate); testthat::test_file('tests/r/test-pipeline-integration.R')"`
Expected: PASS (or skip if inputs unavailable — then run on a machine with `T:` access before Task 19).

- [ ] **Step 4: If any sheet mismatches**, debug the responsible domain against `uv run mgen data` output (Python still present). Fix the R domain, re-run. Do not proceed until all 5 golden sheets match.

- [ ] **Step 5: Commit**

```bash
git add src/r/data/pipeline.R tests/r/test-pipeline-integration.R
git commit -m "feat(r): add pipeline orchestrator and golden integration gate"
```

### Task 18: Entry scripts + run_all.R config refactor

**Files:**
- Create: `src/r/run_data.R`, `src/r/run_pipeline.R`
- Modify: `src/r/run_all.R` (replace TOML regex with `config.R`)
- Test: `tests/r/test-entrypoints.R`
- Reference: `src/mgen/cli.py`, `tests/test_cli.py`

**Interfaces:**
- Produces:
  - `Rscript src/r/run_data.R [cycle.toml] [--validate]` — loads config, runs `run_pipeline`; on `--validate`, runs domains and reports errors without writing; prints an error summary and `quit(status = 1)` on failure, status 0 on success.
  - `Rscript src/r/run_pipeline.R [cycle.toml]` — runs `run_data.R` logic then sources/calls `run_all.R` for figures.

- [ ] **Step 1: Write `src/r/run_data.R`**

```r
#!/usr/bin/env Rscript
# run_data.R — raw spreadsheets -> MtMessengerEcologyData.xlsx (R data pipeline).

local({
  args <- commandArgs(trailingOnly = TRUE)
  validate_only <- "--validate" %in% args
  positional <- args[!startsWith(args, "--")]
  config_path <- if (length(positional) >= 1) positional[[1]] else "cycle.toml"

  data_dir <- file.path("src", "r", "data")
  src1 <- function(f) source(file.path(data_dir, f))
  source(file.path("renv", "activate.R"))
  suppressPackageStartupMessages({
    library(readxl); library(openxlsx); library(dplyr)
    library(tidyr); library(lubridate)
  })
  for (m in c("schemas.R","domain_types.R","errors.R","validation.R","config.R",
              "writer.R","domains/clarity.R","domains/ldv.R","domains/rpd.R",
              "domains/sediment_ingest.R","domains/sediment.R",
              "domains/sediment_size.R","domains/macro_ingest.R","domains/macro.R",
              "domains/macro_species.R","pipeline.R")) src1(m)

  cfg <- tryCatch(load_config(config_path), error = function(e) {
    message("Config error: ", conditionMessage(e)); quit(status = 1) })

  if (validate_only) {
    results <- list(
      process_macro_domain(cfg$macroinvertebrate_db),
      process_macro_species_domain(cfg$macroinvertebrate_db),
      process_sediment_domain(cfg$aquatic_monitoring_db),
      process_sediment_size_domain(cfg$aquatic_monitoring_db),
      process_clarity_domain(cfg$aquatic_monitoring_db),
      process_rpd_domain(cfg$aquatic_monitoring_db),
      process_ldv_domain(cfg$aquatic_monitoring_db))
    errs <- do.call(c, lapply(results, function(r) r$errors))
    if (length(errs) > 0) for (e in errs) message("  ", format(e))
    ok <- all(vapply(results, function(r) r$ok(), logical(1)))
    if (!ok) { message("\nValidation failed."); quit(status = 1) }
    message("Validation passed."); quit(status = 0)
  }

  result <- run_pipeline(cfg)
  if (length(result$errors) > 0) for (e in result$errors) message("  ", format(e))
  if (!result$success) {
    n <- sum(vapply(result$errors, function(e) e$severity == "error", logical(1)))
    message(sprintf("\nPipeline failed: %d error(s) across domains", n))
    quit(status = 1)
  }
  message(sprintf("Wrote %s", cfg$data_xlsx))
})
```

- [ ] **Step 2: Write `src/r/run_pipeline.R`**

```r
#!/usr/bin/env Rscript
# run_pipeline.R — data then figures (the all-R equivalent of `mgen all`).
local({
  args <- commandArgs(trailingOnly = TRUE)
  config_path <- if (length(args) >= 1) args[[1]] else "cycle.toml"
  rc <- system2("Rscript", c("--vanilla", "src/r/run_data.R", shQuote(config_path)))
  if (rc != 0) quit(status = rc)
  rc2 <- system2("Rscript", c("--vanilla", "src/r/run_all.R"))
  quit(status = rc2)
})
```

- [ ] **Step 3: Refactor `run_all.R` to use `config.R`** — replace `resolve_default_xlsx`/`resolve_aquatic_db` regex parsing (lines ~67–95) with `source("src/r/data/config.R")` + `load_config("cycle.toml")`, reading `cfg$data_xlsx` and `cfg$aquatic_monitoring_db`. Keep the CLI-arg overrides. Verify figures still generate unchanged:

Run: `Rscript --vanilla src/r/run_all.R` → figures produced as before (spot-check a known output dir).

- [ ] **Step 4: Write `tests/r/test-entrypoints.R`** mirroring `tests/test_cli.py` cases via `system2("Rscript", ...)` and asserting exit codes (0 on success, 1 on config error / validation failure). Guard live-DB cases with `skip_if`.

- [ ] **Step 5: Run entrypoint tests + commit**

Run: `Rscript --vanilla -e "source('renv/activate.R'); testthat::test_file('tests/r/test-entrypoints.R')"` → PASS.
```bash
git add src/r/run_data.R src/r/run_pipeline.R src/r/run_all.R tests/r/test-entrypoints.R
git commit -m "feat(r): add run_data/run_pipeline entry points; unify config parsing"
```

---

## Phase 5 — Python removal & cleanup

### Task 19: Remove Python pipeline and update tooling/docs

**Precondition:** Tasks 1–18 complete; the golden integration test (Task 17) passes against the real source databases, and the full testthat suite is green:
Run: `Rscript --vanilla -e "source('renv/activate.R'); library(readxl); library(openxlsx); library(dplyr); library(tidyr); library(lubridate); testthat::test_dir('tests/r')"` → all PASS.

**Files:** (delete) `src/mgen/`, `tests/*.py`, `tests/test_domains/`, `tests/mgen/`, `tests/conftest.py`, `pyproject.toml`, `uv.lock`, `requirements.txt`, `.python-version`, `.coverage`, `dist/`. (modify) `.pre-commit-config.yaml`, `.github/`, `README.md`, `docs/usage.md`, `AGENTS.md`, `tasks/`. (keep) `tests/r/assets/expected_Data.xlsx`, `tests/assets/` may be removed once nothing references it.

- [ ] **Step 1: Confirm green** — run the full-suite command above; do not proceed unless all pass.

- [ ] **Step 2: Delete the Python tree**

```powershell
Remove-Item -Recurse -Force src/mgen, tests/test_domains, tests/mgen
Remove-Item -Force tests/test_*.py, tests/conftest.py
Remove-Item -Force pyproject.toml, uv.lock, requirements.txt, .python-version, .coverage
Remove-Item -Recurse -Force dist
```

- [ ] **Step 3: Strip Python from `.pre-commit-config.yaml`** — remove `uv-*`, `ruff`, `deptry`, `nbstripout`, `__all__`, `forbidden testpy`, `Validate pyproject.toml` hooks. Keep generic hooks (large files, merge conflicts, trailing whitespace). Optionally add an R `lintr`/`styler` hook.

- [ ] **Step 4: Update CI** under `.github/` — replace the pytest/ruff job with:
```yaml
- run: Rscript --vanilla -e "source('renv/activate.R'); renv::restore(prompt=FALSE)"
- run: Rscript --vanilla -e "source('renv/activate.R'); library(readxl); library(openxlsx); library(dplyr); library(tidyr); library(lubridate); testthat::test_dir('tests/r', stop_on_failure=TRUE)"
```

- [ ] **Step 5: Rewrite `README.md` + `docs/usage.md`** — drop the Python badge and Python sections; document the R-only entry points (`Rscript src/r/run_data.R`, `run_pipeline.R`, `run_all.R`), renv restore, and the testthat command. Update the architecture mermaid: the `mgen` Python box becomes the R data pipeline.

- [ ] **Step 6: Update `AGENTS.md` and `tasks/`** — remove `install_venv`/`uv`/Python shims; keep `install_r` and renv restore. Update `dev_sync` to restore only R.

- [ ] **Step 7: Snapshot and run final verification**

```powershell
Rscript --vanilla -e "source('renv/activate.R'); renv::snapshot(prompt=FALSE)"
Rscript --vanilla -e "source('renv/activate.R'); library(readxl); library(openxlsx); library(dplyr); library(tidyr); library(lubridate); testthat::test_dir('tests/r', stop_on_failure=TRUE)"
```
Expected: clean snapshot; all tests PASS.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "refactor: remove Python data pipeline; R-only project"
```

---

## Self-review

**Spec coverage:**
- Intermediate xlsx kept → Tasks 7, 17 (writer + golden against `MtMessengerEcologyData.xlsx`); `run_all.R` untouched except config unification (Task 18).
- Big-bang + golden gate → Task 17 gate before Task 19 removal.
- Full-fidelity validation/errors → Tasks 4, 5 (R6 `DomainResult`, `ValidationError` format, three checks).
- Match existing script layout → `src/r/data/` modules, `run_data.R`/`run_pipeline.R` (Tasks 2–18).
- Full testthat port → every domain/infra task ports its pytest counterpart; ldv/rpd get new tests (noted).
- Config via real TOML → Task 6; `run_all.R` regex replaced (Task 18).
- Python removal + tooling/docs → Task 19.

**Placeholder scan:** Domain test steps say "mirror every case in `test_X.py`" — this is a deliberate, named instruction (the pytest file is the authoritative case list), not a vague TODO. All implementation steps include complete R. No "TBD"/"implement later".

**Type/name consistency:** `DomainResult$new(data=, errors=)`, `$ok()`, `$add_error()` consistent across Tasks 4, 8–17. `ValidationError(domain, severity, file, sheet, location, message)` consistent. `load_config()` keys (`macroinvertebrate_db`, `aquatic_monitoring_db`, `data_xlsx`, `figures_dir`, `tables_dir`) consistent across Tasks 6, 17, 18. Sample columns keyed by character index consistent across Tasks 14–16. `SHEET_ORDER`/`SCHEMA_MAP` consistent across Tasks 2, 7, 17.

**Known risk carried forward:** exact float/date parity is verified empirically in Task 17 against real source DBs — if a domain diverges, fix before Task 19 (Python still available for diffing).
