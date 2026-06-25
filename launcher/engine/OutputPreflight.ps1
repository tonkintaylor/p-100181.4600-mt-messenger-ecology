function Test-FileLocked {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
    try {
        $fs = [System.IO.File]::Open($Path, 'Open', 'ReadWrite', 'None')
        $fs.Close(); $fs.Dispose()
        return $false
    } catch [System.IO.IOException] {
        return $true
    }
}

function Test-OutputWritable {
    param(
        [Parameter(Mandatory)][ValidateSet('Databases','Workbook')][string]$Mode,
        [Parameter(Mandatory)][string]$OutputDir,
        [Parameter(Mandatory)][string]$DataXlsx
    )
    $problems = New-Object System.Collections.Generic.List[string]

    # Output folder must exist, or its parent must exist so it can be created.
    if (-not (Test-Path -LiteralPath $OutputDir)) {
        $parent = [System.IO.Path]::GetDirectoryName($OutputDir)
        if (-not $parent -or -not (Test-Path -LiteralPath $parent)) {
            $problems.Add("Output folder cannot be created (parent does not exist): $OutputDir")
        }
    }

    if ($Mode -eq 'Workbook') {
        if (-not (Test-Path -LiteralPath $DataXlsx -PathType Leaf)) {
            $problems.Add("Data workbook not found: $DataXlsx")
        } elseif (Test-FileLocked -Path $DataXlsx) {
            $problems.Add("$([System.IO.Path]::GetFileName($DataXlsx)) is open in Excel - close it and try again.")
        }
    } else {
        # Databases mode: the workbook is produced; only a stale lock blocks us.
        if (Test-FileLocked -Path $DataXlsx) {
            $problems.Add("$([System.IO.Path]::GetFileName($DataXlsx)) is open in Excel - close it and try again.")
        }
    }

    return [pscustomobject]@{
        Ok       = ($problems.Count -eq 0)
        Problems = $problems.ToArray()
    }
}
