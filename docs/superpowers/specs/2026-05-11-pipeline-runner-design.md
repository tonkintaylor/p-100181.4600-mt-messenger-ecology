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

### `mgen figures [cycle.toml] [--only] [--data]`

Replaces the old `mgen plot` command.

Reads the data xlsx (from `cycle.toml` by default), computes stats, and
generates figures and tables to the configured figures directory.

Options:

- `--only` — subset filter: `sediment`, `macro`, `community`, or `all`
  (default: `all`).
- `--data PATH` — override the data xlsx path. Use this to point at a
  manually edited copy instead of the one configured in `cycle.toml`.

Exit codes: 0 success, 1 no figures generated, 2 config error.

### `mgen all [cycle.toml] [--only]`

New command. Runs `data` then `figures` back-to-back.

Behaviour:

1. Load config from `cycle.toml`.
2. Run the data pipeline (same logic as `mgen data`).
3. If data fails → print errors, exit code 1, do not run figures.
4. If data succeeds → run figures using the just-written data xlsx.
5. `--only` passes through to the figures step.

No `--data` override — `all` always uses the freshly generated file.

Exit codes: same as above.

### `mgen validate [cycle.toml]`

Unchanged. Validates config and checks input files exist without running
anything.

## Naming Changes

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

## User Workflow

### One-time setup

```powershell
./tasks/dev_sync.ps1
```

This installs `uv`, creates the virtual environment, installs dependencies,
and activates the venv.

### Running the pipeline

```powershell
# Process inputs → MtMessengerEcologyData.xlsx
mgen data

# Generate figures from data xlsx
mgen figures

# Generate figures from a manually edited copy
mgen figures --data ./my-edited-copy.xlsx

# Run everything back-to-back
mgen all

# Run data + only sediment figures
mgen all --only sediment

# Check config without running
mgen validate
```

No new scripts or infrastructure. The existing `dev_sync.ps1` setup workflow
is unchanged.

## Implementation Scope

### Files to change

- `src/mgen/cli.py` — rename commands, add `all`, rename `--data-xlsx` flag.
- `src/mgen/writer.py` — update log message.
- `cycle.toml` — update output filename.
- `cycle.example.toml` — update output filename.
- `README.md` — update pipeline diagram and any references.
- Tests referencing old command names or `Data.xlsx`.

### Files unchanged

- `src/mgen/config.py` — no changes (key names stay the same).
- `src/mgen/pipeline.py` — no changes (orchestration logic unchanged).
- `src/mgen/figures.py` — no changes (figure generation unchanged).
- `tasks/` — no changes (setup workflow unchanged).

### What is NOT in scope

- No new runner scripts or wrapper scripts.
- No changes to domain processors or stats logic.
- No changes to the figure output format or directory structure.
- No changes to the setup workflow or dependency management.
