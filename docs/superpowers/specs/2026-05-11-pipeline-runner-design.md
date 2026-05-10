# Pipeline Runner Redesign

Simplify the `mgen` CLI to three clear commands — `data`, `figures`, `all` — so
that running the pipeline requires no knowledge beyond one-time setup and a
single command.

## CLI Commands

### `mgen data [cycle.toml]`

Replaces the old `mgen run` command.

Reads the input spreadsheets configured in `cycle.toml`, runs all domain
processors (macro, macro species, sediment, sediment size, clarity), and writes
`MtMessengerEcologyData.xlsx` to the configured output path.

Exit codes: 0 success, 1 domain errors, 2 config error.

### `mgen figures [cycle.toml] [--data]`

Replaces the old `mgen plot` command. Runs the R figure pipeline
(`src/r/run_all.R`) via `Rscript`.

The Python figure code (`src/mgen/figures.py`) is no longer called by the CLI.
It stays in the codebase for now but will be removed in a future cleanup.

Reads the data xlsx (from `cycle.toml` by default), and invokes `Rscript` to
generate figures and tables to the configured output directories.

The R script receives three positional arguments:
`Rscript src/r/run_all.R <data_xlsx> <figures_dir> <tables_dir>`

Options:

- `--data PATH` — override the data xlsx path. Use this to point at a
  manually edited copy instead of the one configured in `cycle.toml`.

Exit codes: 0 success, 1 R script failed, 2 config error.

### `mgen all [cycle.toml]`

New command. Runs `data` then `figures` back-to-back.

Behaviour:

1. Load config from `cycle.toml`.
2. Run the data pipeline (same logic as `mgen data`).
3. If data fails → print errors, exit code 1, do not run figures.
4. If data succeeds → run figures using the just-written data xlsx.

No `--data` override — `all` always uses the freshly generated file.

Exit codes: same as above.

### `mgen validate [cycle.toml]`

Unchanged. Validates config and checks input files exist without running
anything.

## Figure Pipeline: R via Rscript

The `figures` command delegates entirely to R. It:

1. Resolves the data xlsx path (from config or `--data` override).
2. Checks that `Rscript` is on PATH; if not, prints a clear error directing the
   user to run `dev_sync.ps1`.
3. Runs `Rscript src/r/run_all.R <data_xlsx> <figures_dir> <tables_dir>`.
4. Streams R's stdout/stderr to the terminal in real time.
5. Maps R's exit code: 0 → success, non-zero → exit 1.

The `--only` filter is removed. The R pipeline always generates all figure
types. If selective generation is needed in the future, it can be added to
`run_all.R` directly.

## Config Changes

### New key: `[output].tables_dir`

`cycle.toml` already has a `tables_dir` key, but `PipelineConfig` doesn't read
it. Add `tables_dir: Path` to `PipelineConfig`, defaulting to
`figures_dir / "Tables"` if not specified.

### Output file: Data.xlsx → MtMessengerEcologyData.xlsx

The default output filename changes from `Data.xlsx` to
`MtMessengerEcologyData.xlsx`. This affects:

- `cycle.example.toml` — update the example path.
- `cycle.toml` — update the current path.
- `writer.py` — log messages referencing the filename.
- `cli.py` — help text and error messages.
- `README.md` — pipeline diagram node label.

The config key `[output].data_xlsx` and the `PipelineConfig.data_xlsx` field
name stay unchanged — they are internal identifiers, not user-facing names.

### CLI flag: --data-xlsx → --data

The figures command flag for overriding the data xlsx path shortens from
`--data-xlsx` to `--data`.

## Setup: R Installation

The `dev_sync.ps1` setup script gains two additional steps:

1. **Install R** — via `winget install --id RProject.R --accept-source-agreements`
   (skip if `Rscript` is already on PATH).
2. **Install R packages** — via `Rscript -e "install.packages(...)"` for the
   packages required by `run_all.R`: readxl, dplyr, tidyr, ggplot2, vegan,
   indicspecies, ggrepel, zoo, patchwork, openxlsx, lubridate.

This makes the one-time setup fully self-contained: after running
`dev_sync.ps1`, the user has both Python and R environments ready.

## User Workflow

### One-time setup

```powershell
./tasks/dev_sync.ps1
```

This installs `uv`, creates the Python virtual environment, installs Python
dependencies, installs R (if not present), installs R packages, and activates
the venv.

### Running the pipeline

```powershell
# Process inputs → MtMessengerEcologyData.xlsx
mgen data

# Generate figures from data xlsx (runs R pipeline)
mgen figures

# Generate figures from a manually edited copy
mgen figures --data ./my-edited-copy.xlsx

# Run everything back-to-back
mgen all

# Check config without running
mgen validate
```

## Implementation Scope

### Files to change

- `src/mgen/cli.py` — rename commands, add `all`, replace Python figure call
  with `Rscript` subprocess invocation, rename `--data-xlsx` flag, remove
  `--only` flag.
- `src/mgen/config.py` — add `tables_dir` field to `PipelineConfig`.
- `src/mgen/writer.py` — update log message.
- `cycle.toml` — update output filename.
- `cycle.example.toml` — update output filename, add `tables_dir` example.
- `README.md` — update pipeline diagram and references.
- `tasks/` setup scripts — add R installation and package install steps.
- Tests referencing old command names or `Data.xlsx`.

### Files unchanged

- `src/mgen/pipeline.py` — no changes (data pipeline orchestration unchanged).
- `src/mgen/figures.py` — no changes (stays in codebase, just not called by
  CLI).
- `src/r/` — no changes (R scripts are already structured for CLI invocation).
- Domain processors and stats logic — no changes.

### What is NOT in scope

- Removing the Python figure code (deferred to future cleanup).
- Changes to R script logic or output format.
- Changes to domain processors or stats logic.
