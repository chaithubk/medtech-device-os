#!/usr/bin/env bash
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
  --graphics         Enable graphical display instead of serial console
  --background       Run QEMU in background and wait for SSH
  --no-wait-ssh      Skip SSH readiness check in background mode
  --memory <mb>      RAM in megabytes (default: 256)
  --repo <owner/repo>
                     GitHub repository (default: auto-detected from git remote)
  --dry-run          Resolve and print QEMU command without running it
  -h, --help         Show this help

Default behavior:
  - Launches QEMU with serial console attached to this terminal
  - SSH is optional / secondary via: ssh -p 2222 root@localhost
EOF
}

log() {
  echo "[download-and-run-qemu] $*"
}

die() {
  echo "[download-and-run-qemu] ERROR: $*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

RELEASE_TAG="latest"
WORKDIR="./qemu-release"
KEEP=0
GRAPHICS=0
BACKGROUND=0
NO_WAIT_SSH=0
MEMORY_MB=256
REPO=""
DRY_RUN=0
QEMU_PID=""
QEMU_LOG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --release) RELEASE_TAG="${2:-}"; shift 2 ;;
    --workdir) WORKDIR="${2:-}"; shift 2 ;;
    --keep) KEEP=1; shift ;;
    --graphics) GRAPHICS=1; shift ;;
    --background) BACKGROUND=1; shift ;;
    --no-wait-ssh) NO_WAIT_SSH=1; shift ;;
    --memory) MEMORY_MB="${2:-256}"; shift 2 ;;
    --repo) REPO="${2:-}"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown argument: $1" ;;
  esac
done

detect_repo() {
  local remote_url
  remote_url="$(git -C "$SCRIPT_DIR" remote get-url origin 2>/dev/null || true)"
  [[ -n "$remote_url" ]] || return 1

  case "$remote_url" in
    https://github.com/*)
      REPO="${remote_url#https://github.com/}"
      ;;
    git@github.com:*)
      REPO="${remote_url#git@github.com:}"
      ;;
    ssh://git@ssh.github.com:443/*)
      REPO="${remote_url#ssh://git@ssh.github.com:443/}"
      ;;
    ssh://git@github.com/*)
      REPO="${remote_url#ssh://git@github.com/}"
      ;;
    *)
      return 1
      ;;
  esac

  REPO="${REPO%.git}"
  [[ "$REPO" =~ ^[^/]+/[^/]+$ ]]
}

if [[ -z "$REPO" ]]; then
  detect_repo || die "Could not auto-detect GitHub repository. Pass --repo <owner/repo> explicitly."
fi

[[ "$REPO" =~ ^[^/]+/[^/]+$ ]] || die "Repository must be in owner/repo format, got: $REPO"

require_cmd curl
require_cmd sha256sum
require_cmd tar
require_cmd qemu-system-aarch64

WORKDIR_ABS="$(realpath -m "$WORKDIR")"
mkdir -p "$WORKDIR_ABS"

cleanup() {
  if [[ -n "$QEMU_PID" ]] && kill -0 "$QEMU_PID" 2>/dev/null; then
    log "Stopping QEMU (PID $QEMU_PID)"
    kill "$QEMU_PID" 2>/dev/null || true
    wait "$QEMU_PID" 2>/dev/null || true
  fi

  if [[ "$KEEP" -eq 0 && -d "$WORKDIR_ABS" ]]; then
    log "Cleaning up work directory: $WORKDIR_ABS"
    rm -rf "$WORKDIR_ABS"
  fi
}
trap cleanup EXIT

log "Repository : $REPO"
log "Release    : $RELEASE_TAG"
log "Work dir   : $WORKDIR_ABS"

if [[ "$RELEASE_TAG" == "latest" ]]; then
  API_URL="https://api.github.com/repos/${REPO}/releases/latest"
else
  API_URL="https://api.github.com/repos/${REPO}/releases/tags/${RELEASE_TAG}"
fi

RELEASE_JSON="$WORKDIR_ABS/release.json"
log "Fetching release metadata from: $API_URL"
curl -fsSL \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "$API_URL" -o "$RELEASE_JSON" || die "Failed to fetch release metadata"

[[ -s "$RELEASE_JSON" ]] || die "Release metadata file is empty: $RELEASE_JSON"

get_tag_name() {
  if command -v jq >/dev/null 2>&1; then
    jq -r '.tag_name // empty' "$RELEASE_JSON"
  else
    grep -o '"tag_name": *"[^"]*"' "$RELEASE_JSON" \
      | sed 's/.*"tag_name": *"//; s/"$//' \
      | sed -n '1p'
  fi
}

get_asset_url() {
  local name_pattern="$1"
  local url fname

  if command -v jq >/dev/null 2>&1; then
    jq -r --arg pat "$name_pattern" \
      '.assets[] | select(.name | test($pat)) | .browser_download_url' \
      "$RELEASE_JSON" | sed -n '1p'
    return 0
  fi

  while IFS= read -r url; do
    fname="${url##*/}"
    if [[ "$fname" =~ $name_pattern ]]; then
      printf '%s\n' "$url"
      return 0
    fi
  done < <(
    grep -o '"browser_download_url": *"[^"]*"' "$RELEASE_JSON" \
      | sed 's/.*"browser_download_url": *"//; s/"$//'
  )

  return 0
}

RESOLVED_TAG="$(get_tag_name)"
[[ -n "$RESOLVED_TAG" ]] || die "Could not determine resolved release tag"
log "Resolved tag: $RESOLVED_TAG"

BUNDLE_URL="$(get_asset_url 'bundle\.tar\.gz')"
MANIFEST_URL="$(get_asset_url 'manifest\.json')"
SUMS_URL="$(get_asset_url 'SHA256SUMS')"

log "Bundle URL   : ${BUNDLE_URL:-<missing>}"
log "Manifest URL : ${MANIFEST_URL:-<missing>}"
log "SHA256 URL   : ${SUMS_URL:-<missing>}"

[[ -n "$BUNDLE_URL" ]] || die "No bundle.tar.gz asset found in release $RESOLVED_TAG"

download_file() {
  local url="$1"
  local output="$2"
  local label="$3"

  log "Downloading $label -> $output"
  curl -fL --retry 3 --retry-delay 2 --connect-timeout 15 "$url" -o "$output" \
    || die "Failed downloading $label from $url"

  [[ -s "$output" ]] || die "Downloaded $label is empty: $output"
}

BUNDLE_FILE="$WORKDIR_ABS/$(basename "$BUNDLE_URL")"
download_file "$BUNDLE_URL" "$BUNDLE_FILE" "bundle"

if [[ -n "$MANIFEST_URL" ]]; then
  MANIFEST_FILE="$WORKDIR_ABS/$(basename "$MANIFEST_URL")"
  download_file "$MANIFEST_URL" "$MANIFEST_FILE" "manifest"
fi

if [[ -n "$SUMS_URL" ]]; then
  SUMS_FILE="$WORKDIR_ABS/SHA256SUMS"
  download_file "$SUMS_URL" "$SUMS_FILE" "SHA256SUMS"
fi

if [[ -f "$WORKDIR_ABS/SHA256SUMS" ]]; then
  log "Verifying checksums"
  (
    cd "$WORKDIR_ABS"
    sha256sum -c SHA256SUMS
  ) || die "Checksum verification failed"
else
  log "SHA256SUMS not present; skipping checksum verification"
fi

EXTRACT_DIR="$WORKDIR_ABS/extracted"
mkdir -p "$EXTRACT_DIR"
log "Extracting bundle to: $EXTRACT_DIR"
tar -xzf "$BUNDLE_FILE" -C "$EXTRACT_DIR" || die "Failed to extract bundle"

KERNEL="$(find "$EXTRACT_DIR" -type f -name 'Image-qemuarm64.bin' | head -n 1 || true)"
[[ -n "$KERNEL" ]] || KERNEL="$(find "$EXTRACT_DIR" -type f -name 'Image' | head -n 1 || true)"
[[ -n "$KERNEL" ]] || KERNEL="$(find "$EXTRACT_DIR" -type f -name 'Image*' | head -n 1 || true)"

ROOTFS="$(find "$EXTRACT_DIR" -type f -name '*qemuarm64*.ext4' | head -n 1 || true)"
[[ -n "$ROOTFS" ]] || ROOTFS="$(find "$EXTRACT_DIR" -type f -name '*.ext4' | head -n 1 || true)"

DTB="$(find "$EXTRACT_DIR" -type f -name '*qemuarm64*.dtb' | head -n 1 || true)"
[[ -n "$DTB" ]] || DTB="$(find "$EXTRACT_DIR" -type f -name '*.dtb' | head -n 1 || true)"

[[ -n "$KERNEL" ]] || {
  find "$EXTRACT_DIR" -type f | sort >&2
  die "Kernel image not found in extracted bundle"
}
[[ -n "$ROOTFS" ]] || {
  find "$EXTRACT_DIR" -type f | sort >&2
  die "Rootfs image not found in extracted bundle"
}

log "Kernel : $KERNEL"
log "Rootfs : $ROOTFS"
log "DTB    : ${DTB:-<none>}"

if [[ "$GRAPHICS" -eq 1 ]]; then
  DISPLAY_ARGS=(-display gtk)
else
  DISPLAY_ARGS=(-nographic)
fi

QEMU_CMD=(
  qemu-system-aarch64
  -machine virt
  -cpu cortex-a57
  -smp 4
  -m "$MEMORY_MB"
  -kernel "$KERNEL"
  -drive "id=disk0,file=$ROOTFS,if=none,format=raw"
  -device virtio-blk-pci,drive=disk0,romfile=
  -device virtio-net-pci,netdev=net0,mac=52:54:00:12:34:02,romfile=
  -netdev user,id=net0,hostfwd=tcp:127.0.0.1:2222-:22
  -device qemu-xhci
  -device usb-tablet
  -device usb-kbd
  -device virtio-gpu-pci
  -object rng-random,filename=/dev/urandom,id=rng0
  -device virtio-rng-pci,rng=rng0
  "${DISPLAY_ARGS[@]}"
  -append "root=/dev/vda rw console=ttyAMA0,115200"
)

if [[ -n "$DTB" ]]; then
  QEMU_CMD+=( -dtb "$DTB" )
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  log "Dry run enabled. QEMU command:"
  printf '%q ' "${QEMU_CMD[@]}"
  printf '\n'
  exit 0
fi

echo
echo "============================================================"
echo "             MedTech Device OS — QEMU Boot"
echo "============================================================"
echo "Release  : $RESOLVED_TAG"
echo "Memory   : ${MEMORY_MB} MB"
echo "Mode     : $([[ "$BACKGROUND" -eq 1 ]] && echo background/ssh || echo serial-console)"
echo "SSH      : ssh -p 2222 root@localhost"
echo "SCP      : scp -P 2222 file root@localhost:/path/"
echo "============================================================"
echo

if [[ "$BACKGROUND" -eq 0 ]]; then
  echo "Serial console attached to this terminal."
  echo "Exit QEMU: Ctrl+A then X"
  echo
  exec "${QEMU_CMD[@]}"
fi

QEMU_LOG="$WORKDIR_ABS/qemu.log"
log "Starting QEMU in background"
log "QEMU log: $QEMU_LOG"

"${QEMU_CMD[@]}" >"$QEMU_LOG" 2>&1 &
QEMU_PID=$!

sleep 2
if ! kill -0 "$QEMU_PID" 2>/dev/null; then
  echo >&2
  echo "QEMU exited immediately after launch." >&2
  echo "QEMU log: $QEMU_LOG" >&2
  tail -n 100 "$QEMU_LOG" >&2 || true
  exit 1
fi

if [[ "$NO_WAIT_SSH" -eq 0 ]]; then
  log "Waiting for SSH on 127.0.0.1:2222"
  timeout=90
  elapsed=0
  while (( elapsed < timeout )); do
    if ! kill -0 "$QEMU_PID" 2>/dev/null; then
      echo >&2
      echo "QEMU exited before SSH became ready." >&2
      echo "QEMU log: $QEMU_LOG" >&2
      tail -n 100 "$QEMU_LOG" >&2 || true
      exit 1
    fi

    if bash -c "echo >/dev/tcp/127.0.0.1/2222" 2>/dev/null; then
      log "SSH daemon is responding"
      echo
      echo "Connect now:"
      echo "  ssh -p 2222 root@localhost"
      echo
      break
    fi

    printf "  [%02ds/%02ds] Still booting...\r" "$elapsed" "$timeout"
    sleep 2
    (( elapsed += 2 )) || true
  done

  if (( elapsed >= timeout )); then
    echo >&2
    echo "SSH did not become ready within ${timeout}s." >&2
    echo "QEMU log: $QEMU_LOG" >&2
    tail -n 100 "$QEMU_LOG" >&2 || true
    exit 1
  fi
fi

wait "$QEMU_PID" || true
QEMU_PID=""