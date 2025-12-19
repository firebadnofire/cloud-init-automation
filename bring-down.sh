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
CI_DIR="/var/lib/libvirt/cloud-init"

RUN_IMAGE="$RUN_DIR/${NAME}-run.qcow2"
CI_ISO="$CI_DIR/${NAME}.iso"

if sudo virsh dominfo "$NAME" >/dev/null 2>&1; then
  echo "cleaning VM: $NAME"
  sudo virsh destroy "$NAME" >/dev/null 2>&1 || true
  sudo virsh undefine "$NAME" --nvram >/dev/null 2>&1 || true
else
  echo "VM '$NAME' not defined"
fi

if [ -f "$RUN_IMAGE" ]; then
  echo "removing run disk: $RUN_IMAGE"
  sudo rm -f "$RUN_IMAGE"
fi

if [ -f "$CI_ISO" ]; then
  echo "removing cloud-init ISO: $CI_ISO"
  sudo rm -f "$CI_ISO"
fi

echo "bring-down complete for '$NAME'"

