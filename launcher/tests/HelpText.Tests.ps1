BeforeAll { . "$PSScriptRoot/../engine/HelpText.ps1" }
Describe 'Get-LauncherHelpText' {
    BeforeAll { $script:text = Get-LauncherHelpText }
    It 'returns a non-trivial help string' {
        $script:text | Should -Not -BeNullOrEmpty
        $script:text.Length | Should -BeGreaterThan 200
    }
    It 'covers both input modes (labels match the UI)' {
        $script:text | Should -BeLike '*Build data workbook from databases*'
        $script:text | Should -BeLike '*Use an existing data workbook*'
    }
    It 'explains the single output folder and its contents' {
        $script:text | Should -BeLike '*Output folder*'
        $script:text | Should -BeLike '*figures*'
        $script:text | Should -BeLike '*tables*'
        $script:text | Should -BeLike '*MtMessengerEcologyData.xlsx*'
    }
    It 'mentions the key actions' {
        $script:text | Should -BeLike '*Check inputs*'
        $script:text | Should -BeLike '*Run*'
        $script:text | Should -BeLike '*Show R warnings*'
    }
}
