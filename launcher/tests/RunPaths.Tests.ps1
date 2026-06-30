BeforeAll { . "$PSScriptRoot/../engine/RunPaths.ps1" }
Describe 'Resolve-RunPaths' {
    It 'derives figures/tables and the built workbook in Databases mode' {
        $p = Resolve-RunPaths -Mode 'Databases' -OutputDir 'C:\out' `
            -MacroDb 'T:\m.xlsx' -AquaticDb 'T:\q.xlsx'
        $p.FiguresDir | Should -Be (Join-Path 'C:\out' 'figures')
        $p.TablesDir  | Should -Be (Join-Path 'C:\out' 'tables')
        $p.DataXlsx   | Should -Be (Join-Path 'C:\out' 'MtMessengerEcologyData.xlsx')
        $p.MacroDb    | Should -Be 'T:\m.xlsx'
        $p.AquaticDb  | Should -Be 'T:\q.xlsx'
    }
    It 'uses the selected workbook as DataXlsx in Workbook mode' {
        $p = Resolve-RunPaths -Mode 'Workbook' -OutputDir 'C:\out' `
            -DataWorkbook 'D:\existing\Data.xlsx'
        $p.DataXlsx   | Should -Be 'D:\existing\Data.xlsx'
        $p.FiguresDir | Should -Be (Join-Path 'C:\out' 'figures')
        $p.TablesDir  | Should -Be (Join-Path 'C:\out' 'tables')
    }
    It 'rejects an unknown mode' {
        { Resolve-RunPaths -Mode 'Nope' -OutputDir 'C:\out' } | Should -Throw
    }
}
