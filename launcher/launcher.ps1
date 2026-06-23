#requires -Version 5.1
Set-StrictMode -Version 2.0
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
foreach ($f in Get-ChildItem -LiteralPath (Join-Path $ScriptRoot 'engine') -Filter '*.ps1') {
    . $f.FullName
}

# --- Config ---
$script:RWingetVersionFallback = '4.5.1'   # fallback only; confirm/adjust during clean-VM smoke
$PipelineRoot   = Join-Path $ScriptRoot 'pipeline'
$RunPipeline    = Join-Path $PipelineRoot 'src\r\run_pipeline.R'
$RunData        = Join-Path $PipelineRoot 'src\r\run_data.R'
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
$form.Size = New-Object System.Drawing.Size(760, 620)
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

$tbMacro   = New-PathRow $form 'Macroinvertebrate DB'  40  'OpenXlsx'
$tbAquatic = New-PathRow $form 'Aquatic monitoring DB' 72  'OpenXlsx'
$tbData    = New-PathRow $form 'Data workbook (.xlsx)' 116 'SaveXlsx'
$tbFigures = New-PathRow $form 'Figures folder'        148 'Folder'
$tbTables  = New-PathRow $form 'Tables folder'         180 'Folder'

$btnCheck = New-Object System.Windows.Forms.Button
$btnCheck.Text = 'Check inputs'; $btnCheck.Location = '200,220'; $btnCheck.Size = '110,30'
$btnRun = New-Object System.Windows.Forms.Button
$btnRun.Text = 'Run'; $btnRun.Location = '560,220'; $btnRun.Size = '170,32'
$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text = 'Cancel'; $btnCancel.Location = '650,560'; $btnCancel.Size = '80,26'; $btnCancel.Enabled = $false

$log = New-Object System.Windows.Forms.TextBox
$log.Multiline = $true; $log.ReadOnly = $true; $log.ScrollBars = 'Vertical'
$log.Location = '15,265'; $log.Size = '715,250'
$log.Font = New-Object System.Drawing.Font('Consolas', 9)

$status = New-Object System.Windows.Forms.Label
$status.Location = '15,530'; $status.Size = '600,24'; $status.Text = 'Ready.'

$setupPanel = New-Object System.Windows.Forms.Panel
$setupPanel.Location = '15,40'; $setupPanel.Size = '715,170'; $setupPanel.BackColor = 'WhiteSmoke'; $setupPanel.Visible = $false
$setupLabel = New-Object System.Windows.Forms.Label
$setupLabel.Location = '15,15'; $setupLabel.Size = '680,90'
$setupLabel.Text = "R isn't installed on this PC yet.`r`nSetup installs R + the required packages." +
    "`r`n  - One-time, ~5-10 min, needs internet`r`n  - No admin rights needed (installs just for you)"
$btnSetup = New-Object System.Windows.Forms.Button
$btnSetup.Text = 'Start setup'; $btnSetup.Location = '15,120'; $btnSetup.Size = '120,30'
$setupPanel.Controls.AddRange(@($setupLabel, $btnSetup))

$form.Controls.AddRange(@($btnCheck, $btnRun, $btnCancel, $log, $status, $setupPanel))

# --- Helpers ---
function Set-Busy([bool]$busy) {
    $btnRun.Enabled = -not $busy; $btnCheck.Enabled = -not $busy; $btnCancel.Enabled = $busy
    foreach ($t in @($tbMacro,$tbAquatic,$tbData,$tbFigures,$tbTables)) { $t.Enabled = -not $busy }
}
function Append-Log([string]$text) {
    $log.AppendText($text + "`r`n"); [void]$sync.Log.AppendLine($text)
}
function Get-PathsHash {
    @{ MacroDb=$tbMacro.Text; AquaticDb=$tbAquatic.Text; DataXlsx=$tbData.Text
       FiguresDir=$tbFigures.Text; TablesDir=$tbTables.Text }
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
        if ($st.State -eq 'Succeeded') { Save-LauncherSettings -Path $SettingsPath -Settings (Get-PathsHash) }
        # Persist a timestamped run log next to the data workbook.
        try {
            $stamp = (Get-Date).ToString('yyyy-MM-dd-HHmm')
            $logDir = [System.IO.Path]::GetDirectoryName($tbData.Text)
            if ($logDir -and (Test-Path $logDir)) {
                Set-Content -LiteralPath (Join-Path $logDir "run-$stamp.log") -Value $sync.Log.ToString()
            }
        } catch { }
    }
})

# --- Button wiring ---
$btnCheck.Add_Click({
    $status.ForeColor = [System.Drawing.Color]::Black; $status.Text = 'Checking inputs...'
    $log.Clear(); Set-Busy $true
    $cfg = Write-CycleToml -Paths (Get-PathsHash)
    Start-Job $script:RscriptPath @('--vanilla', $RunData, $cfg, '--validate')
    $timer.Start()
})
$btnRun.Add_Click({
    $status.ForeColor = [System.Drawing.Color]::Black
    $pf = Test-OutputWritable -DataXlsx $tbData.Text -FiguresDir $tbFigures.Text -TablesDir $tbTables.Text
    if (-not $pf.Ok) {
        $status.ForeColor = [System.Drawing.Color]::Red
        $status.Text = ($pf.Problems -join '  ')
        return
    }
    $status.Text = 'Running...'; $log.Clear(); Set-Busy $true
    $cfg = Write-CycleToml -Paths (Get-PathsHash)
    Start-Job $script:RscriptPath @('--vanilla', $RunPipeline, $cfg)
    $timer.Start()
})
$btnCancel.Add_Click({
    if ($sync.Process) { Stop-ProcessTree -ProcessId $sync.Process.Id }
    $timer.Stop(); $sync.Running = $false; Set-Busy $false
    $status.ForeColor = [System.Drawing.Color]::Gray; $status.Text = 'Run cancelled.'
})
$btnSetup.Add_Click({
    $btnSetup.Enabled = $false; $status.Text = 'Setting up R...'
    $pinned = $null
    $descPath = Join-Path $PipelineRoot 'DESCRIPTION'
    if (Test-Path -LiteralPath $descPath) { $pinned = Get-PinnedRVersion -DescriptionPath $descPath }
    $rv = if ($pinned) { Get-WingetRVersion -MajorMinor $pinned } else { $null }
    if (-not $rv) { $rv = $script:RWingetVersionFallback; $log.AppendText("Note: using fallback R version $rv`r`n") }
    $res = Install-RIfMissing -WingetVersion $rv `
        -RscriptResolver { Resolve-RscriptPath } -OnOutput { param($l) $log.AppendText($l + "`r`n") }
    if (-not $res.Ok) { $status.ForeColor=[System.Drawing.Color]::Red; $status.Text=$res.Message; $btnSetup.Enabled=$true; return }
    $script:RscriptPath = $res.RscriptPath
    $log.AppendText("Installing R packages...`r`n")
    $rc = Invoke-PackageSync -RscriptPath $script:RscriptPath -PipelineRoot $PipelineRoot `
        -OnOutput { param($l) $log.AppendText($l + "`r`n") }
    if ($rc -ne 0) { $status.ForeColor=[System.Drawing.Color]::Red
        $status.Text='Couldn''t download R packages - check your internet connection, then retry setup.'; $btnSetup.Enabled=$true; return }
    $setupPanel.Visible = $false; Set-Busy $false; $status.Text = 'Ready.'
})

# --- Startup ---
$s = Get-LauncherSettings -Path $SettingsPath
$tbMacro.Text=$s.MacroDb; $tbAquatic.Text=$s.AquaticDb; $tbData.Text=$s.DataXlsx
$tbFigures.Text=$s.FiguresDir; $tbTables.Text=$s.TablesDir
$script:RscriptPath = Resolve-RscriptPath
if (-not $script:RscriptPath) { $setupPanel.Visible = $true; Set-Busy $true; $btnCancel.Enabled = $false }
[void]$form.ShowDialog()
