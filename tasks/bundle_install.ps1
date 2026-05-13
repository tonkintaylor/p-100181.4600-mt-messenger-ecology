# Mt Messenger Ecology Pipeline — Install from Bundle
# Installs mgen globally via uv tool install — no venv activation needed.
#
# Usage:  Right-click → Run with PowerShell
#         Or in PowerShell: .\install.ps1

$ErrorActionPreference = "Stop"
$bundleDir = $PSScriptRoot

Write-Host ""
Write-Host "=== Mt Messenger Ecology Pipeline — Bundle Install ===" -ForegroundColor Cyan
Write-Host ""

# --- 1. Install uv ---
$uvVersion = "0.10.2"
if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
    Write-Host "Installing uv (Python package manager)..."
    Invoke-RestMethod "https://astral.sh/uv/$uvVersion/install.ps1" | Invoke-Expression
    $env:PATH = "$env:USERPROFILE\.local\bin;$env:PATH"
} else {
    Write-Host "uv already installed."
}

# --- 2. Install mgen globally via uv tool install ---
Write-Host "Installing mgen CLI tool..."
$whl = Get-ChildItem "$bundleDir\mgen-*.whl" | Select-Object -First 1
if (-not $whl) { throw "No mgen wheel found in bundle" }
uv tool install $whl.FullName --force --python 3.13
if ($LASTEXITCODE -ne 0) { throw "Failed to install mgen" }

# Ensure uv tool bin is on PATH for this session
$toolBin = & uv tool dir 2>$null | Split-Path -Parent
$uvBin = "$env:USERPROFILE\.local\bin"
if ($env:PATH -notlike "*$uvBin*") {
    $env:PATH = "$uvBin;$env:PATH"
}

# --- 3. Install R + renv packages ---
Write-Host ""
Write-Host "Setting up R environment..."

$rBin = Get-ChildItem "C:\Program Files\R" -Directory -ErrorAction SilentlyContinue |
    Sort-Object Name | Select-Object -Last 1
if ($rBin) {
    $rscript = Join-Path $rBin.FullName "bin\Rscript.exe"
} else {
    $rscript = $null
}

if ($rscript -and (Test-Path $rscript)) {
    Write-Host "  R found: $rscript"
    Push-Location $bundleDir
    & $rscript -e "source('renv/activate.R'); renv::restore(prompt = FALSE)"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  WARNING: R package restore failed. Run manually in R:" -ForegroundColor Yellow
        Write-Host "    source('renv/activate.R'); renv::restore()"
    }
    Pop-Location
} else {
    Write-Host "  WARNING: R not found. Install R from https://cran.r-project.org/" -ForegroundColor Yellow
    Write-Host "  Then run in R from this folder: source('renv/activate.R'); renv::restore()"
}

# --- 4. Create cycle.toml from template ---
if (-not (Test-Path "$bundleDir\cycle.toml")) {
    Copy-Item "$bundleDir\cycle.example.toml" "$bundleDir\cycle.toml"
    Write-Host ""
    Write-Host "  Created cycle.toml — edit this to set your input/output paths." -ForegroundColor Yellow
}

# --- 5. Done ---
Write-Host ""
Write-Host "=== Installation Complete! ===" -ForegroundColor Green
Write-Host ""
Write-Host "To use:"
Write-Host "  1. Edit cycle.toml with your input/output paths"
Write-Host "  2. cd to this folder:  cd $bundleDir"
Write-Host "  3. Run:  mgen all"
Write-Host ""
Write-Host "No virtual environment activation needed — mgen is on your PATH."
Write-Host ""
Read-Host "Press Enter to exit"
