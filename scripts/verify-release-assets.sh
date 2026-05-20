#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
asset_dir="${1:-$repo_root/app/build/outputs}"

check_native_payload() {
  local asset="$1"
  local lib_prefix

  case "$asset" in
    *.apk) lib_prefix="lib/arm64-v8a" ;;
    *.aab) lib_prefix="base/lib/arm64-v8a" ;;
    *) return 0 ;;
  esac

  unzip -Z1 "$asset" | grep -Fx "$lib_prefix/libxtunnel.so" >/dev/null
  unzip -Z1 "$asset" | grep -Fx "$lib_prefix/libhev-socks5-tunnel.so" >/dev/null
}

(
  cd "$repo_root"
  rel_asset_dir="$(realpath --relative-to="$repo_root" "$asset_dir")"
  mapfile -d '' assets < <(
    find "$rel_asset_dir" -type f \( -name "*.apk" -o -name "*.aab" \) -print0 |
      sort -z
  )
  test "${#assets[@]}" -gt 0
  for asset in "${assets[@]}"; do
    check_native_payload "$asset"
  done
  printf '%s\0' "${assets[@]}" | xargs -0 sha256sum > "$repo_root/SHA256SUMS"
)

test -s "$repo_root/SHA256SUMS"
