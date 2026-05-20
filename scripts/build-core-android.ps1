param(
    [string]$CoreDir = $(if ($env:XTUNNEL_CORE_DIR) { $env:XTUNNEL_CORE_DIR } else { "" }),
    [string]$Version = $(if ($env:XTUNNEL_CORE_VERSION) { $env:XTUNNEL_CORE_VERSION } else { "android-dev" }),
    [string]$BuildDate = $(if ($env:XTUNNEL_BUILD_DATE) { $env:XTUNNEL_BUILD_DATE } else { "ci" }),
    [string]$Abis = $(if ($env:ANDROID_ABIS) { $env:ANDROID_ABIS } elseif ($env:ANDROID_ABI) { $env:ANDROID_ABI } else { "arm64-v8a x86_64" }),
    [string]$NdkVersion = $(if ($env:ANDROID_NDK_VERSION) { $env:ANDROID_NDK_VERSION } else { "27.0.12077973" })
)

$ErrorActionPreference = "Stop"

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
if (!$CoreDir) {
    $CoreDir = Join-Path $RepoRoot "external\x-tunnel"
}
if (!(Test-Path $CoreDir)) {
    throw "x-tunnel core directory not found: $CoreDir. Set XTUNNEL_CORE_DIR or check out the core into external\x-tunnel."
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

function Resolve-AbiList {
    param([string]$Value)
    return $Value -split '[,\s]+' | Where-Object { $_ }
}

function Resolve-GoArch {
    param([string]$Abi)
    switch ($Abi) {
        "arm64-v8a" { return "arm64" }
        "x86_64" { return "amd64" }
        default { throw "Unsupported Android ABI for x-tunnel core: $Abi" }
    }
}

function Resolve-AndroidClang {
    param([string]$Abi)
    $triple = switch ($Abi) {
        "arm64-v8a" { "aarch64-linux-android23-clang.cmd" }
        "x86_64" { "x86_64-linux-android23-clang.cmd" }
        default { return "" }
    }
    $cc = Join-Path $NdkHome "toolchains\llvm\prebuilt\windows-x86_64\bin\$triple"
    if (!(Test-Path $cc)) {
        throw "Android NDK clang not found for $Abi`: $cc"
    }
    return $cc
}

$Commit = (& git -C $CoreDir rev-parse --short=12 HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or !$Commit) {
    throw "Failed to resolve x-tunnel core commit"
}

$AbiList = Resolve-AbiList $Abis
foreach ($Abi in $AbiList) {
    $OutDir = Join-Path $RepoRoot "app\src\main\jniLibs\$Abi"
    $OutFile = Join-Path $OutDir "libxtunnel.so"
    New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

    $previousGoos = $env:GOOS
    $previousGoarch = $env:GOARCH
    $previousCgo = $env:CGO_ENABLED
    $previousCc = $env:CC
    try {
        $env:GOOS = "android"
        $env:GOARCH = Resolve-GoArch $Abi
        $cc = Resolve-AndroidClang $Abi
        if ($cc) {
            $env:CGO_ENABLED = "1"
            $env:CC = $cc
        } else {
            $env:CGO_ENABLED = "0"
            $env:CC = $null
        }
        Push-Location $CoreDir
        & go build `
            -trimpath `
            -ldflags "-s -w -X main.buildVersion=$Version -X main.buildCommit=$Commit -X main.buildDate=$BuildDate" `
            -o $OutFile `
            ".\cmd\x-tunnel"
        if ($LASTEXITCODE -ne 0) {
            throw "go build failed for $Abi with exit code $LASTEXITCODE"
        }
    } finally {
        if ((Get-Location).Path -eq (Resolve-Path $CoreDir).Path) {
            Pop-Location
        }
        $env:GOOS = $previousGoos
        $env:GOARCH = $previousGoarch
        $env:CGO_ENABLED = $previousCgo
        $env:CC = $previousCc
    }

    if (!(Test-Path $OutFile)) {
        throw "Expected artifact missing: $OutFile"
    }

    $Hash = (Get-FileHash -Algorithm SHA256 $OutFile).Hash.ToLowerInvariant()
    Set-Content -Path "$OutFile.sha256" -Value "$Hash  $OutFile" -Encoding ascii
    Get-Item $OutFile | Select-Object FullName, Length
}
