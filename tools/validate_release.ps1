param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$ApkPath = "",
    [int]$WarnApkMB = 60,
    [int]$MaxApkMB = 65,
    [int]$MaxAssetMB = 8,
    [int]$MaxAudioMB = 4,
    [int]$MaxTotalArtMB = 55,
    [int]$MaxTotalAudioMB = 8,
    [int]$MaxImageDimension = 4096,
    [switch]$RunBalance,
    [int]$MaxBalanceSeconds = 900
)

$ErrorActionPreference = "Stop"
$failures = [System.Collections.Generic.List[string]]::new()
$root = (Resolve-Path -LiteralPath $ProjectRoot).Path
$isReleaseCI = $env:CI -eq "true" -or $env:CI -eq "1"

if ([string]::IsNullOrWhiteSpace($ApkPath)) {
    $Newest = Get-ChildItem -LiteralPath (Join-Path $root "builds") -Filter "*.apk" -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
    $apk = if ($Newest) { $Newest.FullName } else { "" }
} else {
    $apk = Join-Path $root $ApkPath
}

$assets = Get-ChildItem -LiteralPath (Join-Path $root "assets") -Recurse -File |
    Where-Object { $_.Extension -notin @(".import", ".uid") }
foreach ($asset in $assets) {
    if ($asset.Length -gt $MaxAssetMB * 1MB) { $failures.Add("Asset over ${MaxAssetMB}MiB: $($asset.FullName)") }
    if ($asset.FullName -Like "*\assets\audio\*" -and $asset.Length -gt $MaxAudioMB * 1MB) {
        $failures.Add("Audio asset over ${MaxAudioMB}MiB: $($asset.FullName)")
    }
}
$artBytes = ($assets | Where-Object FullName -Like "*\assets\art\*" | Measure-Object Length -Sum).Sum
$audioBytes = ($assets | Where-Object FullName -Like "*\assets\audio\*" | Measure-Object Length -Sum).Sum
if ($artBytes -gt $MaxTotalArtMB * 1MB) { $failures.Add("Aggregate art over ${MaxTotalArtMB}MiB") }
if ($audioBytes -gt $MaxTotalAudioMB * 1MB) { $failures.Add("Aggregate audio over ${MaxTotalAudioMB}MiB") }

Add-Type -AssemblyName System.Drawing
$assets | Where-Object { $_.Extension.ToLowerInvariant() -in @(".png", ".jpg", ".jpeg") } | ForEach-Object {
    try { $image = [System.Drawing.Image]::FromFile($_.FullName) }
    catch { $failures.Add("Unreadable image: $($_.FullName)"); return }
    try {
        if ($image.Width -gt $MaxImageDimension -or $image.Height -gt $MaxImageDimension) {
            $failures.Add("Image over ${MaxImageDimension}px: $($_.FullName)")
        }
    } finally { $image.Dispose() }
}

$projectText = Get-Content -LiteralPath (Join-Path $root "project.godot") -Raw
$presetText = Get-Content -LiteralPath (Join-Path $root "export_presets.cfg") -Raw
$projectVersion = [regex]::Match($projectText, 'config/version="([^"]+)"').Groups[1].Value
$exportVersion = [regex]::Match($presetText, 'version/name="([^"]+)"').Groups[1].Value
if ($projectVersion -ne $exportVersion) { $failures.Add("Version mismatch: project=$projectVersion export=$exportVersion") }

if ($apk -and (Test-Path -LiteralPath $apk)) {
    $sizeMB = [math]::Round((Get-Item -LiteralPath $apk).Length / 1MB, 2)
    if ($sizeMB -gt $MaxApkMB) { $failures.Add("APK over ${MaxApkMB}MiB: ${sizeMB}MiB") }
    elseif ($sizeMB -gt $WarnApkMB) { Write-Warning "APK over ${WarnApkMB}MiB warning threshold: ${sizeMB}MiB" }
    Write-Output "Newest APK: $apk (${sizeMB}MiB)"
} else { Write-Output "APK not present yet." }

if ($RunBalance -or $isReleaseCI) {
    $godot = Join-Path $root ".tools\Godot_v4.7.1-stable_win64_console.exe"
    if (-not (Test-Path $godot)) { $godot = (Get-Command godot -ErrorAction SilentlyContinue).Source }
    if (-not $godot) { $failures.Add("Balance validation requires Godot") }
    else {
        $timer = [Diagnostics.Stopwatch]::StartNew()
        & $godot --headless --path $root "tests/balance_simulation_test.tscn" -- --balance-long
        $timer.Stop()
        if ($LASTEXITCODE -ne 0) { $failures.Add("Balance simulation failed") }
        if ($timer.Elapsed.TotalSeconds -gt $MaxBalanceSeconds) { $failures.Add("Balance simulation exceeded budget") }
    }
}

if ($failures.Count) { $failures | ForEach-Object { Write-Error $_ }; exit 1 }
Write-Output "Release budgets passed: art $([math]::Round($artBytes/1MB,2))MiB, audio $([math]::Round($audioBytes/1MB,2))MiB, APK <= ${MaxApkMB}MiB."
