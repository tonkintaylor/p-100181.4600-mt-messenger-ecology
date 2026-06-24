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

Describe 'Get-RscriptCandidatePath' {
    It 'puts ExplicitPath first in the returned candidates' {
        $explicit = 'X:\explicit\Rscript.exe'
        $candidates = Get-RscriptCandidatePath -ExplicitPath $explicit -LocalAppData '' -ProgramFiles ''
        $candidates[0] | Should -Be $explicit
    }

    It 'includes versioned subdirs under LocalAppData and sorts newest first' {
        $base = Join-Path $TestDrive 'AppData\Local'
        $r451 = Join-Path $base 'Programs\R\R-4.5.1\bin'
        $r440 = Join-Path $base 'Programs\R\R-4.4.0\bin'
        New-Item -ItemType Directory -Path $r451 -Force | Out-Null
        New-Item -ItemType Directory -Path $r440 -Force | Out-Null

        $candidates = Get-RscriptCandidatePath -LocalAppData $base -ProgramFiles ''
        $candidates | Should -Contain (Join-Path $base 'Programs\R\R-4.5.1\bin\Rscript.exe')
        $candidates | Should -Contain (Join-Path $base 'Programs\R\R-4.4.0\bin\Rscript.exe')

        $idx451 = [array]::IndexOf($candidates, (Join-Path $base 'Programs\R\R-4.5.1\bin\Rscript.exe'))
        $idx440 = [array]::IndexOf($candidates, (Join-Path $base 'Programs\R\R-4.4.0\bin\Rscript.exe'))
        $idx451 | Should -BeLessThan $idx440
    }

    It 'does not add any relative Programs\R candidate when LocalAppData and ProgramFiles are empty' {
        $candidates = Get-RscriptCandidatePath -LocalAppData '' -ProgramFiles ''
        $relative = $candidates | Where-Object { $_ -and (-not [System.IO.Path]::IsPathRooted($_)) -and ($_ -like 'Programs\R*') }
        $relative | Should -BeNullOrEmpty
    }
}

Describe 'Get-LauncherRscript' {
    It 'prefers the bundled R when present' {
        $root = Join-Path $TestDrive 'app'
        New-Item -ItemType Directory -Path (Join-Path $root 'R\bin') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $root 'R\bin\Rscript.exe') -Value 'stub'
        Get-LauncherRscript -ScriptRoot $root -SystemResolver { 'SYSTEM' } |
            Should -Be (Join-Path $root 'R\bin\Rscript.exe')
    }
    It 'falls back to the system resolver when no bundled R is present' {
        $root = Join-Path $TestDrive 'empty'
        New-Item -ItemType Directory -Path $root -Force | Out-Null
        Get-LauncherRscript -ScriptRoot $root -SystemResolver { 'SYSTEM' } | Should -Be 'SYSTEM'
    }
}
