#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_dir="${HEV_SOCKS5_TUNNEL_DIR:-$repo_root/external/hev-socks5-tunnel}"
version="${HEV_SOCKS5_TUNNEL_VERSION:-2.15.0}"
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

if [[ -z "$ndk_home" ]]; then
  if [[ -z "$android_home" ]]; then
    echo "ANDROID_HOME, ANDROID_SDK_ROOT, or ANDROID_NDK_HOME must be set." >&2
    exit 1
  fi
  ndk_home="$android_home/ndk/$ndk_version"
fi

if [[ ! -d "$source_dir/.git" ]]; then
  mkdir -p "$(dirname "$source_dir")"
  git clone --recursive --branch "$version" --depth 1 \
    https://github.com/heiher/hev-socks5-tunnel.git "$source_dir"
else
  git -C "$source_dir" fetch --tags --depth 1 origin "$version"
  git -C "$source_dir" checkout "$version"
  git -C "$source_dir" submodule update --init --recursive --depth 1
fi

ndk_build="$ndk_home/ndk-build"
if [[ ! -x "$ndk_build" && -x "$ndk_home/ndk-build.cmd" ]]; then
  ndk_build="$ndk_home/ndk-build.cmd"
fi
if [[ ! -x "$ndk_build" ]]; then
  echo "ndk-build not found under $ndk_home" >&2
  exit 1
fi
if [[ "$ndk_build" == *.cmd ]]; then
  echo "Windows ndk-build.cmd cannot be run by this bash script in WSL." >&2
  echo "Use scripts/build-hev-android.ps1 for local Windows builds." >&2
  exit 1
fi

abis="${abis//,/ }"
"$ndk_build" \
  NDK_PROJECT_PATH="$source_dir" \
  APP_BUILD_SCRIPT="$source_dir/Android.mk" \
  NDK_APPLICATION_MK="$source_dir/Application.mk" \
  NDK_OUT="$repo_root/build/hev-socks5-tunnel/obj" \
  NDK_LIBS_OUT="$repo_root/app/src/main/jniLibs" \
  APP_ABI="$abis"

for abi in $abis; do
  artifact="$repo_root/app/src/main/jniLibs/$abi/libhev-socks5-tunnel.so"
  test -s "$artifact"
  sha256sum "$artifact" > "$artifact.sha256"
done
