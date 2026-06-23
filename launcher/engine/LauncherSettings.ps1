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
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    ($Settings | ConvertTo-Json) | Set-Content -LiteralPath $Path -Encoding UTF8
}
