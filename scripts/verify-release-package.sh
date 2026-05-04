#!/usr/bin/env bash
# Verify the integrity of a packaged release bundle.
# Checks SHA256 checksums, archive structure, and required payload files.

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  bash scripts/verify-release-package.sh --image-name <pn> [options]

Options:
  --image-name <pn>   BitBake image recipe name, for example core-image-medtech.
  --machine <name>    Yocto machine name. Default: qemuarm64.
  --output-dir <dir>  Package output directory. Default: ./artifacts.
  -h, --help          Show this help.
EOF
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

IMAGE_NAME=""
MACHINE="qemuarm64"
OUTPUT_DIR="$PROJECT_ROOT/artifacts"

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
    --output-dir)
      OUTPUT_DIR="${2:-}"
      shift 2
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

ARCHIVE_PATH="$OUTPUT_DIR/${IMAGE_NAME}-${MACHINE}-bundle.tar.gz"
MANIFEST_PATH="$OUTPUT_DIR/${IMAGE_NAME}-${MACHINE}-manifest.json"
CHECKSUMS_PATH="$OUTPUT_DIR/SHA256SUMS"

for required_file in "$ARCHIVE_PATH" "$MANIFEST_PATH" "$CHECKSUMS_PATH"; do
  if [[ ! -f "$required_file" ]]; then
    echo "Error: required package file missing: $required_file" >&2
    exit 1
  fi
done

(
  cd "$OUTPUT_DIR"
  sha256sum -c "$(basename "$CHECKSUMS_PATH")"
)

ARCHIVE_LISTING="$(mktemp)"
trap 'rm -f "$ARCHIVE_LISTING"' EXIT
tar -tzf "$ARCHIVE_PATH" > "$ARCHIVE_LISTING"

if ! grep -Eq '^payload/image/.+\.ext4$' "$ARCHIVE_LISTING"; then
  echo "Error: archive does not contain a rootfs ext4 payload." >&2
  exit 1
fi

if ! grep -Eq '^payload/metadata/manifest\.json$' "$ARCHIVE_LISTING"; then
  echo "Error: archive does not contain the package manifest." >&2
  exit 1
fi

echo "=== Release bundle verification passed ==="
echo "Archive: $ARCHIVE_PATH"
echo "Contents summary:"
grep -E '^payload/(image|metadata|sbom)/' "$ARCHIVE_LISTING" | sed 's#^#  #' || true