$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$source = Join-Path $root 'assets\icon\qslmm_icon.png'
$res = Join-Path $root 'android\app\src\main\res'
if (-not (Test-Path $source)) { throw "找不到图标源: $source" }
if (-not (Test-Path $res)) { throw "找不到 Android res: $res" }

Add-Type -AssemblyName System.Drawing
$src = [System.Drawing.Image]::FromFile($source)
try {
    $sizes = @{
        'mipmap-mdpi' = 48
        'mipmap-hdpi' = 72
        'mipmap-xhdpi' = 96
        'mipmap-xxhdpi' = 144
        'mipmap-xxxhdpi' = 192
    }
    foreach ($name in $sizes.Keys) {
        $dir = Join-Path $res $name
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        $bmp = New-Object System.Drawing.Bitmap($sizes[$name], $sizes[$name])
        try {
            $g = [System.Drawing.Graphics]::FromImage($bmp)
            try {
                $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
                $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
                $g.DrawImage($src, 0, 0, $sizes[$name], $sizes[$name])
            } finally { $g.Dispose() }
            $bmp.Save((Join-Path $dir 'ic_launcher.png'), [System.Drawing.Imaging.ImageFormat]::Png)
            $bmp.Save((Join-Path $dir 'ic_launcher_round.png'), [System.Drawing.Imaging.ImageFormat]::Png)
        } finally { $bmp.Dispose() }
    }
} finally { $src.Dispose() }

Write-Host 'QSLMM Android launcher icon updated.'


# Adaptive icon resources for Android 8.0+ to avoid launcher-generated white backing.
$anyDpiV26 = Join-Path $res 'mipmap-anydpi-v26'
$drawableNodpi = Join-Path $res 'drawable-nodpi'
$values = Join-Path $res 'values'
New-Item -ItemType Directory -Force -Path $anyDpiV26, $drawableNodpi, $values | Out-Null
Copy-Item -Force $source (Join-Path $drawableNodpi 'ic_launcher_foreground.png')
@'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@drawable/ic_launcher_foreground" />
</adaptive-icon>
'@ | Set-Content -Encoding UTF8 (Join-Path $anyDpiV26 'ic_launcher.xml')
Copy-Item -Force (Join-Path $anyDpiV26 'ic_launcher.xml') (Join-Path $anyDpiV26 'ic_launcher_round.xml')
$colors = Join-Path $values 'colors.xml'
if (-not (Test-Path $colors)) {
    @'
<resources>
    <color name="ic_launcher_background">#45BCEE</color>
</resources>
'@ | Set-Content -Encoding UTF8 $colors
} elseif (-not (Select-String -Path $colors -Pattern 'name="ic_launcher_background"' -Quiet)) {
    $raw = Get-Content $colors -Raw
    $raw = $raw -replace '</resources>', '    <color name="ic_launcher_background">#45BCEE</color>`r`n</resources>'
    $raw | Set-Content -Encoding UTF8 $colors
}
