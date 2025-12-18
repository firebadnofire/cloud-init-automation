BASE_URL="https://cloud.debian.org/images/cloud/trixie/latest"
IMAGE="debian-13-genericcloud-amd64.qcow2"

RO_DIR="/var/lib/libvirt/ro-images"
LOCAL_IMG="$RO_DIR/$IMAGE"
LOCAL_SUM="$RO_DIR/$IMAGE.sha512"

TMP_SUM="$(mktemp)"

curl -fsSL "$BASE_URL/SHA512SUMS" -o "$TMP_SUM"

REMOTE_HASH="$(
  awk -v img="$IMAGE" '$2 == img { print $1 }' "$TMP_SUM"
)"

if [ -z "$REMOTE_HASH" ]; then
  echo "error: hash for $IMAGE not found in SHA512SUMS" >&2
  rm -f "$TMP_SUM"
  exit 1
fi

if [ ! -f "$LOCAL_SUM" ] || ! grep -q "$REMOTE_HASH" "$LOCAL_SUM"; then
  echo "updating base image"
  sudo mkdir -p "$RO_DIR"
  sudo curl -fL "$BASE_URL/$IMAGE" -o "$LOCAL_IMG"
  echo "$REMOTE_HASH  $IMAGE" | sudo tee "$LOCAL_SUM" > /dev/null
else
  echo "base image up to date"
fi

rm -f "$TMP_SUM"
