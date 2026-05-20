#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
core_dir="${XTUNNEL_CORE_DIR:-$repo_root/external/x-tunnel}"
abis="${ANDROID_ABIS:-${ANDROID_ABI:-arm64-v8a x86_64}}"
android_home="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
ndk_version="${ANDROID_NDK_VERSION:-27.0.12077973}"
ndk_home="${ANDROID_NDK_HOME:-}"

to_unix_path() {
  local value="$1"
  if command -v wslpath >/dev/null 2>&1 && [[ "$value" =~ ^[A-Za-z]:\\ ]]; then
    wslpath "$value"
  else
    printf '%s\n' "$value"
  fi
}

android_home="$(to_unix_path "$android_home")"
ndk_home="$(to_unix_path "$ndk_home")"

if [[ -z "$ndk_home" && -n "$android_home" ]]; then
  ndk_home="$android_home/ndk/$ndk_version"
fi

if [[ ! -d "$core_dir" ]]; then
  echo "x-tunnel core directory not found: $core_dir" >&2
  echo "Set XTUNNEL_CORE_DIR or check out the core into external/x-tunnel." >&2
  exit 1
fi

go_arch_for_abi() {
  case "$1" in
    arm64-v8a) printf 'arm64\n' ;;
    x86_64) printf 'amd64\n' ;;
    *) echo "Unsupported Android ABI for x-tunnel core: $1" >&2; exit 1 ;;
  esac
}

clang_for_abi() {
  case "$1" in
    x86_64)
      if [[ -z "$ndk_home" ]]; then
        echo "ANDROID_HOME, ANDROID_SDK_ROOT, or ANDROID_NDK_HOME must be set for x86_64 Android builds." >&2
        exit 1
      fi
      printf '%s/toolchains/llvm/prebuilt/linux-x86_64/bin/x86_64-linux-android23-clang\n' "$ndk_home"
      ;;
    *) printf '\n' ;;
  esac
}

abis="${abis//,/ }"
for abi in $abis; do
  out_dir="$repo_root/app/src/main/jniLibs/$abi"
  out_file="$out_dir/libxtunnel.so"
  mkdir -p "$out_dir"
  goarch="$(go_arch_for_abi "$abi")"
  cc="$(clang_for_abi "$abi")"
  if [[ -n "$cc" && ! -x "$cc" ]]; then
    echo "Android NDK clang not found for $abi: $cc" >&2
    exit 1
  fi
  (
    cd "$core_dir"
    if [[ -n "$cc" ]]; then
      GOOS=android GOARCH="$goarch" CGO_ENABLED=1 CC="$cc" go build \
        -trimpath \
        -ldflags "-s -w -X main.buildVersion=${XTUNNEL_CORE_VERSION:-android-dev} -X main.buildCommit=$(git rev-parse --short=12 HEAD) -X main.buildDate=${XTUNNEL_BUILD_DATE:-ci}" \
        -o "$out_file" \
        ./cmd/x-tunnel
    else
      GOOS=android GOARCH="$goarch" CGO_ENABLED=0 go build \
        -trimpath \
        -ldflags "-s -w -X main.buildVersion=${XTUNNEL_CORE_VERSION:-android-dev} -X main.buildCommit=$(git rev-parse --short=12 HEAD) -X main.buildDate=${XTUNNEL_BUILD_DATE:-ci}" \
        -o "$out_file" \
        ./cmd/x-tunnel
    fi
  )
  test -s "$out_file"
  sha256sum "$out_file" > "$out_file.sha256"
done
