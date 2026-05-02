#!/usr/bin/env bash
# Install and verify host prerequisites for running Yocto QEMU artifacts.
# No Docker required - artifacts are distributed via GitHub Releases.

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  bash scripts/setup-host-qemu-prereqs.sh [options]

Options:
  --no-install         Skip apt install and only run verification checks
  -h, --help           Show this help

What this script does:
  1) Installs QEMU packages on Ubuntu (no Docker required)
  2) Verifies qemu-system-aarch64 is usable

Recommended next step:
  bash scripts/download-and-run-qemu.sh --release latest

Optional - GitHub CLI for higher API rate limits when downloading releases:
  https://cli.github.com/  (not required; curl-based download works without it)
EOF
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing command: $1" >&2
    return 1
  fi
}

NO_INSTALL=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-install)
      NO_INSTALL=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 2
      ;;
  esac
done

if [[ -f /etc/os-release ]]; then
  . /etc/os-release
else
  echo "Cannot determine OS: /etc/os-release not found." >&2
  exit 1
fi

if [[ "${ID:-}" != "ubuntu" ]]; then
  echo "This script currently supports Ubuntu only. Detected ID=${ID:-unknown}." >&2
  exit 1
fi

SUDO=""
if [[ "$(id -u)" -ne 0 ]]; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  else
    echo "Run as root or install sudo." >&2
    exit 1
  fi
fi

if [[ "$NO_INSTALL" -eq 0 ]]; then
  echo "Installing host packages (qemu only - no Docker needed)"
  $SUDO apt-get update -qq
  $SUDO apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    qemu-system-arm \
    qemu-efi-aarch64
fi

require_cmd qemu-system-aarch64

echo "Verifying QEMU binary"
qemu-system-aarch64 --version | head -n 1

echo ""
echo "Host prerequisites are ready."
echo "Next: bash scripts/download-and-run-qemu.sh --release latest"
echo ""
echo "Optional: install the GitHub CLI for authenticated API calls (higher rate limits):"
echo "  https://cli.github.com/"
