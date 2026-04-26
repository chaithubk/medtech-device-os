#!/bin/bash
# clone-with-retry.sh
# Clones all required Yocto layers with exponential-backoff retry logic.
# Idempotent: already-present directories are skipped.

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
YOCTO_DIR="$PROJECT_ROOT/yocto"

# ── Configuration ─────────────────────────────────────────────────────────────
MAX_RETRIES=3
INITIAL_DELAY=5          # seconds before first retry
BACKOFF_MULTIPLIER=2     # each retry waits 2x longer

# Prevent git from prompting for credentials in non-interactive environments
export GIT_TERMINAL_PROMPT=0
# Kill connections that stall below 1 KB/s for 30 seconds (avoids hour-long hangs)
git config --global http.lowSpeedLimit 1000
git config --global http.lowSpeedTime 30
git config --global http.timeout 120

echo "=== Cloning Yocto Layers (with retry) ==="
echo ""

mkdir -p "$YOCTO_DIR"

# ── Helper: clone with exponential backoff ────────────────────────────────────
clone_with_retry() {
    local name="$1"
    local url="$2"
    local branch="$3"
    local target="$YOCTO_DIR/$name"

    if [ -d "$target/.git" ]; then
        echo "   SKIP: $name — already present at $target"
        return 0
    fi

    local attempt=1
    local delay=$INITIAL_DELAY

    while [ "$attempt" -le "$MAX_RETRIES" ]; do
        echo "   Attempt $attempt/$MAX_RETRIES: git clone -b $branch --depth 1 $url $target"
        if git clone -b "$branch" --depth 1 "$url" "$target" 2>&1; then
            echo "   OK: $name cloned"
            return 0
        fi

        if [ "$attempt" -lt "$MAX_RETRIES" ]; then
            echo "   WARNING: clone failed — retrying in ${delay}s..."
            sleep "$delay"
            delay=$(( delay * BACKOFF_MULTIPLIER ))
        fi
        attempt=$(( attempt + 1 ))
    done

    echo "   FAIL: $name could not be cloned after $MAX_RETRIES attempts"
    return 1
}

# ── Layers ────────────────────────────────────────────────────────────────────

# Poky (Yocto reference distro + BitBake)
clone_with_retry \
    "poky" \
    "https://git.yoctoproject.org/git/poky" \
    "kirkstone"

# meta-openembedded (provides meta-oe, meta-python, meta-networking, etc.)
# NOTE: meta-python and meta-networking are subdirectories of this single repo;
#       do NOT clone them separately.
clone_with_retry \
    "meta-openembedded" \
    "https://github.com/openembedded/meta-openembedded.git" \
    "kirkstone"

# meta-qt6 (Qt6 recipes — qtbase, qtdeclarative, qtmqtt, …)
# Primary: official Qt project server; fallback: GitHub mirror
if ! clone_with_retry \
        "meta-qt6" \
        "https://code.qt.io/yocto/meta-qt6.git" \
        "6.4"; then
    echo "   Primary URL failed — trying GitHub mirror..."
    clone_with_retry \
        "meta-qt6" \
        "https://github.com/meta-qt6/meta-qt6.git" \
        "6.4" || {
        echo "   FAIL: meta-qt6 could not be cloned from either source"
        echo "         clinician-ui will not build without meta-qt6"
        exit 1
    }
fi

# meta-medtech (our custom layer — already in the workspace checkout)
if [ ! -d "$YOCTO_DIR/meta-medtech" ]; then
    echo "   FAIL: meta-medtech not found at $YOCTO_DIR/meta-medtech"
    echo "         This is a required custom layer shipped with the repository."
    exit 1
fi
echo "   OK: meta-medtech — present in workspace checkout"

echo ""
echo "========================================="
echo "OK: Layer setup complete"
echo ""
echo "Available layers:"
for d in "$YOCTO_DIR"/poky "$YOCTO_DIR"/meta-openembedded \
          "$YOCTO_DIR"/meta-qt6 "$YOCTO_DIR"/meta-medtech; do
    if [ -d "$d" ]; then
        echo "   $d"
    fi
done
