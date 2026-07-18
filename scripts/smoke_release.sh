#!/usr/bin/env bash
# Copyright (c) Andreas Flakstad and Vev contributors
# SPDX-License-Identifier: EPL-2.0

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TAG="${VEV_RELEASE_TAG:-v0.1.0-rc.3}"
VERSION="${VEV_VERSION:-0.1.0}"
REPOSITORY="${VEV_REPOSITORY:-vevdb/vev}"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/vev-odin-release.XXXXXX")"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

case "$(uname -s)" in
  Darwin) OS="darwin"; LIB_NAME="libvev.dylib"; EXE_SUFFIX="" ;;
  Linux) OS="linux"; LIB_NAME="libvev.so"; EXE_SUFFIX="" ;;
  MINGW*|MSYS*|CYGWIN*) OS="windows"; LIB_NAME="vev.dll"; EXE_SUFFIX=".exe" ;;
  *) echo "unsupported OS: $(uname -s)" >&2; exit 1 ;;
esac

case "$(uname -m)" in
  arm64|aarch64) ARCH="aarch64" ;;
  x86_64|amd64) ARCH="x86_64" ;;
  *) echo "unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

PLATFORM="$OS-$ARCH"
ARCHIVE="vev-native-$PLATFORM-$VERSION.zip"
BASE_URL="https://github.com/$REPOSITORY/releases/download/$TAG"

curl --fail --location --retry 5 --retry-all-errors \
  --silent --show-error \
  --output "$TMP_DIR/$ARCHIVE" \
  "$BASE_URL/$ARCHIVE"
curl --fail --location --retry 5 --retry-all-errors \
  --silent --show-error \
  --output "$TMP_DIR/SHA256SUMS" \
  "$BASE_URL/SHA256SUMS"

expected="$(
  awk -v name="$ARCHIVE" '
    $2 == name || $2 == ("upload/" name) {
      print $1
      exit
    }
  ' "$TMP_DIR/SHA256SUMS"
)"
[[ -n "$expected" ]] || {
  echo "$ARCHIVE is not listed in the release checksums" >&2
  exit 1
}
if command -v shasum >/dev/null 2>&1; then
  actual="$(shasum -a 256 "$TMP_DIR/$ARCHIVE" | awk '{print $1}')"
else
  actual="$(sha256sum "$TMP_DIR/$ARCHIVE" | awk '{print $1}')"
fi
[[ "$actual" == "$expected" ]] || {
  echo "checksum mismatch for $ARCHIVE" >&2
  exit 1
}

unzip -q "$TMP_DIR/$ARCHIVE" -d "$TMP_DIR/sdk"
LIB_PATH="$TMP_DIR/sdk/vev-$VERSION/lib/$LIB_NAME"
[[ -f "$LIB_PATH" ]] || {
  echo "native SDK does not contain $LIB_NAME" >&2
  exit 1
}

odin check "$ROOT" -no-entry-point
odin build "$ROOT/examples/basic" -out:"$TMP_DIR/vev_odin_smoke$EXE_SUFFIX"
PATH="$(dirname "$LIB_PATH"):$PATH" \
  "$TMP_DIR/vev_odin_smoke$EXE_SUFFIX" "$(dirname "$(dirname "$LIB_PATH")")" >/dev/null

echo ":vev-odin-release-ok"
