#!/bin/bash
# Test QEMU image by SSH'ing into it and checking services
# Usage: bash scripts/test-qemu.sh

echo "=== Testing QEMU Image via SSH ==="
echo ""
echo "Waiting for SSH daemon to start (may take 10-30 seconds)..."
echo ""

SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 2222)
if [[ -n "${SSH_IDENTITY_FILE:-}" ]]; then
    if [[ ! -f "$SSH_IDENTITY_FILE" ]]; then
        echo "✗ SSH_IDENTITY_FILE is set but file does not exist: $SSH_IDENTITY_FILE"
        exit 2
    fi
    SSH_OPTS+=(-i "$SSH_IDENTITY_FILE" -o IdentitiesOnly=yes)
elif [[ -f "$HOME/.ssh/id_medtech" ]]; then
    SSH_OPTS+=(-i "$HOME/.ssh/id_medtech" -o IdentitiesOnly=yes)
fi

# Retry SSH connection until QEMU is ready (max 60 seconds)
MAX_RETRY=60
RETRY=0
while (( RETRY < MAX_RETRY )); do
    if ssh -o ConnectTimeout=2 -o BatchMode=yes "${SSH_OPTS[@]}" \
           medadmin@localhost "echo 'SSH ready'" >/dev/null 2>&1; then
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
    echo "  ssh ${SSH_IDENTITY_FILE:+-i $SSH_IDENTITY_FILE }-p 2222 medadmin@localhost"
    exit 1
fi

echo ""
echo "=== System Information ==="
ssh "${SSH_OPTS[@]}" medadmin@localhost "uname -a"

echo ""
echo "=== Service Status ==="
ssh "${SSH_OPTS[@]}" medadmin@localhost "systemctl list-units --type=service --state=running | grep medtech"

echo ""
echo "=== MQTT Broker Check ==="
ssh "${SSH_OPTS[@]}" medadmin@localhost "systemctl status mosquitto | head -5"

echo ""
echo "=== Available MQTT Topics (subscribe for 5 seconds) ==="
timeout 5 ssh "${SSH_OPTS[@]}" medadmin@localhost \
    "mosquitto_sub -t 'medtech/#' -v" || echo "  (No messages in 5s window — services may still be starting)"

echo ""
echo "✓ Test complete"
echo ""
echo "Interactive SSH session:"
echo "  ssh ${SSH_IDENTITY_FILE:+-i $SSH_IDENTITY_FILE }-p 2222 medadmin@localhost"
