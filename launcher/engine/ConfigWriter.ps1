function ConvertTo-TomlPath {
    param([Parameter(Mandatory)][string]$Path)
    return ($Path -replace '\\', '/')
}

function New-CycleTomlContent {
    param(
        [Parameter(Mandatory)][string]$MacroDb,
        [Parameter(Mandatory)][string]$AquaticDb,
        [Parameter(Mandatory)][string]$DataXlsx,
        [Parameter(Mandatory)][string]$FiguresDir,
        [Parameter(Mandatory)][string]$TablesDir
    )
    $lines = @(
        '[input]'
        "macroinvertebrate_db = `"$(ConvertTo-TomlPath $MacroDb)`""
        "aquatic_monitoring_db = `"$(ConvertTo-TomlPath $AquaticDb)`""
        ''
        '[output]'
        "data_xlsx = `"$(ConvertTo-TomlPath $DataXlsx)`""
        "figures_dir = `"$(ConvertTo-TomlPath $FiguresDir)`""
        "tables_dir = `"$(ConvertTo-TomlPath $TablesDir)`""
    )
    return (($lines -join "`r`n") + "`r`n")
}

function Write-CycleToml {
    param(
        [Parameter(Mandatory)][hashtable]$Paths,
        [string]$Path = (Join-Path ([System.IO.Path]::GetTempPath()) ("cycle-" + [guid]::NewGuid().ToString('N') + ".toml"))
    )
    $content = New-CycleTomlContent @Paths
    [System.IO.File]::WriteAllText($Path, $content, (New-Object System.Text.UTF8Encoding($false)))
    return $Path
}
