# Launcher Workbook Modes & Single Output Folder — Design

- **Date:** 2026-06-26
- **Status:** Approved (brainstorming) — pending implementation plan
- **Author:** Ben Karl (with Claude)

## Context & goal

The Pipeline Launcher GUI (see `2026-06-23-pipeline-launcher-gui-design.md`)
collects five paths — two input `.xlsx` databases and three outputs (a data
workbook, a figures folder, a tables folder) — writes a temporary `cycle.toml`,
and runs the bundled R pipeline. Two changes are wanted:

1. **The data workbook is both an output and an optional input.** A user should
   be able to *either* build the workbook from the two source databases (today's
   behaviour) *or* select an existing data workbook and just (re)generate the
   figures and tables from it — skipping the multi-minute data-build stage.
2. **Collapse the three output paths into one output folder.** The launcher
   creates `figures/` and `tables/` subfolders inside it, and (in build mode)
   writes the data workbook at its root.

A prerequisite falls out of (1): today **fish** is the only domain read *live*
from the aquatic monitoring DB at figure time (`run_all.R` calls
`load_fish_trapping(aquatic_db_path)`), so a workbook-only run would silently
lose the fish plots. We therefore **move fish into the data workbook** so the
workbook is fully self-sufficient as the figure stage's input.

## Locked decisions

| Decision | Choice |
|---|---|
| Fish data | **Written into the data workbook** as a `Fish` sheet at data-build time; figure stage reads it from the workbook, not the live DB |
| Fish sheet contents | **Raw trapping rows** (the columns the plots need); aggregation stays at plot time in `compute_fish_catch_per_night()` |
| Input mode | **Radio toggle**: *Build from databases* (two DB pickers) **or** *Use an existing data workbook* (one `.xlsx` picker) |
| Mode encoding | **Implicit** — the launcher picks the R entrypoint and omits the input DBs from `cycle.toml` in workbook mode; no explicit `mode` key |
| Output collection | **A single output folder**; `figures/` and `tables/` created inside; build mode writes `MtMessengerEcologyData.xlsx` at its root |
| Build-mode workbook name | `MtMessengerEcologyData.xlsx` (descriptive, self-identifying when shared) |
| Python schema parity | **Out of scope** — add `Fish` to the R `schemas.R` only; the launcher runs the R pipeline. Documented divergence from `mgen/shared/schemas.py` |

## Architecture

The integration seam is unchanged: collect paths → write a temporary
`cycle.toml` → shell out to the bundled R pipeline → stream → report exit code.
What changes is (a) which entrypoint runs, (b) the shape of the generated
`cycle.toml`, and (c) the R pipeline now carries fish through the workbook.

```
Build mode:    inputs = 2 DBs  →  run_pipeline.R  →  workbook + figures + tables
Workbook mode: input  = 1 .xlsx →  run_all.R --config  →  figures + tables
```

## A. Pipeline — fish in the workbook

Fish currently bypasses the data workbook entirely. Bring it into the same
domain → schema → writer flow as every other sheet.

- **New `src/r/data/domains/fish.R`** — `process_fish_domain(aquatic_db)`:
  reads the "Fish Trapping" sheet (reusing the cleaning logic in
  `load_fish_trapping`), selects and validates the columns the plots consume,
  and returns the standard domain result with `$data$Fish`. Follows the existing
  ingest-domain pattern (e.g. `domains/clarity.R`), returning `ok()`/`errors`.
- **`schemas.R`** — add `FISH_COLUMNS`, append `"Fish"` to `SHEET_ORDER`, and add
  the `Fish = FISH_COLUMNS` entry to `SCHEMA_MAP`. Proposed columns (finalised in
  the plan against the source sheet):
  `Site`, `Catchment`, `Date retrieved`, `Species`,
  `Species category (for abundance)`, `Number`.
  These are exactly what `compute_fish_catch_per_night()` reads, plus `Species`
  for traceability.
- **`pipeline.R`** — add `process_fish_domain(config$aquatic_monitoring_db)` to
  the `results` list so the `Fish` sheet is assembled and written. The writer's
  existing non-empty + exact-column-match guards then apply to `Fish` too.
- **`run_data.R --validate`** — add the fish domain to the validation list so
  Check inputs covers it.
- **`run_all.R`** — replace the live-DB fish read with a workbook read: use
  `data$Fish` (loaded by `load_all_data`) and pass it to
  `plot_fish_by_catchment()`. **Skip gracefully** when the sheet is absent, so a
  workbook produced by an older pipeline still works (minus fish) rather than
  erroring. `load_all_data` gains a `Fish` branch (`read_excel(... "Fish") |>
  clean_colnames() |> mutate(\`Date retrieved\` = as.Date(...))`).

`plot_fish_by_catchment()` already takes a raw fish data frame, so its internals
and the aggregation are unchanged — only its data source moves.

## B. R config — optional input DBs

`config.R::load_config` currently hard-requires both input DBs. In workbook mode
they are absent.

- Treat `macroinvertebrate_db` and `aquatic_monitoring_db` as **optional**: do
  not error when missing; only `normalizePath` + existence-check the ones that
  are present. Return `NULL` for an absent DB.
- `data_xlsx` stays **required** (it's the workbook path in both modes).
- `figures_dir` / `tables_dir` defaults are unchanged.

This keeps `run_all.R` (which loads the same config) happy with a DB-less
config, and `run_data.R` is only ever invoked in build mode where the DBs are
present.

## C. Launcher UI

A single window, restructured into an **Input** group with a mode toggle and an
**Output** group with one folder.

```
┌─ Mt Messenger Ecology Pipeline ───────────────────────────┐
│  Input                                                     │
│   ( ) Build data workbook from databases                   │
│       Macroinvertebrate DB  [ T:\…\…Macro….xlsx ] [Browse] │
│       Aquatic monitoring DB [ T:\…\…Aquatic….xlsx][Browse] │
│   ( ) Use an existing data workbook                        │
│       Data workbook (.xlsx) [ …\…Data.xlsx       ] [Browse] │
│  Output                                                    │
│   Output folder             [ …\Outputs          ] [Browse] │
│                                                            │
│   [ Check inputs ]                            [   Run   ]  │
│  ┌─ Log ──────────────────────────────────────────────┐   │
│  └────────────────────────────────────────────────────┘   │
│  Status: ● Ready                                [ Cancel ] │
└────────────────────────────────────────────────────────────┘
```

- Two radio buttons select the mode. The **inactive** mode's input rows are
  disabled (greyed) — kept in place rather than hidden, so the window layout
  stays fixed — and only the active mode's pickers accept input.
- DB pickers use `OpenFileDialog` (filtered to `*.xlsx`); the existing-workbook
  picker uses `OpenFileDialog`; the output folder uses `FolderBrowserDialog`.
  (The `SaveFileDialog` for the data workbook is gone — the workbook name is now
  derived in build mode.)
- Fields and the selected mode pre-fill from remembered settings.
- The bundled-R-missing disabled state is unchanged.

## D. Launcher engine

- **`ConfigWriter.ps1`** — derive output sub-paths and write a mode-appropriate
  `cycle.toml`:
  - `figures_dir = <out>/figures`, `tables_dir = <out>/tables` (forward-slashed).
  - Build mode: emit `[input]` with both DBs; `data_xlsx =
    <out>/MtMessengerEcologyData.xlsx`.
  - Workbook mode: **omit** `[input]` DBs; `data_xlsx =` the selected workbook.
  - Keep the backslash→forward-slash conversion.
- **`LauncherSettings.ps1`** — persist `Mode`, `MacroDb`, `AquaticDb`,
  `DataWorkbook` (the existing-workbook path), and `OutputDir`. Load with safe
  defaults (blank + a default mode) when keys/file are missing or corrupt.
- **`OutputPreflight.ps1`** — validate the **output folder** (exists or
  creatable). In **build mode**, additionally verify the produced workbook
  `<out>/MtMessengerEcologyData.xlsx` is not locked open in Excel. In **workbook
  mode**, verify the selected workbook exists and is readable.
- **`launcher.ps1`** (view) —
  - **Run:** build mode → `run_pipeline.R <toml>`; workbook mode →
    `run_all.R --config=<toml>` (figures only). Output-writability pre-flight
    runs first, as today.
  - **Check inputs:** build mode → `run_data.R <toml> --validate` (as today);
    workbook mode → a lightweight check that the chosen workbook exists, opens,
    and isn't locked (file-level pre-flight; no multi-minute work).
  - The Set-Busy / cancel / timestamped-run-log behaviour is otherwise unchanged;
    the run log is written into the output folder.

## Run flow

**Build mode (unchanged data flow, new packaging):** Check inputs validates the
two DBs; Run builds `MtMessengerEcologyData.xlsx` then figures + tables, all
under the one output folder.

**Workbook mode (new):** Check inputs confirms the workbook opens; Run skips the
data-build stage and runs the figure stage directly against the selected
workbook, writing `figures/` and `tables/` into the output folder.

## Testing strategy

**Unit tests (Pester, CI on Windows):**
- `ConfigWriter`: build mode → `[input]` + `[output]` with derived
  `figures/`/`tables/` and the descriptive workbook name; workbook mode → no
  `[input]` DBs and `data_xlsx` = selected workbook; backslash→slash conversion.
- `LauncherSettings`: round-trip including `Mode`; missing/corrupt file → safe
  defaults, no crash.
- `OutputPreflight`: output folder missing/creatable; build-mode workbook locked;
  workbook-mode input missing/locked → correct verdicts.

**R tests:**
- `process_fish_domain` produces a `Fish` data frame matching `FISH_COLUMNS`
  (and the writer's non-empty/column-match guards) from a fixture aquatic DB.
- `run_all.R` reads fish from a workbook `Fish` sheet and skips cleanly when the
  sheet is absent. Reuse the existing R test harness / golden data.

**Manual smoke checklist:** build-mode run end-to-end → one output folder with
`MtMessengerEcologyData.xlsx` + `figures/` + `tables/` (fish figures present);
then workbook-mode run against that produced workbook → figures + tables
regenerate (fish included) without re-reading the DBs.

## Out of scope (YAGNI)

- Keeping the Python `mgen/shared/schemas.py` in sync with the new `Fish` sheet —
  the launcher runs the R pipeline; documented divergence only.
- An optional aquatic-DB picker in workbook mode — superseded by fish living in
  the workbook.
- Per-domain "figures only / data only" buttons beyond the two modes here.
- Migrating old remembered three-path settings — a one-time re-pick is
  acceptable; load falls back to defaults for the new keys.

## Key references

- Fish read path moving into the workbook: `src/r/run_all.R` fish section,
  `src/r/helpers/fish_plots.R`, `src/r/helpers/data_loading.R::load_fish_trapping`.
- Domain/schema/writer pattern: `src/r/data/pipeline.R`, `src/r/data/writer.R`,
  `src/r/data/schemas.R`, `src/r/data/domains/clarity.R`.
- Config parsing: `src/r/data/config.R::load_config`.
- Launcher engine + view: `launcher/engine/*.ps1`, `launcher/launcher.ps1`.
