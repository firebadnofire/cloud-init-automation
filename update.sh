#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONF_FILE="$SCRIPT_DIR/image-info.conf"

if [ ! -f "$CONF_FILE" ]; then
  echo "error: missing $CONF_FILE" >&2
  exit 1
fi

. "$CONF_FILE"

RO_DIR="/var/lib/libvirt/ro-images"
LOCAL_IMG="$RO_DIR/$IMAGE"
LOCAL_SUM="$RO_DIR/$IMAGE.sha512"

TMP_SUM="$(mktemp)"
cleanup() {
  rm -f "$TMP_SUM"
}
trap cleanup EXIT

curl -fsSL "$BASE_URL/SHA512SUMS" -o "$TMP_SUM"

REMOTE_HASH="$(
  awk -v img="$IMAGE" '$2 == img { print $1 }' "$TMP_SUM"
)"

if [ -z "$REMOTE_HASH" ]; then
  echo "error: hash for $IMAGE not found in SHA512SUMS" >&2
  exit 1
fi

needs_update() {
  [ ! -f "$LOCAL_SUM" ] || ! grep -q "$REMOTE_HASH" "$LOCAL_SUM"
}

if needs_update; then
  echo "updating base image"
  sudo mkdir -p "$RO_DIR"
  sudo curl -fL "$BASE_URL/$IMAGE" -o "$LOCAL_IMG"
  echo "$REMOTE_HASH  $IMAGE" | sudo tee "$LOCAL_SUM" > /dev/null
else
  echo "base image up to date"
fi

