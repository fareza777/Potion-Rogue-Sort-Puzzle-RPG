param(
    [string]$Output = (Join-Path (Split-Path $PSScriptRoot -Parent) 'assets\art\app_icon.png')
)

Add-Type -AssemblyName System.Drawing
$root = Split-Path $PSScriptRoot -Parent
$canvas = [System.Drawing.Bitmap]::new(512, 512, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$graphics = [System.Drawing.Graphics]::FromImage($canvas)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$graphics.Clear([System.Drawing.Color]::FromArgb(255, 8, 5, 14))

$background = [System.Drawing.Image]::FromFile((Join-Path $root 'assets\art\backgrounds\shadow_crypt_battle.png'))
$source = [System.Drawing.RectangleF]::new(($background.Width - $background.Height) / 2, 0,
    $background.Height, $background.Height)
$target = [System.Drawing.RectangleF]::new(0, 0, 512, 512)
$graphics.DrawImage($background, $target, $source, [System.Drawing.GraphicsUnit]::Pixel)

$dark = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(70, 5, 2, 11))
$graphics.FillEllipse($dark, 24, 24, 464, 464)
$slime = [System.Drawing.Image]::FromFile((Join-Path $root 'assets\art\enemies\slime\cave_slime.png'))
$graphics.DrawImage($slime, [System.Drawing.RectangleF]::new(22, 68, 468, 390))

$outer = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(255, 239, 185, 66), 16)
$inner = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(230, 66, 38, 18), 7)
$graphics.DrawEllipse($outer, 15, 15, 482, 482)
$graphics.DrawEllipse($inner, 29, 29, 454, 454)

$canvas.Save($Output, [System.Drawing.Imaging.ImageFormat]::Png)
$inner.Dispose()
$outer.Dispose()
$slime.Dispose()
$dark.Dispose()
$background.Dispose()
$graphics.Dispose()
$canvas.Dispose()
Write-Output "Wrote $Output"
