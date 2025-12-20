#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "usage: $0 <name>" >&2
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

RUN_DIR="/var/lib/libvirt/images"
RUN_IMAGE="$RUN_DIR/${NAME}-run.qcow2"

LOG_ROOT="$SCRIPT_DIR/logs"
OUT_DIR="$LOG_ROOT/$NAME"

if [ ! -f "$RUN_IMAGE" ]; then
  echo "error: run image not found: $RUN_IMAGE" >&2
  exit 1
fi

sudo mkdir -p "$OUT_DIR"
sudo chown "$(id -u):$(id -g)" "$OUT_DIR"

LOGS=(
  /var/log/cloud-init.log
  /var/log/cloud-init-output.log
)

for log in "${LOGS[@]}"; do
  out="$OUT_DIR/$(basename "$log")"
  if sudo virt-cat -a "$RUN_IMAGE" "$log" 2>/dev/null | sudo tee "$out" >/dev/null; then
    sudo chown "$(id -u):$(id -g)" "$out"
    echo "copied $(basename "$log")"
  else
    rm -f "$out"
    echo "missing $(basename "$log")"
  fi
done

echo "logs copied to $OUT_DIR"
