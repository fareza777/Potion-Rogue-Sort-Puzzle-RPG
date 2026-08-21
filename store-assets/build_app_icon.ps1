param(
    [string]$MasterInput = (Join-Path (Split-Path $PSScriptRoot -Parent) 'assets\art\app_icon_v3_master.png'),
    [string]$ProjectOutput = (Join-Path (Split-Path $PSScriptRoot -Parent) 'assets\art\app_icon_v3.png'),
    [string]$StoreOutput = (Join-Path $PSScriptRoot 'app-icon-v3-512.png')
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

function Save-ResizedPng {
    param(
        [Parameter(Mandatory = $true)][string]$InputPath,
        [Parameter(Mandatory = $true)][string]$OutputPath,
        [Parameter(Mandatory = $true)][int]$Size
    )

    $source = [System.Drawing.Image]::FromFile($InputPath)
    try {
        $canvas = [System.Drawing.Bitmap]::new($Size, $Size,
            [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        try {
            $graphics = [System.Drawing.Graphics]::FromImage($canvas)
            try {
                $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
                $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
                $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
                $graphics.DrawImage($source, 0, 0, $Size, $Size)
            }
            finally {
                $graphics.Dispose()
            }
            $canvas.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
        }
        finally {
            $canvas.Dispose()
        }
    }
    finally {
        $source.Dispose()
    }
}

# Android's largest launcher foreground target is 432 px. A 448 px source
# preserves a small resampling margin without packaging an oversized texture.
Save-ResizedPng -InputPath $MasterInput -OutputPath $ProjectOutput -Size 448
Save-ResizedPng -InputPath $MasterInput -OutputPath $StoreOutput -Size 512
Write-Output "Wrote $ProjectOutput"
Write-Output "Wrote $StoreOutput"
