#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
  echo "usage: $0 <name> [guest-path]" >&2
  exit 1
fi

NAME="$1"
GUEST_PATH="${2:-}"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONF_FILE="$SCRIPT_DIR/image-info.conf"

if [ ! -f "$CONF_FILE" ]; then
  echo "error: missing $CONF_FILE" >&2
  exit 1
fi

. "$CONF_FILE"

RUN_DIR="/var/lib/libvirt/images"
RUN_IMAGE="$RUN_DIR/${NAME}-run.qcow2"

if [ ! -f "$RUN_IMAGE" ]; then
  echo "error: run image not found: $RUN_IMAGE" >&2
  exit 1
fi

LOG_ROOT="$SCRIPT_DIR/logs"
OUT_DIR="$LOG_ROOT/$NAME"

mkdir -p "$LOG_ROOT"
sudo mkdir -p "$OUT_DIR"
sudo chown "$(id -u):$(id -g)" "$OUT_DIR"

if [ -n "$GUEST_PATH" ]; then
  FILES=("$GUEST_PATH")
else
  FILES=(
    /var/log/cloud-init.log
    /var/log/cloud-init-output.log
  )
fi

for path in "${FILES[@]}"; do
  out="$OUT_DIR/$(basename "$path")"

  if sudo virt-cat -a "$RUN_IMAGE" "$path" 2>/dev/null | sudo tee "$out" >/dev/null; then
    sudo chown "$(id -u):$(id -g)" "$out"
    echo "copied $path"
  else
    rm -f "$out"
    echo "missing $path"
  fi
done

echo "files copied to $OUT_DIR"
