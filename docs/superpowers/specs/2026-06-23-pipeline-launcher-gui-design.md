# Pipeline Launcher GUI — Design

- **Date:** 2026-06-23
- **Status:** Approved (brainstorming) — pending implementation plan
- **Author:** Ben Karl (with Claude)

## Context & goal

The Mt Messenger ecology pipeline is an R batch process run from a terminal as:

```
Rscript --vanilla src/r/run_pipeline.R cycle.toml
```

`cycle.toml` carries exactly five paths — two input `.xlsx` databases and three
outputs (a consolidated data workbook, a figures folder, a tables folder).

The goal is a **click-to-run app**: a colleague double-clicks an icon, points it
at the input datasets, says where outputs go, clicks **Run**, watches progress,
and gets a clear pass/fail. The target users are **non-technical, non-admin
colleagues on the corporate network with internet access** who have **not** set
up the repo and do **not** have R installed (delivery "Model 2": the app
provisions R on first run).

The integration seam is small and already exists: collect five paths → write a
temporary `cycle.toml` → shell out to the existing in-repo `run_pipeline.R` →
stream stdout/stderr → report the exit code.

## Locked decisions

| Decision | Choice |
|---|---|
| Launcher technology | **PowerShell + WinForms** (must be non-R: it installs R before R exists) |
| Delivery | **Inno Setup per-user installer** that drops the app folder + an icon'd shortcut |
| Bundled content | The app ships a **copy of the R pipeline** (colleagues don't clone the repo) |
| Output collection | **Three separate paths** (data workbook file, figures dir, tables dir) — full `cycle.toml` flexibility |
| Actions | **Run** (full pipeline) + **Check inputs** (fast `--validate` pre-flight) |
| Path persistence | **Remember last-used** five paths in a per-user settings file |
| First-run R setup | **Notice + one click to start**, then progress; no admin required (`winget --scope user`) |
| R version pin | **Pin winget to the R version that matches the project** (`--version`); see Open decisions |

## Architecture

A single Inno Setup installer, run once per user (no admin):

```
MtMessengerPipeline-Setup.exe        ← colleagues run this once
        │  installs to %LOCALAPPDATA%\MtMessengerPipeline\ ; makes a Start-menu shortcut
        ▼
%LOCALAPPDATA%\MtMessengerPipeline\
├── launcher.ps1            ← the WinForms GUI (the only bespoke code)
├── app.ico                 ← shortcut/window icon
├── pipeline\               ← verbatim copy of the repo's R code
│   ├── src\r\…              (run_pipeline.R, run_data.R, run_all.R, data\, helpers\)
│   ├── scripts\sync_r_packages.R
│   └── DESCRIPTION          (pinned R version + PPM snapshot date)
└── settings.json           ← written at runtime, per user (last-used paths)
```

The shortcut runs:

```
powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File launcher.ps1
```

with `app.ico`. The launcher is the only code we write; the pipeline is the
existing R, copied in verbatim so `run_pipeline.R` resolves its own
`renv`/script-relative paths correctly.

### Code structure: engine vs view

`launcher.ps1` is structured as two layers so the risky logic is testable
without a window:

- **Engine** — pure functions, no WinForms: resolve `Rscript.exe`, build
  `cycle.toml`, output pre-flight, settings load/save, status/message mapping,
  process launch + streaming.
- **View** — the WinForms form and event handlers, which only call the engine.

## Window & UX

A single window:

```
┌─ Mt Messenger Ecology Pipeline ───────────────────────────┐
│  Inputs                                                    │
│   Macroinvertebrate DB  [ T:\…\MTMA Macro….xlsx ] [Browse] │
│   Aquatic monitoring DB [ T:\…\MTMA Aquatic….xlsx][Browse] │
│  Outputs                                                   │
│   Data workbook (.xlsx) [ R:\…\…Data.xlsx       ] [Browse] │
│   Figures folder        [ R:\…\Figures          ] [Browse] │
│   Tables folder         [ R:\…\Tables           ] [Browse] │
│                                                            │
│   [ Check inputs ]                            [   Run   ]  │
│  ┌─ Log ──────────────────────────────────────────────┐   │
│  │ === Mt Messenger Ecology Pipeline ===              │   │
│  │ Loading data...                                    │   │
│  └────────────────────────────────────────────────────┘   │
│  Status: ● Running…   [▓▓▓▓▓░░░░░]              [ Cancel ]  │
└────────────────────────────────────────────────────────────┘
```

- Input pickers use `OpenFileDialog` (filtered to `*.xlsx`); the data workbook
  uses `SaveFileDialog`; figures/tables use `FolderBrowserDialog`.
- Fields pre-fill from remembered last-used paths.
- On a machine without R, the form opens **disabled** behind a one-time setup
  notice (below).

## Run flow & state machine

**On launch:**
1. Load `settings.json` → pre-fill fields.
2. Resolve `Rscript.exe` (chain below).
3. If found → enable the form. If not → show the setup notice, form disabled.

**First-run setup notice:**

```
┌─ First-time setup ─────────────────────────────────────┐
│  R isn't installed on this PC yet.                     │
│  Setup installs R + the required packages.             │
│   • One-time, ~5–10 min, needs internet                │
│   • No admin rights needed (installs just for you)     │
│                                        [  Start setup ] │
└─────────────────────────────────────────────────────────┘
```

**Setup (on "Start setup"),** with live log + progress:
1. `winget install --id RProject.R --scope user --version <pinned> --silent`
   (+ `--accept-source-agreements --accept-package-agreements`).
2. Re-resolve `Rscript.exe` (now under `%LOCALAPPDATA%\Programs\R\…`).
3. `Rscript --vanilla pipeline\scripts\sync_r_packages.R` → installs pinned
   packages from the PPM snapshot (Windows binaries, no compiler needed).
4. Success → enable form. Failure → error + "Copy log" (e.g. winget blocked by
   policy → contact IT).

**Normal operation:**
- **Check inputs** → write temp `cycle.toml` → `run_data.R <toml> --validate`
  (seconds) → pass/fail. No output written.
- **Run** → output-writability pre-flight → write temp `cycle.toml` →
  `run_pipeline.R <toml>` → stream → exit code.

**State machine:** `Provisioning → Idle → Validating → Running →
(Succeeded | Failed | Cancelled) → Idle`. One job at a time; Run/Check disabled
while busy, Cancel enabled while busy.

### Rscript resolver chain

Explicit setting → `HKCU\SOFTWARE\R-core\R` → `%LOCALAPPDATA%\Programs\R\R-*\bin`
→ `HKLM\SOFTWARE\R-core\R` / `C:\Program Files\R\R-*\bin` (newest) → `PATH`.

A per-user winget install lands under `%LOCALAPPDATA%\Programs\R` with its
registry key under **HKCU**, and winget does **not** add R to `PATH` — hence the
HKCU and user-program-files entries come first.

### Threading model

The form runs on the UI thread; each job runs on a **background runspace** so
the window never freezes. `Rscript` is launched via `System.Diagnostics.Process`
with `UseShellExecute=$false`, `CreateNoWindow=$true`, both streams redirected,
async `OutputDataReceived`/`ErrorDataReceived`. Each line is marshalled to the
log box via `Invoke()`. Completion reads `ExitCode`. **Both** streams are read to
avoid a pipe-buffer deadlock. Handlers are unregistered on completion.

## Correctness-critical rules

1. **Invoke the bundled in-repo `run_pipeline.R` as-is**, with the working
   directory set to `…\pipeline\`. `--vanilla` skips `.Rprofile`; renv only
   activates because the scripts source `renv/activate.R` themselves keyed off
   the script location (`src/r/run_data.R:28-29`, `src/r/run_all.R:28-31`).
   Relocating the script breaks renv activation → wrong package versions.
2. **Child-process R discovery.** `run_pipeline.R:20,25` spawns two child
   `Rscript` processes that find R via `PATH`. The launcher prepends the
   resolved R `bin` to the child environment's `PATH` (and sets `R_HOME`) so the
   children find R.
3. **Cancel kills the whole process tree** (`taskkill /PID <id> /T /F` or
   `Process.Kill($true)`), because of the self-spawned children — otherwise an
   orphaned `Rscript` keeps the output `.xlsx` locked.
4. **Output-writability pre-flight.** Before a Run, verify each of the three
   output targets: parent folder exists/creatable, and `data_xlsx` is not open
   in Excel (openxlsx fails — sometimes silently — on a locked file). Stop
   before the multi-minute run with a clear message if locked.
5. **R-version pin vs winget-latest.** Project pins R 4.5 (`DESCRIPTION`,
   enforced by `scripts/sync_r_packages.R:131-143`). Default: pin winget to the
   matching R version via `--version` (see Open decisions).
6. **Forward slashes in the generated `cycle.toml`.** Convert dialog
   backslashes to `/`; R accepts `/` and `normalizePath` preserves the `T:`
   mapped-drive letter.

## Error handling & failure UX

- **Pass/fail = process exit code** (pipeline already exits non-zero on error,
  `run_data.R:62-66`). Status line shows ● green Succeeded / red Failed / grey
  Cancelled.
- **On failure:** keep the log visible, auto-scroll to and highlight the last
  error lines (`run_data.R:53-54,61-65`); offer **Copy log** / **Save log…**.
- **Always** write a timestamped run log next to the chosen outputs
  (`run-YYYY-MM-DD-HHMM.log`) as an audit trail.
- **Friendly messages** for predictable failures, shown above the raw log:

  | Condition | Message |
  |---|---|
  | Output `.xlsx` locked by Excel | "…Data.xlsx is open in Excel — close it and try again." (caught in pre-flight) |
  | Input missing / unreadable | "Couldn't read <file> — check it exists and you have access to T:." |
  | winget absent / blocked | "Automatic R setup couldn't run on this PC — contact IT (winget unavailable)." |
  | Package sync failed | "Couldn't download R packages — check your internet connection, then retry setup." |
  | R-version mismatch | expected vs found version, stated plainly |

- **Mid-run robustness:** a dropped `T:` connection surfaces as a clear failure,
  not a silent hang. Cancel is always available during a run.

## Testing strategy

**Unit tests (Pester, CI on Windows)** — per engine function:
- Rscript resolver honours the chain order against stubbed registry/filesystem.
- `cycle.toml` generation: five paths → correct `[input]`/`[output]` TOML with
  backslash→forward-slash conversion (the shape `src/r/data/config.R` parses).
- Output pre-flight: locked/missing/creatable → correct verdict.
- Settings round-trip: save→load identity; corrupt/missing file → blank, no crash.
- Status mapping: exit code + condition → correct message and colour.

**Integration smoke test (scripted, Windows + R present):** call the engine's
run path with test inputs against the **bundled** `run_pipeline.R`; assert exit 0
and that outputs appear. Reuses the pipeline's existing golden data; asserts the
seam, not pipeline correctness (covered by `src/r/tests/` / `tests/r/`).

**Manual smoke checklist (clean Windows VM, no R) — the acceptance test for
provisioning:** installer per-user → setup notice → Start setup (winget +
package sync) → form enables → Check inputs → Run → live log → outputs present →
Cancel mid-run leaves no orphaned `Rscript`.

**Not CI-able (documented manual):** winget install + multi-minute real run
needs a networked Windows box; CI covers engine units only.

## Open implementation decisions (to resolve in the plan)

- **R-version pinning (default 5a):** pin winget to the R version matching
  `Config/R/Version` via `winget install --version`. Confirm that an R `4.5.x`
  build is available in winget-pkgs for `RProject.R`; if not, fall back to (b)
  bump `Config/R/Version` + PPM snapshot to current R, or (c) `--allow-r-mismatch`.
- **Icon asset** (`app.ico`) — source/produce a project icon.
- **Build/release wiring** — a script that assembles the app folder (copies the
  R pipeline in) and runs the Inno Setup compile; where the installer is published
  for colleagues to download.

## Out of scope (YAGNI)

- Bundling a portable R (Model 3) — only needed for offline/no-winget machines.
- Data-only / figures-only buttons — full run + Check inputs cover the use cases.
- Save/Load named presets — last-used remembered paths are enough for now.
- Auto-update of the app — rides the existing installer/distribution process.
- Cross-platform (macOS/Linux) — Windows-only by requirement.

## Key references

- R non-admin install + per-user location: CRAN R-for-Windows FAQ
  (`https://cran.r-project.org/bin/windows/base/rw-FAQ.html`).
- winget scope/admin behaviour: Microsoft Learn winget docs.
- winget does not add R to PATH: `microsoft/winget-cli#3611`.
- Package provisioning model: `scripts/sync_r_packages.R` (dated PPM snapshot,
  Windows binaries).
