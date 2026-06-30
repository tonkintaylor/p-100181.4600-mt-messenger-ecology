function Resolve-RunPaths {
    param(
        [Parameter(Mandatory)][ValidateSet('Databases','Workbook')][string]$Mode,
        [Parameter(Mandatory)][string]$OutputDir,
        [string]$MacroDb = '',
        [string]$AquaticDb = '',
        [string]$DataWorkbook = ''
    )
    $figures = Join-Path $OutputDir 'figures'
    $tables  = Join-Path $OutputDir 'tables'
    $dataXlsx = if ($Mode -eq 'Workbook') {
        $DataWorkbook
    } else {
        Join-Path $OutputDir 'MtMessengerEcologyData.xlsx'
    }
    @{
        Mode       = $Mode
        MacroDb    = $MacroDb
        AquaticDb  = $AquaticDb
        OutputDir  = $OutputDir
        DataXlsx   = $dataXlsx
        FiguresDir = $figures
        TablesDir  = $tables
    }
}
