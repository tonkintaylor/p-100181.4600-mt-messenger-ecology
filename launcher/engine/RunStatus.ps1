function Get-LogTail {
    param(
        [Parameter(Mandatory)][string]$LogText,
        [int]$Lines = 8
    )
    $nonEmpty = $LogText -split "`r?`n" | Where-Object { $_.Trim() -ne '' }
    if ($nonEmpty.Count -le $Lines) { return ($nonEmpty -join "`n") }
    return (($nonEmpty | Select-Object -Last $Lines) -join "`n")
}

function Get-RunStatus {
    param(
        [Parameter(Mandatory)][int]$ExitCode,
        [string]$LogText = '',
        [switch]$Cancelled
    )
    if ($Cancelled) {
        return [pscustomobject]@{ State = 'Cancelled'; Color = 'Gray'; Message = 'Run cancelled.' }
    }
    if ($ExitCode -eq 0) {
        return [pscustomobject]@{ State = 'Succeeded'; Color = 'Green'; Message = 'Completed successfully.' }
    }
    $tail = Get-LogTail -LogText $LogText
    return [pscustomobject]@{ State = 'Failed'; Color = 'Red'; Message = "Failed (exit $ExitCode):`n$tail" }
}
