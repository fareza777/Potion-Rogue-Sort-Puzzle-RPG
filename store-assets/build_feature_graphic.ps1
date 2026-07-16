param(
    [string]$Output = (Join-Path $PSScriptRoot 'play-store-feature-graphic.png')
)

Add-Type -AssemblyName System.Drawing

function Draw-CropFill {
    param($Graphics, $Image, [System.Drawing.RectangleF]$Target)
    $sourceRatio = $Image.Width / $Image.Height
    $targetRatio = $Target.Width / $Target.Height
    if ($sourceRatio -gt $targetRatio) {
        $sourceHeight = $Image.Height
        $sourceWidth = $sourceHeight * $targetRatio
        $sourceX = ($Image.Width - $sourceWidth) / 2
        $sourceY = 0
    } else {
        $sourceWidth = $Image.Width
        $sourceHeight = $sourceWidth / $targetRatio
        $sourceX = 0
        $sourceY = ($Image.Height - $sourceHeight) / 2
    }
    $source = [System.Drawing.RectangleF]::new($sourceX, $sourceY, $sourceWidth, $sourceHeight)
    $Graphics.DrawImage($Image, $Target, $source, [System.Drawing.GraphicsUnit]::Pixel)
}

function New-RoundedPath {
    param([System.Drawing.RectangleF]$Rect, [float]$Radius)
    $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $diameter = $Radius * 2
    $path.AddArc($Rect.X, $Rect.Y, $diameter, $diameter, 180, 90)
    $path.AddArc($Rect.Right - $diameter, $Rect.Y, $diameter, $diameter, 270, 90)
    $path.AddArc($Rect.Right - $diameter, $Rect.Bottom - $diameter, $diameter, $diameter, 0, 90)
    $path.AddArc($Rect.X, $Rect.Bottom - $diameter, $diameter, $diameter, 90, 90)
    $path.CloseFigure()
    return $path
}

$root = Split-Path $PSScriptRoot -Parent
$fontFile = Join-Path $root 'assets\fonts\Cinzel.ttf'
$fontCollection = [System.Drawing.Text.PrivateFontCollection]::new()
$fontCollection.AddFontFile($fontFile)
$titleFamily = $fontCollection.Families[0]
$titleFont = [System.Drawing.Font]::new($titleFamily, 47, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$subtitleFont = [System.Drawing.Font]::new($titleFamily, 18, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$captionFont = [System.Drawing.Font]::new($titleFamily, 17, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)

$canvas = [System.Drawing.Bitmap]::new(1024, 500, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$graphics = [System.Drawing.Graphics]::FromImage($canvas)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

$background = [System.Drawing.Image]::FromFile((Join-Path $root 'assets\art\backgrounds\shadow_crypt_battle.png'))
Draw-CropFill $graphics $background ([System.Drawing.RectangleF]::new(0, 0, 1024, 500))
$overlay = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
    [System.Drawing.Point]::new(0, 0), [System.Drawing.Point]::new(0, 500),
    [System.Drawing.Color]::FromArgb(105, 5, 2, 12),
    [System.Drawing.Color]::FromArgb(225, 3, 2, 8))
$graphics.FillRectangle($overlay, 0, 0, 1024, 500)

$center = [System.Drawing.StringFormat]::new()
$center.Alignment = [System.Drawing.StringAlignment]::Center
$center.LineAlignment = [System.Drawing.StringAlignment]::Center
$shadowBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(220, 0, 0, 0))
$goldBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 242, 190, 83))
$creamBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 225, 211, 182))
$graphics.DrawString('POTION ROGUE', $titleFont, $shadowBrush, [System.Drawing.RectangleF]::new(3, 8, 1024, 62), $center)
$graphics.DrawString('POTION ROGUE', $titleFont, $goldBrush, [System.Drawing.RectangleF]::new(0, 5, 1024, 62), $center)
$graphics.DrawString('SORT PUZZLES. BUILD POWER. CONQUER THE CRYPT.', $subtitleFont, $creamBrush,
    [System.Drawing.RectangleF]::new(0, 65, 1024, 30), $center)

$cards = @(
    @{ File = '02-cave-slime-battle.png'; X = 148; Caption = 'SORT TO ATTACK' },
    @{ File = '03-dungeon-map.png'; X = 407; Caption = 'CHOOSE YOUR PATH' },
    @{ File = '04-fire-golem-boss.png'; X = 666; Caption = 'DEFEAT EPIC BOSSES' }
)

foreach ($card in $cards) {
    $image = [System.Drawing.Image]::FromFile((Join-Path $PSScriptRoot ('screenshots\' + $card.File)))
    $rect = [System.Drawing.RectangleF]::new([float]$card.X, 103, 210, 326)
    $path = New-RoundedPath $rect 18
    $oldClip = $graphics.Clip
    $graphics.SetClip($path)
    Draw-CropFill $graphics $image $rect
    $graphics.Clip = $oldClip
    $borderPen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(255, 195, 145, 53), 4)
    $graphics.DrawPath($borderPen, $path)
    $glowPen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(95, 255, 206, 99), 10)
    $graphics.DrawPath($glowPen, $path)
    $graphics.DrawString($card.Caption, $captionFont, $goldBrush,
        [System.Drawing.RectangleF]::new([float]$card.X - 20, 440, 250, 32), $center)
    $glowPen.Dispose()
    $borderPen.Dispose()
    $path.Dispose()
    $image.Dispose()
}

$graphics.DrawString('OFFLINE ROGUELIKE PUZZLE RPG', $subtitleFont, $creamBrush,
    [System.Drawing.RectangleF]::new(0, 470, 1024, 25), $center)

$canvas.Save($Output, [System.Drawing.Imaging.ImageFormat]::Png)
$background.Dispose()
$overlay.Dispose()
$shadowBrush.Dispose()
$goldBrush.Dispose()
$creamBrush.Dispose()
$center.Dispose()
$titleFont.Dispose()
$subtitleFont.Dispose()
$captionFont.Dispose()
$fontCollection.Dispose()
$graphics.Dispose()
$canvas.Dispose()
Write-Output "Wrote $Output"
