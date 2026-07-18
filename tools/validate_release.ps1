param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$ApkPath = "builds/PotionRogue-v10-debug.apk",
    [int]$MaxApkMB = 200,
    [int]$MaxAssetMB = 8,
    [int]$MaxImageDimension = 4096
)

$ErrorActionPreference = "Stop"
$failures = [System.Collections.Generic.List[string]]::new()
$root = (Resolve-Path -LiteralPath $ProjectRoot).Path
$apk = Join-Path $root $ApkPath

Get-ChildItem -LiteralPath (Join-Path $root "assets") -Recurse -File |
    Where-Object { $_.Extension -notin @(".import", ".uid") } |
    ForEach-Object {
        if ($_.Length -gt $MaxAssetMB * 1MB) {
            $failures.Add("Asset over ${MaxAssetMB}MB: $($_.FullName)")
        }
    }

Add-Type -AssemblyName System.Drawing
Get-ChildItem -LiteralPath (Join-Path $root "assets") -Recurse -File |
    Where-Object { $_.Extension.ToLowerInvariant() -in @(".png", ".jpg", ".jpeg") } |
    ForEach-Object {
        $assetPath = $_.FullName
        try { $image = [System.Drawing.Image]::FromFile($assetPath) }
        catch { $failures.Add("Unreadable image: $assetPath"); return }
        try {
            if ($image.Width -gt $MaxImageDimension -or $image.Height -gt $MaxImageDimension) {
                $failures.Add("Image over ${MaxImageDimension}px: $assetPath $($image.Width)x$($image.Height)")
            }
        } finally { $image.Dispose() }
    }

if (Test-Path -LiteralPath $apk) {
    $sizeMB = [math]::Round((Get-Item -LiteralPath $apk).Length / 1MB, 2)
    if ($sizeMB -gt $MaxApkMB) { $failures.Add("APK over ${MaxApkMB}MB: ${sizeMB}MB") }
    Write-Output "APK: ${sizeMB}MB"
} else {
    Write-Output "APK not present yet: $apk"
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}
Write-Output "Release budgets passed (APK <= ${MaxApkMB}MB, asset <= ${MaxAssetMB}MB, image <= ${MaxImageDimension}px)."
