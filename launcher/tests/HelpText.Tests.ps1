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
Describe 'Get-LauncherHelpSections' {
    BeforeAll { $script:sections = @(Get-LauncherHelpSections) }
    It 'returns a list of typed sections' {
        $script:sections.Count | Should -BeGreaterThan 5
    }
    It 'starts with the Title' {
        $script:sections[0].Kind | Should -Be 'Title'
        $script:sections[0].Text | Should -Be 'Mt Messenger Ecology Pipeline'
    }
    It 'uses only known section kinds' {
        $known = 'Title','Body','Heading','Sub','Detail','Code','Bullet'
        foreach ($s in $script:sections) { $known | Should -Contain $s.Kind }
    }
    It 'every section has non-empty text' {
        foreach ($s in $script:sections) { $s.Text | Should -Not -BeNullOrEmpty }
    }
}
