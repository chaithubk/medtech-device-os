#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  bash scripts/package-ghcr-artifacts.sh --image-name <pn> [options]

Options:
  --image-name <pn>     BitBake image recipe name, for example core-image-medtech.
  --machine <machine>   Yocto machine name. Default: qemuarm64.
  --deploy-dir <path>   Deploy images directory.
  --sbom-dir <path>     Optional SBOM directory to include when present.
  --output-dir <path>   Output directory for packaged artifacts. Default: ./artifacts.
  --archive-name <name> Override archive file name.
  --keep-staging        Keep the temporary staging directory for debugging.
  -h, --help            Show this help.
EOF
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

IMAGE_NAME=""
MACHINE="qemuarm64"
DEPLOY_DIR="$PROJECT_ROOT/yocto/build/tmp/deploy/images/qemuarm64"
SBOM_DIR="$PROJECT_ROOT/sbom"
OUTPUT_DIR="$PROJECT_ROOT/artifacts"
ARCHIVE_NAME=""
KEEP_STAGING=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --image-name)
      IMAGE_NAME="${2:-}"
      shift 2
      ;;
    --machine)
      MACHINE="${2:-}"
      shift 2
      ;;
    --deploy-dir)
      DEPLOY_DIR="${2:-}"
      shift 2
      ;;
    --sbom-dir)
      SBOM_DIR="${2:-}"
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="${2:-}"
      shift 2
      ;;
    --archive-name)
      ARCHIVE_NAME="${2:-}"
      shift 2
      ;;
    --keep-staging)
      KEEP_STAGING=1
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

if [[ -z "$IMAGE_NAME" ]]; then
  echo "Error: --image-name is required." >&2
  usage >&2
  exit 2
fi

if [[ ! -d "$DEPLOY_DIR" ]]; then
  echo "Error: deploy directory not found: $DEPLOY_DIR" >&2
  exit 1
fi

pick_latest() {
  local pattern="$1"

  find -L "$DEPLOY_DIR" -maxdepth 1 \( -type f -o -type l \) -name "$pattern" -printf '%T@ %p\n' 2>/dev/null \
    | sort -nr \
    | head -n 1 \
    | cut -d' ' -f2-
}

ROOTFS_PATH="$(pick_latest "${IMAGE_NAME}-${MACHINE}*.rootfs.ext4")"
if [[ -z "$ROOTFS_PATH" ]]; then
  ROOTFS_PATH="$(pick_latest "${IMAGE_NAME}-${MACHINE}*.ext4")"
fi

if [[ -z "$ROOTFS_PATH" ]]; then
  echo "Error: could not locate a rootfs ext4 for ${IMAGE_NAME} in $DEPLOY_DIR" >&2
  exit 1
fi

KERNEL_PATH="$(pick_latest "Image*${MACHINE}*.bin")"
if [[ -z "$KERNEL_PATH" ]]; then
  KERNEL_PATH="$(pick_latest "Image")"
fi
if [[ -z "$KERNEL_PATH" ]]; then
  KERNEL_PATH="$(pick_latest "Image*")"
fi

QEMUBOOT_CONF="$(pick_latest "${IMAGE_NAME}-${MACHINE}*.qemuboot.conf")"
MANIFEST_PATH="$(pick_latest "${IMAGE_NAME}-${MACHINE}*.rootfs.manifest")"
TESTDATA_PATH="$(pick_latest "${IMAGE_NAME}-${MACHINE}*.testdata.json")"

if [[ -z "$ARCHIVE_NAME" ]]; then
  ARCHIVE_NAME="${IMAGE_NAME}-${MACHINE}-bundle.tar.gz"
fi

STAGING_DIR="$(mktemp -d)"
BUNDLE_ROOT="$STAGING_DIR/${IMAGE_NAME}-${MACHINE}"
PAYLOAD_DIR="$BUNDLE_ROOT/payload"
IMAGE_DIR="$PAYLOAD_DIR/image"
METADATA_DIR="$PAYLOAD_DIR/metadata"

cleanup() {
  if [[ "$KEEP_STAGING" -eq 0 ]]; then
    rm -rf "$STAGING_DIR"
  fi
}
trap cleanup EXIT

mkdir -p "$IMAGE_DIR" "$METADATA_DIR" "$OUTPUT_DIR"
rm -f "$OUTPUT_DIR"/*.tar.gz "$OUTPUT_DIR"/*-manifest.json "$OUTPUT_DIR"/SHA256SUMS

copy_in() {
  local src="$1"
  local dst_dir="$2"

  if [[ -n "$src" && -e "$src" ]]; then
    cp -L "$src" "$dst_dir/"
  fi
}

copy_in "$ROOTFS_PATH" "$IMAGE_DIR"
copy_in "$KERNEL_PATH" "$IMAGE_DIR"
copy_in "$QEMUBOOT_CONF" "$METADATA_DIR"
copy_in "$MANIFEST_PATH" "$METADATA_DIR"
copy_in "$TESTDATA_PATH" "$METADATA_DIR"

mapfile -t DTB_PATHS < <(find -L "$DEPLOY_DIR" -maxdepth 1 \( -type f -o -type l \) -name "*.dtb" | sort)
if [[ ${#DTB_PATHS[@]} -gt 0 ]]; then
  mkdir -p "$IMAGE_DIR/dtb"
  for dtb in "${DTB_PATHS[@]}"; do
    cp -L "$dtb" "$IMAGE_DIR/dtb/"
  done
fi

if [[ -d "$SBOM_DIR" ]]; then
  mapfile -t SBOM_FILES < <(find "$SBOM_DIR" -maxdepth 1 -type f | sort)
  if [[ ${#SBOM_FILES[@]} -gt 0 ]]; then
    mkdir -p "$PAYLOAD_DIR/sbom"
    for sbom_file in "${SBOM_FILES[@]}"; do
      cp -L "$sbom_file" "$PAYLOAD_DIR/sbom/"
    done
  fi
fi

MANIFEST_JSON="$OUTPUT_DIR/${IMAGE_NAME}-${MACHINE}-manifest.json"

{
  echo "{" 
  printf '  "image_name": "%s",\n' "$IMAGE_NAME"
  printf '  "machine": "%s",\n' "$MACHINE"
  printf '  "created_at_utc": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "archive": "%s",\n' "$ARCHIVE_NAME"
  echo '  "files": ['

  first=1
  while IFS= read -r relative_path; do
    checksum="$(cd "$PAYLOAD_DIR" && sha256sum "$relative_path" | awk '{print $1}')"
    size_bytes="$(stat -c '%s' "$PAYLOAD_DIR/$relative_path")"

    if [[ "$first" -eq 0 ]]; then
      echo ','
    fi

    printf '    {"path": "%s", "sha256": "%s", "size_bytes": %s}' \
      "$relative_path" "$checksum" "$size_bytes"
    first=0
  done < <(cd "$PAYLOAD_DIR" && find . -type f | sed 's#^\./##' | sort)

  echo
  echo '  ]'
  echo '}'
} > "$MANIFEST_JSON"

cp "$MANIFEST_JSON" "$METADATA_DIR/manifest.json"

ARCHIVE_PATH="$OUTPUT_DIR/$ARCHIVE_NAME"
tar -C "$BUNDLE_ROOT" -czf "$ARCHIVE_PATH" payload

(
  cd "$OUTPUT_DIR"
  sha256sum "$(basename "$ARCHIVE_PATH")" "$(basename "$MANIFEST_JSON")" > SHA256SUMS
)

echo "=== GHCR bundle created ==="
echo "Output directory : $OUTPUT_DIR"
echo "Archive          : $ARCHIVE_PATH"
echo "Manifest         : $MANIFEST_JSON"
echo "Checksums        : $OUTPUT_DIR/SHA256SUMS"
echo ""
find "$OUTPUT_DIR" -maxdepth 1 -type f -printf '%f\n' | sort