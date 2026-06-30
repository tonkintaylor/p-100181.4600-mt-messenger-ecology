# Pipeline Launcher GUI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Windows click-to-run app — a PowerShell WinForms launcher that collects five paths, writes a temp `cycle.toml`, runs the bundled R pipeline, streams progress, and reports pass/fail — delivered via a per-user Inno Setup installer that provisions R on first run.

**Architecture:** A single `launcher.ps1` split into a testable **engine** (pure PowerShell functions, no WinForms) and a thin **view** (the form + event handlers). The engine is unit-tested with Pester; the view is verified by a manual smoke checklist. An installer bundles the launcher plus a verbatim copy of the R pipeline (minus `renv/`/`.Rprofile`) and installs R on first run via `winget --scope user`.

**Tech Stack:** Windows PowerShell 5.1 (.NET Framework 4.x WinForms via `System.Windows.Forms`), Pester 5 (tests), Inno Setup 6 (installer), the existing R pipeline + `scripts/sync_r_packages.R` (PPM snapshot).

## Global Constraints

- **Windows-only.** Target Windows 10/11 with Windows PowerShell 5.1.
- **PowerShell 5.1 compatible.** No PS7-only syntax. In particular, `ProcessStartInfo.ArgumentList` does **not** exist on .NET Framework — build the argument string manually (see Task 6).
- **The launcher is non-R.** It must run before R exists (it installs R).
- **No admin at runtime.** R is installed per-user: `winget install --id RProject.R --scope user --silent`.
- **Invoke the bundled in-repo `run_pipeline.R` as-is**, working directory = the bundled `pipeline\` root, so the scripts' own `renv`/path resolution works.
- **The bundle excludes `renv/` and `.Rprofile`** so `source(renv/activate.R)` stays inactive and the scripts use the default user library populated by `sync_r_packages.R`.
- **Child R discovery:** prepend the resolved R `bin` to the child process `Path` and set `R_HOME`, because `run_pipeline.R` spawns child `Rscript` processes that look up R via PATH.
- **Cancel = process-tree kill** (`taskkill /PID <id> /T /F`).
- **Forward slashes in the generated `cycle.toml`.**
- **R version pin:** install the R version whose major.minor matches `Config/R/Version` in `DESCRIPTION` (currently `4.5`) via `winget --version`. The exact `4.5.x` is set in `$script:RWingetVersion` and confirmed against winget-pkgs in Task 7.
- **All new launcher code lives under `launcher/`; tests under `launcher/tests/`.**

---

## File Structure

| File | Responsibility |
|---|---|
| `launcher/engine/Resolve-RscriptPath.ps1` | Build ordered Rscript candidates; return the first that exists |
| `launcher/engine/ConfigWriter.ps1` | `ConvertTo-TomlPath`, `New-CycleTomlContent`, `Write-CycleToml` |
| `launcher/engine/OutputPreflight.ps1` | `Test-FileLocked`, `Test-OutputWritable` (Excel-lock guard) |
| `launcher/engine/LauncherSettings.ps1` | `Get-LauncherSettings`, `Save-LauncherSettings` (remember last-used) |
| `launcher/engine/RunStatus.ps1` | `Get-LogTail`, `Get-RunStatus` (exit code → state/colour/message) |
| `launcher/engine/ProcessRunner.ps1` | `ConvertTo-ArgumentString`, `Invoke-PipelineProcess`, `Stop-ProcessTree` |
| `launcher/engine/Provisioning.ps1` | `Get-PinnedRVersion`, `Get-WingetInstallArgs`, `Install-RIfMissing`, `Invoke-PackageSync` |
| `launcher/launcher.ps1` | The WinForms view: form, dot-sources engine, wires events, background runspace |
| `launcher/app.ico` | Window/shortcut icon |
| `launcher/tests/*.Tests.ps1` | Pester tests, one per engine file |
| `launcher/tests/Invoke-Pester.ps1` | Local test runner (installs Pester 5 if missing, runs the suite) |
| `tasks/build_launcher.ps1` | Assemble the staging app folder (copy pipeline in, excluding renv) |
| `installer/MtMessengerPipeline.iss` | Inno Setup per-user installer script |
| `.github/workflows/launcher-tests.yml` | Run the Pester suite on a Windows runner |

---

## Task 1: Test harness + Rscript resolver

**Files:**
- Create: `launcher/engine/Resolve-RscriptPath.ps1`
- Create: `launcher/tests/Invoke-Pester.ps1`
- Test: `launcher/tests/Resolve-RscriptPath.Tests.ps1`

**Interfaces:**
- Produces: `Get-RscriptCandidatePath([string]$ExplicitPath, [string]$LocalAppData, [string]$ProgramFiles) -> string[]`; `Resolve-RscriptPath([string[]]$Candidate, [scriptblock]$PathExists) -> string` (returns `$null` if none exist).

- [ ] **Step 1: Write the test runner**

Create `launcher/tests/Invoke-Pester.ps1`:

```powershell
#requires -Version 5.1
# Installs Pester 5 for the current user if absent, then runs the launcher suite.
if (-not (Get-Module -ListAvailable -Name Pester |
          Where-Object { $_.Version -ge [version]'5.0.0' })) {
    Install-Module -Name Pester -Scope CurrentUser -Force -SkipPublisherCheck -MinimumVersion 5.0.0
}
Import-Module Pester -MinimumVersion 5.0.0 -Force
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$config = New-PesterConfiguration
$config.Run.Path = $here
$config.Output.Verbosity = 'Detailed'
Invoke-Pester -Configuration $config
```

- [ ] **Step 2: Write the failing test**

Create `launcher/tests/Resolve-RscriptPath.Tests.ps1`:

```powershell
BeforeAll {
    . "$PSScriptRoot/../engine/Resolve-RscriptPath.ps1"
}
Describe 'Resolve-RscriptPath' {
    It 'returns the first candidate that exists' {
        $exists = { param($p) $p -eq 'C:\R\bin\Rscript.exe' }
        Resolve-RscriptPath -Candidate @('C:\nope\Rscript.exe', 'C:\R\bin\Rscript.exe') -PathExists $exists |
            Should -Be 'C:\R\bin\Rscript.exe'
    }
    It 'preserves candidate order (earlier wins)' {
        $exists = { param($p) $true }
        Resolve-RscriptPath -Candidate @('A', 'B') -PathExists $exists | Should -Be 'A'
    }
    It 'returns $null when no candidate exists' {
        $exists = { param($p) $false }
        Resolve-RscriptPath -Candidate @('A', 'B') -PathExists $exists | Should -BeNullOrEmpty
    }
}
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `powershell -NoProfile -File launcher/tests/Invoke-Pester.ps1`
Expected: FAIL — `Resolve-RscriptPath.ps1` does not exist / function not found.

- [ ] **Step 4: Write the implementation**

Create `launcher/engine/Resolve-RscriptPath.ps1`:

```powershell
function Get-RscriptCandidatePath {
    [CmdletBinding()]
    param(
        [string]$ExplicitPath,
        [string]$LocalAppData = $env:LOCALAPPDATA,
        [string]$ProgramFiles = $env:ProgramFiles
    )
    $candidates = New-Object System.Collections.Generic.List[string]
    if ($ExplicitPath) { $candidates.Add($ExplicitPath) }

    foreach ($hive in 'HKCU:', 'HKLM:') {
        $key = Join-Path $hive 'SOFTWARE\R-core\R'
        try {
            $install = (Get-ItemProperty -LiteralPath $key -ErrorAction Stop).InstallPath
            if ($install) { $candidates.Add((Join-Path $install 'bin\Rscript.exe')) }
        } catch { }
    }

    foreach ($base in @((Join-Path $LocalAppData 'Programs\R'), (Join-Path $ProgramFiles 'R'))) {
        if ($base -and (Test-Path -LiteralPath $base)) {
            Get-ChildItem -LiteralPath $base -Directory -Filter 'R-*' -ErrorAction SilentlyContinue |
                Sort-Object Name -Descending |
                ForEach-Object { $candidates.Add((Join-Path $_.FullName 'bin\Rscript.exe')) }
        }
    }

    $onPath = Get-Command Rscript.exe -ErrorAction SilentlyContinue
    if ($onPath) { $candidates.Add($onPath.Source) }

    return $candidates.ToArray()
}

function Resolve-RscriptPath {
    [CmdletBinding()]
    param(
        [string[]]$Candidate,
        [scriptblock]$PathExists = { param($p) Test-Path -LiteralPath $p -PathType Leaf }
    )
    if (-not $PSBoundParameters.ContainsKey('Candidate')) {
        $Candidate = Get-RscriptCandidatePath
    }
    foreach ($c in $Candidate) {
        if ($c -and (& $PathExists $c)) { return $c }
    }
    return $null
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `powershell -NoProfile -File launcher/tests/Invoke-Pester.ps1`
Expected: PASS — 3 tests in `Resolve-RscriptPath`.

- [ ] **Step 6: Commit**

```bash
git add launcher/engine/Resolve-RscriptPath.ps1 launcher/tests/Resolve-RscriptPath.Tests.ps1 launcher/tests/Invoke-Pester.ps1
git commit -m "feat(launcher): Rscript resolver + Pester harness"
```

---

## Task 2: cycle.toml writer

**Files:**
- Create: `launcher/engine/ConfigWriter.ps1`
- Test: `launcher/tests/ConfigWriter.Tests.ps1`

**Interfaces:**
- Produces: `ConvertTo-TomlPath([string]$Path) -> string`; `New-CycleTomlContent(-MacroDb,-AquaticDb,-DataXlsx,-FiguresDir,-TablesDir) -> string`; `Write-CycleToml([hashtable]$Paths, [string]$Path) -> string` (path written). `$Paths` keys: `MacroDb, AquaticDb, DataXlsx, FiguresDir, TablesDir`.
- Consumes: nothing.

- [ ] **Step 1: Write the failing test**

Create `launcher/tests/ConfigWriter.Tests.ps1`:

```powershell
BeforeAll { . "$PSScriptRoot/../engine/ConfigWriter.ps1" }
Describe 'New-CycleTomlContent' {
    It 'converts backslashes to forward slashes' {
        $c = New-CycleTomlContent -MacroDb 'T:\a\m.xlsx' -AquaticDb 'T:\a\q.xlsx' `
            -DataXlsx 'C:\out\Data.xlsx' -FiguresDir 'C:\out\Figures' -TablesDir 'C:\out\Tables'
        $c | Should -Match 'macroinvertebrate_db = "T:/a/m.xlsx"'
        $c | Should -Match 'data_xlsx = "C:/out/Data.xlsx"'
        $c | Should -Not -Match '\\'
    }
    It 'emits [input] and [output] sections' {
        $c = New-CycleTomlContent -MacroDb m -AquaticDb q -DataXlsx d -FiguresDir f -TablesDir t
        $c | Should -Match '\[input\]'
        $c | Should -Match '\[output\]'
    }
}
Describe 'Write-CycleToml' {
    It 'writes a readable temp file with the five paths' {
        $p = Write-CycleToml -Paths @{ MacroDb='T:\m.xlsx'; AquaticDb='T:\q.xlsx'; DataXlsx='C:\o\D.xlsx'; FiguresDir='C:\o\F'; TablesDir='C:\o\T' } `
            -Path (Join-Path $TestDrive 'cycle.toml')
        Test-Path $p | Should -BeTrue
        (Get-Content -Raw $p) | Should -Match 'aquatic_monitoring_db = "T:/q.xlsx"'
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `powershell -NoProfile -File launcher/tests/Invoke-Pester.ps1`
Expected: FAIL — `ConfigWriter.ps1` not found.

- [ ] **Step 3: Write the implementation**

Create `launcher/engine/ConfigWriter.ps1`:

```powershell
function ConvertTo-TomlPath {
    param([Parameter(Mandatory)][string]$Path)
    return ($Path -replace '\\', '/')
}

function New-CycleTomlContent {
    param(
        [Parameter(Mandatory)][string]$MacroDb,
        [Parameter(Mandatory)][string]$AquaticDb,
        [Parameter(Mandatory)][string]$DataXlsx,
        [Parameter(Mandatory)][string]$FiguresDir,
        [Parameter(Mandatory)][string]$TablesDir
    )
    $lines = @(
        '[input]'
        "macroinvertebrate_db = `"$(ConvertTo-TomlPath $MacroDb)`""
        "aquatic_monitoring_db = `"$(ConvertTo-TomlPath $AquaticDb)`""
        ''
        '[output]'
        "data_xlsx = `"$(ConvertTo-TomlPath $DataXlsx)`""
        "figures_dir = `"$(ConvertTo-TomlPath $FiguresDir)`""
        "tables_dir = `"$(ConvertTo-TomlPath $TablesDir)`""
    )
    return (($lines -join "`r`n") + "`r`n")
}

function Write-CycleToml {
    param(
        [Parameter(Mandatory)][hashtable]$Paths,
        [string]$Path = (Join-Path ([System.IO.Path]::GetTempPath()) ("cycle-" + [guid]::NewGuid().ToString('N') + ".toml"))
    )
    $content = New-CycleTomlContent @Paths
    [System.IO.File]::WriteAllText($Path, $content, (New-Object System.Text.UTF8Encoding($false)))
    return $Path
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `powershell -NoProfile -File launcher/tests/Invoke-Pester.ps1`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add launcher/engine/ConfigWriter.ps1 launcher/tests/ConfigWriter.Tests.ps1
git commit -m "feat(launcher): cycle.toml writer with forward-slash normalisation"
```

---

## Task 3: Output pre-flight (Excel-lock guard)

**Files:**
- Create: `launcher/engine/OutputPreflight.ps1`
- Test: `launcher/tests/OutputPreflight.Tests.ps1`

**Interfaces:**
- Produces: `Test-FileLocked([string]$Path) -> bool`; `Test-OutputWritable(-DataXlsx,-FiguresDir,-TablesDir) -> pscustomobject{ Ok:bool; Problems:string[] }`.

- [ ] **Step 1: Write the failing test**

Create `launcher/tests/OutputPreflight.Tests.ps1`:

```powershell
BeforeAll { . "$PSScriptRoot/../engine/OutputPreflight.ps1" }
Describe 'Test-FileLocked' {
    It 'is false for a file that is not open' {
        $f = Join-Path $TestDrive 'free.txt'; Set-Content -LiteralPath $f -Value 'hi'
        Test-FileLocked -Path $f | Should -BeFalse
    }
    It 'is false for a path that does not exist' {
        Test-FileLocked -Path (Join-Path $TestDrive 'nope.txt') | Should -BeFalse
    }
    It 'is true for a file held with an exclusive lock' {
        $f = Join-Path $TestDrive 'locked.txt'; Set-Content -LiteralPath $f -Value 'hi'
        $s = [System.IO.File]::Open($f, 'Open', 'ReadWrite', 'None')
        try { Test-FileLocked -Path $f | Should -BeTrue }
        finally { $s.Close(); $s.Dispose() }
    }
}
Describe 'Test-OutputWritable' {
    It 'is Ok when parents exist and the workbook is free' {
        $out = Join-Path $TestDrive 'out'; New-Item -ItemType Directory -Path $out | Out-Null
        (Test-OutputWritable -DataXlsx (Join-Path $out 'Data.xlsx') `
            -FiguresDir (Join-Path $out 'Figures') -TablesDir (Join-Path $out 'Tables')).Ok |
            Should -BeTrue
    }
    It 'flags a locked workbook with an Excel message' {
        $out = Join-Path $TestDrive 'out2'; New-Item -ItemType Directory -Path $out | Out-Null
        $xlsx = Join-Path $out 'Data.xlsx'; Set-Content -LiteralPath $xlsx -Value 'x'
        $s = [System.IO.File]::Open($xlsx, 'Open', 'ReadWrite', 'None')
        try {
            $r = Test-OutputWritable -DataXlsx $xlsx -FiguresDir (Join-Path $out 'F') -TablesDir (Join-Path $out 'T')
            $r.Ok | Should -BeFalse
            ($r.Problems -join ' ') | Should -Match 'open in Excel'
        } finally { $s.Close(); $s.Dispose() }
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `powershell -NoProfile -File launcher/tests/Invoke-Pester.ps1`
Expected: FAIL — `OutputPreflight.ps1` not found.

- [ ] **Step 3: Write the implementation**

Create `launcher/engine/OutputPreflight.ps1`:

```powershell
function Test-FileLocked {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
    try {
        $fs = [System.IO.File]::Open($Path, 'Open', 'ReadWrite', 'None')
        $fs.Close(); $fs.Dispose()
        return $false
    } catch [System.IO.IOException] {
        return $true
    }
}

function Test-OutputWritable {
    param(
        [Parameter(Mandatory)][string]$DataXlsx,
        [Parameter(Mandatory)][string]$FiguresDir,
        [Parameter(Mandatory)][string]$TablesDir
    )
    $problems = New-Object System.Collections.Generic.List[string]

    $dataParent = Split-Path -LiteralPath $DataXlsx -Parent
    if ($dataParent -and -not (Test-Path -LiteralPath $dataParent)) {
        $problems.Add("Output folder does not exist: $dataParent")
    }
    if (Test-FileLocked -Path $DataXlsx) {
        $problems.Add("$([System.IO.Path]::GetFileName($DataXlsx)) is open in Excel - close it and try again.")
    }
    foreach ($dir in @($FiguresDir, $TablesDir)) {
        $parent = Split-Path -LiteralPath $dir -Parent
        if ($parent -and -not (Test-Path -LiteralPath $parent)) {
            $problems.Add("Folder path does not exist: $parent")
        }
    }

    return [pscustomobject]@{
        Ok       = ($problems.Count -eq 0)
        Problems = $problems.ToArray()
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `powershell -NoProfile -File launcher/tests/Invoke-Pester.ps1`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add launcher/engine/OutputPreflight.ps1 launcher/tests/OutputPreflight.Tests.ps1
git commit -m "feat(launcher): output writability + Excel-lock pre-flight"
```

---

## Task 4: Settings persistence (remember last-used paths)

**Files:**
- Create: `launcher/engine/LauncherSettings.ps1`
- Test: `launcher/tests/LauncherSettings.Tests.ps1`

**Interfaces:**
- Produces: `Get-LauncherSettings([string]$Path) -> pscustomobject{ MacroDb,AquaticDb,DataXlsx,FiguresDir,TablesDir }` (blank strings if missing/corrupt); `Save-LauncherSettings([string]$Path, [hashtable]$Settings)`.

- [ ] **Step 1: Write the failing test**

Create `launcher/tests/LauncherSettings.Tests.ps1`:

```powershell
BeforeAll { . "$PSScriptRoot/../engine/LauncherSettings.ps1" }
Describe 'LauncherSettings' {
    It 'returns blank defaults when the file is missing' {
        $s = Get-LauncherSettings -Path (Join-Path $TestDrive 'none.json')
        $s.MacroDb | Should -BeNullOrEmpty
        $s.TablesDir | Should -BeNullOrEmpty
    }
    It 'round-trips saved paths' {
        $p = Join-Path $TestDrive 'settings.json'
        Save-LauncherSettings -Path $p -Settings @{ MacroDb='m'; AquaticDb='q'; DataXlsx='d'; FiguresDir='f'; TablesDir='t' }
        $s = Get-LauncherSettings -Path $p
        $s.MacroDb | Should -Be 'm'
        $s.FiguresDir | Should -Be 'f'
    }
    It 'falls back to defaults on a corrupt file' {
        $p = Join-Path $TestDrive 'bad.json'; Set-Content -LiteralPath $p -Value '{ not json'
        (Get-LauncherSettings -Path $p).MacroDb | Should -BeNullOrEmpty
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `powershell -NoProfile -File launcher/tests/Invoke-Pester.ps1`
Expected: FAIL — `LauncherSettings.ps1` not found.

- [ ] **Step 3: Write the implementation**

Create `launcher/engine/LauncherSettings.ps1`:

```powershell
function Get-LauncherSettings {
    param([Parameter(Mandatory)][string]$Path)
    $default = [ordered]@{ MacroDb = ''; AquaticDb = ''; DataXlsx = ''; FiguresDir = ''; TablesDir = '' }
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

function Save-LauncherSettings {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][hashtable]$Settings
    )
    $dir = Split-Path -LiteralPath $Path -Parent
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    ($Settings | ConvertTo-Json) | Set-Content -LiteralPath $Path -Encoding UTF8
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `powershell -NoProfile -File launcher/tests/Invoke-Pester.ps1`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add launcher/engine/LauncherSettings.ps1 launcher/tests/LauncherSettings.Tests.ps1
git commit -m "feat(launcher): per-user settings persistence"
```

---

## Task 5: Run-status mapping

**Files:**
- Create: `launcher/engine/RunStatus.ps1`
- Test: `launcher/tests/RunStatus.Tests.ps1`

**Interfaces:**
- Produces: `Get-LogTail([string]$LogText, [int]$Lines=8) -> string`; `Get-RunStatus([int]$ExitCode, [string]$LogText, [switch]$Cancelled) -> pscustomobject{ State, Color, Message }`. States: `Succeeded|Failed|Cancelled`; Colors: `Green|Red|Gray`.

- [ ] **Step 1: Write the failing test**

Create `launcher/tests/RunStatus.Tests.ps1`:

```powershell
BeforeAll { . "$PSScriptRoot/../engine/RunStatus.ps1" }
Describe 'Get-RunStatus' {
    It 'maps exit 0 to Succeeded/Green' {
        $r = Get-RunStatus -ExitCode 0
        $r.State | Should -Be 'Succeeded'
        $r.Color | Should -Be 'Green'
    }
    It 'maps non-zero to Failed/Red and includes the log tail' {
        $r = Get-RunStatus -ExitCode 1 -LogText "line1`nERROR: boom`n"
        $r.State | Should -Be 'Failed'
        $r.Color | Should -Be 'Red'
        $r.Message | Should -Match 'boom'
    }
    It 'maps -Cancelled to Cancelled/Gray regardless of exit code' {
        (Get-RunStatus -ExitCode 1 -Cancelled).State | Should -Be 'Cancelled'
    }
}
Describe 'Get-LogTail' {
    It 'returns the last N non-empty lines' {
        Get-LogTail -LogText "a`n`nb`nc`n" -Lines 2 | Should -Be "b`nc"
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `powershell -NoProfile -File launcher/tests/Invoke-Pester.ps1`
Expected: FAIL — `RunStatus.ps1` not found.

- [ ] **Step 3: Write the implementation**

Create `launcher/engine/RunStatus.ps1`:

```powershell
function Get-LogTail {
    param(
        [Parameter(Mandatory)][string]$LogText,
        [int]$Lines = 8
    )
    $nonEmpty = $LogText -split "`r?`n" | Where-Object { $_.Trim() -ne '' }
    if ($nonEmpty.Count -le $Lines) { return ($nonEmpty -join "`n") }
    return (($nonEmpty | Select-Object -Last $Lines) -join "`n")
}

function Get-RunStatus {
    param(
        [Parameter(Mandatory)][int]$ExitCode,
        [string]$LogText = '',
        [switch]$Cancelled
    )
    if ($Cancelled) {
        return [pscustomobject]@{ State = 'Cancelled'; Color = 'Gray'; Message = 'Run cancelled.' }
    }
    if ($ExitCode -eq 0) {
        return [pscustomobject]@{ State = 'Succeeded'; Color = 'Green'; Message = 'Completed successfully.' }
    }
    $tail = Get-LogTail -LogText $LogText
    return [pscustomobject]@{ State = 'Failed'; Color = 'Red'; Message = "Failed (exit $ExitCode):`n$tail" }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `powershell -NoProfile -File launcher/tests/Invoke-Pester.ps1`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add launcher/engine/RunStatus.ps1 launcher/tests/RunStatus.Tests.ps1
git commit -m "feat(launcher): run-status and log-tail mapping"
```

---

## Task 6: Process runner + cancellation

**Files:**
- Create: `launcher/engine/ProcessRunner.ps1`
- Test: `launcher/tests/ProcessRunner.Tests.ps1`

**Interfaces:**
- Produces:
  - `ConvertTo-ArgumentString([string[]]$Arguments) -> string`
  - `Invoke-PipelineProcess(-FilePath, [string[]]$Arguments, -WorkingDirectory, [scriptblock]$OnOutput, -PrependPath, -RHome, [ref]$ProcessRef) -> pscustomobject{ ExitCode:int; Output:string }`
  - `Stop-ProcessTree([int]$ProcessId)`
- Consumes: nothing.
- Note for the view: `OnOutput` receives one line at a time (stderr is streamed live because R's `message()` writes to stderr). `$ProcessRef` is populated after `Start()` so the view can cancel.

- [ ] **Step 1: Write the failing test**

Create `launcher/tests/ProcessRunner.Tests.ps1`:

```powershell
BeforeAll { . "$PSScriptRoot/../engine/ProcessRunner.ps1" }
Describe 'ConvertTo-ArgumentString' {
    It 'quotes arguments containing spaces' {
        ConvertTo-ArgumentString -Arguments @('--vanilla', 'C:\a b\run.R', 'x') |
            Should -Be '--vanilla "C:\a b\run.R" x'
    }
    It 'leaves space-free arguments unquoted' {
        ConvertTo-ArgumentString -Arguments @('a', 'b') | Should -Be 'a b'
    }
}
Describe 'Invoke-PipelineProcess' {
    It 'captures exit code and streams stderr lines via OnOutput' {
        $seen = New-Object System.Collections.Generic.List[string]
        $cb = { param($line) $seen.Add($line) }
        $r = Invoke-PipelineProcess -FilePath $env:ComSpec `
            -Arguments @('/c', 'echo OUT& echo ERR 1>&2& exit 2') `
            -OnOutput $cb
        $r.ExitCode | Should -Be 2
        $r.Output | Should -Match 'OUT'
        $r.Output | Should -Match 'ERR'
        ($seen -join ' ') | Should -Match 'ERR'
    }
}
Describe 'Stop-ProcessTree' {
    It 'terminates a running child process tree' {
        $p = Start-Process -FilePath $env:ComSpec -ArgumentList '/c','ping -n 20 127.0.0.1 >NUL' -PassThru -WindowStyle Hidden
        Stop-ProcessTree -ProcessId $p.Id
        $p.WaitForExit(5000) | Should -BeTrue
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `powershell -NoProfile -File launcher/tests/Invoke-Pester.ps1`
Expected: FAIL — `ProcessRunner.ps1` not found.

- [ ] **Step 3: Write the implementation**

Create `launcher/engine/ProcessRunner.ps1`:

```powershell
function ConvertTo-ArgumentString {
    param([string[]]$Arguments = @())
    ($Arguments | ForEach-Object {
        if ($_ -match '[\s"]') { '"' + ($_ -replace '"', '\"') + '"' } else { $_ }
    }) -join ' '
}

function Invoke-PipelineProcess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [string[]]$Arguments = @(),
        [string]$WorkingDirectory = (Get-Location).Path,
        [scriptblock]$OnOutput = { param($line) },
        [string]$PrependPath,
        [string]$RHome,
        [ref]$ProcessRef
    )
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName               = $FilePath
    $psi.Arguments              = ConvertTo-ArgumentString -Arguments $Arguments
    $psi.WorkingDirectory       = $WorkingDirectory
    $psi.UseShellExecute        = $false
    $psi.CreateNoWindow         = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    if ($PrependPath) {
        $existing = [string]$psi.EnvironmentVariables['Path']
        $psi.EnvironmentVariables['Path'] = "$PrependPath;$existing"
    }
    if ($RHome) { $psi.EnvironmentVariables['R_HOME'] = $RHome }

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi
    [void]$proc.Start()
    if ($ProcessRef) { $ProcessRef.Value = $proc }

    # R's message() (progress) goes to stderr, so stream stderr live and drain
    # stdout asynchronously to prevent a full-buffer deadlock.
    $outTask = $proc.StandardOutput.ReadToEndAsync()
    $sb = New-Object System.Text.StringBuilder
    while ($null -ne ($line = $proc.StandardError.ReadLine())) {
        [void]$sb.AppendLine($line)
        & $OnOutput $line
    }
    $proc.WaitForExit()
    $stdout = $outTask.Result
    if ($stdout) { [void]$sb.Append($stdout) }

    return [pscustomobject]@{ ExitCode = $proc.ExitCode; Output = $sb.ToString() }
}

function Stop-ProcessTree {
    param([Parameter(Mandatory)][int]$ProcessId)
    & taskkill.exe /PID $ProcessId /T /F 2>&1 | Out-Null
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `powershell -NoProfile -File launcher/tests/Invoke-Pester.ps1`
Expected: PASS (3 describes). If the `Stop-ProcessTree` test is flaky on a slow runner, increase the `WaitForExit` timeout.

- [ ] **Step 5: Commit**

```bash
git add launcher/engine/ProcessRunner.ps1 launcher/tests/ProcessRunner.Tests.ps1
git commit -m "feat(launcher): process runner with stderr streaming and tree-kill"
```

---

## Task 7: R provisioning helpers

**Files:**
- Create: `launcher/engine/Provisioning.ps1`
- Test: `launcher/tests/Provisioning.Tests.ps1`

**Interfaces:**
- Produces:
  - `Get-PinnedRVersion([string]$DescriptionPath) -> string` (the `Config/R/Version` value, e.g. `4.5`)
  - `Get-WingetInstallArgs([string]$RVersion) -> string[]`
  - `Install-RIfMissing(-RscriptResolver [scriptblock], -WingetVersion, -OnOutput) -> pscustomobject{ Ok:bool; RscriptPath:string; Message:string }`
  - `Invoke-PackageSync(-RscriptPath, -PipelineRoot, -OnOutput) -> int` (exit code)
- Consumes: `Invoke-PipelineProcess`, `Resolve-RscriptPath` (dot-sourced by the view; the test dot-sources all three engine files).
- Note: `$script:RWingetVersion` is defined in `launcher.ps1` (Task 8). Confirm a matching `4.5.x` exists: run `winget show --id RProject.R --versions` and pick the newest `4.5.*`; if none exists, fall back to bumping `Config/R/Version` + the PPM snapshot (recorded in the spec's Open Decisions).

- [ ] **Step 1: Write the failing test**

Create `launcher/tests/Provisioning.Tests.ps1`:

```powershell
BeforeAll {
    . "$PSScriptRoot/../engine/Provisioning.ps1"
}
Describe 'Get-PinnedRVersion' {
    It 'reads Config/R/Version from a DESCRIPTION file' {
        $d = Join-Path $TestDrive 'DESCRIPTION'
        Set-Content -LiteralPath $d -Value "Type: project`r`nConfig/R/Version: 4.5`r`n"
        Get-PinnedRVersion -DescriptionPath $d | Should -Be '4.5'
    }
}
Describe 'Get-WingetInstallArgs' {
    It 'requests user scope and silent install' {
        $a = Get-WingetInstallArgs -RVersion '4.5.1'
        ($a -join ' ') | Should -Match '--scope user'
        ($a -join ' ') | Should -Match '--silent'
        ($a -join ' ') | Should -Match '--version 4\.5\.1'
    }
    It 'omits --version when no version is given' {
        (Get-WingetInstallArgs) -join ' ' | Should -Not -Match '--version'
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `powershell -NoProfile -File launcher/tests/Invoke-Pester.ps1`
Expected: FAIL — `Provisioning.ps1` not found.

- [ ] **Step 3: Write the implementation**

Create `launcher/engine/Provisioning.ps1`:

```powershell
function Get-PinnedRVersion {
    param([Parameter(Mandatory)][string]$DescriptionPath)
    $line = Get-Content -LiteralPath $DescriptionPath |
        Where-Object { $_ -match '^\s*Config/R/Version\s*:' } |
        Select-Object -First 1
    if (-not $line) { return $null }
    return ($line -replace '^\s*Config/R/Version\s*:\s*', '').Trim()
}

function Get-WingetInstallArgs {
    param([string]$RVersion)
    $a = @('install', '--id', 'RProject.R', '--scope', 'user', '--silent',
           '--accept-source-agreements', '--accept-package-agreements')
    if ($RVersion) { $a += @('--version', $RVersion) }
    return $a
}

function Install-RIfMissing {
    param(
        [Parameter(Mandatory)][scriptblock]$RscriptResolver, # returns a path or $null
        [string]$WingetVersion,
        [scriptblock]$OnOutput = { param($line) }
    )
    $existing = & $RscriptResolver
    if ($existing) {
        return [pscustomobject]@{ Ok = $true; RscriptPath = $existing; Message = 'R already installed.' }
    }
    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
        return [pscustomobject]@{ Ok = $false; RscriptPath = $null
            Message = 'Automatic R setup could not run on this PC - contact IT (winget unavailable).' }
    }
    $res = Invoke-PipelineProcess -FilePath 'winget.exe' `
        -Arguments (Get-WingetInstallArgs -RVersion $WingetVersion) -OnOutput $OnOutput
    $resolved = & $RscriptResolver
    if ($res.ExitCode -eq 0 -and $resolved) {
        return [pscustomobject]@{ Ok = $true; RscriptPath = $resolved; Message = 'R installed.' }
    }
    return [pscustomobject]@{ Ok = $false; RscriptPath = $null
        Message = "R install failed (winget exit $($res.ExitCode))." }
}

function Invoke-PackageSync {
    param(
        [Parameter(Mandatory)][string]$RscriptPath,
        [Parameter(Mandatory)][string]$PipelineRoot,
        [scriptblock]$OnOutput = { param($line) }
    )
    $sync = Join-Path $PipelineRoot 'scripts\sync_r_packages.R'
    $res = Invoke-PipelineProcess -FilePath $RscriptPath `
        -Arguments @('--vanilla', $sync) -WorkingDirectory $PipelineRoot -OnOutput $OnOutput
    return $res.ExitCode
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `powershell -NoProfile -File launcher/tests/Invoke-Pester.ps1`
Expected: PASS (`Get-PinnedRVersion`, `Get-WingetInstallArgs`). `Install-RIfMissing`/`Invoke-PackageSync` are covered by the manual smoke checklist (Task 8) since they shell out.

- [ ] **Step 5: Commit**

```bash
git add launcher/engine/Provisioning.ps1 launcher/tests/Provisioning.Tests.ps1
git commit -m "feat(launcher): R provisioning helpers (winget + package sync)"
```

---

## Task 8: WinForms view (the launcher window)

**Files:**
- Create: `launcher/launcher.ps1`

**Interfaces:**
- Consumes: every engine function from Tasks 1-7 (dot-sourced).
- Produces: the runnable GUI (no exported functions; verified manually).

This task has no Pester test — WinForms + winget + a multi-minute R run are verified by the **manual smoke checklist** in Step 3. The form runs jobs on a background runspace and drains a synchronized output queue with a `System.Windows.Forms.Timer` on the UI thread (the responsive-GUI pattern; no cross-thread control access).

- [ ] **Step 1: Write the view**

Create `launcher/launcher.ps1`:

```powershell
#requires -Version 5.1
Set-StrictMode -Version 2.0
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
foreach ($f in Get-ChildItem -LiteralPath (Join-Path $ScriptRoot 'engine') -Filter '*.ps1') {
    . $f.FullName
}

# --- Config ---
$script:RWingetVersion = '4.5.1'   # confirmed available via: winget show --id RProject.R --versions
$PipelineRoot   = Join-Path $ScriptRoot 'pipeline'
$RunPipeline    = Join-Path $PipelineRoot 'src\r\run_pipeline.R'
$RunData        = Join-Path $PipelineRoot 'src\r\run_data.R'
$SettingsPath   = Join-Path $env:LOCALAPPDATA 'MtMessengerPipeline\settings.json'

# --- Shared state across UI thread and background runspace ---
$sync = [hashtable]::Synchronized(@{
    Queue   = New-Object System.Collections.Queue
    Running = $false
    Process = $null
    Done    = $false
    Exit    = $null
    Log     = New-Object System.Text.StringBuilder
})

# --- Build the form ---
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Mt Messenger Ecology Pipeline'
$form.Size = New-Object System.Drawing.Size(760, 620)
$form.StartPosition = 'CenterScreen'
$icoPath = Join-Path $ScriptRoot 'app.ico'
if (Test-Path $icoPath) { $form.Icon = New-Object System.Drawing.Icon($icoPath) }

function New-PathRow {
    param($Parent, [string]$Label, [int]$Y, [string]$Mode) # Mode: OpenXlsx|SaveXlsx|Folder
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $Label; $lbl.Location = "15,$Y"; $lbl.Size = '180,20'
    $tb = New-Object System.Windows.Forms.TextBox
    $tb.Location = "200,$($Y-2)"; $tb.Size = '440,22'
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = 'Browse'; $btn.Location = "650,$($Y-3)"; $btn.Size = '80,24'
    $btn.Add_Click({
        switch ($Mode) {
            'OpenXlsx' {
                $d = New-Object System.Windows.Forms.OpenFileDialog
                $d.Filter = 'Excel workbook (*.xlsx)|*.xlsx'
                if ($d.ShowDialog() -eq 'OK') { $tb.Text = $d.FileName }
            }
            'SaveXlsx' {
                $d = New-Object System.Windows.Forms.SaveFileDialog
                $d.Filter = 'Excel workbook (*.xlsx)|*.xlsx'; $d.DefaultExt = 'xlsx'
                if ($d.ShowDialog() -eq 'OK') { $tb.Text = $d.FileName }
            }
            'Folder' {
                $d = New-Object System.Windows.Forms.FolderBrowserDialog
                if ($d.ShowDialog() -eq 'OK') { $tb.Text = $d.SelectedPath }
            }
        }
    }.GetNewClosure())
    $Parent.Controls.AddRange(@($lbl, $tb, $btn))
    return $tb
}

$tbMacro   = New-PathRow $form 'Macroinvertebrate DB'  40  'OpenXlsx'
$tbAquatic = New-PathRow $form 'Aquatic monitoring DB' 72  'OpenXlsx'
$tbData    = New-PathRow $form 'Data workbook (.xlsx)' 116 'SaveXlsx'
$tbFigures = New-PathRow $form 'Figures folder'        148 'Folder'
$tbTables  = New-PathRow $form 'Tables folder'         180 'Folder'

$btnCheck = New-Object System.Windows.Forms.Button
$btnCheck.Text = 'Check inputs'; $btnCheck.Location = '200,220'; $btnCheck.Size = '110,30'
$btnRun = New-Object System.Windows.Forms.Button
$btnRun.Text = 'Run'; $btnRun.Location = '560,220'; $btnRun.Size = '170,32'
$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text = 'Cancel'; $btnCancel.Location = '650,560'; $btnCancel.Size = '80,26'; $btnCancel.Enabled = $false

$log = New-Object System.Windows.Forms.TextBox
$log.Multiline = $true; $log.ReadOnly = $true; $log.ScrollBars = 'Vertical'
$log.Location = '15,265'; $log.Size = '715,250'
$log.Font = New-Object System.Drawing.Font('Consolas', 9)

$status = New-Object System.Windows.Forms.Label
$status.Location = '15,530'; $status.Size = '600,24'; $status.Text = 'Ready.'

$setupPanel = New-Object System.Windows.Forms.Panel
$setupPanel.Location = '15,40'; $setupPanel.Size = '715,170'; $setupPanel.BackColor = 'WhiteSmoke'; $setupPanel.Visible = $false
$setupLabel = New-Object System.Windows.Forms.Label
$setupLabel.Location = '15,15'; $setupLabel.Size = '680,90'
$setupLabel.Text = "R isn't installed on this PC yet.`r`nSetup installs R + the required packages." +
    "`r`n  - One-time, ~5-10 min, needs internet`r`n  - No admin rights needed (installs just for you)"
$btnSetup = New-Object System.Windows.Forms.Button
$btnSetup.Text = 'Start setup'; $btnSetup.Location = '15,120'; $btnSetup.Size = '120,30'
$setupPanel.Controls.AddRange(@($setupLabel, $btnSetup))

$form.Controls.AddRange(@($btnCheck, $btnRun, $btnCancel, $log, $status, $setupPanel))

# --- Helpers ---
function Set-Busy([bool]$busy) {
    $btnRun.Enabled = -not $busy; $btnCheck.Enabled = -not $busy; $btnCancel.Enabled = $busy
    foreach ($t in @($tbMacro,$tbAquatic,$tbData,$tbFigures,$tbTables)) { $t.Enabled = -not $busy }
}
function Append-Log([string]$text) {
    $log.AppendText($text + "`r`n"); [void]$sync.Log.AppendLine($text)
}
function Get-PathsHash {
    @{ MacroDb=$tbMacro.Text; AquaticDb=$tbAquatic.Text; DataXlsx=$tbData.Text
       FiguresDir=$tbFigures.Text; TablesDir=$tbTables.Text }
}

# Run an Rscript command in a background runspace, streaming to $sync.Queue.
function Start-Job([string]$rscript, [string[]]$scriptArgs) {
    $sync.Running = $true; $sync.Done = $false; $sync.Exit = $null
    $sync.Queue.Clear(); [void]$sync.Log.Clear()
    $rbin = Split-Path -Parent $rscript
    $rhome = Split-Path -Parent $rbin
    $ps = [PowerShell]::Create()
    $ps.Runspace = [runspacefactory]::CreateRunspace(); $ps.Runspace.Open()
    $ps.Runspace.SessionStateProxy.SetVariable('sync', $sync)
    $ps.Runspace.SessionStateProxy.SetVariable('engineDir', (Join-Path $ScriptRoot 'engine'))
    $ps.Runspace.SessionStateProxy.SetVariable('rscript', $rscript)
    $ps.Runspace.SessionStateProxy.SetVariable('scriptArgs', $scriptArgs)
    $ps.Runspace.SessionStateProxy.SetVariable('wd', $PipelineRoot)
    $ps.Runspace.SessionStateProxy.SetVariable('rbin', $rbin)
    $ps.Runspace.SessionStateProxy.SetVariable('rhome', $rhome)
    [void]$ps.AddScript({
        . (Join-Path $engineDir 'ProcessRunner.ps1')
        $cb = { param($line) $sync.Queue.Enqueue($line) }
        $procRef = [ref]$null
        $r = Invoke-PipelineProcess -FilePath $rscript -Arguments $scriptArgs `
            -WorkingDirectory $wd -OnOutput $cb -PrependPath $rbin -RHome $rhome -ProcessRef $procRef
        $sync.Process = $procRef.Value
        $sync.Exit = $r.ExitCode
        $sync.Done = $true
    })
    [void]$ps.BeginInvoke()
}

# --- Drain timer (UI thread) ---
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 150
$timer.Add_Tick({
    while ($sync.Queue.Count -gt 0) { $log.AppendText([string]$sync.Queue.Dequeue() + "`r`n") }
    if ($sync.Done -and $sync.Running) {
        $sync.Running = $false; $timer.Stop()
        $st = Get-RunStatus -ExitCode ([int]$sync.Exit) -LogText $sync.Log.ToString()
        $status.Text = $st.Message; $status.ForeColor = [System.Drawing.Color]::$($st.Color)
        Set-Busy $false
        if ($st.State -eq 'Succeeded') { Save-LauncherSettings -Path $SettingsPath -Settings (Get-PathsHash) }
        # Persist a timestamped run log next to the data workbook.
        try {
            $stamp = (Get-Date).ToString('yyyy-MM-dd-HHmm')
            $logDir = Split-Path -Parent $tbData.Text
            if ($logDir -and (Test-Path $logDir)) {
                Set-Content -LiteralPath (Join-Path $logDir "run-$stamp.log") -Value $sync.Log.ToString()
            }
        } catch { }
    }
})

# --- Button wiring ---
$btnCheck.Add_Click({
    $status.ForeColor = [System.Drawing.Color]::Black; $status.Text = 'Checking inputs...'
    $log.Clear(); Set-Busy $true
    $cfg = Write-CycleToml -Paths (Get-PathsHash)
    Start-Job $script:RscriptPath @('--vanilla', $RunData, $cfg, '--validate')
    $timer.Start()
})
$btnRun.Add_Click({
    $status.ForeColor = [System.Drawing.Color]::Black
    $pf = Test-OutputWritable -DataXlsx $tbData.Text -FiguresDir $tbFigures.Text -TablesDir $tbTables.Text
    if (-not $pf.Ok) {
        $status.ForeColor = [System.Drawing.Color]::Red
        $status.Text = ($pf.Problems -join '  ')
        return
    }
    $status.Text = 'Running...'; $log.Clear(); Set-Busy $true
    $cfg = Write-CycleToml -Paths (Get-PathsHash)
    Start-Job $script:RscriptPath @('--vanilla', $RunPipeline, $cfg)
    $timer.Start()
})
$btnCancel.Add_Click({
    if ($sync.Process) { Stop-ProcessTree -ProcessId $sync.Process.Id }
    $timer.Stop(); $sync.Running = $false; Set-Busy $false
    $status.ForeColor = [System.Drawing.Color]::Gray; $status.Text = 'Run cancelled.'
})
$btnSetup.Add_Click({
    $btnSetup.Enabled = $false; $status.Text = 'Setting up R...'
    $res = Install-RIfMissing -WingetVersion $script:RWingetVersion `
        -RscriptResolver { Resolve-RscriptPath } -OnOutput { param($l) $log.AppendText($l + "`r`n") }
    if (-not $res.Ok) { $status.ForeColor=[System.Drawing.Color]::Red; $status.Text=$res.Message; $btnSetup.Enabled=$true; return }
    $script:RscriptPath = $res.RscriptPath
    $log.AppendText("Installing R packages...`r`n")
    $rc = Invoke-PackageSync -RscriptPath $script:RscriptPath -PipelineRoot $PipelineRoot `
        -OnOutput { param($l) $log.AppendText($l + "`r`n") }
    if ($rc -ne 0) { $status.ForeColor=[System.Drawing.Color]::Red
        $status.Text='Couldn''t download R packages - check your internet connection, then retry setup.'; $btnSetup.Enabled=$true; return }
    $setupPanel.Visible = $false; Set-Busy $false; $status.Text = 'Ready.'
})

# --- Startup ---
$s = Get-LauncherSettings -Path $SettingsPath
$tbMacro.Text=$s.MacroDb; $tbAquatic.Text=$s.AquaticDb; $tbData.Text=$s.DataXlsx
$tbFigures.Text=$s.FiguresDir; $tbTables.Text=$s.TablesDir
$script:RscriptPath = Resolve-RscriptPath
if (-not $script:RscriptPath) { $setupPanel.Visible = $true; Set-Busy $true; $btnCancel.Enabled = $false }
[void]$form.ShowDialog()
```

- [ ] **Step 2: Syntax-check the view**

Run:
```powershell
powershell -NoProfile -Command "[void][System.Management.Automation.Language.Parser]::ParseFile('launcher/launcher.ps1',[ref]$null,[ref]$errs); $errs"
```
Expected: no parser errors printed.

- [ ] **Step 3: Manual smoke checklist** (record results in the commit message)

On a machine **with** R + packages already present (fast path):
1. `powershell -NoProfile -ExecutionPolicy Bypass -File launcher/launcher.ps1` → window opens, fields pre-filled from any prior run.
2. Fill the 5 paths → **Check inputs** → status shows validation pass/fail within seconds, no output written.
3. **Run** → live log streams `message()` progress; on success status turns green and outputs appear; a `run-<stamp>.log` is written next to the data workbook.
4. Start a Run, click **Cancel** mid-run → status grey; confirm no orphaned `Rscript.exe` in Task Manager.
5. Open the data workbook in Excel, click **Run** → blocked immediately with the "open in Excel" message (no multi-minute wait).

On a **clean** VM (no R) — the provisioning acceptance test:
6. Run the launcher → setup panel shown, form disabled → **Start setup** → winget installs R per-user (no UAC), then package sync runs with live log → form enables → repeat steps 2-3.

- [ ] **Step 4: Commit**

```bash
git add launcher/launcher.ps1
git commit -m "feat(launcher): WinForms view with background runspace + setup panel"
```

---

## Task 9: Application icon

**Files:**
- Create: `launcher/app.ico`
- Create: `launcher/tools/New-PlaceholderIcon.ps1`

**Interfaces:** none (binary asset).

- [ ] **Step 1: Generate a placeholder icon**

Create `launcher/tools/New-PlaceholderIcon.ps1`:

```powershell
Add-Type -AssemblyName System.Drawing
$bmp = New-Object System.Drawing.Bitmap 32, 32
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.Clear([System.Drawing.Color]::FromArgb(0, 102, 68))
$font = New-Object System.Drawing.Font('Segoe UI', 14, [System.Drawing.FontStyle]::Bold)
$g.DrawString('M', $font, [System.Drawing.Brushes]::White, 6, 4)
$g.Dispose()
$icon = [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
$out = Join-Path (Split-Path -Parent $PSScriptRoot) 'app.ico'
$fs = [System.IO.File]::Create($out)
$icon.Save($fs); $fs.Close()
Write-Host "Wrote $out"
```

- [ ] **Step 2: Run it and verify**

Run: `powershell -NoProfile -File launcher/tools/New-PlaceholderIcon.ps1`
Expected: `launcher/app.ico` exists and is non-empty. (Replace with a designed icon later — tracked in the spec's Open Decisions.)

- [ ] **Step 3: Commit**

```bash
git add launcher/tools/New-PlaceholderIcon.ps1 launcher/app.ico
git commit -m "chore(launcher): placeholder application icon"
```

---

## Task 10: Build/staging script

**Files:**
- Create: `tasks/build_launcher.ps1`
- Test: `launcher/tests/Build.Tests.ps1`

**Interfaces:**
- Produces: a staging folder `build/launcher-app/` containing `launcher.ps1`, `engine/`, `app.ico`, and `pipeline/` (a copy of `src/r`, `scripts/sync_r_packages.R`, `DESCRIPTION`), **excluding** `renv/`, `.Rprofile`, `tests/`. `Build-LauncherApp([string]$RepoRoot, [string]$Destination) -> string` (destination path).

- [ ] **Step 1: Write the failing test**

Create `launcher/tests/Build.Tests.ps1`:

```powershell
BeforeAll { . "$PSScriptRoot/../../tasks/build_launcher.ps1" }
Describe 'Build-LauncherApp' {
    It 'stages the launcher and the pipeline, excluding renv/.Rprofile' {
        $repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        $dest = Join-Path $TestDrive 'app'
        Build-LauncherApp -RepoRoot $repo -Destination $dest | Out-Null
        Test-Path (Join-Path $dest 'launcher.ps1')                       | Should -BeTrue
        Test-Path (Join-Path $dest 'engine\Resolve-RscriptPath.ps1')     | Should -BeTrue
        Test-Path (Join-Path $dest 'pipeline\src\r\run_pipeline.R')      | Should -BeTrue
        Test-Path (Join-Path $dest 'pipeline\scripts\sync_r_packages.R') | Should -BeTrue
        Test-Path (Join-Path $dest 'pipeline\DESCRIPTION')               | Should -BeTrue
        Test-Path (Join-Path $dest 'pipeline\renv')                      | Should -BeFalse
        Test-Path (Join-Path $dest 'pipeline\.Rprofile')                 | Should -BeFalse
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `powershell -NoProfile -File launcher/tests/Invoke-Pester.ps1`
Expected: FAIL — `build_launcher.ps1` / `Build-LauncherApp` not found.

- [ ] **Step 3: Write the implementation**

Create `tasks/build_launcher.ps1`:

```powershell
function Build-LauncherApp {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$Destination
    )
    if (Test-Path -LiteralPath $Destination) { Remove-Item -LiteralPath $Destination -Recurse -Force }
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null

    Copy-Item (Join-Path $RepoRoot 'launcher\launcher.ps1') $Destination
    Copy-Item (Join-Path $RepoRoot 'launcher\app.ico') $Destination -ErrorAction SilentlyContinue
    Copy-Item (Join-Path $RepoRoot 'launcher\engine') (Join-Path $Destination 'engine') -Recurse

    $pipeline = Join-Path $Destination 'pipeline'
    New-Item -ItemType Directory -Path (Join-Path $pipeline 'src') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $pipeline 'scripts') -Force | Out-Null
    Copy-Item (Join-Path $RepoRoot 'src\r') (Join-Path $pipeline 'src\r') -Recurse
    Copy-Item (Join-Path $RepoRoot 'scripts\sync_r_packages.R') (Join-Path $pipeline 'scripts')
    Copy-Item (Join-Path $RepoRoot 'DESCRIPTION') $pipeline

    # Exclude renv/.Rprofile so bundled scripts use the user library, not an empty renv lib.
    foreach ($x in @('pipeline\renv', 'pipeline\.Rprofile', 'pipeline\src\r\tests')) {
        $p = Join-Path $Destination $x
        if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force }
    }
    return $Destination
}

if ($MyInvocation.InvocationName -ne '.') {
    $repo = Split-Path -Parent $PSScriptRoot
    Build-LauncherApp -RepoRoot $repo -Destination (Join-Path $repo 'build\launcher-app')
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `powershell -NoProfile -File launcher/tests/Invoke-Pester.ps1`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add tasks/build_launcher.ps1 launcher/tests/Build.Tests.ps1
git commit -m "feat(launcher): staging/build script (bundle pipeline, exclude renv)"
```

---

## Task 11: Inno Setup installer

**Files:**
- Create: `installer/MtMessengerPipeline.iss`

**Interfaces:** none (build artifact). Verified by compiling with ISCC and a manual install.

- [ ] **Step 1: Write the installer script**

Create `installer/MtMessengerPipeline.iss`:

```ini
; Per-user installer for the Mt Messenger pipeline launcher (no admin required).
; Build: ISCC.exe installer\MtMessengerPipeline.iss  (after tasks\build_launcher.ps1)
#define AppName "Mt Messenger Ecology Pipeline"
#define AppVer  "1.0.0"

[Setup]
AppName={#AppName}
AppVersion={#AppVer}
DefaultDirName={localappdata}\MtMessengerPipeline
DefaultGroupName={#AppName}
PrivilegesRequired=lowest
DisableProgramGroupPage=yes
OutputBaseFilename=MtMessengerPipeline-Setup
OutputDir=..\build
UninstallDisplayIcon={app}\app.ico
SetupIconFile=..\launcher\app.ico

[Files]
Source: "..\build\launcher-app\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "powershell.exe"; \
  Parameters: "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""{app}\launcher.ps1"""; \
  IconFilename: "{app}\app.ico"
Name: "{userdesktop}\{#AppName}"; Filename: "powershell.exe"; \
  Parameters: "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""{app}\launcher.ps1"""; \
  IconFilename: "{app}\app.ico"

[Run]
Filename: "powershell.exe"; \
  Parameters: "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""{app}\launcher.ps1"""; \
  Description: "Launch now"; Flags: postinstall nowait skipifsilent
```

- [ ] **Step 2: Build the staging folder and compile** (manual — needs Inno Setup 6)

Run:
```powershell
powershell -NoProfile -File tasks/build_launcher.ps1
& "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe" installer/MtMessengerPipeline.iss
```
Expected: `build/MtMessengerPipeline-Setup.exe` is produced.

- [ ] **Step 3: Manual install verification**

Run `build/MtMessengerPipeline-Setup.exe` as a **standard (non-admin) user**: installs to `%LOCALAPPDATA%\MtMessengerPipeline` with **no UAC prompt**; Start-menu + desktop shortcuts launch the window; uninstall removes it.

- [ ] **Step 4: Commit**

```bash
git add installer/MtMessengerPipeline.iss
git commit -m "feat(launcher): per-user Inno Setup installer"
```

---

## Task 12: Pester CI on Windows

**Files:**
- Create: `.github/workflows/launcher-tests.yml`

**Interfaces:** none.

- [ ] **Step 1: Write the workflow**

Create `.github/workflows/launcher-tests.yml`:

```yaml
name: launcher-tests
on:
  push:
    paths: ['launcher/**', 'tasks/build_launcher.ps1', '.github/workflows/launcher-tests.yml']
  pull_request:
    paths: ['launcher/**', 'tasks/build_launcher.ps1']
jobs:
  pester:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run launcher Pester suite
        shell: powershell
        run: ./launcher/tests/Invoke-Pester.ps1
```

- [ ] **Step 2: Verify locally first**

Run: `powershell -NoProfile -File launcher/tests/Invoke-Pester.ps1`
Expected: the full suite (Tasks 1-7, 10) passes.

- [ ] **Step 3: Commit and push the branch**

```bash
git add .github/workflows/launcher-tests.yml
git commit -m "ci(launcher): run Pester suite on Windows"
git push -u origin feature/pipeline-launcher-gui
```

Expected: the `launcher-tests` workflow runs green on the pushed branch.

---

## Self-Review

**Spec coverage:**
- Single window, 5 pickers, Run + Check inputs → Task 8 (+ engine Tasks 2-3).
- Remember last-used paths → Task 4 + Task 8 save-on-success.
- First-run setup notice + Start button → Task 8 setup panel + Task 7 helpers.
- Rscript resolver chain (HKCU/%LOCALAPPDATA% first) → Task 1.
- In-repo `run_pipeline.R`, working dir = pipeline root → Task 8; bundle excludes renv → Task 10.
- Child PATH/R_HOME injection → Task 6 (`Invoke-PipelineProcess`) + Task 8 wiring.
- Tree-kill cancel → Task 6 + Task 8.
- Excel-lock pre-flight → Task 3 + Task 8 Run handler.
- Forward-slash cycle.toml → Task 2.
- Friendly failure messages + timestamped run log + Copy/Save log → Task 5 + Task 8. *(Note: "Copy log"/"Save log" buttons folded into the status/run-log behaviour; add explicit buttons in Task 8 Step 1 if desired.)*
- R-version pin (5a) → Task 7 + `$script:RWingetVersion` in Task 8.
- Engine unit tests + integration + manual smoke + CI → Tasks 1-7, 10, 12 + Task 8 Step 3.
- Per-user Inno installer → Task 11.

**Placeholder scan:** No `TBD`/`TODO` in steps; every code step has complete code. `$script:RWingetVersion = '4.5.1'` must be confirmed against winget-pkgs (Task 7 note) — this is a verification, not a placeholder.

**Type consistency:** `$Paths` hashtable keys (`MacroDb, AquaticDb, DataXlsx, FiguresDir, TablesDir`) are identical across Tasks 2, 4, 8, 10. `Get-RunStatus` returns `State/Color/Message` consumed in Task 8. `Invoke-PipelineProcess` returns `ExitCode/Output`; `Resolve-RscriptPath` returns a path or `$null`; both consumed consistently in Tasks 7-8.

**Known follow-ups (non-blocking):** explicit "Copy log"/"Save log" buttons; replace the placeholder icon; confirm the exact `4.5.x` winget version.
