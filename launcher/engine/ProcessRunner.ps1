function ConvertTo-ArgumentString {
    param([string[]]$Arguments = @())
    ($Arguments | ForEach-Object {
        if ($_ -match '[\s"]') { '"' + ($_ -replace '"', '\"') + '"' } else { $_ }
    }) -join ' '
}

function Invoke-PipelineProcess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [string[]]$Arguments = @(),
        [string]$WorkingDirectory = (Get-Location).Path,
        [scriptblock]$OnOutput = { param($line) },
        [string]$PrependPath,
        [string]$RHome,
        [ref]$ProcessRef,
        [scriptblock]$OnStarted = { param($p) }
    )
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName               = $FilePath
    $psi.Arguments              = ConvertTo-ArgumentString -Arguments $Arguments
    $psi.WorkingDirectory       = $WorkingDirectory
    $psi.UseShellExecute        = $false
    $psi.CreateNoWindow         = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    if ($PrependPath) {
        $existing = [string]$psi.EnvironmentVariables['Path']
        $psi.EnvironmentVariables['Path'] = "$PrependPath;$existing"
    }
    if ($RHome) { $psi.EnvironmentVariables['R_HOME'] = $RHome }

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi
    try {
        [void]$proc.Start()
    } catch {
        return [pscustomobject]@{ ExitCode = -1; Output = "Failed to launch '$FilePath': $($_.Exception.Message)" }
    }
    if ($ProcessRef) { $ProcessRef.Value = $proc }
    & $OnStarted $proc

    # R's message() (progress) goes to stderr, so stream stderr live and drain
    # stdout asynchronously to prevent a full-buffer deadlock.
    $outTask = $proc.StandardOutput.ReadToEndAsync()
    $sb = New-Object System.Text.StringBuilder
    while ($null -ne ($line = $proc.StandardError.ReadLine())) {
        [void]$sb.AppendLine($line)
        & $OnOutput $line
    }
    $proc.WaitForExit()
    $stdout = $outTask.Result
    if ($stdout) { [void]$sb.Append($stdout) }

    return [pscustomobject]@{ ExitCode = $proc.ExitCode; Output = $sb.ToString() }
}

function Stop-ProcessTree {
    param([Parameter(Mandatory)][int]$ProcessId)
    & taskkill.exe /PID $ProcessId /T /F 2>&1 | Out-Null
}
