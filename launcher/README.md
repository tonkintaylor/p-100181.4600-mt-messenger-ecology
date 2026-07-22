# Mt Messenger Pipeline Launcher

A Windows "click-to-run" GUI for the Mt Messenger R ecology pipeline. The user
picks the two input databases and the three output locations, clicks **Run**,
and the launcher runs the bundled R pipeline and streams progress. The installer
**bundles its own R + packages**, so it runs on a machine with no R, no admin,
and no internet — nothing to set up beforehand.

- Design: [`docs/superpowers/specs/2026-06-23-pipeline-launcher-gui-design.md`](../docs/superpowers/specs/2026-06-23-pipeline-launcher-gui-design.md)
- Implementation plan: [`docs/superpowers/plans/2026-06-23-pipeline-launcher-gui.md`](../docs/superpowers/plans/2026-06-23-pipeline-launcher-gui.md)

---

## For end users (colleagues)

You just need the installer — **no R, no admin, no setup beforehand**:

1. Get `MtMessengerPipeline-Setup.exe` (from wherever it was shared — see
   [Distributing](#distributing)).
2. Double-click it. It installs to your own profile (`%LOCALAPPDATA%`) and adds
   a **Mt Messenger Ecology Pipeline** shortcut to the Start menu and desktop.
   No admin, and no R install — R is bundled inside the app.
3. Launch it. Choose **Build data workbook from databases** and browse to the
   two input `.xlsx` databases, **or** choose **Use an existing data workbook**
   and pick a previously built workbook. Pick an **Output folder** (the app
   creates `figures\` and `tables\` inside it, and in build mode writes
   `MtMessengerEcologyData.xlsx` there). Click **Check inputs**, then **Run**.

Your paths are remembered for next time.

---

## For developers / maintainers

### Prerequisites

- **Windows 10/11** with **Windows PowerShell 5.1** (built in — `powershell.exe`).
- **Inno Setup 6** — to compile the installer (see below).
- **A matching R install + internet — to BUILD** (not to test). The build copies
  an installed R whose major.minor matches `DESCRIPTION`'s `Config/R/Version`
  (currently `4.5`, e.g. `R-4.5.3`) into the bundle and downloads the project's
  packages into it. Install that R first (e.g. `winget install --id RProject.R`),
  or point the build at one with `$env:LAUNCHER_R_HOME`.
- **The Pester suite needs neither R nor internet** — it tests pure functions and
  shells out to `cmd.exe`; Pester 5 auto-installs on first run.

### Install Inno Setup

```powershell
winget install --id JRSoftware.InnoSetup -e --accept-source-agreements --accept-package-agreements
```

This installs **per-user** (no admin) to `%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe`.
(If installed machine-wide it lands in `C:\Program Files (x86)\Inno Setup 6\`.)
Alternatively, download from <https://jrsoftware.org/isdl.php>.

### Run the tests

```powershell
powershell.exe -NoProfile -File launcher\tests\Invoke-Pester.ps1
```

Expect all tests passing (34 at time of writing). The runner installs Pester 5
(and the NuGet provider) for the current user if absent.

### Build the installer

**Quickest — regenerate the `.exe` with one command** (from the repo root):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tasks\build_installer.ps1
```

This runs both steps below and prints the path to the finished installer. Re-run
it after **any** change to `launcher\`, the engine, or the R pipeline — it
re-stages and recompiles from scratch. Needs **R installed + internet** and
**Inno Setup 6** (see Prerequisites above); takes a few minutes. On success it
prints, e.g. `Done. Installer: …\build\MtMessengerPipeline-Setup.exe  (151 MB)`.

---

Under the hood it runs two steps, which you can also do by hand from the repo root.

**1. Stage the app** — `build_launcher.ps1` copies the launcher + engine + a
code-only copy of the pipeline into `build\launcher-app\` (excludes `renv`,
`.Rprofile`, tests, generated `src/r/outputs`), **then bundles R**: it copies a
matching installed R into `build\launcher-app\R\` and restores `renv.lock`
into that R's own library (`renv::restore`, Windows binaries). It finds the R
automatically (pinned major.minor, under Program Files or
`%LOCALAPPDATA%\Programs\R`); override with `$env:LAUNCHER_R_HOME`.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tasks\build_launcher.ps1
```

This step needs **R installed + internet** and takes a few minutes (it downloads
all the pipeline's R packages into the bundle).

**2. Compile the installer** with Inno Setup's command-line compiler (`ISCC.exe`):

```powershell
# Locate ISCC wherever winget put it, then compile
$iscc = @(
  (Get-Command ISCC.exe -ErrorAction SilentlyContinue).Source,
  "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
  "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe"
) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1

& $iscc installer\MtMessengerPipeline.iss
```

Output: **`build\MtMessengerPipeline-Setup.exe`** — a per-user installer of
roughly **150 MB** (it embeds R + all packages; ~300 MB once installed).

> Re-run the stage step before compiling after any change to `launcher\`, the
> engine, the R pipeline, or to refresh the bundled R/packages.

### Run it locally without building the installer

After staging, run the staged launcher directly (it uses the bundled `R\` and
`pipeline\` folders beside it, which staging creates):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File build\launcher-app\launcher.ps1
```

Running `launcher\launcher.ps1` straight from the repo opens the window, but with
no bundled `R\`/`pipeline\` beside it, it falls back to a system R (if any) and
**Run/Check fail** without the staged `pipeline\`.

---

## Distributing

The installer installs locally per machine; you only need to put the **single
`.exe`** somewhere recipients can reach:

- **Do** put `MtMessengerPipeline-Setup.exe` on a shared drive everyone has
  mapped (e.g. the `T:` project share), or send it via Teams/email.
- **Don't** put it on a personal drive (e.g. `R:\<you>\...`) others can't open,
  and **don't** run the app itself from a network share — it installs and runs
  locally by design (avoids Mark-of-the-Web / ExecutionPolicy / network-latency
  problems).
- The **input databases stay on `T:`** — the launcher reads them in place; only
  the installer and R move/install locally.

---

## How it works (brief)

- `launcher.ps1` is the **view** (WinForms window + a background runspace so the
  UI stays responsive during the multi-minute run).
- `engine\*.ps1` are pure, unit-tested functions: pick the bundled `Rscript.exe`,
  write a temp `cycle.toml`, pre-flight output paths (incl. Excel-lock), persist
  last-used paths, map exit codes to pass/fail, and run/cancel the process tree.
- A **Run** writes the chosen paths to a temp `cycle.toml`. In *Build* mode it
  invokes `run_pipeline.R` (data workbook → figures + tables); in *Workbook*
  mode it invokes `run_all.R --config` (figures + tables from the selected
  workbook). Both modes now include the report-shaped tables
  (`tables\ReportTables\`), which `run_all.R` renders as its final stage.
  **Check inputs** runs `run_data.R --validate` in Build mode, and a
  quick file check on the workbook in Workbook mode.
- Output is a single folder containing `MtMessengerEcologyData.xlsx` (build
  mode), `figures\`, and `tables\` (including `tables\ReportTables\`). Fish
  trapping figures come from a `Fish` sheet now written into the data workbook.
- The bundled R's library is built at package time by restoring `renv.lock`
  (`renv::restore`, Windows binaries, with the renv cache disabled so the bundle
  gets real copies, not cache symlinks), so the app needs no R install or
  internet at runtime.
- `engine\Provisioning.ps1` (a winget install-on-demand path) is retained and
  tested but **not wired** — see the note at the top of that file.

---

## Notes & caveats

- **Updating the bundled R/packages:** the app always uses its own bundled R, so
  to change the R version or refresh packages, install the new R (matching
  `DESCRIPTION`'s `Config/R/Version`) and **re-run the stage + compile**. Bumping
  the R version means editing `Config/R/Version` in `DESCRIPTION` and refreshing
  `renv.lock` (`renv::snapshot()`) first. Because R is bundled, a different/newer R already on a
  target machine is irrelevant — the app never uses it.
- **Installer size:** ~150 MB (≈300 MB installed) because R + all packages are
  embedded. That is the deliberate trade for "runs anywhere, no admin, no internet."
- **Bundle completeness:** the build installs packages into the bundle with the
  library path isolated from the build machine's own R library (`R_LIBS_USER`/
  `R_LIBS_SITE`), so every transitive dependency is included. Without that, deps
  already present on the build machine are skipped and the app fails on clean
  machines (the "openxlsx not available" class of bug).
- **SmartScreen / antivirus:** the installer is unsigned, so SmartScreen may warn
  ("unrecognized app") until reputation accrues. For internal use, distribute
  from a trusted location and/or have IT allow-list it; code-signing is the
  durable fix if you distribute widely.
- **CI:** `.github/workflows/launcher-tests.yml` runs the Pester suite on
  `windows-latest` for changes under `launcher\**`.
- **Smoke-test before a wide rollout:** run the installed app on a machine that
  has **no R** to confirm the bundled R runs the pipeline end-to-end.
