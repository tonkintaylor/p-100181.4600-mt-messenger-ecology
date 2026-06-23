BeforeAll {
    . "$PSScriptRoot/../engine/Resolve-RscriptPath.ps1"
}
Describe 'Resolve-RscriptPath' {
    It 'returns the first candidate that exists' {
        $exists = { param($p) $p -eq 'C:\R\bin\Rscript.exe' }
        Resolve-RscriptPath -Candidate @('C:\nope\Rscript.exe', 'C:\R\bin\Rscript.exe') -PathExists $exists |
            Should -Be 'C:\R\bin\Rscript.exe'
    }
    It 'preserves candidate order (earlier wins)' {
        $exists = { param($p) $true }
        Resolve-RscriptPath -Candidate @('A', 'B') -PathExists $exists | Should -Be 'A'
    }
    It 'returns $null when no candidate exists' {
        $exists = { param($p) $false }
        Resolve-RscriptPath -Candidate @('A', 'B') -PathExists $exists | Should -BeNullOrEmpty
    }
}
