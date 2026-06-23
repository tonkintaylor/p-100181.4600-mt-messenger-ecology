BeforeAll { . "$PSScriptRoot/../engine/ProcessRunner.ps1" }
Describe 'ConvertTo-ArgumentString' {
    It 'quotes arguments containing spaces' {
        ConvertTo-ArgumentString -Arguments @('--vanilla', 'C:\a b\run.R', 'x') |
            Should -Be '--vanilla "C:\a b\run.R" x'
    }
    It 'leaves space-free arguments unquoted' {
        ConvertTo-ArgumentString -Arguments @('a', 'b') | Should -Be 'a b'
    }
}
Describe 'Invoke-PipelineProcess' {
    It 'returns a structured failure (exit -1, message) when the executable does not exist' {
        $r = Invoke-PipelineProcess -FilePath (Join-Path $TestDrive 'nope-does-not-exist.exe')
        $r.ExitCode | Should -Be -1
        $r.Output   | Should -Match 'Failed to launch'
    }
    It 'captures exit code and streams stderr lines via OnOutput' {
        $seen = New-Object System.Collections.Generic.List[string]
        $cb = { param($line) $seen.Add($line) }
        $r = Invoke-PipelineProcess -FilePath $env:ComSpec `
            -Arguments @('/c', 'echo OUT& echo ERR 1>&2& exit 2') `
            -OnOutput $cb
        $r.ExitCode | Should -Be 2
        $r.Output | Should -Match 'OUT'
        $r.Output | Should -Match 'ERR'
        ($seen -join ' ') | Should -Match 'ERR'
    }
}
Describe 'Stop-ProcessTree' {
    It 'terminates a running child process tree' {
        $p = Start-Process -FilePath $env:ComSpec -ArgumentList '/c','ping -n 20 127.0.0.1 >NUL' -PassThru -WindowStyle Hidden
        Stop-ProcessTree -ProcessId $p.Id
        $p.WaitForExit(5000) | Should -BeTrue
    }
}
