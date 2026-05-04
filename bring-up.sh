#!/usr/bin/env bash
set -euo pipefail

NO_CONSOLE=0

usage() {
  echo "usage: $0 [-n|--no-console] <name>" >&2
  exit 1
}

# Parse args
while [ $# -gt 0 ]; do
  case "$1" in
    -n|--no-console)
      NO_CONSOLE=1
      shift
      ;;
    -h|--help)
      usage
      ;;
    -* )
      echo "error: unknown option $1" >&2
      usage
      ;;
    *)
      break
      ;;
  esac
done

if [ $# -ne 1 ]; then
  usage
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

# Deterministically derive the last 3 MAC bytes from a stable input string.
# Prefix 52:54:00 keeps the address in the qemu/libvirt locally administered range.
generate_mac() {
  local seed="$1"
  local hex

  hex="$(printf '%s' "$seed" | sha256sum | awk '{print $1}')"

  printf '52:54:00:%s:%s:%s\n' \
    "${hex:0:2}" \
    "${hex:2:2}" \
    "${hex:4:2}"
}

# Return an explicit MAC if provided, otherwise generate one deterministically.
resolve_mac() {
  local explicit_mac="${1:-}"
  local seed="$2"

  if [ -n "$explicit_mac" ]; then
    printf '%s\n' "$explicit_mac"
  else
    generate_mac "$seed"
  fi
}

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

# Resize only the overlay disk, never the base image.
if [ -n "${VM_DISK_ADD:-}" ]; then
  sudo qemu-img resize "$RUN_IMAGE" "+${VM_DISK_ADD}G" >/dev/null
fi

NET_ARGS=()

case "$VM_NET_MODE" in
  libvirt)
    VM_MAC="$(resolve_mac "${VM_MAC_ADDR:-}" "$NAME")"
    NET_ARGS+=(
      --network "network=${VM_NETWORK},model=virtio,mac=${VM_MAC}"
    )
    ;;
  macvtap)
    : "${VM_NET_IFACE:?missing VM_NET_IFACE for macvtap}"
    VM_MAC="$(resolve_mac "${VM_MAC_ADDR:-}" "$NAME")"
    NET_ARGS+=(
      --network "type=direct,source=${VM_NET_IFACE},source_mode=bridge,model=virtio,mac=${VM_MAC}"
    )
    ;;
  dual)
    : "${VM_NET_IFACE:?missing VM_NET_IFACE for dual mode}"

    VM_MAC_VTAP="$(resolve_mac "${VM_MAC_ADDR_VTAP:-}" "${NAME}vtap")"
    VM_MAC_INTERNAL="$(resolve_mac "${VM_MAC_ADDR_INTERNAL:-}" "${NAME}internal")"

    NET_ARGS+=(
      --network "type=direct,source=${VM_NET_IFACE},source_mode=bridge,model=virtio,mac=${VM_MAC_VTAP}"
      --network "network=${VM_NETWORK},model=virtio,mac=${VM_MAC_INTERNAL}"
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

if [ "$NO_CONSOLE" -eq 0 ]; then
  sudo virsh console "$NAME"
else
  echo "VM '$NAME' started (no console attached)"
fi
