BeforeAll { . "$PSScriptRoot/../engine/ConfigWriter.ps1" }
Describe 'New-CycleTomlContent' {
    It 'converts backslashes to forward slashes' {
        $c = New-CycleTomlContent -MacroDb 'T:\a\m.xlsx' -AquaticDb 'T:\a\q.xlsx' `
            -DataXlsx 'C:\out\Data.xlsx' -FiguresDir 'C:\out\Figures' -TablesDir 'C:\out\Tables'
        $c | Should -Match 'macroinvertebrate_db = "T:/a/m.xlsx"'
        $c | Should -Match 'data_xlsx = "C:/out/Data.xlsx"'
        $c | Should -Not -Match '\\'
    }
    It 'emits [input] and [output] sections' {
        $c = New-CycleTomlContent -MacroDb m -AquaticDb q -DataXlsx d -FiguresDir f -TablesDir t
        $c | Should -Match '\[input\]'
        $c | Should -Match '\[output\]'
    }
}
Describe 'Write-CycleToml' {
    It 'writes a readable temp file with the five paths' {
        $p = Write-CycleToml -Paths @{ MacroDb='T:\m.xlsx'; AquaticDb='T:\q.xlsx'; DataXlsx='C:\o\D.xlsx'; FiguresDir='C:\o\F'; TablesDir='C:\o\T' } `
            -Path (Join-Path $TestDrive 'cycle.toml')
        Test-Path $p | Should -BeTrue
        (Get-Content -Raw $p) | Should -Match 'aquatic_monitoring_db = "T:/q.xlsx"'
    }
}
