# HelpText.ps1 — the user-facing "what this app does / how to use it" content
# shown by the launcher's Help button.
#
# The content is defined once as a list of typed sections (Get-LauncherHelpSections)
# so it is unit-testable and the view can render each section with its own style.
# Get-LauncherHelpText derives a plain-text rendering from the same source.

function Get-LauncherHelpSections {
    # ASCII-only diagram (renders in a monospace block) showing that the data
    # workbook is the hub: built from the two databases, then everything is
    # drawn from it - or supplied directly in the advanced mode.
    $diagramRaw = @'
  BUILD FROM DATABASES  (default)

  Macroinvertebrate DB --+
                         +--> [ DATA WORKBOOK ] --> figures + tables
  Aquatic monitoring DB -+

  USE AN EXISTING WORKBOOK  (advanced)

  [ DATA WORKBOOK built earlier ] --------> figures + tables
'@
    # Pad every line to the same width so the shaded panel is a clean rectangle.
    $w = ($diagramRaw -split "`r?`n" | Measure-Object -Property Length -Maximum).Maximum
    $diagram = (($diagramRaw -split "`r?`n") | ForEach-Object { $_.PadRight($w) }) -join "`n"
    @(
        [pscustomobject]@{ Kind = 'Title';   Text = 'Mt Messenger Ecology Pipeline' }
        [pscustomobject]@{ Kind = 'Body';    Text = 'Runs the Mt Messenger ecology analysis pipeline and produces the report figures and tables. It bundles its own copy of R, so nothing needs to be installed beforehand.' }

        [pscustomobject]@{ Kind = 'Heading'; Text = 'How it fits together' }
        [pscustomobject]@{ Kind = 'Body';    Text = 'The data workbook is the hub. In the normal mode it is BUILT from the two source databases and then the figures and tables are drawn from it. The advanced mode feeds an existing workbook straight in.' }
        [pscustomobject]@{ Kind = 'Diagram'; Text = $diagram }

        [pscustomobject]@{ Kind = 'Heading'; Text = '1.  Choose an input mode' }
        [pscustomobject]@{ Kind = 'Sub';     Text = 'Build data workbook from databases' }
        [pscustomobject]@{ Kind = 'Detail';  Text = 'Pick the two source spreadsheets - the Macroinvertebrate DB and the Aquatic monitoring DB. The app builds the consolidated data workbook (MtMessengerEcologyData.xlsx) and then all figures and tables from it.' }
        [pscustomobject]@{ Kind = 'Sub';     Text = 'Use an existing data workbook  (advanced)' }
        [pscustomobject]@{ Kind = 'Detail';  Text = 'This is the advanced, rarely-needed option. It takes a data workbook the app built on a previous run (MtMessengerEcologyData.xlsx) and only re-draws the figures and tables from it - it does NOT rebuild the data from the source databases.' }
        [pscustomobject]@{ Kind = 'Detail';  Text = 'Use it only when you already have a good workbook and just want to regenerate the outputs - for example after a change to the plotting. If in doubt, use "Build data workbook from databases" above: it always produces a fresh, correct workbook and the figures and tables from it in one step.' }

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
            'Diagram' { "`r`n" + $sec.Text }
            'Bullet'  { '  - ' + $sec.Text }
            default   { $sec.Text }
        }
    }) -join "`r`n"
}
