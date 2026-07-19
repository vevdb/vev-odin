#!/usr/bin/env bash
# Copyright (c) Andreas Flakstad and Vev contributors
# SPDX-License-Identifier: EPL-2.0

set -euo pipefail

if [[ $# -ne 4 ]]; then
  echo "usage: scripts/package_vendor_bundle.sh <platform> <vev-version> <odin-version> <output-dir>" >&2
  exit 1
fi

PLATFORM="$1"
VEV_VERSION="$2"
ODIN_VERSION="$3"
mkdir -p "$4"
OUT_DIR="$(cd "$4" && pwd)"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VEV_RELEASE_TAG="${VEV_RELEASE_TAG:-v0.2.0-rc.2}"
VEV_REPOSITORY="${VEV_REPOSITORY:-vevdb/vev}"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/vev-odin-bundle.XXXXXX")"
STAGE="$TMP_DIR/stage/vev"
SDK_ARCHIVE="vev-native-$PLATFORM-$VEV_VERSION.zip"
OUTPUT_NAME="vev-odin-$PLATFORM-$ODIN_VERSION.zip"
BASE_URL="https://github.com/$VEV_REPOSITORY/releases/download/$VEV_RELEASE_TAG"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

case "$PLATFORM" in
  darwin-aarch64|darwin-x86_64) LIB_NAME="libvev.dylib" ;;
  linux-aarch64|linux-x86_64) LIB_NAME="libvev.so" ;;
  windows-x86_64) LIB_NAME="vev.dll" ;;
  *) echo "unsupported platform: $PLATFORM" >&2; exit 1 ;;
esac

mkdir -p "$STAGE/lib"
curl --fail --location --retry 5 --retry-all-errors \
  --silent --show-error \
  --output "$TMP_DIR/$SDK_ARCHIVE" \
  "$BASE_URL/$SDK_ARCHIVE"
curl --fail --location --retry 5 --retry-all-errors \
  --silent --show-error \
  --output "$TMP_DIR/SHA256SUMS" \
  "$BASE_URL/SHA256SUMS"

expected="$(
  awk -v name="$SDK_ARCHIVE" '
    $2 == name || $2 == ("upload/" name) {
      print $1
      exit
    }
  ' "$TMP_DIR/SHA256SUMS"
)"
[[ -n "$expected" ]] || {
  echo "$SDK_ARCHIVE is not listed in the VevDB release checksums" >&2
  exit 1
}
if command -v shasum >/dev/null 2>&1; then
  actual="$(shasum -a 256 "$TMP_DIR/$SDK_ARCHIVE" | awk '{print $1}')"
else
  actual="$(sha256sum "$TMP_DIR/$SDK_ARCHIVE" | awk '{print $1}')"
fi
[[ "$actual" == "$expected" ]] || {
  echo "checksum mismatch for $SDK_ARCHIVE" >&2
  exit 1
}

unzip -q "$TMP_DIR/$SDK_ARCHIVE" -d "$TMP_DIR/sdk"
cp "$ROOT/doc.odin" "$STAGE/doc.odin"
cp "$ROOT/vev.odin" "$STAGE/vev.odin"
cp "$ROOT/README.md" "$STAGE/README.md"
cp "$ROOT/LICENSE" "$STAGE/LICENSE"
cp "$TMP_DIR/sdk/vev-$VEV_VERSION/lib/$LIB_NAME" "$STAGE/lib/$LIB_NAME"

if command -v zip >/dev/null 2>&1; then
  (
    cd "$TMP_DIR/stage"
    zip -q -r "$OUT_DIR/$OUTPUT_NAME" vev
  )
elif command -v powershell.exe >/dev/null 2>&1 &&
     command -v cygpath >/dev/null 2>&1; then
  powershell.exe \
    -NoProfile \
    -Command \
    "Add-Type -AssemblyName System.IO.Compression.FileSystem; [System.IO.Compression.ZipFile]::CreateFromDirectory('$(cygpath -w "$STAGE")', '$(cygpath -w "$OUT_DIR/$OUTPUT_NAME")', [System.IO.Compression.CompressionLevel]::Optimal, \$true)"
else
  echo "zip or PowerShell ZipFile support is required" >&2
  exit 1
fi
echo "$OUT_DIR/$OUTPUT_NAME"
