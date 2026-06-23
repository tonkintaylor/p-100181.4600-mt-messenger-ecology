BeforeAll { . "$PSScriptRoot/../engine/RunStatus.ps1" }
Describe 'Get-RunStatus' {
    It 'maps exit 0 to Succeeded/Green' {
        $r = Get-RunStatus -ExitCode 0
        $r.State | Should -Be 'Succeeded'
        $r.Color | Should -Be 'Green'
    }
    It 'maps non-zero to Failed/Red and includes the log tail' {
        $r = Get-RunStatus -ExitCode 1 -LogText "line1`nERROR: boom`n"
        $r.State | Should -Be 'Failed'
        $r.Color | Should -Be 'Red'
        $r.Message | Should -Match 'boom'
    }
    It 'maps -Cancelled to Cancelled/Gray regardless of exit code' {
        (Get-RunStatus -ExitCode 1 -Cancelled).State | Should -Be 'Cancelled'
    }
}
Describe 'Get-LogTail' {
    It 'returns the last N non-empty lines' {
        Get-LogTail -LogText "a`n`nb`nc`n" -Lines 2 | Should -Be "b`nc"
    }
}
