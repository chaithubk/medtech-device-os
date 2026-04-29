#!/usr/bin/env bash
# Pull a GHCR image that contains Yocto QEMU artifacts and boot it with qemu-system-aarch64.
# Intended for running outside the dev container on Ubuntu hosts.

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  bash scripts/run-ghcr-qemu.sh --image ghcr.io/<owner>/<repo>/qemu-image[:tag] [options]

Options:
  --image <ref>       Required. Container image reference.
  --workdir <path>    Extraction/work directory (default: ./ghcr-qemu-run)
  --kernel <path>     Optional. Host path to kernel image (overrides auto-detect)
  --rootfs <path>     Optional. Host path to rootfs ext4 (overrides auto-detect)
  --dtb <path>        Optional. Host path to dtb (overrides auto-detect)
  --graphics          Use GTK display instead of nographic console
  --memory <mb>       VM memory in MB (default: 256)
  --smp <n>           Number of vCPUs (default: 4)
  --keep              Keep extracted files and container snapshot metadata
  --dry-run           Resolve artifacts and print QEMU command without booting
  -h, --help          Show this help

Examples:
  bash scripts/run-ghcr-qemu.sh --image ghcr.io/acme/medtech-device-os/qemu-image:latest
  bash scripts/run-ghcr-qemu.sh --image ghcr.io/acme/medtech-device-os/qemu-image:main --graphics --memory 512
  bash scripts/run-ghcr-qemu.sh --image ghcr.io/acme/medtech-device-os/qemu-image:latest --kernel ~/Image-qemuarm64.bin

Notes:
  - For private GHCR images, login first:
      export GHCR_PAT=YOUR_GITHUB_PAT_WITH_READ_PACKAGES
      echo "$GHCR_PAT" | docker login ghcr.io -u <github-user> --password-stdin
  - Required host binaries: docker, qemu-system-aarch64
EOF
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    return 1
  fi
}

IMAGE_REF=""
WORKDIR="./ghcr-qemu-run"
GRAPHICS=0
MEMORY_MB=256
SMP=4
KEEP=0
DRY_RUN=0
KERNEL_OVERRIDE=""
ROOTFS_OVERRIDE=""
DTB_OVERRIDE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --image)
      IMAGE_REF="${2:-}"
      shift 2
      ;;
    --workdir)
      WORKDIR="${2:-}"
      shift 2
      ;;
    --graphics)
      GRAPHICS=1
      shift
      ;;
    --kernel)
      KERNEL_OVERRIDE="${2:-}"
      shift 2
      ;;
    --rootfs)
      ROOTFS_OVERRIDE="${2:-}"
      shift 2
      ;;
    --dtb)
      DTB_OVERRIDE="${2:-}"
      shift 2
      ;;
    --memory)
      MEMORY_MB="${2:-}"
      shift 2
      ;;
    --smp)
      SMP="${2:-}"
      shift 2
      ;;
    --keep)
      KEEP=1
      shift
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
      usage
      exit 2
      ;;
  esac
done

if [[ -z "$IMAGE_REF" ]]; then
  echo "Error: --image is required." >&2
  usage
  exit 2
fi

require_cmd docker
require_cmd qemu-system-aarch64

echo "Pulling container image: $IMAGE_REF"
if ! PULL_OUTPUT="$(docker pull "$IMAGE_REF" 2>&1)"; then
  echo "$PULL_OUTPUT" >&2
  if grep -qiE "unauthorized|denied|authentication required" <<<"$PULL_OUTPUT"; then
    echo "" >&2
    echo "GHCR authentication failed for: $IMAGE_REF" >&2
    echo "If this package is private, login first:" >&2
    echo "  export GHCR_PAT=<token-with-read:packages>" >&2
    echo "  echo \"\$GHCR_PAT\" | docker login ghcr.io -u <github-username> --password-stdin" >&2
    echo "" >&2
    echo "If you use org SSO, make sure the token is authorized for that org." >&2
  fi
  exit 1
fi

mkdir -p "$WORKDIR"
WORKDIR_ABS="$(cd "$WORKDIR" && pwd)"
EXTRACT_DIR="$WORKDIR_ABS/extracted"
ARTIFACTS_DIR="$WORKDIR_ABS/artifacts"
mkdir -p "$EXTRACT_DIR" "$ARTIFACTS_DIR"

CID="$(docker create "$IMAGE_REF")"
cleanup() {
  docker rm "$CID" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "Attempting to copy /artifacts from image"
if docker cp "$CID":/artifacts/. "$ARTIFACTS_DIR" 2>/dev/null; then
  echo "Copied /artifacts contents to: $ARTIFACTS_DIR"
else
  echo "No /artifacts directory found in image (this can be normal)."
fi

echo "Discovering candidate kernel/rootfs/dtb files inside image"
mapfile -t CANDIDATE_PATHS < <(
  docker run --rm --entrypoint /bin/sh "$IMAGE_REF" -lc \
    'find / \( -name "*.ext4" -o -name "Image*" -o -name "*.dtb" -o -name "*qemuarm64*.bin" -o -name "vmlinuz*" -o -name "zImage*" \) 2>/dev/null | sort -u'
)

if [[ ${#CANDIDATE_PATHS[@]} -eq 0 ]]; then
  echo "No candidate artifacts found inside container."
  echo "Expected at least one .ext4 and one kernel image (Image*)."
  exit 1
fi

echo "Copying discovered candidates from image"
for p in "${CANDIDATE_PATHS[@]}"; do
  rel="${p#/}"
  dst="$EXTRACT_DIR/$rel"
  mkdir -p "$(dirname "$dst")"
  docker cp "$CID":"$p" "$dst" 2>/dev/null || true
done

echo "Extracted artifacts:"
find "$EXTRACT_DIR" -type f \( -name "*.ext4" -o -name "Image*" -o -name "Image" -o -name "*.dtb" \) -exec ls -lh {} \; 2>/dev/null || true

pick_first() {
  local pattern="$1"
  shift
  local roots=("$@")
  local found
  found="$(find "${roots[@]}" -type f -name "$pattern" 2>/dev/null | head -n 1 || true)"
  if [[ -n "$found" ]]; then
    printf '%s\n' "$found"
  fi
}

SEARCH_ROOTS=("$ARTIFACTS_DIR" "$EXTRACT_DIR")

KERNEL="$KERNEL_OVERRIDE"
ROOTFS="$ROOTFS_OVERRIDE"
DTB="$DTB_OVERRIDE"

if [[ -n "$KERNEL" && ! -f "$KERNEL" ]]; then
  echo "Provided --kernel path does not exist: $KERNEL" >&2
  exit 1
fi

if [[ -n "$ROOTFS" && ! -f "$ROOTFS" ]]; then
  echo "Provided --rootfs path does not exist: $ROOTFS" >&2
  exit 1
fi

if [[ -n "$DTB" && ! -f "$DTB" ]]; then
  echo "Provided --dtb path does not exist: $DTB" >&2
  exit 1
fi

if [[ -z "$KERNEL" ]]; then
  KERNEL="$(pick_first "Image-qemuarm64.bin" "${SEARCH_ROOTS[@]}")"
fi
if [[ -z "$KERNEL" ]]; then
  KERNEL="$(find "${SEARCH_ROOTS[@]}" -type f -name "*qemuarm64*.bin" 2>/dev/null | head -n 1 || true)"
fi
if [[ -z "$KERNEL" ]]; then
  KERNEL="$(pick_first "Image" "${SEARCH_ROOTS[@]}")"
fi
if [[ -z "$KERNEL" ]]; then
  KERNEL="$(find "${SEARCH_ROOTS[@]}" -type f -name "Image*" 2>/dev/null | head -n 1 || true)"
fi
if [[ -z "$KERNEL" ]]; then
  # Explicitly try to find files named exactly "Image" (common in Yocto deploy)
  KERNEL="$(find "${SEARCH_ROOTS[@]}" -type f -name "Image" 2>/dev/null | head -n 1 || true)"
fi
if [[ -z "$KERNEL" ]]; then
  KERNEL="$(find "${SEARCH_ROOTS[@]}" -type f \( -name "vmlinuz*" -o -name "zImage*" \) 2>/dev/null | head -n 1 || true)"
fi

if [[ -z "$ROOTFS" ]]; then
  ROOTFS="$(find "${SEARCH_ROOTS[@]}" -type f -name "*qemuarm64*.ext4" 2>/dev/null | head -n 1 || true)"
fi
if [[ -z "$ROOTFS" ]]; then
  ROOTFS="$(find "${SEARCH_ROOTS[@]}" -type f -name "*.ext4" 2>/dev/null | head -n 1 || true)"
fi

if [[ -z "$DTB" ]]; then
  DTB="$(find "${SEARCH_ROOTS[@]}" -type f -name "*qemuarm64*.dtb" 2>/dev/null | head -n 1 || true)"
fi
if [[ -z "$DTB" ]]; then
  DTB="$(find "${SEARCH_ROOTS[@]}" -type f -name "*.dtb" 2>/dev/null | head -n 1 || true)"
fi

if [[ -z "$KERNEL" || -z "$ROOTFS" ]]; then
  echo "Failed to resolve required artifacts."
  echo "Resolved kernel: ${KERNEL:-<none>}"
  echo "Resolved rootfs: ${ROOTFS:-<none>}"
  echo "Extracted files are under: $WORKDIR_ABS"
  echo ""
  echo "This usually means the container image only includes rootfs (.ext4) and not kernel artifacts."
  echo "You can provide a kernel manually:"
  echo "  bash scripts/run-ghcr-qemu.sh --image $IMAGE_REF --kernel /path/to/Image-qemuarm64.bin"
  echo ""
  echo "To inspect candidate files in the image:"
  echo "  docker run --rm --entrypoint /bin/sh $IMAGE_REF -lc 'find / \( -name "*.ext4" -o -name "Image*" -o -name "*.dtb" -o -name "*qemuarm64*.bin" \) 2>/dev/null | sort -u'"
  exit 1
fi

DISPLAY_ARGS=(-nographic)
if [[ "$GRAPHICS" -eq 1 ]]; then
  DISPLAY_ARGS=(-display gtk)
fi

QEMU_CMD=(
  qemu-system-aarch64
  -machine virt
  -cpu cortex-a57
  -smp "$SMP"
  -m "$MEMORY_MB"
  -kernel "$KERNEL"
  -drive "id=disk0,file=$ROOTFS,if=none,format=raw"
  -device virtio-blk-pci,drive=disk0
  -device virtio-net-pci,netdev=net0,mac=52:54:00:12:34:02
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

echo "Artifacts resolved:"
echo "  Kernel: $KERNEL"
echo "  Rootfs: $ROOTFS"
echo "  DTB:    ${DTB:-<none>}"
echo ""
echo "SSH after boot: ssh -p 2222 root@localhost"
echo "Exit QEMU: Ctrl+A then X"
echo ""

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "Dry run enabled. Command:"
  printf ' %q' "${QEMU_CMD[@]}"
  echo
  exit 0
fi

"${QEMU_CMD[@]}"

if [[ "$KEEP" -eq 0 ]]; then
  echo "Cleaning extraction directory: $WORKDIR_ABS"
  rm -rf "$WORKDIR_ABS"
fi
