#!/usr/bin/env bash
# Install and verify host prerequisites for running GHCR Yocto artifacts in QEMU.

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  bash scripts/setup-host-qemu-prereqs.sh [options]

Options:
  --no-install         Skip apt install and only run verification checks
  --add-docker-group   Add current user to docker group (requires re-login)
  -h, --help           Show this help

What this script does:
  1) Installs Docker + QEMU packages on Ubuntu
  2) Enables and starts Docker service
  3) Verifies docker daemon and qemu-system-aarch64 are usable

Recommended next step:
  bash scripts/run-ghcr-qemu.sh --image ghcr.io/<owner>/<repo>/qemu-image:latest
EOF
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing command: $1" >&2
    return 1
  fi
}

NO_INSTALL=0
ADD_DOCKER_GROUP=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-install)
      NO_INSTALL=1
      shift
      ;;
    --add-docker-group)
      ADD_DOCKER_GROUP=1
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
  echo "Installing host packages (docker + qemu)"
  $SUDO apt-get update -qq
  $SUDO apt-get install -y --no-install-recommends \
    ca-certificates \
    docker.io \
    qemu-system-arm \
    qemu-efi-aarch64
fi

require_cmd docker
require_cmd qemu-system-aarch64

echo "Enabling and starting Docker service"
$SUDO systemctl enable --now docker

if [[ "$ADD_DOCKER_GROUP" -eq 1 && "$(id -u)" -ne 0 ]]; then
  echo "Adding user ${USER} to docker group"
  $SUDO usermod -aG docker "$USER"
  echo "User added to docker group. Re-login is required for group changes to apply."
fi

echo "Verifying Docker daemon"
if ! $SUDO docker info >/dev/null 2>&1; then
  echo "Docker daemon is not reachable. Check: systemctl status docker" >&2
  exit 1
fi

echo "Verifying QEMU binary"
qemu-system-aarch64 --version | head -n 1

echo "Host prerequisites are ready."
echo "Next: bash scripts/run-ghcr-qemu.sh --image ghcr.io/<owner>/<repo>/qemu-image:latest"
