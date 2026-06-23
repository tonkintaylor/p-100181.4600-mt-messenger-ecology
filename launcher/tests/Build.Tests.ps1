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
    }
}
