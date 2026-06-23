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
        [Parameter(Mandatory)][string]$DataXlsx,
        [Parameter(Mandatory)][string]$FiguresDir,
        [Parameter(Mandatory)][string]$TablesDir
    )
    $problems = New-Object System.Collections.Generic.List[string]

    $dataParent = Split-Path -Path $DataXlsx -Parent
    if ($dataParent -and -not (Test-Path -LiteralPath $dataParent)) {
        $problems.Add("Output folder does not exist: $dataParent")
    }
    if (Test-FileLocked -Path $DataXlsx) {
        $problems.Add("$([System.IO.Path]::GetFileName($DataXlsx)) is open in Excel - close it and try again.")
    }
    foreach ($dir in @($FiguresDir, $TablesDir)) {
        $parent = Split-Path -Path $dir -Parent
        if ($parent -and -not (Test-Path -LiteralPath $parent)) {
            $problems.Add("Folder path does not exist: $parent")
        }
    }

    return [pscustomobject]@{
        Ok       = ($problems.Count -eq 0)
        Problems = $problems.ToArray()
    }
}
