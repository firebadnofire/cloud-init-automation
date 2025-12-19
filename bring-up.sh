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

: "${IMAGE:?missing IMAGE in image-info.conf}"
: "${VM_MEMORY:?missing VM_MEMORY in image-info.conf}"
: "${VM_VCPUS:?missing VM_VCPUS in image-info.conf}"

VM_OS_VARIANT="${VM_OS_VARIANT:-debian13}"
VM_NET_MODE="${VM_NET_MODE:-libvirt}"
VM_NETWORK="${VM_NETWORK:-default}"

BASE_DIR="$SCRIPT_DIR"
BUILD_SCRIPT="$BASE_DIR/build.sh"

RO_DIR="/var/lib/libvirt/ro-images"
RUN_DIR="/var/lib/libvirt/images"
CI_DIR="/var/lib/libvirt/cloud-init"

RO_IMAGE="$RO_DIR/$IMAGE"
RUN_IMAGE="$RUN_DIR/${NAME}-run.qcow2"
CI_ISO="$CI_DIR/${NAME}.iso"

if [ ! -x "$BUILD_SCRIPT" ]; then
  echo "error: build.sh not executable: $BUILD_SCRIPT" >&2
  exit 1
fi

if [ ! -f "$RO_IMAGE" ]; then
  echo "error: base image not found: $RO_IMAGE" >&2
  exit 1
fi

"$BUILD_SCRIPT" "$NAME"

if sudo virsh dominfo "$NAME" >/dev/null 2>&1; then
  echo "existing VM '$NAME' found, removing"
  sudo virsh destroy "$NAME" >/dev/null 2>&1 || true
  sudo virsh undefine "$NAME" --nvram >/dev/null 2>&1 || true
fi

sudo rm -f "$RUN_IMAGE"

sudo qemu-img create \
  -f qcow2 \
  -F qcow2 \
  -b "$RO_IMAGE" \
  "$RUN_IMAGE" \
  >/dev/null

NET_ARGS=()

case "$VM_NET_MODE" in
  libvirt)
    NET_ARGS+=(
      --network "network=${VM_NETWORK},model=virtio"
    )
    ;;
  macvtap)
    : "${VM_NET_IFACE:?missing VM_NET_IFACE for macvtap}"
    NET_ARGS+=(
      --network "type=direct,source=${VM_NET_IFACE},source_mode=bridge,model=virtio"
    )
    ;;
  dual)
    : "${VM_NET_IFACE:?missing VM_NET_IFACE for dual mode}"
    NET_ARGS+=(
      --network "type=direct,source=${VM_NET_IFACE},source_mode=bridge,model=virtio"
      --network "network=${VM_NETWORK},model=virtio"
    )
    ;;
  *)
    echo "error: unknown VM_NET_MODE=$VM_NET_MODE" >&2
    exit 1
    ;;
esac

sudo virt-install \
  --name "$NAME" \
  --memory "$VM_MEMORY" \
  --vcpus "$VM_VCPUS" \
  --import \
  --disk path="$RUN_IMAGE",format=qcow2,bus=virtio \
  --disk path="$CI_ISO",format=raw,device=cdrom \
  --os-variant "$VM_OS_VARIANT" \
  --graphics none \
  --boot uefi \
  --noautoconsole \
  "${NET_ARGS[@]}"

sudo virsh console "$NAME"

