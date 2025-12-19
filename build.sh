#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "usage: $0 <build-dir-name>" >&2
  exit 1
fi

NAME="$1"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONF_FILE="$SCRIPT_DIR/image-info.conf"

if [ ! -f "$CONF_FILE" ]; then
  echo "error: missing $CONF_FILE" >&2
  exit 1
fi

. "$CONF_FILE"

SRC_DIR="$SCRIPT_DIR/$NAME"
OUT_DIR="/var/lib/libvirt/cloud-init"
OUT_ISO="$OUT_DIR/$NAME.iso"

if [ ! -d "$SRC_DIR" ]; then
  echo "error: source directory does not exist: $SRC_DIR" >&2
  exit 1
fi

if [ ! -f "$SRC_DIR/user-data" ] || [ ! -f "$SRC_DIR/meta-data" ]; then
  echo "error: $SRC_DIR must contain user-data and meta-data" >&2
  exit 1
fi

sudo mkdir -p "$OUT_DIR"

sudo xorriso -as mkisofs \
  -output "$OUT_ISO" \
  -volid cidata \
  -joliet -rock \
  "$SRC_DIR/user-data" \
  "$SRC_DIR/meta-data"

echo "built: $OUT_ISO"

