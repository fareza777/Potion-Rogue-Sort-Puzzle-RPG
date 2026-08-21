param(
    [string]$GodotPath = (Join-Path (Split-Path -Parent $PSScriptRoot) '.tools\Godot_v4.7.1-stable_win64_console.exe'),
    [string]$KeystorePath = (Join-Path (Split-Path -Parent $PSScriptRoot) 'potion-rogue-upload.keystore'),
    [string]$OutputPath = (Join-Path (Split-Path -Parent $PSScriptRoot) 'builds\PotionRogue-v1.7.5.aab')
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$resolvedGodot = (Resolve-Path -LiteralPath $GodotPath).Path
$resolvedKeystore = (Resolve-Path -LiteralPath $KeystorePath).Path
$resolvedOutput = [IO.Path]::GetFullPath($OutputPath)
$securePassword = Read-Host 'Enter the existing Potion Rogue upload-keystore password' -AsSecureString
$passwordPtr = [IntPtr]::Zero
$plainPassword = $null

try {
    $passwordPtr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
    $plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordPtr)
    $env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH = $resolvedKeystore
    $env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD = $plainPassword

    $keytool = (Get-Command keytool -ErrorAction Stop).Source
    $keyList = & $keytool -list -v -keystore $resolvedKeystore `
        -storepass:env GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw 'The keystore could not be opened. Check that the existing upload-keystore password is correct.'
    }

    $aliasMatch = $keyList | Select-String -Pattern '^Alias name:\s*(.+)$' | Select-Object -First 1
    if (-not $aliasMatch) {
        throw 'No key alias was found in the upload keystore.'
    }
    $env:GODOT_ANDROID_KEYSTORE_RELEASE_USER = $aliasMatch.Matches[0].Groups[1].Value.Trim()

    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedOutput) | Out-Null
    & $resolvedGodot --headless --path $projectRoot --export-release 'Android Release' $resolvedOutput
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $resolvedOutput)) {
        throw "Godot did not produce the signed release bundle: $resolvedOutput"
    }

    $bundle = Get-Item -LiteralPath $resolvedOutput
    Write-Output "Signed release ready: $($bundle.FullName) ($([math]::Round($bundle.Length / 1MB, 2)) MiB)"
}
finally {
    Remove-Item Env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH -ErrorAction SilentlyContinue
    Remove-Item Env:GODOT_ANDROID_KEYSTORE_RELEASE_USER -ErrorAction SilentlyContinue
    Remove-Item Env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD -ErrorAction SilentlyContinue
    $plainPassword = $null
    if ($passwordPtr -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPtr)
    }
}
