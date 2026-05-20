param(
    [string]$CoreDir = $(if ($env:XTUNNEL_CORE_DIR) { $env:XTUNNEL_CORE_DIR } else { "" }),
    [string]$Version = $(if ($env:XTUNNEL_CORE_VERSION) { $env:XTUNNEL_CORE_VERSION } else { "android-dev" }),
    [string]$BuildDate = $(if ($env:XTUNNEL_BUILD_DATE) { $env:XTUNNEL_BUILD_DATE } else { "ci" })
)

$ErrorActionPreference = "Stop"

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
if (!$CoreDir) {
    $CoreDir = Join-Path $RepoRoot "external\x-tunnel"
}
if (!(Test-Path $CoreDir)) {
    throw "x-tunnel core directory not found: $CoreDir. Set XTUNNEL_CORE_DIR or check out the core into external\x-tunnel."
}

$OutDir = Join-Path $RepoRoot "app\src\main\jniLibs\arm64-v8a"
$OutFile = Join-Path $OutDir "libxtunnel.so"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$Commit = (& git -C $CoreDir rev-parse --short=12 HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or !$Commit) {
    throw "Failed to resolve x-tunnel core commit"
}

$previousGoos = $env:GOOS
$previousGoarch = $env:GOARCH
$previousCgo = $env:CGO_ENABLED
try {
    $env:GOOS = "android"
    $env:GOARCH = "arm64"
    $env:CGO_ENABLED = "0"
    Push-Location $CoreDir
    & go build `
        -trimpath `
        -ldflags "-s -w -X main.buildVersion=$Version -X main.buildCommit=$Commit -X main.buildDate=$BuildDate" `
        -o $OutFile `
        ".\cmd\x-tunnel"
    if ($LASTEXITCODE -ne 0) {
        throw "go build failed with exit code $LASTEXITCODE"
    }
} finally {
    if ((Get-Location).Path -eq (Resolve-Path $CoreDir).Path) {
        Pop-Location
    }
    $env:GOOS = $previousGoos
    $env:GOARCH = $previousGoarch
    $env:CGO_ENABLED = $previousCgo
}

if (!(Test-Path $OutFile)) {
    throw "Expected artifact missing: $OutFile"
}

$Hash = (Get-FileHash -Algorithm SHA256 $OutFile).Hash.ToLowerInvariant()
Set-Content -Path "$OutFile.sha256" -Value "$Hash  $OutFile" -Encoding ascii
Get-Item $OutFile | Select-Object FullName, Length
