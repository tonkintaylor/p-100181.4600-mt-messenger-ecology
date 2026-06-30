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

    foreach ($base in @(
        $(if ($LocalAppData) { Join-Path $LocalAppData 'Programs\R' }),
        $(if ($ProgramFiles) { Join-Path $ProgramFiles 'R' })
    ) | Where-Object { $_ }) {
        if (Test-Path -LiteralPath $base) {
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

# Pick the Rscript the launcher should use: the R bundled inside the app
# (<ScriptRoot>\R\bin\Rscript.exe) when present, else fall back to a
# system-resolved R. The bundled-R build ships its own pinned R, so this
# normally returns the bundled copy and never touches a system install.
function Get-LauncherRscript {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ScriptRoot,
        [scriptblock]$SystemResolver = { Resolve-RscriptPath }
    )
    $bundled = Join-Path $ScriptRoot 'R\bin\Rscript.exe'
    if (Test-Path -LiteralPath $bundled -PathType Leaf) { return $bundled }
    return (& $SystemResolver)
}
