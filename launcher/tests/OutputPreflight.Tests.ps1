BeforeAll { . "$PSScriptRoot/../engine/OutputPreflight.ps1" }
Describe 'Test-FileLocked' {
    It 'is false for a file that is not open' {
        $f = Join-Path $TestDrive 'free.txt'; Set-Content -LiteralPath $f -Value 'hi'
        Test-FileLocked -Path $f | Should -BeFalse
    }
    It 'is false for a path that does not exist' {
        Test-FileLocked -Path (Join-Path $TestDrive 'nope.txt') | Should -BeFalse
    }
    It 'is true for a file held with an exclusive lock' {
        $f = Join-Path $TestDrive 'locked.txt'; Set-Content -LiteralPath $f -Value 'hi'
        $s = [System.IO.File]::Open($f, 'Open', 'ReadWrite', 'None')
        try { Test-FileLocked -Path $f | Should -BeTrue }
        finally { $s.Close(); $s.Dispose() }
    }
}
Describe 'Test-OutputWritable' {
    It 'is Ok when parents exist and the workbook is free' {
        $out = Join-Path $TestDrive 'out'; New-Item -ItemType Directory -Path $out | Out-Null
        (Test-OutputWritable -DataXlsx (Join-Path $out 'Data.xlsx') `
            -FiguresDir (Join-Path $out 'Figures') -TablesDir (Join-Path $out 'Tables')).Ok |
            Should -BeTrue
    }
    It 'flags a locked workbook with an Excel message' {
        $out = Join-Path $TestDrive 'out2'; New-Item -ItemType Directory -Path $out | Out-Null
        $xlsx = Join-Path $out 'Data.xlsx'; Set-Content -LiteralPath $xlsx -Value 'x'
        $s = [System.IO.File]::Open($xlsx, 'Open', 'ReadWrite', 'None')
        try {
            $r = Test-OutputWritable -DataXlsx $xlsx -FiguresDir (Join-Path $out 'F') -TablesDir (Join-Path $out 'T')
            $r.Ok | Should -BeFalse
            ($r.Problems -join ' ') | Should -Match 'open in Excel'
        } finally { $s.Close(); $s.Dispose() }
    }
}
