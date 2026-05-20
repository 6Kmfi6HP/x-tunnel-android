#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
core_dir="${XTUNNEL_CORE_DIR:-$repo_root/external/x-tunnel}"
out_dir="$repo_root/app/src/main/jniLibs/arm64-v8a"
out_file="$out_dir/libxtunnel.so"

if [[ ! -d "$core_dir" ]]; then
  echo "x-tunnel core directory not found: $core_dir" >&2
  echo "Set XTUNNEL_CORE_DIR or check out the core into external/x-tunnel." >&2
  exit 1
fi

mkdir -p "$out_dir"
(
  cd "$core_dir"
  GOOS=android GOARCH=arm64 CGO_ENABLED=0 go build \
    -trimpath \
    -ldflags "-s -w -X main.buildVersion=${XTUNNEL_CORE_VERSION:-android-dev} -X main.buildCommit=$(git rev-parse --short=12 HEAD) -X main.buildDate=${XTUNNEL_BUILD_DATE:-ci}" \
    -o "$out_file" \
    ./cmd/x-tunnel
)

test -s "$out_file"
sha256sum "$out_file" > "$out_file.sha256"

