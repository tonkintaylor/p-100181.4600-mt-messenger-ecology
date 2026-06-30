BeforeAll { . "$PSScriptRoot/../engine/ConfigWriter.ps1" }
Describe 'New-CycleTomlContent (Databases mode)' {
    It 'emits [input] with both DBs and [output] with all three paths' {
        $c = New-CycleTomlContent -Mode 'Databases' -MacroDb 'T:\a\m.xlsx' `
            -AquaticDb 'T:\a\q.xlsx' -DataXlsx 'C:\out\MtMessengerEcologyData.xlsx' `
            -FiguresDir 'C:\out\figures' -TablesDir 'C:\out\tables'
        $c | Should -Match '\[input\]'
        $c | Should -Match 'macroinvertebrate_db = "T:/a/m.xlsx"'
        $c | Should -Match 'aquatic_monitoring_db = "T:/a/q.xlsx"'
        $c | Should -Match '\[output\]'
        $c | Should -Match 'data_xlsx = "C:/out/MtMessengerEcologyData.xlsx"'
        $c | Should -Match 'figures_dir = "C:/out/figures"'
        $c | Should -Match 'tables_dir = "C:/out/tables"'
        $c | Should -Not -Match '\\'
    }
}
Describe 'New-CycleTomlContent (Workbook mode)' {
    It 'omits [input] and points data_xlsx at the selected workbook' {
        $c = New-CycleTomlContent -Mode 'Workbook' `
            -DataXlsx 'D:\existing\Data.xlsx' `
            -FiguresDir 'C:\out\figures' -TablesDir 'C:\out\tables'
        $c | Should -Not -Match '\[input\]'
        $c | Should -Not -Match 'macroinvertebrate_db'
        $c | Should -Match '\[output\]'
        $c | Should -Match 'data_xlsx = "D:/existing/Data.xlsx"'
    }
}
Describe 'Write-CycleToml' {
    It 'writes a readable temp file from a resolved paths hashtable' {
        $paths = @{ Mode='Databases'; MacroDb='T:\m.xlsx'; AquaticDb='T:\q.xlsx';
                    DataXlsx='C:\o\MtMessengerEcologyData.xlsx';
                    FiguresDir='C:\o\figures'; TablesDir='C:\o\tables'; OutputDir='C:\o' }
        $p = Write-CycleToml -Paths $paths -Path (Join-Path $TestDrive 'cycle.toml')
        Test-Path $p | Should -BeTrue
        (Get-Content -Raw $p) | Should -Match 'aquatic_monitoring_db = "T:/q.xlsx"'
    }
}
