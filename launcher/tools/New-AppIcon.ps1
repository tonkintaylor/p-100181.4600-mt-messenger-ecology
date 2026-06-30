# New-AppIcon.ps1 — build a multi-resolution app.ico (16-256 px) from a source
# image, so the icon renders crisply everywhere the Windows shell uses it
# (Start menu, taskbar, Explorer, Alt-Tab). PNG-encoded entries (Win Vista+).
#
# Defaults to upgrading the existing launcher\app.ico in place. Pass a higher-
# resolution -Source (e.g. a 256x256 PNG) for the sharpest result.
#
#   powershell.exe -NoProfile -File launcher\tools\New-AppIcon.ps1
#   powershell.exe -NoProfile -File launcher\tools\New-AppIcon.ps1 -Source art.png

param(
    [string]$Source  = (Join-Path (Split-Path -Parent $PSScriptRoot) 'app.ico'),
    [string]$OutPath = (Join-Path (Split-Path -Parent $PSScriptRoot) 'app.ico')
)
Add-Type -AssemblyName System.Drawing

function Get-SourceBitmap([string]$path) {
    if ([System.IO.Path]::GetExtension($path) -ieq '.ico') {
        # Request the largest image the icon holds, then draw from it.
        $ico = New-Object System.Drawing.Icon($path, 256, 256)
        return $ico.ToBitmap()
    }
    return New-Object System.Drawing.Bitmap($path)
}

$src   = Get-SourceBitmap $Source
$sizes = 256, 128, 64, 48, 32, 24, 16
$pngs  = @()
foreach ($s in $sizes) {
    $bmp = New-Object System.Drawing.Bitmap($s, $s)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.DrawImage($src, 0, 0, $s, $s)
    $g.Dispose()
    $ms = New-Object System.IO.MemoryStream
    $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    $pngs += , ($ms.ToArray())
    $bmp.Dispose(); $ms.Dispose()
}
$src.Dispose()

# Write the ICO: ICONDIR header + one ICONDIRENTRY per size + the PNG blobs.
$fs = [System.IO.File]::Create($OutPath)
$bw = New-Object System.IO.BinaryWriter($fs)
$bw.Write([UInt16]0); $bw.Write([UInt16]1); $bw.Write([UInt16]$sizes.Count)
$offset = 6 + 16 * $sizes.Count
for ($i = 0; $i -lt $sizes.Count; $i++) {
    $dim = if ($sizes[$i] -ge 256) { 0 } else { $sizes[$i] }  # 0 means 256
    $bw.Write([Byte]$dim); $bw.Write([Byte]$dim)
    $bw.Write([Byte]0);    $bw.Write([Byte]0)
    $bw.Write([UInt16]1);  $bw.Write([UInt16]32)
    $bw.Write([UInt32]$pngs[$i].Length); $bw.Write([UInt32]$offset)
    $offset += $pngs[$i].Length
}
foreach ($data in $pngs) { $bw.Write($data) }
$bw.Flush(); $fs.Close()
Write-Host "Wrote $OutPath ($($sizes.Count) sizes: $($sizes -join ', '))"
