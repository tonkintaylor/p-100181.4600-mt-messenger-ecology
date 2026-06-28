# HelpText.ps1 — the user-facing "what this app does / how to use it" content
# shown by the launcher's Help button.
#
# The content is defined once as a list of typed sections (Get-LauncherHelpSections)
# so it is unit-testable and the view can render each section with its own style.
# Get-LauncherHelpText derives a plain-text rendering from the same source.

function Get-LauncherHelpSections {
    @(
        [pscustomobject]@{ Kind = 'Title';   Text = 'Mt Messenger Ecology Pipeline' }
        [pscustomobject]@{ Kind = 'Body';    Text = 'Runs the Mt Messenger ecology analysis pipeline and produces the report figures and tables. It bundles its own copy of R, so nothing needs to be installed beforehand.' }

        [pscustomobject]@{ Kind = 'Heading'; Text = '1.  Choose an input mode' }
        [pscustomobject]@{ Kind = 'Sub';     Text = 'Build data workbook from databases' }
        [pscustomobject]@{ Kind = 'Detail';  Text = 'Pick the two source spreadsheets - the Macroinvertebrate DB and the Aquatic monitoring DB. The app builds the consolidated data workbook (MtMessengerEcologyData.xlsx) and then all figures and tables from it.' }
        [pscustomobject]@{ Kind = 'Sub';     Text = 'Use an existing data workbook' }
        [pscustomobject]@{ Kind = 'Detail';  Text = 'Pick a data workbook the app built earlier (.xlsx). The app skips the data-building step and (re)generates the figures and tables from it.' }

        [pscustomobject]@{ Kind = 'Heading'; Text = '2.  Choose an output folder' }
        [pscustomobject]@{ Kind = 'Body';    Text = 'Everything is written inside the single folder you choose:' }
        [pscustomobject]@{ Kind = 'Code';    Text = '<output folder>\figures\      all figures, grouped by topic' }
        [pscustomobject]@{ Kind = 'Code';    Text = '<output folder>\tables\       all output tables' }
        [pscustomobject]@{ Kind = 'Code';    Text = 'MtMessengerEcologyData.xlsx   the consolidated data (build mode)' }
        [pscustomobject]@{ Kind = 'Body';    Text = 'A timestamped run log (run-YYYY-MM-DD-HHMM.log) is also saved there.' }

        [pscustomobject]@{ Kind = 'Heading'; Text = '3.  Run it' }
        [pscustomobject]@{ Kind = 'Bullet';  Text = 'Click "Check inputs" to validate your selections - fast, and writes nothing.' }
        [pscustomobject]@{ Kind = 'Bullet';  Text = 'Click "Run" to produce the outputs. Progress streams in the log below; use "Cancel" to stop a run.' }
        [pscustomobject]@{ Kind = 'Bullet';  Text = 'Tick "Show R warnings in the log" to see R''s warnings live.' }

        [pscustomobject]@{ Kind = 'Heading'; Text = 'Tips' }
        [pscustomobject]@{ Kind = 'Bullet';  Text = 'Close the data workbook in Excel before running - an open file cannot be written.' }
        [pscustomobject]@{ Kind = 'Bullet';  Text = 'Your selections are remembered for next time.' }
    )
}

# Plain-text rendering of the same content (fallback / tests).
function Get-LauncherHelpText {
    # Alias the section: inside `switch` the automatic $_ is rebound to the
    # switched value (the Kind), so $_.Text would be null.
    (Get-LauncherHelpSections | ForEach-Object {
        $sec = $_
        switch ($sec.Kind) {
            'Heading' { "`r`n" + $sec.Text }
            'Sub'     { '  ' + $sec.Text }
            'Detail'  { '    ' + $sec.Text }
            'Code'    { '    ' + $sec.Text }
            'Bullet'  { '  - ' + $sec.Text }
            default   { $sec.Text }
        }
    }) -join "`r`n"
}
