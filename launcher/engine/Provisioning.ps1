# NOTE: Not wired into the launcher. The app bundles its own R (see
# tasks/build_launcher.ps1 Add-PortableR), so no on-first-run install is needed.
# These winget helpers are retained, with their tests, as a ready alternative if
# a no-bundle / install-on-demand path is ever wanted. RProject.R's winget
# manifest is machine-scope only, so a winget path would require admin (UAC).
function Get-PinnedRVersion {
    param([Parameter(Mandatory)][string]$DescriptionPath)
    $line = Get-Content -LiteralPath $DescriptionPath |
        Where-Object { $_ -match '^\s*Config/R/Version\s*:' } |
        Select-Object -First 1
    if (-not $line) { return $null }
    return ($line -replace '^\s*Config/R/Version\s*:\s*', '').Trim()
}

function Select-NewestMatchingRVersion {
    param([string[]]$Available, [Parameter(Mandatory)][string]$MajorMinor)
    $escaped = [regex]::Escape($MajorMinor)
    $matching = @($Available | Where-Object { $_ -match ("^" + $escaped + "(\.|$)") })
    if ($matching.Count -eq 0) { return $null }
    $parsed = foreach ($v in $matching) {
        $ver = $null
        if ([version]::TryParse($v, [ref]$ver)) { [pscustomobject]@{ Text = $v; Ver = $ver } }
    }
    if (-not $parsed) { return $null }
    return ($parsed | Sort-Object Ver -Descending | Select-Object -First 1).Text
}

function Get-WingetRVersion {
    param([Parameter(Mandatory)][string]$MajorMinor)
    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) { return $null }
    $out = & winget.exe show --id RProject.R --versions 2>$null
    $versions = @($out | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^\d+\.\d+(\.\d+)*$' })
    return (Select-NewestMatchingRVersion -Available $versions -MajorMinor $MajorMinor)
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
    # No-bundle / install-on-demand path: restore the renv.lock library in place
    # (working dir = the checkout root, which has renv.lock + renv/activate.R).
    $expr = "if (!requireNamespace('renv', quietly=TRUE)) install.packages('renv', repos='https://packagemanager.posit.co/cran/latest'); renv::restore(prompt=FALSE)"
    $res = Invoke-PipelineProcess -FilePath $RscriptPath `
        -Arguments @('--vanilla', '-e', $expr) -WorkingDirectory $PipelineRoot -OnOutput $OnOutput
    return $res.ExitCode
}
