#!/usr/bin/env bash
set -euo pipefail

REPO="midfusionlabs/releases"
VERSION="${1:-}"
USE_SUDO="${SUDO:-auto}"

# Get latest version if not specified
if [[ -z "${VERSION}" ]]; then
  if command -v jq >/dev/null 2>&1; then
    VERSION=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" | jq -r .tag_name)
  else
    VERSION=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" | sed -n 's/.*"tag_name"\s*:\s*"\([^"]*\)".*/\1/p')
  fi
  if [[ -z "${VERSION}" || "${VERSION}" == "null" ]]; then
    echo "Failed to fetch latest version" >&2
    exit 1
  fi
fi

OS=$(uname | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)
case "${ARCH}" in
  x86_64|amd64) ARCH=amd64 ;;
  aarch64|arm64) ARCH=arm64 ;;
  *) echo "Unsupported architecture: ${ARCH}" >&2; exit 1 ;;
esac

ARCHIVE="midfusion-${OS}-${ARCH}.gz"
tmpdir=$(mktemp -d)
trap 'rm -rf "${tmpdir}"' EXIT

echo "Installing midfusion ${VERSION} (${OS}/${ARCH})..."

URL="https://github.com/${REPO}/releases/download/${VERSION}/${ARCHIVE}"
curl -fsSL "${URL}" -o "${tmpdir}/${ARCHIVE}" || {
  echo "Download failed: ${URL}" >&2
  exit 1
}

gunzip -c "${tmpdir}/${ARCHIVE}" > "${tmpdir}/midfusion"
chmod +x "${tmpdir}/midfusion"

INSTALL_DIR="/usr/local/bin"
if [[ "${USE_SUDO}" == "auto" ]]; then
  [[ -w "${INSTALL_DIR}" ]] && USE_SUDO="" || USE_SUDO="sudo"
elif [[ "${USE_SUDO}" == "true" ]]; then
  USE_SUDO="sudo"
fi

${USE_SUDO} install -m 0755 "${tmpdir}/midfusion" "${INSTALL_DIR}/midfusion"
${USE_SUDO} ln -sf "${INSTALL_DIR}/midfusion" "${INSTALL_DIR}/mf" 2>/dev/null || true

if command -v midfusion >/dev/null 2>&1; then
  echo "Installed: $(midfusion --version 2>/dev/null || echo ${VERSION})"
else
  echo "Installed to ${INSTALL_DIR}/midfusion"
  echo "Add ${INSTALL_DIR} to your PATH if not already"
fi

echo ""
echo "Usage: midfusion [command] or mf [command]"
echo "Run 'midfusion --help' for available commands"
