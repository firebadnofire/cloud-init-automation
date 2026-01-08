#!/usr/bin/env bash
set -euo pipefail

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

ARCH="$(uname -m)"

case "$ARCH" in
  x86_64)
    GOARCH="amd64"
    ;;
  aarch64|arm64)
    GOARCH="arm64"
    ;;
  *)
    echo "Unsupported architecture: $ARCH" >&2
    exit 1
    ;;
esac

VERSION="$(
  curl -fsSL https://go.dev/dl/ \
    | grep -oP "go[0-9]+\.[0-9]+\.[0-9]+(?=\.linux-${GOARCH}\.tar\.gz)" \
    | grep -vE 'beta|rc' \
    | head -n 1
)"

if [[ -z "$VERSION" ]]; then
  echo "Failed to determine latest Go version" >&2
  exit 1
fi

TAR="${VERSION}.linux-${GOARCH}.tar.gz"
URL="https://go.dev/dl/${TAR}"
TAR_PATH="${TMPDIR}/${TAR}"

echo "Architecture : ${ARCH}"
echo "Go arch      : ${GOARCH}"
echo "Go version   : ${VERSION}"
echo "Downloading  : ${URL}"

curl -fL -o "$TAR_PATH" "$URL"

if [[ ! -s "$TAR_PATH" ]]; then
  echo "Downloaded archive is empty or missing" >&2
  exit 1
fi

echo "Removing existing Go installation"
sudo rm -rf /usr/local/go

echo "Extracting Go to /usr/local"
sudo tar -C /usr/local -xzf "$TAR_PATH"

PROFILED_FILE="/etc/profile.d/go.sh"

echo "Installing PATH integration at ${PROFILED_FILE}"
sudo tee "$PROFILED_FILE" >/dev/null <<'EOF'
export PATH="$PATH:/usr/local/go/bin"
EOF

sudo chmod 0644 "$PROFILED_FILE"

echo "Go ${VERSION} installed successfully"
echo "PATH integration active on next login"

