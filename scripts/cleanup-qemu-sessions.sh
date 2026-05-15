#!/bin/bash
# Minimal QEMU cleanup helper.
# Equivalent to the manual sequence:
#   pgrep -af qemu-system-aarch64
#   pkill -TERM -f qemu-system-aarch64
#   sleep 1
#   pkill -KILL -f qemu-system-aarch64

set -euo pipefail

echo "=== QEMU cleanup (minimal) ==="
pgrep -af qemu-system-aarch64 || true
pkill -TERM -f qemu-system-aarch64 || true
sleep 1
pkill -KILL -f qemu-system-aarch64 || true
echo "Done."
