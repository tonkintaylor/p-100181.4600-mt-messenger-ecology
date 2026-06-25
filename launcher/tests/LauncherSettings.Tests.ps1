BeforeAll { . "$PSScriptRoot/../engine/LauncherSettings.ps1" }
Describe 'LauncherSettings' {
    It 'returns defaults (Mode=Databases, blanks) when the file is missing' {
        $s = Get-LauncherSettings -Path (Join-Path $TestDrive 'none.json')
        $s.Mode | Should -Be 'Databases'
        $s.MacroDb | Should -BeNullOrEmpty
        $s.OutputDir | Should -BeNullOrEmpty
        $s.DataWorkbook | Should -BeNullOrEmpty
    }
    It 'round-trips saved settings including Mode' {
        $p = Join-Path $TestDrive 'settings.json'
        Save-LauncherSettings -Path $p -Settings @{ Mode='Workbook'; MacroDb='m'; AquaticDb='q';
            DataWorkbook='d.xlsx'; OutputDir='C:\out' }
        $s = Get-LauncherSettings -Path $p
        $s.Mode | Should -Be 'Workbook'
        $s.DataWorkbook | Should -Be 'd.xlsx'
        $s.OutputDir | Should -Be 'C:\out'
    }
    It 'falls back to defaults on a corrupt file' {
        $p = Join-Path $TestDrive 'bad.json'; Set-Content -LiteralPath $p -Value '{ not json'
        $s = Get-LauncherSettings -Path $p
        $s.Mode | Should -Be 'Databases'
        $s.MacroDb | Should -BeNullOrEmpty
    }
}
