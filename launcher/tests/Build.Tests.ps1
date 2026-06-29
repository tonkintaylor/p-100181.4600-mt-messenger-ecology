BeforeAll { . "$PSScriptRoot/../../tasks/build_launcher.ps1" }
Describe 'Build-LauncherApp' {
    It 'stages the launcher and the pipeline, excluding renv/.Rprofile' {
        $repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        $dest = Join-Path $TestDrive 'app'
        Build-LauncherApp -RepoRoot $repo -Destination $dest | Out-Null
        Test-Path (Join-Path $dest 'launcher.ps1')                       | Should -BeTrue
        Test-Path (Join-Path $dest 'engine\Resolve-RscriptPath.ps1')     | Should -BeTrue
        Test-Path (Join-Path $dest 'pipeline\src\r\run_pipeline.R')      | Should -BeTrue
        Test-Path (Join-Path $dest 'pipeline\scripts\sync_r_packages.R') | Should -BeTrue
        Test-Path (Join-Path $dest 'pipeline\DESCRIPTION')               | Should -BeTrue
        Test-Path (Join-Path $dest 'pipeline\renv')                      | Should -BeFalse
        Test-Path (Join-Path $dest 'pipeline\.Rprofile')                 | Should -BeFalse
        Test-Path (Join-Path $dest 'pipeline\src\r\tests')               | Should -BeFalse
        Test-Path (Join-Path $dest 'pipeline\src\r\outputs')             | Should -BeFalse
    }
}
Describe 'Add-LauncherExe' {
    It 'compiles a GUI-subsystem launcher exe (no console window)' {
        $repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        $dest = Join-Path $TestDrive 'app-exe'
        Build-LauncherApp -RepoRoot $repo -Destination $dest | Out-Null
        $exe = Add-LauncherExe -RepoRoot $repo -Destination $dest
        Test-Path $exe | Should -BeTrue
        # Confirm the PE subsystem is Windows GUI (2), not console (3) — this is
        # what guarantees launching it never spawns a terminal window.
        $bytes = [System.IO.File]::ReadAllBytes($exe)
        $peOff = [BitConverter]::ToInt32($bytes, 0x3C)
        [BitConverter]::ToUInt16($bytes, $peOff + 92) | Should -Be 2
    }
}
