Add-Type -AssemblyName System.Drawing
$bmp = New-Object System.Drawing.Bitmap 32, 32
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.Clear([System.Drawing.Color]::FromArgb(0, 102, 68))
$font = New-Object System.Drawing.Font('Segoe UI', 14, [System.Drawing.FontStyle]::Bold)
$g.DrawString('M', $font, [System.Drawing.Brushes]::White, 6, 4)
$g.Dispose()
$icon = [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
$out = Join-Path (Split-Path -Parent $PSScriptRoot) 'app.ico'
$fs = [System.IO.File]::Create($out)
$icon.Save($fs); $fs.Close()
Write-Host "Wrote $out"
