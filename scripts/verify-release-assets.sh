#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
asset_dir="${1:-$repo_root/app/build/outputs}"

check_native_payload() {
  local asset="$1"
  local lib_root
  local listing

  case "$asset" in
    *.apk) lib_root="lib" ;;
    *.aab) lib_root="base/lib" ;;
    *) return 0 ;;
  esac

  listing="$(unzip -Z1 "$asset")"
  for abi in arm64-v8a x86_64; do
    for native_lib in libxtunnel.so libhev-socks5-tunnel.so; do
      if ! grep -Fx "$lib_root/$abi/$native_lib" <<< "$listing" >/dev/null; then
        echo "Missing $lib_root/$abi/$native_lib in $asset" >&2
        echo "Native entries found:" >&2
        grep -E '(^|/)lib/[^/]+/.*\.so$' <<< "$listing" >&2 || true
        return 1
      fi
    done
  done
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
    echo "Verifying $asset"
    check_native_payload "$asset"
  done
  printf '%s\0' "${assets[@]}" | xargs -0 sha256sum > "$repo_root/SHA256SUMS"
)

test -s "$repo_root/SHA256SUMS"
