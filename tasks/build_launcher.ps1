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
    Copy-Item (Join-Path $RepoRoot 'src\r') (Join-Path $pipeline 'src\r') -Recurse
    Copy-Item (Join-Path $RepoRoot 'DESCRIPTION') $pipeline

    # Exclude renv/.Rprofile (so bundled scripts use the user library, not an empty
    # renv lib) and dev-machine artifacts (tests, and generated figures under
    # src/r/outputs) so the bundle ships only pipeline code, not stale outputs.
    foreach ($x in @('pipeline\renv', 'pipeline\.Rprofile', 'pipeline\src\r\tests', 'pipeline\src\r\outputs')) {
        $p = Join-Path $Destination $x
        if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force }
    }
    return $Destination
}

# Compile the tiny GUI launcher (MtMessengerPipeline.exe) into the staged app.
# Built with the .NET Framework C# compiler (present on any Windows with .NET
# 4.x). /target:winexe gives a GUI-subsystem exe (no console window) and
# /win32icon embeds app.ico so the shortcut/taskbar show the app, not PowerShell.
function Add-LauncherExe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Destination,
        [Parameter(Mandatory)][string]$RepoRoot
    )
    $src  = Join-Path $RepoRoot 'launcher\MtMessengerPipeline.Launcher.cs'
    $icon = Join-Path $Destination 'app.ico'
    $exe  = Join-Path $Destination 'MtMessengerPipeline.exe'
    if (-not (Test-Path -LiteralPath $src)) { throw "Launcher stub source not found: $src" }

    $fwk = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319'
    if (-not (Test-Path -LiteralPath (Join-Path $fwk 'csc.exe'))) {
        $fwk = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319'
    }
    $csc = Join-Path $fwk 'csc.exe'
    if (-not (Test-Path -LiteralPath $csc)) {
        throw "C# compiler (csc.exe) not found under $env:WINDIR\Microsoft.NET. .NET Framework 4.x is required to build the launcher exe."
    }

    $cscArgs = @('/nologo', '/target:winexe', "/out:$exe",
                 "/reference:$(Join-Path $fwk 'System.Windows.Forms.dll')")
    if (Test-Path -LiteralPath $icon) { $cscArgs += "/win32icon:$icon" }
    $cscArgs += $src
    Write-Host "Add-LauncherExe: compiling MtMessengerPipeline.exe ..."
    & $csc @cscArgs
    if ($LASTEXITCODE -ne 0) { throw "Compiling MtMessengerPipeline.exe failed (csc exit $LASTEXITCODE)." }
    if (-not (Test-Path -LiteralPath $exe)) { throw "csc reported success but '$exe' is missing." }
    return $exe
}

# Bundle a self-contained R into the staged app: copy a relocatable R install
# tree to <Destination>\R, then install the project's declared packages into
# that R's own library (PPM Windows binaries; no compiler needed). The result
# runs on a machine with no R and no admin. This is the heavy, internet-dependent
# build step and is NOT exercised by the Pester suite.
function Add-PortableR {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Destination,
        [Parameter(Mandatory)][string]$RHome,
        [string]$RepoRoot
    )
    $srcRscript = Join-Path $RHome 'bin\Rscript.exe'
    if (-not (Test-Path -LiteralPath $srcRscript)) {
        throw "Source R not found at '$RHome' (expected bin\Rscript.exe)."
    }
    if (-not $RepoRoot) { $RepoRoot = Split-Path -Parent $PSScriptRoot }

    $destR = Join-Path $Destination 'R'
    if (Test-Path -LiteralPath $destR) { Remove-Item -LiteralPath $destR -Recurse -Force }
    Write-Host "Add-PortableR: copying R from $RHome ..."
    Copy-Item -LiteralPath $RHome -Destination $destR -Recurse -Force

    $rscript = Join-Path $destR 'bin\Rscript.exe'
    $lock    = Join-Path $RepoRoot 'renv.lock'
    $lib     = Join-Path $destR 'library'
    if (-not (Test-Path -LiteralPath $lock)) { throw "renv.lock not found at '$lock'." }
    Write-Host "Add-PortableR: restoring renv.lock into bundled library ..."
    # Restore the exact versions from renv.lock straight into the bundled R's own
    # library ($destR\library - the default lib the bundled --vanilla R reads at
    # runtime). renv::restore is lockfile- and target-library-scoped, so it
    # installs the FULL lockfile closure into $lib regardless of what the build
    # machine has installed - no R_LIBS isolation needed.
    #
    #  * RENV_CONFIG_CACHE_ENABLED=FALSE - install real copies, not symlinks into
    #    the build machine's renv cache (which won't exist on a target PC).
    #  * Do NOT set R_LIBS_USER/SITE=$lib: pointing them at the same dir as
    #    library= makes renv's transactional restore report success while
    #    populating nothing in $lib (ships an empty bundle). Verified.
    #  * Pass paths via env vars, not string interpolation, so a build path with
    #    spaces or quotes can't break the R -e expression.
    $savedLock = $env:MTM_RENV_LOCK; $savedLibEnv = $env:MTM_RENV_LIB; $savedCache = $env:RENV_CONFIG_CACHE_ENABLED
    $env:MTM_RENV_LOCK = $lock; $env:MTM_RENV_LIB = $lib; $env:RENV_CONFIG_CACHE_ENABLED = 'FALSE'
    try {
        & $rscript --vanilla -e "if (!requireNamespace('renv', quietly=TRUE)) install.packages('renv', repos='https://packagemanager.posit.co/cran/2026-05-13'); renv::restore(lockfile=Sys.getenv('MTM_RENV_LOCK'), library=Sys.getenv('MTM_RENV_LIB'), prompt=FALSE)"
        $rc = $LASTEXITCODE
    } finally {
        if ($null -eq $savedLock)   { Remove-Item Env:\MTM_RENV_LOCK -ErrorAction SilentlyContinue } else { $env:MTM_RENV_LOCK = $savedLock }
        if ($null -eq $savedLibEnv) { Remove-Item Env:\MTM_RENV_LIB -ErrorAction SilentlyContinue } else { $env:MTM_RENV_LIB = $savedLibEnv }
        if ($null -eq $savedCache)  { Remove-Item Env:\RENV_CONFIG_CACHE_ENABLED -ErrorAction SilentlyContinue } else { $env:RENV_CONFIG_CACHE_ENABLED = $savedCache }
    }
    if ($rc -ne 0) { throw "renv restore into bundled R failed (exit $rc)." }
    # Guard: fail loudly if restore reported success but populated nothing (the
    # silent-empty-bundle failure mode). Confirm the key runtime packages exist.
    $must = @('readxl', 'openxlsx', 'dplyr', 'tidyr', 'ggplot2', 'vegan')
    $absent = $must | Where-Object { -not (Test-Path -LiteralPath (Join-Path $lib $_)) }
    if ($absent) {
        throw "Bundled R library at '$lib' is missing packages after restore: $($absent -join ', '). The bundle would fail at runtime - aborting build."
    }
    return $destR
}

# Locate an R install whose major.minor matches the project's pinned version.
function Find-PinnedRHome {
    param([Parameter(Mandatory)][string]$RepoRoot)
    $pin = '4.5'
    $line = Get-Content (Join-Path $RepoRoot 'DESCRIPTION') -ErrorAction SilentlyContinue |
        Where-Object { $_ -match '^\s*Config/R/Version\s*:' } | Select-Object -First 1
    if ($line) { $pin = ($line -replace '^\s*Config/R/Version\s*:\s*', '').Trim() }
    # ProgramW6432 is the real 64-bit Program Files even from a 32-bit host
    # (where $env:ProgramFiles points at the x86 dir). Use -like, not -Filter:
    # Windows file filters mishandle the embedded dots in "R-4.5.*".
    $bases = @()
    foreach ($pf in @($env:ProgramW6432, $env:ProgramFiles)) { if ($pf) { $bases += (Join-Path $pf 'R') } }
    if ($env:LOCALAPPDATA) { $bases += (Join-Path $env:LOCALAPPDATA 'Programs\R') }
    foreach ($b in ($bases | Select-Object -Unique)) {
        if (Test-Path -LiteralPath $b) {
            $hit = Get-ChildItem -LiteralPath $b -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -like "R-$pin.*" } |
                Sort-Object Name -Descending | Select-Object -First 1
            if ($hit) { return $hit.FullName }
        }
    }
    return $null
}

if ($MyInvocation.InvocationName -ne '.') {
    $repo = Split-Path -Parent $PSScriptRoot
    $dest = Join-Path $repo 'build\launcher-app'
    Build-LauncherApp -RepoRoot $repo -Destination $dest
    Add-LauncherExe -RepoRoot $repo -Destination $dest | Out-Null

    $rhome = $env:LAUNCHER_R_HOME
    if (-not $rhome) { $rhome = Find-PinnedRHome -RepoRoot $repo }
    if (-not $rhome) {
        throw "No matching R install found to bundle. Install the pinned R, or set `$env:LAUNCHER_R_HOME to an R home (folder containing bin\Rscript.exe)."
    }
    Add-PortableR -Destination $dest -RHome $rhome -RepoRoot $repo | Out-Null
    Write-Host "Build complete: $dest"
}
