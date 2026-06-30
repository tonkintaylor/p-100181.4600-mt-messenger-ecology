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
    It 'is Ok in Databases mode when the output folder exists and the workbook is free' {
        $out = Join-Path $TestDrive 'out'; New-Item -ItemType Directory -Path $out | Out-Null
        (Test-OutputWritable -Mode 'Databases' -OutputDir $out `
            -DataXlsx (Join-Path $out 'MtMessengerEcologyData.xlsx')).Ok | Should -BeTrue
    }
    It 'is Ok in Databases mode when the output folder is missing but its parent exists' {
        $parent = Join-Path $TestDrive 'p'; New-Item -ItemType Directory -Path $parent | Out-Null
        $out = Join-Path $parent 'new-out'
        (Test-OutputWritable -Mode 'Databases' -OutputDir $out `
            -DataXlsx (Join-Path $out 'MtMessengerEcologyData.xlsx')).Ok | Should -BeTrue
    }
    It 'flags a locked built workbook with an Excel message (Databases mode)' {
        $out = Join-Path $TestDrive 'out2'; New-Item -ItemType Directory -Path $out | Out-Null
        $xlsx = Join-Path $out 'MtMessengerEcologyData.xlsx'; Set-Content -LiteralPath $xlsx -Value 'x'
        $s = [System.IO.File]::Open($xlsx, 'Open', 'ReadWrite', 'None')
        try {
            $r = Test-OutputWritable -Mode 'Databases' -OutputDir $out -DataXlsx $xlsx
            $r.Ok | Should -BeFalse
            ($r.Problems -join ' ') | Should -Match 'open in Excel'
        } finally { $s.Close(); $s.Dispose() }
    }
    It 'flags a missing input workbook (Workbook mode)' {
        $out = Join-Path $TestDrive 'out3'; New-Item -ItemType Directory -Path $out | Out-Null
        $r = Test-OutputWritable -Mode 'Workbook' -OutputDir $out `
            -DataXlsx (Join-Path $TestDrive 'nope.xlsx')
        $r.Ok | Should -BeFalse
        ($r.Problems -join ' ') | Should -Match 'not found'
    }
    It 'is Ok in Workbook mode when the workbook exists and is free' {
        $out = Join-Path $TestDrive 'out4'; New-Item -ItemType Directory -Path $out | Out-Null
        $wb = Join-Path $TestDrive 'Data.xlsx'; Set-Content -LiteralPath $wb -Value 'x'
        (Test-OutputWritable -Mode 'Workbook' -OutputDir $out -DataXlsx $wb).Ok | Should -BeTrue
    }
    It 'flags a locked input workbook with an Excel message (Workbook mode)' {
        $out = Join-Path $TestDrive 'out5'; New-Item -ItemType Directory -Path $out | Out-Null
        $wb = Join-Path $TestDrive 'LockedData.xlsx'; Set-Content -LiteralPath $wb -Value 'x'
        $s = [System.IO.File]::Open($wb, 'Open', 'ReadWrite', 'None')
        try {
            $r = Test-OutputWritable -Mode 'Workbook' -OutputDir $out -DataXlsx $wb
            $r.Ok | Should -BeFalse
            ($r.Problems -join ' ') | Should -Match 'open in Excel'
        } finally { $s.Close(); $s.Dispose() }
    }
}
