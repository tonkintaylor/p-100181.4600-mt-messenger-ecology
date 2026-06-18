# Data Pipeline R Port — Design

**Date:** 2026-06-18
**Status:** Approved (design)
**Author:** Ben Karl

## Context & motivation

The repository is currently a hybrid: a Python package (`src/mgen/`, ~2,070 lines
plus ~2,700 lines of pytest) runs the **data pipeline** (ingest the two source
spreadsheets, transform per domain, validate, write the intermediate
`MtMessengerEcologyData.xlsx`), and R (`src/r/`) runs the **figure pipeline**
(reads that xlsx, produces figures and tables).

The ecology team that will own this project is R-native, and the current author
is leaving the company. The team needs to regenerate **everything from raw data**
each monitoring cycle, not merely re-render figures. An R-only team inheriting a
Python data pipeline is a bus-factor problem: they could change figures but not
the data logic. Collapsing to a single language (R) they can maintain — and, in a
follow-up project, ship as a portable click-and-run bundle — removes that risk.

This spec covers **only the Python → R port of the data pipeline**. The portable,
no-install click-and-run distribution bundle is a separate follow-up project with
its own spec.

## Goals

- Reproduce the `mgen` data pipeline in R, mirroring its structure one-for-one.
- Preserve the intermediate `MtMessengerEcologyData.xlsx` as the hand-off point;
  leave `run_all.R` (figures) essentially untouched.
- Keep `tests/assets/expected_Data.xlsx` as the single acceptance contract across
  the language switch.
- Remove the Python side entirely once parity holds, leaving a single-language
  (R + renv) repository.

## Non-goals (out of scope)

- The portable click-and-run distribution bundle (follow-up project #2).
- The fish-trapping path in `run_all.R` that reads the Aquatic DB directly — it is
  figure-side and stays as-is.
- Any change to figure output or the figure pipeline's logic.
- Promoting the R code to a formal R package (possible future cleanup; not now).

## Key decisions

| Decision | Choice |
| --- | --- |
| Intermediate xlsx | **Keep** `MtMessengerEcologyData.xlsx`; `run_all.R` unchanged. |
| Migration strategy | **Big-bang** rewrite; golden-file diff as the final acceptance gate. |
| Validation layer | **Full structural fidelity** — mirror `ValidationError` / `DomainResult`. |
| Structure & entry | **Match existing script layout** (`source()`-based, no package). |
| Testing | **Full testthat port** of the pytest suite + golden-file gate. |

## Section 1 — Architecture & module map

The R data pipeline mirrors `mgen` one-for-one, under `src/r/data/`:

| Python (`src/mgen/`) | New R (`src/r/data/`) | Purpose |
| --- | --- | --- |
| `config.py` | `config.R` | Parse + validate `cycle.toml`, check input files exist. |
| `shared/errors.py` | `errors.R` | `ValidationError`, `DomainResult` (R6). |
| `shared/validation.py` | `validation.R` | `check_required_columns`, `check_no_nulls`, `check_value_range`. |
| `shared/schemas.py` | `schemas.R` | Column-name vectors + expected dtypes per sheet. |
| `domain/*.py` (9 files) | `domains/*.R` | clarity, ldv, macro, macro_ingest, macro_species, rpd, sediment, sediment_ingest, sediment_size. |
| `writer.py` | `writer.R` | `SHEET_ORDER`, schema check, write via `openxlsx`. |
| `pipeline.py` | `pipeline.R` | `run_pipeline()` — run all domains, no-partial-output contract. |
| `cli.py` | `run_data.R` + `run_pipeline.R` | Rscript entry points (see §3). |

**Data flow (unchanged in shape):** `cycle.toml` → `run_data.R` → each domain returns
a `DomainResult` → if all OK, merge → `writer.R` writes
`MtMessengerEcologyData.xlsx` → existing `run_all.R` reads it → figures. The
intermediate xlsx and `run_all.R` are untouched.

**Dependencies:** `readxl` (read, existing), `openxlsx` (write, existing),
`dplyr` / `tidyr` / `lubridate` (transforms, existing). **One new dependency:** a
TOML parser — `RcppTOML` (mature, faithful). Caveat: it is compiled, a minor
consideration for the future portable bundle (bakeable).

## Section 2 — Validation & error layer (full fidelity, R6)

`DomainResult` is mutable (domains build it incrementally), so R6 fits.
`ValidationError` is frozen in Python — implemented as a classed list / constructor
with no setters, preserving the exact string format
`[SEVERITY] file → sheet → location: message`.

```r
# errors.R
ValidationError <- function(domain, severity, file, sheet, location, message) {
  structure(
    list(domain = domain, severity = severity, file = file,
         sheet = sheet, location = location, message = message),
    class = "ValidationError"
  )
}
format.ValidationError <- function(x, ...)
  sprintf("[%s] %s → %s → %s: %s",
          toupper(x$severity), x$file, x$sheet, x$location, x$message)

DomainResult <- R6::R6Class("DomainResult",
  public = list(
    data = NULL,            # named list of data.frames, or NULL
    errors = list(),
    initialize = function(data = NULL, errors = list()) { ... },
    add_error = function(e) { ... },
    ok = function() !any(vapply(self$errors, \(e) e$severity == "error", logical(1)))
  )
)
```

The three validation functions return a `list()` of `ValidationError` (mirroring
`list[ValidationError]`), preserving the subtle behaviors:

- `check_required_columns` — reports sorted missing columns at `location = "header"`.
- `check_no_nulls` — reports count + first 5 offending rows per column.
- `check_value_range` — detects non-numeric values coerced to NA
  (`suppressWarnings(as.numeric(x))` + "was it NA before?"), and min/max breaches,
  reporting the first 5 offending rows each.

**Row-index reporting:** R is 1-based, pandas 0-based. Error locations report the
**source-spreadsheet row number** (most useful to an ecologist). This is a
deliberate, documented divergence — error *messages* will not be byte-identical to
Python's.

**Failure behavior (matches Python):** any `severity == "error"` → no xlsx written
(no-partial-output contract in `pipeline.R`), all errors printed as a summary, and
`run_data.R` calls `quit(status = 1)` so a click-and-run wrapper can detect failure.

## Section 3 — Config parsing & entry points

`config.R` replaces the regex TOML-scraping currently in `run_all.R` with real
parsing via `RcppTOML::parseTOML`, mirroring `config.py`:

- Required: `[input].macroinvertebrate_db`, `[input].aquatic_monitoring_db`,
  `[output].data_xlsx`.
- Defaults: `figures_dir` → `<data_xlsx parent>/Figures`;
  `tables_dir` → `<figures_dir>/Tables`.
- Validates input files exist; raises a clear error (and exit 1) if config is
  missing/malformed — same `ConfigError` semantics.
- `run_all.R`'s TOML regex is replaced by a call into this shared `config.R`, so
  there is one config reader, not two.

**Entry points** replacing the `mgen` CLI (all via `Rscript`, ready to wrap in a
`.cmd` later):

| Old (`mgen`) | New |
| --- | --- |
| `mgen data` | `Rscript src/r/run_data.R [cycle.toml]` |
| `mgen validate` | `Rscript src/r/run_data.R [cycle.toml] --validate` (runs domains, reports errors, writes nothing) |
| `mgen figures` | `Rscript src/r/run_all.R ...` (unchanged) |
| `mgen all` | `Rscript src/r/run_pipeline.R [cycle.toml]` (runs `run_data` then `run_all`) |

`run_pipeline.R` is the target for the future click-and-run bundle. The `--quiet`
flag is dropped (low value for unattended runs).

## Section 4 — Writer & xlsx parity strategy (highest risk)

`writer.R` mirrors `writer.py`: enforce `SHEET_ORDER`, refuse empty sheets, assert
each sheet's columns match the schema exactly, then write all 8 sheets via
`openxlsx` (workbook built sheet-by-sheet to control column types).

`SHEET_ORDER`: `Macro, Macro1, MacroSpecies, Sediment, SedimentSize, Clarity, RPD,
LDV`.

Parity is bounded by how the golden test compares — **tolerance-based on read-back,
not byte-exact**. The three things that must survive the `openxlsx` → `readxl`
round-trip:

1. **Dates** — `Date` columns read back as datetime, not text or Excel serial.
   `openxlsx` writes `Date`/`POSIXct` as real Excel dates; column types set
   explicitly; the golden test's datetime check guards this.
2. **Numerics as float64** — metrics written as numbers, not strings. Schema-column
   assertion + tolerance compare (`rtol ≈ 1e-7`) absorbs last-digit float
   differences between R and pandas math.
3. **NA handling** — pandas `NaN` ↔ R `NA` ↔ empty Excel cell must round-trip
   consistently so `na_value = NaN` comparisons line up.

**Big-bang safety net:** build the R golden-file harness **first** — before/alongside
the domain ports — replicating the Python comparison (read both, filter actual to
golden dates, sort by `Date` + `Site`, exact columns/strings, tolerance numerics).
The instant the R pipeline produces output, this gives a per-sheet parity signal,
sheet by sheet, even without domain-by-domain gating.

`tests/assets/expected_Data.xlsx` is reused unchanged as the single source of truth
across the language switch.

## Section 5 — Testing (full testthat port + golden gate)

Port the pytest suite to `testthat` 1:1, under `tests/r/` (replacing the
placeholder `src/r/tests/test_pipeline.R`), runnable via
`Rscript -e "testthat::test_dir('tests/r')"`:

| pytest file | testthat file |
| --- | --- |
| `test_config.py` | `test-config.R` |
| `test_validation.py` | `test-validation.R` |
| `test_errors.py` | `test-errors.R` |
| `test_schemas.py` | `test-schemas.R` |
| `test_domains/test_*.py` (6) | `test-domain-*.R` (6) |
| `test_writer.py` (incl. golden) | `test-writer.R` |
| `test_pipeline_integration.py` | `test-pipeline-integration.R` |
| `test_cli.py` | `test-entrypoints.R` (invoke `run_data.R` via `Rscript`, check exit codes/output) |
| `conftest.py` fixtures | `helper-*.R` + `setup-*.R` |

Numeric comparisons use `testthat::expect_equal(tolerance = )` to mirror
`assert_allclose`. The golden comparison becomes the headline integration test and
the **acceptance gate**: Python is not removed until `test-writer.R`'s golden test
is green for all 8 sheets.

This is the largest single chunk of the project (~2,700 lines of test logic to
re-express), roughly doubling the build effort versus a golden-gate-plus-targeted
approach. Full parity was chosen deliberately; the implementation plan budgets for
it explicitly.

## Section 6 — Python removal & repo cleanup

Once the golden gate is green and the testthat suite passes, remove the Python side
in one commit (git history preserves it — no in-tree archive):

**Delete:** `src/mgen/`, all `tests/*.py` + `tests/test_domains/` + `tests/mgen/` +
`conftest.py`, `pyproject.toml`, `uv.lock`, `requirements.txt`, `.python-version`,
`.coverage`, `.ruff_cache/`, `dist/` wheels + `mgen-bundle/` (superseded by the
future R bundle).

**Migrate (do not delete):** `tests/assets/expected_Data.xlsx` → `tests/r/assets/`.

**Update:**

- `.pre-commit-config.yaml` — drop ruff/python hooks; optionally add `lintr`/`styler`.
- `.github/` workflows — CI runs `renv::restore()` + `testthat`, not pytest/ruff.
- `README.md` — drop Python badge/sections; document the R-only `Rscript` entry points.
- `docs/usage.md` — rewrite for the R-only workflow.
- `AGENTS.md`, `tasks/` shims — drop `uv`/venv/`install_venv` installers; keep the R install path.
- `DESCRIPTION` — add `R6`, `RcppTOML`, `testthat`; `renv::snapshot()`.

**Left alone:** `src/r/` figures code, `src/archive/`, `renv/`, the `cycle.toml` files.

`tasks/` and CI cleanup is real surface area — the plan treats it as its own step so
nothing dangling references Python.

## Section 7 — Risks

1. **xlsx round-trip parity** (highest) — dates, float64, NA. Mitigated by the
   tolerance-based golden harness built first (§4). Where big-bang will most likely
   first show trouble, and where the earliest signal appears.
2. **Float divergence in metric math** — QMCI/EPT/grain-size in R vs pandas may
   differ in the last digits. Absorbed by `tolerance =` in the golden compare.
3. **NA/NaN semantics** — pandas and R treat missing/`NaN`/empty differently;
   transform and validation code must be deliberate. Covered by ported tests.
4. **Row-index reporting** — switching to source-spreadsheet row numbers (§2); a
   documented divergence from Python's 0-based index.
5. **`RcppTOML` is compiled** — fine now; a consideration to bake into the future
   portable bundle.
6. **Big-bang has no full parity until late** — mitigated by per-sheet golden
   signal as soon as the pipeline runs.
7. **Full testthat port is the bulk of the effort** — accepted tradeoff for coverage
   parity.

## Acceptance criteria

- `Rscript src/r/run_data.R cycle.toml` produces `MtMessengerEcologyData.xlsx` with
  all 8 sheets in `SHEET_ORDER`, correct columns/dtypes.
- The R golden test passes for all 8 sheets against
  `tests/assets/expected_Data.xlsx` (tolerance-based numerics, exact columns/strings).
- The full testthat suite passes.
- `Rscript src/r/run_pipeline.R cycle.toml` runs data → figures end-to-end.
- The Python side and its tooling are removed; CI/pre-commit/docs reference only R.
- `run_all.R` figure output is unchanged.
