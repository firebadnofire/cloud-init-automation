#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "usage: $0 <name>" >&2
  exit 1
fi

NAME="$1"

BASE_DIR="$HOME/cloud-init"
BUILD_SCRIPT="$BASE_DIR/build.sh"

RO_IMAGE="/var/lib/libvirt/ro-images/debian-13-genericcloud-amd64.qcow2"
RUN_IMAGE="/var/lib/libvirt/images/${NAME}-run.qcow2"
CI_ISO="/var/lib/libvirt/cloud-init/${NAME}.iso"

if [ ! -x "$BUILD_SCRIPT" ]; then
  echo "error: build.sh not found or not executable at $BUILD_SCRIPT" >&2
  exit 1
fi

if [ ! -f "$RO_IMAGE" ]; then
  echo "error: base image not found: $RO_IMAGE" >&2
  exit 1
fi

# Build cloud-init ISO
"$BUILD_SCRIPT" "$NAME"

# Remove existing VM if present
if sudo virsh dominfo "$NAME" >/dev/null 2>&1; then
  echo "existing VM '$NAME' found, removing"
  sudo virsh destroy "$NAME" >/dev/null 2>&1 || true
  sudo virsh undefine "$NAME" --nvram >/dev/null 2>&1 || true
fi

# Remove any previous run disk
sudo rm -f "$RUN_IMAGE"

# Create qcow2 overlay backed by the RO base image
sudo qemu-img create \
  -f qcow2 \
  -F qcow2 \
  -b "$RO_IMAGE" \
  "$RUN_IMAGE" \
  >/dev/null

# Define and start VM using UEFI firmware
sudo virt-install \
  --name "$NAME" \
  --memory 2048 \
  --vcpus 2 \
  --import \
  --disk path="$RUN_IMAGE",format=qcow2,bus=virtio \
  --disk path="$CI_ISO",format=raw,device=cdrom \
  --os-variant debian13 \
  --network network=default,model=virtio \
  --graphics none \
  --boot uefi \
  --noautoconsole

# Attach to serial console
sudo virsh console "$NAME"

