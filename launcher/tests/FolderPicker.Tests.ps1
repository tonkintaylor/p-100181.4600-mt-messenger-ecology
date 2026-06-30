BeforeAll {
    Add-Type -AssemblyName System.Windows.Forms
    . "$PSScriptRoot/../engine/FolderPicker.ps1"
}
Describe 'FolderPicker' {
    It 'compiles the modern Explorer-style folder-dialog interop' {
        Initialize-FolderPicker | Should -BeTrue
        ([System.Management.Automation.PSTypeName]'MtMessenger.FolderPicker').Type |
            Should -Not -BeNullOrEmpty
    }
    It 'exposes the MtMessenger.FolderPicker::Show entry point' {
        $m = [MtMessenger.FolderPicker].GetMethod('Show')
        $m | Should -Not -BeNullOrEmpty
        $m.GetParameters().Count | Should -Be 3
    }
    It 'exposes Show-FolderPicker (with a legacy fallback)' {
        Get-Command Show-FolderPicker -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
    }
}
