#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "usage: $0 <name>" >&2
  exit 1
fi

NAME="$1"

RUN_IMAGE="/var/lib/libvirt/images/${NAME}-run.qcow2"
CI_ISO="/var/lib/libvirt/cloud-init/${NAME}.iso"

# Destroy and undefine VM if it exists
if sudo virsh dominfo "$NAME" >/dev/null 2>&1; then
  echo "cleaning VM: $NAME"

  sudo virsh destroy "$NAME" >/dev/null 2>&1 || true
  sudo virsh undefine "$NAME" --nvram >/dev/null 2>&1 || true
else
  echo "VM '$NAME' not defined"
fi

# Remove per-run qcow2 overlay
if [ -f "$RUN_IMAGE" ]; then
  echo "removing run disk: $RUN_IMAGE"
  sudo rm -f "$RUN_IMAGE"
fi

# Remove cloud-init ISO
if [ -f "$CI_ISO" ]; then
  echo "removing cloud-init ISO: $CI_ISO"
  sudo rm -f "$CI_ISO"
fi

echo "bring-down complete for '$NAME'"

