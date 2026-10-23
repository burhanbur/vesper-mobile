# Regenerate Android launcher/splash assets from the existing Vesper logo.
# Run on Windows: powershell -File scripts/generate-android-branding.ps1
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$projectRoot = Split-Path -Parent $PSScriptRoot
$resourceRoot = Join-Path $projectRoot 'android/app/src/main/res'
$source = [System.Drawing.Bitmap]::new((Join-Path $projectRoot 'assets/images/logo.png'))
try {
    $left = $source.Width
    $top = $source.Height
    $right = 0
    $bottom = 0
    for ($y = 0; $y -lt $source.Height; $y++) {
        for ($x = 0; $x -lt $source.Width; $x++) {
            if ($source.GetPixel($x, $y).A -gt 8) {
                $left = [Math]::Min($left, $x)
                $top = [Math]::Min($top, $y)
                $right = [Math]::Max($right, $x)
                $bottom = [Math]::Max($bottom, $y)
            }
        }
    }
    $crop = [System.Drawing.Rectangle]::new($left, $top, $right - $left + 1, $bottom - $top + 1)
    function Write-Logo([string]$relativePath, [int]$size, [double]$fraction, [bool]$opaque) {
        $destination = Join-Path $resourceRoot $relativePath
        New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
        $bitmap = [System.Drawing.Bitmap]::new($size, $size)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        try {
            $background = if ($opaque) { [System.Drawing.Color]::White } else { [System.Drawing.Color]::Transparent }
            $graphics.Clear($background)
            $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $scale = $size * $fraction / [Math]::Max($crop.Width, $crop.Height)
            $width = [int][Math]::Round($crop.Width * $scale)
            $height = [int][Math]::Round($crop.Height * $scale)
            $target = [System.Drawing.Rectangle]::new([int](($size - $width) / 2), [int](($size - $height) / 2), $width, $height)
            $graphics.DrawImage($source, $target, $crop, [System.Drawing.GraphicsUnit]::Pixel)
            $bitmap.Save($destination, [System.Drawing.Imaging.ImageFormat]::Png)
        } finally {
            $graphics.Dispose()
            $bitmap.Dispose()
        }
    }
    foreach ($density in @(
        @{ Name = 'mdpi'; Scale = 1 },
        @{ Name = 'hdpi'; Scale = 1.5 },
        @{ Name = 'xhdpi'; Scale = 2 },
        @{ Name = 'xxhdpi'; Scale = 3 },
        @{ Name = 'xxxhdpi'; Scale = 4 }
    )) {
        Write-Logo "mipmap-$($density.Name)/ic_launcher.png" (48 * $density.Scale) 0.72 $true
        # Keep the entire mark inside the 66dp adaptive-icon safe circle.
        Write-Logo "drawable-$($density.Name)/ic_launcher_foreground.png" (108 * $density.Scale) 0.46 $false
        Write-Logo "drawable-$($density.Name)/splash_logo.png" (144 * $density.Scale) 0.67 $false
    }
    Write-Output 'Generated Android branding from assets/images/logo.png.'
} finally {
    $source.Dispose()
}
