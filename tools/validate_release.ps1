param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$ApkPath = "",
    [string]$ReleaseArtifactPath = "",
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
    $NewestDebug = Get-ChildItem -LiteralPath (Join-Path $root "builds") -Filter "*.apk" -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
    $debugApk = if ($NewestDebug) { $NewestDebug.FullName } else { "" }
} else {
    $debugApk = if ([IO.Path]::IsPathRooted($ApkPath)) { $ApkPath }
    else { Join-Path $root $ApkPath }
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

$storySceneRoot = Join-Path $root "assets\art\story_scenes"
$storyWebps = @(Get-ChildItem -LiteralPath $storySceneRoot -Filter "*.webp" -File -ErrorAction SilentlyContinue)
if ($storyWebps.Count -ne 40) { $failures.Add("Expected 40 story-scene WebP paintings, found $($storyWebps.Count)") }
foreach ($webp in $storyWebps) {
    $importPath = Join-Path $storySceneRoot ($webp.Name + ".import")
    if (-not (Test-Path -LiteralPath $importPath)) {
        $failures.Add("Missing WebP import policy: $importPath")
        continue
    }
    $importText = Get-Content -LiteralPath $importPath -Raw
    if ($importText -notmatch '(?m)^compress/mode=1\r?$') {
        $failures.Add("Story WebP must use package-safe lossy import compress/mode=1: $importPath")
    }
}

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
$configuredExport = [regex]::Match($presetText, 'export_path="([^"]+)"').Groups[1].Value
$releaseArtifact = if (-not [string]::IsNullOrWhiteSpace($ReleaseArtifactPath)) {
    if ([IO.Path]::IsPathRooted($ReleaseArtifactPath)) { $ReleaseArtifactPath }
    else { Join-Path $root $ReleaseArtifactPath }
} elseif (-not [string]::IsNullOrWhiteSpace($configuredExport)) {
    Join-Path $root $configuredExport
} else { "" }
$projectVersion = [regex]::Match($projectText, 'config/version="([^"]+)"').Groups[1].Value
$exportVersion = [regex]::Match($presetText, 'version/name="([^"]+)"').Groups[1].Value
if ($projectVersion -ne $exportVersion) { $failures.Add("Version mismatch: project=$projectVersion export=$exportVersion") }

function Get-ArchiveComposition([string]$Path) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($Path)
    try {
        [long]$nativeBytes = 0
        [long]$assetBytes = 0
        [long]$otherBytes = 0
        foreach ($entry in $archive.Entries) {
            $name = $entry.FullName.Replace('\', '/')
            if ($name -match '(^|/)lib/') { $nativeBytes += $entry.CompressedLength }
            elseif ($name -match '(^|/)assets/') { $assetBytes += $entry.CompressedLength }
            else { $otherBytes += $entry.CompressedLength }
        }
        return @{
            NativeMB = [math]::Round($nativeBytes / 1MB, 2)
            AssetsMB = [math]::Round($assetBytes / 1MB, 2)
            OtherMB = [math]::Round($otherBytes / 1MB, 2)
        }
    } finally { $archive.Dispose() }
}

if ($releaseArtifact -and (Test-Path -LiteralPath $releaseArtifact)) {
    $sizeMB = [math]::Round((Get-Item -LiteralPath $releaseArtifact).Length / 1MB, 2)
    if ($sizeMB -gt $MaxApkMB) { $failures.Add("Release artifact over ${MaxApkMB}MiB: ${sizeMB}MiB") }
    elseif ($sizeMB -gt $WarnApkMB) { Write-Warning "Release artifact over ${WarnApkMB}MiB warning threshold: ${sizeMB}MiB" }
    $releaseLabel = if ([IO.Path]::GetExtension($releaseArtifact) -eq ".aab") { "Release AAB" } else { "Release APK" }
    Write-Output "Configured release artifact - ${releaseLabel}: $releaseArtifact (${sizeMB}MiB)"
    try {
        $composition = Get-ArchiveComposition $releaseArtifact
        Write-Output "Native/assets composition: native $($composition.NativeMB)MiB, assets $($composition.AssetsMB)MiB, other $($composition.OtherMB)MiB"
    } catch { $failures.Add("Cannot inspect configured release artifact: $($_.Exception.Message)") }
} elseif (-not [string]::IsNullOrWhiteSpace($ReleaseArtifactPath)) {
    $failures.Add("Requested release artifact not found: $releaseArtifact")
} else { Write-Output "Configured release artifact not present yet." }

if ($debugApk -and (Test-Path -LiteralPath $debugApk)) {
    $debugSizeMB = [math]::Round((Get-Item -LiteralPath $debugApk).Length / 1MB, 2)
    Write-Output "Debug APK: $debugApk (${debugSizeMB}MiB; informational, includes debug payload)"
} else { Write-Output "Debug APK not present yet." }

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
Write-Output "Release budgets passed: art $([math]::Round($artBytes/1MB,2))MiB, audio $([math]::Round($audioBytes/1MB,2))MiB, configured artifact <= ${MaxApkMB}MiB."
