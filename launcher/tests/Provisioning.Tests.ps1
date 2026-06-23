BeforeAll {
    . "$PSScriptRoot/../engine/Provisioning.ps1"
}
Describe 'Get-PinnedRVersion' {
    It 'reads Config/R/Version from a DESCRIPTION file' {
        $d = Join-Path $TestDrive 'DESCRIPTION'
        Set-Content -LiteralPath $d -Value "Type: project`r`nConfig/R/Version: 4.5`r`n"
        Get-PinnedRVersion -DescriptionPath $d | Should -Be '4.5'
    }
}
Describe 'Get-WingetInstallArgs' {
    It 'requests user scope and silent install' {
        $a = Get-WingetInstallArgs -RVersion '4.5.1'
        ($a -join ' ') | Should -Match '--scope user'
        ($a -join ' ') | Should -Match '--silent'
        ($a -join ' ') | Should -Match '--version 4\.5\.1'
    }
    It 'omits --version when no version is given' {
        (Get-WingetInstallArgs) -join ' ' | Should -Not -Match '--version'
    }
}
