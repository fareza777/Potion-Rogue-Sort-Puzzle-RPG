param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$ApkPath = "builds/PotionRogue-v12-debug.apk",
	[int]$MaxAssetMB = 8,
	[int]$MaxAudioMB = 12,
	[int]$MaxApkMB = 70,
	[int]$MaxImageDimension = 4096,
	[switch]$RunBalance,
	[int]$MaxBalanceSeconds = 900
)

$ErrorActionPreference = "Stop"
$failures = [System.Collections.Generic.List[string]]::new()
$root = (Resolve-Path -LiteralPath $ProjectRoot).Path
$apk = Join-Path $root $ApkPath
$isReleaseCI = $env:CI -eq "true" -or $env:CI -eq "1"
$shouldRunBalance = $RunBalance -or $isReleaseCI

Get-ChildItem -LiteralPath (Join-Path $root "assets") -Recurse -File |
    Where-Object { $_.Extension -notin @(".import", ".uid") } |
    ForEach-Object {
        if ($_.Length -gt $MaxAssetMB * 1MB) {
            $failures.Add("Asset over ${MaxAssetMB}MB: $($_.FullName)")
        }
    }

Get-ChildItem -LiteralPath (Join-Path $root "assets\audio") -Recurse -File |
    Where-Object { $_.Extension -notin @(".import", ".uid") } |
    ForEach-Object {
        if ($_.Length -gt $MaxAudioMB * 1MB) {
            $failures.Add("Audio over ${MaxAudioMB}MB: $($_.FullName)")
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

if ($shouldRunBalance) {
	$godot = Join-Path $root ".tools\Godot_v4.7.1-stable_win64_console.exe"
	if (-not (Test-Path -LiteralPath $godot)) {
		$workspaceRoot = Split-Path -Parent (Split-Path -Parent $root)
		$godot = Join-Path $workspaceRoot ".tools\Godot_v4.7.1-stable_win64_console.exe"
	}
	if (-not (Test-Path -LiteralPath $godot)) {
		$failures.Add("Balance validation requires Godot console executable")
	} else {
		$timer = [System.Diagnostics.Stopwatch]::StartNew()
		& $godot --headless --path $root "tests/balance_simulation_test.tscn" -- --balance-long
		$timer.Stop()
		if ($LASTEXITCODE -ne 0) {
			$failures.Add("Balance simulation failed with exit code $LASTEXITCODE")
		}
		if ($timer.Elapsed.TotalSeconds -gt $MaxBalanceSeconds) {
			$failures.Add("Balance simulation exceeded ${MaxBalanceSeconds}s: $([math]::Round($timer.Elapsed.TotalSeconds, 2))s")
		}
		Write-Output "Balance simulation: $([math]::Round($timer.Elapsed.TotalSeconds, 2))s (limit ${MaxBalanceSeconds}s)"
	}
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}
Write-Output "Release budgets passed (APK <= ${MaxApkMB}MB, asset <= ${MaxAssetMB}MB, audio <= ${MaxAudioMB}MB, image <= ${MaxImageDimension}px)."
