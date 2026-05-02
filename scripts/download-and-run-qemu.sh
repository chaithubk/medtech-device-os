#!/usr/bin/env bash
# Download QEMU artifacts from GitHub Releases, verify checksums, and boot in QEMU.
# Intended for users who want to run the MedTech Device OS image without Docker.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'EOF'
Usage:
  bash scripts/download-and-run-qemu.sh [options]

Options:
  --release <tag>    GitHub Release tag to download, or "latest" (default: latest)
  --workdir <path>   Work directory for downloads (default: ./qemu-release)
  --keep             Keep downloaded artifacts after QEMU exits
  --graphics         Enable graphical display (passed to QEMU)
  --memory <mb>      RAM in megabytes (default: 256)
  --repo <owner/repo>
                     GitHub repository (default: auto-detected from git remote)
  --dry-run          Resolve and print QEMU command without running it
  -h, --help         Show this help

What this script does:
  1) Fetches release metadata from GitHub API
  2) Downloads bundle.tar.gz, manifest.json, and SHA256SUMS
  3) Verifies SHA256 checksums of all downloaded files
  4) Extracts the bundle
  5) Boots the image in QEMU (qemu-system-aarch64)
  6) Removes the work directory on exit unless --keep is set

Dependencies (all standard on Ubuntu):
  curl, sha256sum, tar, qemu-system-aarch64
  Optional: gh (GitHub CLI, for higher API rate limits), jq

Examples:
  # Download and run the latest release
  bash scripts/download-and-run-qemu.sh

  # Download a specific release
  bash scripts/download-and-run-qemu.sh --release v1.2.3

  # Keep artifacts after QEMU exits
  bash scripts/download-and-run-qemu.sh --keep

  # Run with graphical display
  bash scripts/download-and-run-qemu.sh --graphics

  # Set up host prerequisites first (one-time):
  bash scripts/setup-host-qemu-prereqs.sh
EOF
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
RELEASE_TAG="latest"
WORKDIR="./qemu-release"
KEEP=0
GRAPHICS=0
MEMORY_MB=256
REPO=""
DRY_RUN=0

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --release)
      RELEASE_TAG="${2:-}"
      shift 2
      ;;
    --workdir)
      WORKDIR="${2:-}"
      shift 2
      ;;
    --keep)
      KEEP=1
      shift
      ;;
    --graphics)
      GRAPHICS=1
      shift
      ;;
    --memory)
      MEMORY_MB="${2:-256}"
      shift 2
      ;;
    --repo)
      REPO="${2:-}"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Auto-detect repository from git remote when not provided
# ---------------------------------------------------------------------------
if [[ -z "$REPO" ]]; then
  REMOTE_URL="$(git -C "$SCRIPT_DIR" remote get-url origin 2>/dev/null || true)"
  if [[ -n "$REMOTE_URL" ]]; then
    # Strip protocol and .git suffix to get "owner/repo"
    REPO="$(echo "$REMOTE_URL" | sed -E \
      's#^(https://github\.com/|git@github\.com:)##; s#\.git$##')"
  fi
fi

if [[ -z "$REPO" ]]; then
  echo "Error: Could not auto-detect GitHub repository." >&2
  echo "Pass --repo <owner/repo> explicitly." >&2
  exit 1
fi

echo "Repository : $REPO"
echo "Release    : $RELEASE_TAG"
echo "Work dir   : $WORKDIR"

# ---------------------------------------------------------------------------
# Prerequisite checks
# ---------------------------------------------------------------------------
require_cmd curl
require_cmd sha256sum
require_cmd tar
require_cmd qemu-system-aarch64

# ---------------------------------------------------------------------------
# Cleanup trap
# ---------------------------------------------------------------------------
WORKDIR_ABS="$(realpath -m "$WORKDIR")"
WORKDIR_CREATED=0

cleanup() {
  if [[ "$KEEP" -eq 0 && "$WORKDIR_CREATED" -eq 1 && -d "$WORKDIR_ABS" ]]; then
    echo ""
    echo "Cleaning up work directory: $WORKDIR_ABS"
    rm -rf "$WORKDIR_ABS"
  fi
}
trap cleanup EXIT

if [[ ! -d "$WORKDIR_ABS" ]]; then
  WORKDIR_CREATED=1
fi
mkdir -p "$WORKDIR_ABS"

# ---------------------------------------------------------------------------
# Fetch release metadata from GitHub API
# ---------------------------------------------------------------------------
echo ""
echo "=== Fetching release metadata ==="

if [[ "$RELEASE_TAG" == "latest" ]]; then
  API_URL="https://api.github.com/repos/${REPO}/releases/latest"
else
  API_URL="https://api.github.com/repos/${REPO}/releases/tags/${RELEASE_TAG}"
fi

# Use gh CLI if available (authenticated, higher rate limits); fall back to curl.
# curl respects GITHUB_TOKEN / GH_TOKEN environment variables for private repos.
fetch_json() {
  local url="$1"
  if command -v gh >/dev/null 2>&1; then
    gh api "${url#https://api.github.com/}" 2>/dev/null
  else
    local -a auth_header=()
    local token="${GITHUB_TOKEN:-${GH_TOKEN:-}}"
    # Guard against header injection: tokens must not contain newlines or CR.
    if [[ -n "$token" && "$token" != *$'\n'* && "$token" != *$'\r'* ]]; then
      auth_header=(-H "Authorization: Bearer ${token}")
    fi
    curl -fsSL \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      "${auth_header[@]}" \
      "$url"
  fi
}

RELEASE_JSON="$WORKDIR_ABS/release.json"
if ! fetch_json "$API_URL" > "$RELEASE_JSON" 2>&1; then
  echo "" >&2
  echo "Error: Could not fetch release metadata from:" >&2
  echo "  $API_URL" >&2
  echo "" >&2
  echo "Available releases can be found at:" >&2
  echo "  https://github.com/${REPO}/releases" >&2
  echo "" >&2
  echo "If this repository is private, set a GitHub token:" >&2
  echo "  export GITHUB_TOKEN=<your_token>" >&2
  echo "  curl -H \"Authorization: Bearer \$GITHUB_TOKEN\" $API_URL" >&2
  exit 1
fi

# Parse asset download URLs (use jq if available, else grep/sed fallback)
get_asset_url() {
  local name_pattern="$1"
  if command -v jq >/dev/null 2>&1; then
    jq -r --arg pat "$name_pattern" \
      '.assets[] | select(.name | test($pat)) | .browser_download_url' \
      "$RELEASE_JSON" | head -n 1
  else
    # Extract the URL value for every browser_download_url entry, then filter
    # by whether the basename (last path segment) matches the pattern.
    # Process substitution avoids a subshell so local variables behave correctly.
    while IFS= read -r url; do
      local fname="${url##*/}"
      echo "$fname" | grep -qE "$name_pattern" && echo "$url"
    done < <(
      grep -o '"browser_download_url": *"[^"]*"' "$RELEASE_JSON" \
        | sed 's/.*"browser_download_url": *"//; s/"$//'
    ) | head -n 1
  fi
}

get_tag_name() {
  if command -v jq >/dev/null 2>&1; then
    jq -r '.tag_name' "$RELEASE_JSON"
  else
    grep -o '"tag_name": *"[^"]*"' "$RELEASE_JSON" \
      | sed 's/.*"tag_name": *"//; s/"//' | head -n 1
  fi
}

RESOLVED_TAG="$(get_tag_name)"
echo "Resolved tag: $RESOLVED_TAG"

BUNDLE_URL="$(get_asset_url 'bundle\.tar\.gz')"
MANIFEST_URL="$(get_asset_url 'manifest\.json')"
SUMS_URL="$(get_asset_url 'SHA256SUMS')"

if [[ -z "$BUNDLE_URL" ]]; then
  echo "" >&2
  echo "Error: No bundle.tar.gz asset found in release '${RESOLVED_TAG}'." >&2
  echo "Expected assets: *bundle.tar.gz, *manifest.json, SHA256SUMS" >&2
  echo "" >&2
  echo "Check available assets at:" >&2
  echo "  https://github.com/${REPO}/releases/tag/${RESOLVED_TAG}" >&2
  exit 1
fi

if [[ -z "$SUMS_URL" ]]; then
  echo "Warning: SHA256SUMS asset not found in release. Checksum verification will be skipped." >&2
fi

# ---------------------------------------------------------------------------
# Download assets
# ---------------------------------------------------------------------------
echo ""
echo "=== Downloading release assets ==="

download_asset() {
  local url="$1"
  local dest="$2"
  local label="$3"

  echo "  Downloading $label ..."
  local -a auth_header=()
  if command -v gh >/dev/null 2>&1; then
    # Store token in a variable before interpolating into header to prevent word-splitting
    local gh_token
    gh_token="$(gh auth token 2>/dev/null || true)"
    # Guard against header injection: tokens must not contain newlines or CR.
    if [[ -n "$gh_token" && "$gh_token" != *$'\n'* && "$gh_token" != *$'\r'* ]]; then
      auth_header=(-H "Authorization: token ${gh_token}")
    fi
  else
    local token="${GITHUB_TOKEN:-${GH_TOKEN:-}}"
    if [[ -n "$token" && "$token" != *$'\n'* && "$token" != *$'\r'* ]]; then
      auth_header=(-H "Authorization: Bearer ${token}")
    fi
  fi
  curl -fsSL "${auth_header[@]}" -L "$url" -o "$dest"
}

BUNDLE_FILE="$WORKDIR_ABS/$(basename "$BUNDLE_URL")"
download_asset "$BUNDLE_URL" "$BUNDLE_FILE" "bundle"

if [[ -n "$MANIFEST_URL" ]]; then
  MANIFEST_FILE="$WORKDIR_ABS/$(basename "$MANIFEST_URL")"
  download_asset "$MANIFEST_URL" "$MANIFEST_FILE" "manifest"
fi

if [[ -n "$SUMS_URL" ]]; then
  SUMS_FILE="$WORKDIR_ABS/SHA256SUMS"
  download_asset "$SUMS_URL" "$SUMS_FILE" "SHA256SUMS"
fi

# ---------------------------------------------------------------------------
# Verify checksums
# ---------------------------------------------------------------------------
if [[ -n "$SUMS_URL" && -f "$WORKDIR_ABS/SHA256SUMS" ]]; then
  echo ""
  echo "=== Verifying SHA256 checksums ==="
  (
    cd "$WORKDIR_ABS"
    # SHA256SUMS references filenames only (no paths); ensure we're in same dir
    sha256sum -c SHA256SUMS
  )
  echo "Checksum verification passed."
else
  echo "Warning: Skipping checksum verification (SHA256SUMS not available)." >&2
fi

# ---------------------------------------------------------------------------
# Extract bundle
# ---------------------------------------------------------------------------
echo ""
echo "=== Extracting bundle ==="
EXTRACT_DIR="$WORKDIR_ABS/extracted"
mkdir -p "$EXTRACT_DIR"
tar -xzf "$BUNDLE_FILE" -C "$EXTRACT_DIR"

echo "Extraction complete: $EXTRACT_DIR"

# ---------------------------------------------------------------------------
# Locate kernel, rootfs, and optional DTB inside the extracted bundle
# ---------------------------------------------------------------------------
echo ""
echo "=== Resolving artifacts ==="

SEARCH_ROOTS=("$EXTRACT_DIR")

KERNEL=""
ROOTFS=""
DTB=""

# Prefer named Image-qemuarm64.bin first (matches run-qemu.sh convention)
KERNEL="$(find "${SEARCH_ROOTS[@]}" -type f -name "Image-qemuarm64.bin" 2>/dev/null | head -n 1 || true)"
if [[ -z "$KERNEL" ]]; then
  KERNEL="$(find "${SEARCH_ROOTS[@]}" -type f -name "Image" 2>/dev/null | head -n 1 || true)"
fi
if [[ -z "$KERNEL" ]]; then
  KERNEL="$(find "${SEARCH_ROOTS[@]}" -type f \( -name "Image*" -o -name "vmlinuz*" -o -name "zImage*" \) 2>/dev/null | head -n 1 || true)"
fi

ROOTFS="$(find "${SEARCH_ROOTS[@]}" -type f -name "*qemuarm64*.ext4" 2>/dev/null | head -n 1 || true)"
if [[ -z "$ROOTFS" ]]; then
  ROOTFS="$(find "${SEARCH_ROOTS[@]}" -type f -name "*.ext4" 2>/dev/null | head -n 1 || true)"
fi

DTB="$(find "${SEARCH_ROOTS[@]}" -type f -name "*qemuarm64*.dtb" 2>/dev/null | head -n 1 || true)"
if [[ -z "$DTB" ]]; then
  DTB="$(find "${SEARCH_ROOTS[@]}" -type f -name "*.dtb" 2>/dev/null | head -n 1 || true)"
fi

if [[ -z "$KERNEL" ]]; then
  echo "Error: Could not find kernel image in extracted bundle." >&2
  echo "Expected file names: Image-qemuarm64.bin, Image, Image*" >&2
  echo "Bundle contents:" >&2
  find "$EXTRACT_DIR" -type f | sort >&2
  exit 1
fi

if [[ -z "$ROOTFS" ]]; then
  echo "Error: Could not find rootfs (.ext4) in extracted bundle." >&2
  echo "Bundle contents:" >&2
  find "$EXTRACT_DIR" -type f | sort >&2
  exit 1
fi

echo "  Kernel : $KERNEL"
echo "  Rootfs : $ROOTFS"
echo "  DTB    : ${DTB:-<none>}"

# ---------------------------------------------------------------------------
# Build QEMU command
# ---------------------------------------------------------------------------
if [[ "$GRAPHICS" -eq 1 ]]; then
  DISPLAY_ARG="-display gtk"
else
  DISPLAY_ARG="-nographic"
fi

QEMU_CMD=(
  qemu-system-aarch64
  -machine virt
  -cpu cortex-a57
  -smp 4
  -m "$MEMORY_MB"
  -kernel "$KERNEL"
  -drive "id=disk0,file=${ROOTFS},if=none,format=raw"
  -device virtio-blk-pci,drive=disk0
  -device "virtio-net-pci,netdev=net0,mac=52:54:00:12:34:02"
  -netdev "user,id=net0,hostfwd=tcp:127.0.0.1:2222-:22"
  -device qemu-xhci
  -device usb-tablet
  -device usb-kbd
  -device virtio-gpu-pci
  -object rng-random,filename=/dev/urandom,id=rng0
  -device virtio-rng-pci,rng=rng0
  $DISPLAY_ARG
  -append "root=/dev/vda rw console=ttyAMA0,115200"
)

if [[ -n "$DTB" ]]; then
  QEMU_CMD+=( -dtb "$DTB" )
fi

echo ""
echo "Login as: root"
echo "Password: root"
echo "SSH after boot: ssh -p 2222 root@localhost"
echo "Exit QEMU: Ctrl+A then X (or: shutdown -h now)"
echo ""

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "Dry run enabled. QEMU command:"
  printf '  '
  printf '%q ' "${QEMU_CMD[@]}"
  printf '\n'
  KEEP=1   # don't clean up in dry-run so the user can inspect
  exit 0
fi

echo "=== Booting QEMU ==="
# Run QEMU without exec so the EXIT trap fires and cleanup runs after the VM exits.
"${QEMU_CMD[@]}"
