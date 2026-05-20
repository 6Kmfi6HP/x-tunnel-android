param(
    [string]$Version = $(if ($env:HEV_SOCKS5_TUNNEL_VERSION) { $env:HEV_SOCKS5_TUNNEL_VERSION } else { "2.15.0" }),
    [string]$Abi = $(if ($env:ANDROID_ABI) { $env:ANDROID_ABI } else { "arm64-v8a" }),
    [string]$NdkVersion = $(if ($env:ANDROID_NDK_VERSION) { $env:ANDROID_NDK_VERSION } else { "27.0.12077973" })
)

$ErrorActionPreference = "Stop"

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$SourceDir = if ($env:HEV_SOCKS5_TUNNEL_DIR) {
    $env:HEV_SOCKS5_TUNNEL_DIR
} else {
    Join-Path $RepoRoot "external\hev-socks5-tunnel"
}

$AndroidHome = if ($env:ANDROID_HOME) {
    $env:ANDROID_HOME
} elseif ($env:ANDROID_SDK_ROOT) {
    $env:ANDROID_SDK_ROOT
} else {
    Join-Path $env:LOCALAPPDATA "Android\Sdk"
}

$NdkHome = if ($env:ANDROID_NDK_HOME) {
    $env:ANDROID_NDK_HOME
} else {
    Join-Path $AndroidHome "ndk\$NdkVersion"
}

$NdkBuild = Join-Path $NdkHome "ndk-build.cmd"
if (!(Test-Path $NdkBuild)) {
    throw "ndk-build.cmd not found: $NdkBuild"
}

if (!(Test-Path (Join-Path $SourceDir ".git"))) {
    New-Item -ItemType Directory -Force -Path (Split-Path $SourceDir) | Out-Null
    git clone --recursive --branch $Version --depth 1 https://github.com/heiher/hev-socks5-tunnel.git $SourceDir
} else {
    git -C $SourceDir fetch --tags --depth 1 origin $Version
    git -C $SourceDir checkout $Version
    git -C $SourceDir submodule update --init --recursive --depth 1
}

function Convert-WslSymlinksToFiles {
    param([string]$Root)

    $bash = Get-Command bash -ErrorAction SilentlyContinue
    if (!$bash) {
        return
    }

    $escaped = $Root.Replace("'", "'\''")
    $wslRoot = (& bash -lc "wslpath '$escaped'").Trim()
    if (!$wslRoot) {
        return
    }

    $tempScript = Join-Path $env:TEMP "materialize-wsl-symlinks.sh"
    $scriptContent = @'
#!/usr/bin/env bash
set -euo pipefail
cd "$1"
find . -type l -print0 | while IFS= read -r -d '' link; do
  target=$(readlink "$link")
  src=$(realpath -m "$(dirname "$link")/$target")
  rm "$link"
  cp "$src" "$link"
done
'@
    [System.IO.File]::WriteAllText(
        $tempScript,
        $scriptContent.Replace("`r`n", "`n") + "`n",
        [System.Text.Encoding]::ASCII
    )
    $escapedScript = $tempScript.Replace("'", "'\''")
    $wslScript = (& bash -lc "wslpath '$escapedScript'").Trim()
    & bash $wslScript $wslRoot
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to materialize WSL symlinks under $Root"
    }
}

Convert-WslSymlinksToFiles -Root $SourceDir

$JniLibsOut = Join-Path $RepoRoot "app\src\main\jniLibs"
$ObjOut = Join-Path $RepoRoot "build\hev-socks5-tunnel\obj"

$previousHostOs = $env:HOST_OS
$env:HOST_OS = "windows"
& $NdkBuild `
    "NDK_PROJECT_PATH=$SourceDir" `
    "APP_BUILD_SCRIPT=$(Join-Path $SourceDir 'Android.mk')" `
    "NDK_APPLICATION_MK=$(Join-Path $SourceDir 'Application.mk')" `
    "NDK_OUT=$ObjOut" `
    "NDK_LIBS_OUT=$JniLibsOut" `
    "APP_ABI=$Abi"
$env:HOST_OS = $previousHostOs

if ($LASTEXITCODE -ne 0) {
    throw "ndk-build failed with exit code $LASTEXITCODE"
}

$Artifact = Join-Path $JniLibsOut "$Abi\libhev-socks5-tunnel.so"
if (!(Test-Path $Artifact)) {
    throw "Expected artifact missing: $Artifact"
}

$Hash = (Get-FileHash -Algorithm SHA256 $Artifact).Hash.ToLowerInvariant()
Set-Content -Path "$Artifact.sha256" -Value "$Hash  $Artifact" -Encoding ascii
Get-Item $Artifact | Select-Object FullName, Length
