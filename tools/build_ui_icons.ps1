param([string]$OutputDirectory = "assets\art\ui\controls")

Add-Type -AssemblyName System.Drawing
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null

function New-IconCanvas {
    $bitmap = [System.Drawing.Bitmap]::new(512, 512, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.Clear([System.Drawing.Color]::Transparent)
    $shadow = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(130, 0, 0, 0))
    $graphics.FillEllipse($shadow, 46, 54, 420, 420)
    $body = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 17, 14, 22))
    $graphics.FillEllipse($body, 42, 42, 420, 420)
    $outer = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(255, 228, 174, 64), 18)
    $inner = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(255, 92, 58, 25), 8)
    $graphics.DrawEllipse($outer, 42, 42, 420, 420)
    $graphics.DrawEllipse($inner, 62, 62, 380, 380)
    $shine = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(180, 255, 224, 133), 5)
    $graphics.DrawArc($shine, 72, 72, 360, 360, 205, 112)
    $shadow.Dispose(); $body.Dispose(); $outer.Dispose(); $inner.Dispose(); $shine.Dispose()
    return @($bitmap, $graphics)
}

function Save-Icon($name, [scriptblock]$draw) {
    $pair = New-IconCanvas
    $bitmap = $pair[0]; $graphics = $pair[1]
    & $draw $graphics
    $path = Join-Path $OutputDirectory ("icon_" + $name + ".png")
    $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose(); $bitmap.Dispose()
    Write-Output "Wrote $path"
}

$gold = [System.Drawing.Color]::FromArgb(255, 242, 190, 76)
$highlight = [System.Drawing.Color]::FromArgb(255, 255, 230, 147)
$glyphPen = [System.Drawing.Pen]::new($gold, 30)
$glyphPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$glyphPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
$glyphBrush = [System.Drawing.SolidBrush]::new($gold)
$lightPen = [System.Drawing.Pen]::new($highlight, 8)

Save-Icon 'undo' {
    param($g)
    $g.DrawArc($glyphPen, 145, 142, 235, 235, 208, 244)
    $points = [System.Drawing.PointF[]]@(
        [System.Drawing.PointF]::new(118, 188),
        [System.Drawing.PointF]::new(210, 172),
        [System.Drawing.PointF]::new(169, 257))
    $g.FillPolygon($glyphBrush, $points)
    $g.DrawArc($lightPen, 166, 159, 194, 194, 222, 82)
}

Save-Icon 'mix' {
    param($g)
    $path1 = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $path1.AddBezier(132, 177, 226, 177, 270, 334, 378, 334)
    $g.DrawPath($glyphPen, $path1)
    $path2 = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $path2.AddBezier(132, 334, 226, 334, 270, 177, 378, 177)
    $g.DrawPath($glyphPen, $path2)
    $g.FillPolygon($glyphBrush, [System.Drawing.PointF[]]@([System.Drawing.PointF]::new(354,142),[System.Drawing.PointF]::new(414,177),[System.Drawing.PointF]::new(354,212)))
    $g.FillPolygon($glyphBrush, [System.Drawing.PointF[]]@([System.Drawing.PointF]::new(354,299),[System.Drawing.PointF]::new(414,334),[System.Drawing.PointF]::new(354,369)))
    $path1.Dispose(); $path2.Dispose()
}

Save-Icon 'pause' {
    param($g)
    $g.FillRectangle($glyphBrush, 174, 146, 58, 220)
    $g.FillRectangle($glyphBrush, 280, 146, 58, 220)
    $g.DrawLine($lightPen, 188, 164, 188, 344)
    $g.DrawLine($lightPen, 294, 164, 294, 344)
}

Save-Icon 'music' {
    param($g)
    $g.DrawLine($glyphPen, 250, 164, 250, 321)
    $g.DrawLine($glyphPen, 250, 164, 350, 143)
    $g.DrawLine($glyphPen, 350, 143, 350, 291)
    $g.FillEllipse($glyphBrush, 174, 292, 92, 66)
    $g.FillEllipse($glyphBrush, 274, 262, 92, 66)
    $g.DrawLine($lightPen, 269, 181, 331, 168)
}

Save-Icon 'sound' {
    param($g)
    $speaker = [System.Drawing.PointF[]]@(
        [System.Drawing.PointF]::new(145,225),[System.Drawing.PointF]::new(203,225),
        [System.Drawing.PointF]::new(278,165),[System.Drawing.PointF]::new(278,347),
        [System.Drawing.PointF]::new(203,287),[System.Drawing.PointF]::new(145,287))
    $g.FillPolygon($glyphBrush, $speaker)
    $g.DrawArc($glyphPen, 263, 188, 106, 136, -55, 110)
    $g.DrawArc($lightPen, 289, 210, 56, 92, -52, 104)
}

Save-Icon 'vibration' {
    param($g)
    $g.DrawRectangle($glyphPen, 202, 139, 108, 234)
    $g.DrawArc($glyphPen, 136, 187, 70, 138, 105, 150)
    $g.DrawArc($glyphPen, 306, 187, 70, 138, -75, 150)
    $g.DrawArc($lightPen, 158, 211, 44, 90, 105, 150)
    $g.DrawArc($lightPen, 310, 211, 44, 90, -75, 150)
}

$glyphPen.Dispose(); $glyphBrush.Dispose(); $lightPen.Dispose()
