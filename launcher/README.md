# Mt Messenger Pipeline Launcher

A Windows "click-to-run" GUI for the Mt Messenger R ecology pipeline. The user
picks the two input databases and the three output locations, clicks **Run**,
and the launcher runs the bundled R pipeline and streams progress. On a machine
without R, it installs R per-user (no admin) on first launch.

- Design: [`docs/superpowers/specs/2026-06-23-pipeline-launcher-gui-design.md`](../docs/superpowers/specs/2026-06-23-pipeline-launcher-gui-design.md)
- Implementation plan: [`docs/superpowers/plans/2026-06-23-pipeline-launcher-gui.md`](../docs/superpowers/plans/2026-06-23-pipeline-launcher-gui.md)

---

## For end users (colleagues)

You just need the installer — **no R, no admin, no setup beforehand**:

1. Get `MtMessengerPipeline-Setup.exe` (from wherever it was shared — see
   [Distributing](#distributing)).
2. Double-click it. It installs to your own profile (`%LOCALAPPDATA%`) and adds
   a **Mt Messenger Ecology Pipeline** shortcut to the Start menu and desktop.
3. Launch it. If R isn't installed, you'll see a **First-time setup** panel —
   click **Start setup** (one-time, a few minutes, needs internet; no admin).
4. Browse to the two input `.xlsx` databases and the three output locations,
   click **Check inputs** to validate, then **Run**.

Your paths are remembered for next time.

---

## For developers / maintainers

### Prerequisites

- **Windows 10/11** with **Windows PowerShell 5.1** (built in — `powershell.exe`).
- **Inno Setup 6** — only needed to *build the installer* (see below).
- **R is NOT required to build or test.** The test suite covers pure PowerShell
  functions and shells out to `cmd.exe`; Pester 5 is installed automatically by
  the test runner on first use.

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

Two steps, run from the repo root.

**1. Stage the app folder** — copies the launcher + engine + a code-only copy of
the R pipeline into `build\launcher-app\` (excludes `renv`, `.Rprofile`, tests,
and generated `src/r/outputs`):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tasks\build_launcher.ps1
```

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

Output: **`build\MtMessengerPipeline-Setup.exe`** (~2 MB, per-user installer).

> Always **re-run the stage step before compiling** after any change to
> `launcher\`, the engine, or the R pipeline — the installer packages whatever is
> in `build\launcher-app\`.

### Run it locally without building the installer

After staging, run the staged launcher directly (it needs the `pipeline\` folder
beside it, which staging creates):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File build\launcher-app\launcher.ps1
```

Running `launcher\launcher.ps1` straight from the repo will open the window but
**Run/Check will fail** — the pipeline copy only exists in the staged folder.

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
- `engine\*.ps1` are pure, unit-tested functions: locate `Rscript.exe`, write a
  temp `cycle.toml`, pre-flight output paths (incl. Excel-lock), persist
  last-used paths, map exit codes to pass/fail, run/cancel the process, and
  provision R via winget.
- A **Run** writes the 5 paths to a temp `cycle.toml` and invokes the bundled
  `src\r\run_pipeline.R`; **Check inputs** runs `run_data.R --validate`.
- First-run setup uses the repo's own `scripts\sync_r_packages.R` (a dated Posit
  Package Manager snapshot — Windows binaries, no compiler) after winget installs R.

---

## Notes & caveats

- **R version:** the launcher installs the newest R matching the pinned
  major.minor in `DESCRIPTION` (`Config/R/Version`, currently `4.5`). Confirm a
  matching build exists in winget before a rollout:
  `winget show --id RProject.R --versions`.
- **Pre-existing newer R:** if a target machine already has a newer R (e.g. 4.6+)
  installed for other work, the launcher resolves to the newest R it finds and
  the pipeline's version gate will stop. The auto-setup only helps when R is
  *absent*.
- **SmartScreen / antivirus:** the installer is unsigned, so SmartScreen may warn
  ("unrecognized app") until reputation accrues. For internal use, distribute
  from a trusted location and/or have IT allow-list it; code-signing is the
  durable fix if you distribute widely.
- **CI:** `.github/workflows/launcher-tests.yml` runs the Pester suite on
  `windows-latest` for changes under `launcher\**`.
- **Not yet validated on a clean machine:** the live GUI run and the first-run
  winget R install should be smoke-tested on a machine without R before a wider
  rollout.
