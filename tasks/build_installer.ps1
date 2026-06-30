#requires -Version 5.1
# build_installer.ps1 — regenerate the distributable installer in one step.
#
# Runs the two build stages back to back:
#   1. Stage the app + bundle R   (tasks\build_launcher.ps1)
#   2. Compile the Inno Setup installer  (ISCC.exe installer\MtMessengerPipeline.iss)
#
# Output: build\MtMessengerPipeline-Setup.exe
#
# Run from anywhere (paths are resolved from the script location):
#   powershell.exe -NoProfile -ExecutionPolicy Bypass -File tasks\build_installer.ps1
#
# Prerequisites (build machine only — NOT the end user's machine):
#   - A matching R install + internet (the stage bundles R + downloads packages).
#   - Inno Setup 6 (provides ISCC.exe):  winget install --id JRSoftware.InnoSetup -e

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$repoRoot   = Split-Path -Parent $PSScriptRoot
$stageScript = Join-Path $PSScriptRoot 'build_launcher.ps1'
$issFile     = Join-Path $repoRoot 'installer\MtMessengerPipeline.iss'
$outExe      = Join-Path $repoRoot 'build\MtMessengerPipeline-Setup.exe'

Write-Host '== 1/2  Staging the app + bundling R (a few minutes; needs internet) ==' -ForegroundColor Cyan
# Run the stage in a child process so its own `exit` can't terminate this script.
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $stageScript
if ($LASTEXITCODE -ne 0) { throw "Staging failed (build_launcher.ps1 exit $LASTEXITCODE)." }

Write-Host '== 2/2  Compiling the installer (Inno Setup) ==' -ForegroundColor Cyan
$isccCandidates = @()
$isccOnPath = Get-Command ISCC.exe -ErrorAction SilentlyContinue
if ($isccOnPath) { $isccCandidates += $isccOnPath.Source }
$isccCandidates += "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
$isccCandidates += "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe"
$iscc = $isccCandidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if (-not $iscc) {
    throw "Inno Setup 6 compiler (ISCC.exe) not found. Install it with:`n  winget install --id JRSoftware.InnoSetup -e --accept-source-agreements --accept-package-agreements"
}
& $iscc $issFile
if ($LASTEXITCODE -ne 0) { throw "Installer compile failed (ISCC exit $LASTEXITCODE)." }

if (-not (Test-Path -LiteralPath $outExe)) {
    throw "Compile reported success but '$outExe' was not found."
}
$mb = [math]::Round((Get-Item -LiteralPath $outExe).Length / 1MB, 1)
Write-Host ""
Write-Host "Done. Installer: $outExe  ($mb MB)" -ForegroundColor Green
