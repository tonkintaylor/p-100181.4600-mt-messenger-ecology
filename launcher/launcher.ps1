#requires -Version 5.1
Set-StrictMode -Version 2.0
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
foreach ($f in Get-ChildItem -LiteralPath (Join-Path $ScriptRoot 'engine') -Filter '*.ps1') {
    . $f.FullName
}

# --- Config ---
$PipelineRoot   = Join-Path $ScriptRoot 'pipeline'
$RunPipeline    = Join-Path $PipelineRoot 'src\r\run_pipeline.R'
$RunData        = Join-Path $PipelineRoot 'src\r\run_data.R'
$RunAll         = Join-Path $PipelineRoot 'src\r\run_all.R'
$SettingsPath   = Join-Path $env:LOCALAPPDATA 'MtMessengerPipeline\settings.json'

# --- Shared state across UI thread and background runspace ---
$sync = [hashtable]::Synchronized(@{
    Queue   = [System.Collections.Queue]::Synchronized((New-Object System.Collections.Queue))
    Running = $false
    Process = $null
    Done    = $false
    Exit    = $null
    Log     = New-Object System.Text.StringBuilder
})

# --- Build the form ---
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Mt Messenger Ecology Pipeline'
$form.Size = New-Object System.Drawing.Size(780, 640)
$form.StartPosition = 'CenterScreen'
$icoPath = Join-Path $ScriptRoot 'app.ico'
if (Test-Path $icoPath) { $form.Icon = New-Object System.Drawing.Icon($icoPath) }

function New-PathRow {
    param($Parent, [string]$Label, [int]$Y, [string]$Mode) # Mode: OpenXlsx|SaveXlsx|Folder
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $Label; $lbl.Location = "15,$Y"; $lbl.Size = '180,20'
    $tb = New-Object System.Windows.Forms.TextBox
    $tb.Location = "200,$($Y-2)"; $tb.Size = '440,22'
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = 'Browse'; $btn.Location = "650,$($Y-3)"; $btn.Size = '80,24'
    $btn.Add_Click({
        switch ($Mode) {
            'OpenXlsx' {
                $d = New-Object System.Windows.Forms.OpenFileDialog
                $d.Filter = 'Excel workbook (*.xlsx)|*.xlsx'
                if ($d.ShowDialog() -eq 'OK') { $tb.Text = $d.FileName }
            }
            'SaveXlsx' {
                $d = New-Object System.Windows.Forms.SaveFileDialog
                $d.Filter = 'Excel workbook (*.xlsx)|*.xlsx'; $d.DefaultExt = 'xlsx'
                if ($d.ShowDialog() -eq 'OK') { $tb.Text = $d.FileName }
            }
            'Folder' {
                $d = New-Object System.Windows.Forms.FolderBrowserDialog
                if ($d.ShowDialog() -eq 'OK') { $tb.Text = $d.SelectedPath }
            }
        }
    }.GetNewClosure())
    $Parent.Controls.AddRange(@($lbl, $tb, $btn))
    return $tb
}

# --- Input mode toggle ---
$grpInput = New-Object System.Windows.Forms.GroupBox
$grpInput.Text = 'Input'; $grpInput.Location = '12,8'; $grpInput.Size = '736,150'

$rbDatabases = New-Object System.Windows.Forms.RadioButton
$rbDatabases.Text = 'Build data workbook from databases'
$rbDatabases.Location = '10,20'; $rbDatabases.Size = '320,20'; $rbDatabases.Checked = $true
$rbWorkbook = New-Object System.Windows.Forms.RadioButton
$rbWorkbook.Text = 'Use an existing data workbook'
$rbWorkbook.Location = '10,92'; $rbWorkbook.Size = '320,20'
$grpInput.Controls.AddRange(@($rbDatabases, $rbWorkbook))
$form.Controls.Add($grpInput)

# Rows live inside the Input group; Y is relative to the group box.
$tbMacro    = New-PathRow $grpInput 'Macroinvertebrate DB'  46  'OpenXlsx'
$tbAquatic  = New-PathRow $grpInput 'Aquatic monitoring DB' 68  'OpenXlsx'
$tbWorkbook = New-PathRow $grpInput 'Data workbook (.xlsx)' 118 'OpenXlsx'

# --- Output folder ---
$tbOutput = New-PathRow $form 'Output folder' 172 'Folder'

$btnCheck = New-Object System.Windows.Forms.Button
$btnCheck.Text = 'Check inputs'; $btnCheck.Location = '210,212'; $btnCheck.Size = '110,30'
$btnRun = New-Object System.Windows.Forms.Button
$btnRun.Text = 'Run'; $btnRun.Location = '578,212'; $btnRun.Size = '170,32'
$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text = 'Cancel'; $btnCancel.Location = '672,578'; $btnCancel.Size = '80,26'; $btnCancel.Enabled = $false

$log = New-Object System.Windows.Forms.TextBox
$log.Multiline = $true; $log.ReadOnly = $true; $log.ScrollBars = 'Vertical'
$log.Location = '15,285'; $log.Size = '740,250'
$log.Font = New-Object System.Drawing.Font('Consolas', 9)

$status = New-Object System.Windows.Forms.Label
$status.Location = '15,548'; $status.Size = '600,24'; $status.Text = 'Ready.'

$form.Controls.AddRange(@($btnCheck, $btnRun, $btnCancel, $log, $status))

# --- Mode toggle handler ---
function Update-ModeEnabled {
    $dbMode = $rbDatabases.Checked
    $tbMacro.Enabled    = $dbMode
    $tbAquatic.Enabled  = $dbMode
    $tbWorkbook.Enabled = -not $dbMode
}
$rbDatabases.Add_CheckedChanged({ Update-ModeEnabled })
$rbWorkbook.Add_CheckedChanged({ Update-ModeEnabled })

# --- Helpers ---
function Set-Busy([bool]$busy) {
    $btnRun.Enabled = -not $busy; $btnCheck.Enabled = -not $busy; $btnCancel.Enabled = $busy
    $rbDatabases.Enabled = -not $busy; $rbWorkbook.Enabled = -not $busy
    foreach ($t in @($tbMacro,$tbAquatic,$tbWorkbook,$tbOutput)) { $t.Enabled = -not $busy }
    if (-not $busy) { Update-ModeEnabled }
}
function Append-Log([string]$text) {
    $log.AppendText($text + "`r`n"); [void]$sync.Log.AppendLine($text)
}
function Get-UiState {
    $mode = if ($rbDatabases.Checked) { 'Databases' } else { 'Workbook' }
    @{ Mode = $mode; MacroDb = $tbMacro.Text; AquaticDb = $tbAquatic.Text
       DataWorkbook = $tbWorkbook.Text; OutputDir = $tbOutput.Text }
}
function Get-ResolvedPaths {
    $s = Get-UiState
    Resolve-RunPaths -Mode $s.Mode -OutputDir $s.OutputDir `
        -MacroDb $s.MacroDb -AquaticDb $s.AquaticDb -DataWorkbook $s.DataWorkbook
}

# Run an Rscript command in a background runspace, streaming to $sync.Queue.
function Start-Job([string]$rscript, [string[]]$scriptArgs) {
    $sync.Running = $true; $sync.Done = $false; $sync.Exit = $null; $sync.Process = $null
    $sync.Queue.Clear(); [void]$sync.Log.Clear()
    $rbin = Split-Path -Parent $rscript
    $rhome = Split-Path -Parent $rbin
    $ps = [PowerShell]::Create()
    $ps.Runspace = [runspacefactory]::CreateRunspace(); $ps.Runspace.Open()
    $ps.Runspace.SessionStateProxy.SetVariable('sync', $sync)
    $ps.Runspace.SessionStateProxy.SetVariable('engineDir', (Join-Path $ScriptRoot 'engine'))
    $ps.Runspace.SessionStateProxy.SetVariable('rscript', $rscript)
    $ps.Runspace.SessionStateProxy.SetVariable('scriptArgs', $scriptArgs)
    $ps.Runspace.SessionStateProxy.SetVariable('wd', $PipelineRoot)
    $ps.Runspace.SessionStateProxy.SetVariable('rbin', $rbin)
    $ps.Runspace.SessionStateProxy.SetVariable('rhome', $rhome)
    [void]$ps.AddScript({
        . (Join-Path $engineDir 'ProcessRunner.ps1')
        $cb = { param($line) $sync.Queue.Enqueue($line) }
        $r = Invoke-PipelineProcess -FilePath $rscript -Arguments $scriptArgs `
            -WorkingDirectory $wd -OnOutput $cb -PrependPath $rbin -RHome $rhome `
            -OnStarted { param($p) $sync.Process = $p }
        $sync.Exit = $r.ExitCode
        $sync.Done = $true
    })
    [void]$ps.BeginInvoke()
}

# --- Drain timer (UI thread) ---
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 150
$timer.Add_Tick({
    while ($sync.Queue.Count -gt 0) {
        $line = [string]$sync.Queue.Dequeue()
        $log.AppendText($line + "`r`n")
        [void]$sync.Log.AppendLine($line)
    }
    if ($sync.Done -and $sync.Running) {
        $sync.Running = $false; $timer.Stop()
        $st = Get-RunStatus -ExitCode ([int]$sync.Exit) -LogText $sync.Log.ToString()
        $status.Text = $st.Message; $status.ForeColor = [System.Drawing.Color]::$($st.Color)
        Set-Busy $false
        if ($st.State -eq 'Succeeded') { Save-LauncherSettings -Path $SettingsPath -Settings (Get-UiState) }
        try {
            $stamp = (Get-Date).ToString('yyyy-MM-dd-HHmm')
            $logDir = $tbOutput.Text
            if ($logDir -and (Test-Path $logDir)) {
                Set-Content -LiteralPath (Join-Path $logDir "run-$stamp.log") -Value $sync.Log.ToString()
            }
        } catch { }
    }
})

# --- Button wiring ---
$btnCheck.Add_Click({
    $status.ForeColor = [System.Drawing.Color]::Black
    $resolved = Get-ResolvedPaths
    if ($resolved.Mode -eq 'Workbook') {
        $wb = $resolved.DataXlsx
        if (-not (Test-Path -LiteralPath $wb -PathType Leaf) -or
            [System.IO.Path]::GetExtension($wb) -ne '.xlsx') {
            $status.ForeColor = [System.Drawing.Color]::Red
            $status.Text = 'Select an existing .xlsx data workbook.'
            return
        }
        if (Test-FileLocked -Path $wb) {
            $status.ForeColor = [System.Drawing.Color]::Red
            $status.Text = "$([System.IO.Path]::GetFileName($wb)) is open in Excel - close it and try again."
            return
        }
        $status.ForeColor = [System.Drawing.Color]::Green
        $status.Text = 'Workbook looks readable. Click Run to generate figures and tables.'
        return
    }
    $status.Text = 'Checking inputs...'
    $log.Clear(); Set-Busy $true
    $cfg = Write-CycleToml -Paths $resolved
    Start-Job $script:RscriptPath @('--vanilla', $RunData, $cfg, '--validate')
    $timer.Start()
})
$btnRun.Add_Click({
    $status.ForeColor = [System.Drawing.Color]::Black
    $resolved = Get-ResolvedPaths
    $pf = Test-OutputWritable -Mode $resolved.Mode -OutputDir $resolved.OutputDir -DataXlsx $resolved.DataXlsx
    if (-not $pf.Ok) {
        $status.ForeColor = [System.Drawing.Color]::Red
        $status.Text = ($pf.Problems -join '  ')
        return
    }
    $status.Text = 'Running...'; $log.Clear(); Set-Busy $true
    $cfg = Write-CycleToml -Paths $resolved
    if ($resolved.Mode -eq 'Workbook') {
        Start-Job $script:RscriptPath @('--vanilla', $RunAll, "--config=$cfg")
    } else {
        Start-Job $script:RscriptPath @('--vanilla', $RunPipeline, $cfg)
    }
    $timer.Start()
})
$btnCancel.Add_Click({
    if ($sync.Process) { Stop-ProcessTree -ProcessId $sync.Process.Id }
    $timer.Stop(); $sync.Running = $false; Set-Busy $false
    $status.ForeColor = [System.Drawing.Color]::Gray; $status.Text = 'Run cancelled.'
})

# --- Startup ---
$s = Get-LauncherSettings -Path $SettingsPath
if ($s.Mode -eq 'Workbook') { $rbWorkbook.Checked = $true } else { $rbDatabases.Checked = $true }
$tbMacro.Text = $s.MacroDb; $tbAquatic.Text = $s.AquaticDb
$tbWorkbook.Text = $s.DataWorkbook; $tbOutput.Text = $s.OutputDir
Update-ModeEnabled
# The app bundles its own pinned R; Get-LauncherRscript returns that bundled
# copy (falling back to a system R only in an unstaged dev checkout).
$script:RscriptPath = Get-LauncherRscript -ScriptRoot $ScriptRoot
if (-not $script:RscriptPath) {
    $status.ForeColor = [System.Drawing.Color]::Red
    $status.Text = 'Bundled R not found - reinstall the app (the installer ships R).'
    Set-Busy $true; $btnCheck.Enabled = $false; $btnRun.Enabled = $false; $btnCancel.Enabled = $false
}
[void]$form.ShowDialog()
