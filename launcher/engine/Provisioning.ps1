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
