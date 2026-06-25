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

    # Exclude renv/.Rprofile (so bundled scripts use the user library, not an empty
    # renv lib) and dev-machine artifacts (tests, and generated figures under
    # src/r/outputs) so the bundle ships only pipeline code, not stale outputs.
    foreach ($x in @('pipeline\renv', 'pipeline\.Rprofile', 'pipeline\src\r\tests', 'pipeline\src\r\outputs')) {
        $p = Join-Path $Destination $x
        if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force }
    }
    return $Destination
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
    $sync    = Join-Path $RepoRoot 'scripts\sync_r_packages.R'
    $lib     = Join-Path $destR 'library'
    Write-Host "Add-PortableR: syncing packages into bundled library ..."
    # Isolate the bundled R from any library on the BUILD machine so every
    # transitive dependency lands IN the bundle. Otherwise install.packages skips
    # deps it already finds in the builder's user library (e.g. Rcpp/zip/stringi),
    # producing a bundle that only works on the build machine.
    $savedUser = $env:R_LIBS_USER; $savedSite = $env:R_LIBS_SITE
    $env:R_LIBS_USER = $lib; $env:R_LIBS_SITE = $lib
    try {
        & $rscript --vanilla $sync "--lib=$lib"
        $rc = $LASTEXITCODE
    } finally {
        if ($null -eq $savedUser) { Remove-Item Env:\R_LIBS_USER -ErrorAction SilentlyContinue } else { $env:R_LIBS_USER = $savedUser }
        if ($null -eq $savedSite) { Remove-Item Env:\R_LIBS_SITE -ErrorAction SilentlyContinue } else { $env:R_LIBS_SITE = $savedSite }
    }
    if ($rc -ne 0) { throw "Package sync into bundled R failed (exit $rc)." }
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

    $rhome = $env:LAUNCHER_R_HOME
    if (-not $rhome) { $rhome = Find-PinnedRHome -RepoRoot $repo }
    if (-not $rhome) {
        throw "No matching R install found to bundle. Install the pinned R, or set `$env:LAUNCHER_R_HOME to an R home (folder containing bin\Rscript.exe)."
    }
    Add-PortableR -Destination $dest -RHome $rhome -RepoRoot $repo | Out-Null
    Write-Host "Build complete: $dest"
}
