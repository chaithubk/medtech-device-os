#!/bin/bash
# Test QEMU image by SSH'ing into it and checking services
# Usage: bash scripts/test-qemu.sh

echo "=== Testing QEMU Image via SSH ==="
echo ""
echo "Waiting for SSH daemon to start (may take 10-30 seconds)..."
echo ""

# Retry SSH connection until QEMU is ready (max 60 seconds)
MAX_RETRY=60
RETRY=0
while (( RETRY < MAX_RETRY )); do
    if ssh -o ConnectTimeout=2 -o BatchMode=yes -o StrictHostKeyChecking=no \
           -p 2222 root@localhost "echo 'SSH ready'" >/dev/null 2>&1; then
        echo "✓ SSH connection successful"
        break
    fi
    RETRY=$((RETRY + 1))
    sleep 1
    if (( RETRY % 10 == 0 )); then
        echo "  Still waiting... (${RETRY}s)"
    fi
done

if (( RETRY >= MAX_RETRY )); then
    echo "✗ SSH timeout after ${MAX_RETRY}s — QEMU may still be booting"
    echo ""
    echo "Continue in terminal:"
    echo "  ssh -p 2222 root@localhost"
    exit 1
fi

echo ""
echo "=== System Information ==="
ssh -o StrictHostKeyChecking=no -p 2222 root@localhost "uname -a"

echo ""
echo "=== Service Status ==="
ssh -o StrictHostKeyChecking=no -p 2222 root@localhost "systemctl list-units --type=service --state=running | grep medtech"

echo ""
echo "=== MQTT Broker Check ==="
ssh -o StrictHostKeyChecking=no -p 2222 root@localhost "systemctl status mosquitto | head -5"

echo ""
echo "=== Available MQTT Topics (subscribe for 5 seconds) ==="
timeout 5 ssh -o StrictHostKeyChecking=no -p 2222 root@localhost \
    "mosquitto_sub -t 'medtech/#' -v" || echo "  (No messages in 5s window — services may still be starting)"

echo ""
echo "✓ Test complete"
echo ""
echo "Interactive SSH session:"
echo "  ssh -p 2222 root@localhost"
