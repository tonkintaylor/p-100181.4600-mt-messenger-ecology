# HelpText.ps1 — the user-facing "what this app does / how to use it" text
# shown by the launcher's Help button. Kept here (not in the view) so the
# content is unit-testable and stays aligned with the actual UI labels.

function Get-LauncherHelpText {
    return @'
Mt Messenger Ecology Pipeline

WHAT THIS APP DOES
  It runs the Mt Messenger ecology analysis pipeline and produces the report
  figures and tables. It bundles its own copy of R, so nothing needs to be
  installed beforehand.

1. CHOOSE AN INPUT MODE
  - Build data workbook from databases
      Pick the two source spreadsheets: the Macroinvertebrate DB and the
      Aquatic monitoring DB. The app builds the consolidated data workbook
      (MtMessengerEcologyData.xlsx) and then all figures and tables from it.

  - Use an existing data workbook
      Pick a data workbook the app built earlier (.xlsx). The app skips the
      data-building step and (re)generates the figures and tables from it.

2. CHOOSE AN OUTPUT FOLDER
  Everything is written inside the single folder you choose:
      <output folder>\figures\   - all figures, grouped by topic
      <output folder>\tables\    - all output tables
      MtMessengerEcologyData.xlsx (build mode only) - the consolidated data
  A timestamped run log (run-YYYY-MM-DD-HHMM.log) is also saved there.

3. RUN IT
  - Click "Check inputs" to validate your selections (fast; writes nothing).
  - Click "Run" to produce the outputs. Progress streams in the log below;
    use "Cancel" to stop a run.
  - Tick "Show R warnings in the log" to see R's warnings live in the log.

TIPS
  - Close the data workbook in Excel before running - an open file cannot be
    written.
  - Your selections are remembered for next time.
'@
}
