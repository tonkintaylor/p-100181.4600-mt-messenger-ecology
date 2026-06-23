BeforeAll { . "$PSScriptRoot/../engine/LauncherSettings.ps1" }
Describe 'LauncherSettings' {
    It 'returns blank defaults when the file is missing' {
        $s = Get-LauncherSettings -Path (Join-Path $TestDrive 'none.json')
        $s.MacroDb | Should -BeNullOrEmpty
        $s.TablesDir | Should -BeNullOrEmpty
    }
    It 'round-trips saved paths' {
        $p = Join-Path $TestDrive 'settings.json'
        Save-LauncherSettings -Path $p -Settings @{ MacroDb='m'; AquaticDb='q'; DataXlsx='d'; FiguresDir='f'; TablesDir='t' }
        $s = Get-LauncherSettings -Path $p
        $s.MacroDb | Should -Be 'm'
        $s.FiguresDir | Should -Be 'f'
    }
    It 'falls back to defaults on a corrupt file' {
        $p = Join-Path $TestDrive 'bad.json'; Set-Content -LiteralPath $p -Value '{ not json'
        (Get-LauncherSettings -Path $p).MacroDb | Should -BeNullOrEmpty
    }
}
