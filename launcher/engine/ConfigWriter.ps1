function ConvertTo-TomlPath {
    param([Parameter(Mandatory)][string]$Path)
    return ($Path -replace '\\', '/')
}

function New-CycleTomlContent {
    param(
        [Parameter(Mandatory)][ValidateSet('Databases','Workbook')][string]$Mode,
        [string]$MacroDb,
        [string]$AquaticDb,
        [Parameter(Mandatory)][string]$DataXlsx,
        [Parameter(Mandatory)][string]$FiguresDir,
        [Parameter(Mandatory)][string]$TablesDir
    )
    $lines = New-Object System.Collections.Generic.List[string]
    if ($Mode -eq 'Databases') {
        $lines.Add('[input]')
        $lines.Add("macroinvertebrate_db = `"$(ConvertTo-TomlPath $MacroDb)`"")
        $lines.Add("aquatic_monitoring_db = `"$(ConvertTo-TomlPath $AquaticDb)`"")
        $lines.Add('')
    }
    $lines.Add('[output]')
    $lines.Add("data_xlsx = `"$(ConvertTo-TomlPath $DataXlsx)`"")
    $lines.Add("figures_dir = `"$(ConvertTo-TomlPath $FiguresDir)`"")
    $lines.Add("tables_dir = `"$(ConvertTo-TomlPath $TablesDir)`"")
    return (($lines -join "`r`n") + "`r`n")
}

function Write-CycleToml {
    param(
        [Parameter(Mandatory)][hashtable]$Paths,
        [string]$Path = (Join-Path ([System.IO.Path]::GetTempPath()) ("cycle-" + [guid]::NewGuid().ToString('N') + ".toml"))
    )
    $content = New-CycleTomlContent -Mode $Paths.Mode -MacroDb $Paths.MacroDb `
        -AquaticDb $Paths.AquaticDb -DataXlsx $Paths.DataXlsx `
        -FiguresDir $Paths.FiguresDir -TablesDir $Paths.TablesDir
    [System.IO.File]::WriteAllText($Path, $content, (New-Object System.Text.UTF8Encoding($false)))
    return $Path
}
