# build_bundle.ps1 — Rebuild the mgen distributable bundle
#
# Creates a self-contained folder with everything needed to run mgen
# without cloning the repo. Output: ./dist/mgen-bundle/
#
# Usage:  ./tasks/build_bundle.ps1
#         ./tasks/build_bundle.ps1 -OutputDir "R:\BEKA\mt_messenger\mgen-bundle"

param(
    [string]$OutputDir = ".\dist\mgen-bundle"
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path $PSScriptRoot -Parent

Push-Location $repoRoot

Write-Host ""
Write-Host "=== Building mgen bundle ===" -ForegroundColor Cyan
Write-Host ""

# 1. Build the wheel
Write-Host "Building wheel..."
uv build --wheel --quiet
if ($LASTEXITCODE -ne 0) { throw "Wheel build failed" }
$whl = Get-ChildItem "dist\mgen-*.whl" | Sort-Object LastWriteTime | Select-Object -Last 1
Write-Host "  Built: $($whl.Name)"

# 2. Prepare output directory
if (Test-Path $OutputDir) { Remove-Item $OutputDir -Recurse -Force }
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
New-Item -ItemType Directory -Path "$OutputDir\renv" -Force | Out-Null

# 3. Copy wheel
Copy-Item $whl.FullName "$OutputDir\" -Force

# 4. Copy R code
Write-Host "Copying R code..."
Copy-Item "src\r" "$OutputDir\r" -Recurse -Force
# Remove R test files and outputs from bundle
Remove-Item "$OutputDir\r\tests" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$OutputDir\r\outputs" -Recurse -Force -ErrorAction SilentlyContinue

# 5. Copy renv infrastructure
Write-Host "Copying renv lockfile..."
Copy-Item "renv.lock" "$OutputDir\" -Force
Copy-Item ".Rprofile" "$OutputDir\" -Force
Copy-Item "DESCRIPTION" "$OutputDir\" -Force
Copy-Item "renv\activate.R" "$OutputDir\renv\" -Force
Copy-Item "renv\settings.json" "$OutputDir\renv\" -Force

# 6. Copy config template
Copy-Item "cycle.example.toml" "$OutputDir\" -Force

# 7. Copy the install script
Copy-Item "tasks\bundle_install.ps1" "$OutputDir\install.ps1" -Force

Write-Host ""
Write-Host "=== Bundle ready ===" -ForegroundColor Green
Write-Host "  Location: $OutputDir"
Write-Host "  Contents:"
Get-ChildItem $OutputDir -File | ForEach-Object { Write-Host "    $($_.Name)" }
Get-ChildItem $OutputDir -Directory | ForEach-Object { Write-Host "    $($_.Name)/" }
Write-Host ""

Pop-Location
