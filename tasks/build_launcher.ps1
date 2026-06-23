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
