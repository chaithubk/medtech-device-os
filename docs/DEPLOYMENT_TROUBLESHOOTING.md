# Deployment Troubleshooting Guide

Common issues and solutions when running MedTech Device OS in QEMU.

---

## Table of Contents

- [SSH connection refused](#ssh-connection-refused)
- [SSH hangs / times out](#ssh-hangs--times-out)
- [QEMU shows black screen / no output](#qemu-shows-black-screen--no-output)
- [QEMU appears frozen](#qemu-appears-frozen)
- [Download failures](#download-failures)
- [Checksum verification failed](#checksum-verification-failed)
- [SCP file transfer issues](#scp-file-transfer-issues)
- [Services not running](#services-not-running)
- [MQTT data not flowing](#mqtt-data-not-flowing)
- [Port 2222 already in use](#port-2222-already-in-use)
- [WSL2 specific issues](#wsl2-specific-issues)

---

## SSH connection refused

**Symptom:**
```
ssh: connect to host localhost port 2222: Connection refused
```

**Cause:** The SSH daemon inside the VM has not started yet. This is normal for
the first 20–40 seconds after boot.

**Solutions:**

1. **Use the automatic SSH wait** (default behavior since Milestone 2):
   ```bash
   bash scripts/download-and-run-qemu.sh
   # The script now waits up to 60 seconds for SSH automatically
   ```

2. **Wait and retry manually:**
   ```bash
   # Wait 30 seconds then try
   sleep 30 && ssh -p 2222 root@localhost
   ```

3. **Use the console instead** to log in directly while SSH starts:
   ```bash
   bash scripts/download-and-run-qemu.sh --console
   ```

4. **Check if QEMU is actually running:**
   ```bash
   pgrep -l qemu-system
   ```

---

## SSH hangs / times out

**Symptom:** SSH command hangs without connecting or timing out quickly.

**Cause:** Could be a host firewall rule, network issue, or QEMU networking problem.

**Solutions:**

1. **Check QEMU is listening on port 2222:**
   ```bash
   ss -tlnp | grep 2222
   # Should show: 127.0.0.1:2222
   ```

2. **Check for host firewall blocking loopback:**
   ```bash
   sudo ufw status
   # If active, allow loopback:
   sudo ufw allow from 127.0.0.1
   ```

3. **Try with verbose SSH output:**
   ```bash
   ssh -v -p 2222 root@localhost
   ```

4. **Restart with more memory:**
   ```bash
   bash scripts/download-and-run-qemu.sh --memory 512
   ```

---

## QEMU shows black screen / no output

**Symptom:** After running the script, you see a blank terminal with no messages.

**Cause:** QEMU launched in nographic (headless) mode. The OS is booting but
the serial console output appears in the same terminal.

**Solutions:**

1. **Just wait:** The boot process takes 20–60 seconds. Output will appear.

2. **Press Enter** to trigger a login prompt if the console appears stuck.

3. **Use --console flag** to ensure serial console is attached:
   ```bash
   bash scripts/download-and-run-qemu.sh --console
   ```

4. **Check for QEMU errors in the terminal output** — look for lines starting
   with `qemu-system-aarch64:` which indicate hardware configuration problems.

---

## QEMU appears frozen

**Symptom:** No response to keyboard input, SSH not connecting, boot appears stuck.

**Possible causes:**
- Low memory causing excessive swapping
- Kernel crash
- Filesystem corruption in the image

**Solutions:**

1. **Kill and restart with more memory:**
   ```bash
   pkill -f qemu-system-aarch64
   bash scripts/download-and-run-qemu.sh --memory 512
   ```

2. **Check host memory:**
   ```bash
   free -h
   ```

3. **Exit QEMU forcefully:**
   ```
   Press Ctrl+A then X
   ```

4. **Re-download the release** (image may be corrupted):
   ```bash
   rm -rf ./qemu-release
   bash scripts/download-and-run-qemu.sh --keep
   ```

---

## Download failures

### API rate limit exceeded

**Symptom:**
```
Error: Could not fetch release metadata
```
Or a JSON response with `"message": "API rate limit exceeded"`.

**Solution:**
```bash
# Generate a GitHub token at: https://github.com/settings/tokens
export GITHUB_TOKEN=ghp_your_token_here
bash scripts/download-and-run-qemu.sh
```

Or install the GitHub CLI for automatic authentication:
```bash
gh auth login
bash scripts/download-and-run-qemu.sh
```

### Network error during download

**Symptom:** `curl: (28) Operation timed out`

**Solution:**
```bash
# Retry (the script resumes from scratch)
bash scripts/download-and-run-qemu.sh

# Or keep the work directory to inspect partial downloads
bash scripts/download-and-run-qemu.sh --keep --workdir ./downloads
```

### No bundle.tar.gz in release

**Symptom:**
```
Error: No bundle.tar.gz asset found in release 'latest'
```

**Cause:** The latest CI run may not have produced a release, or there may not
be any releases yet.

**Solution:**
```bash
# Check available releases at:
# https://github.com/<owner>/<repo>/releases

# Try specifying a known release tag
bash scripts/download-and-run-qemu.sh --release v1.0.0
```

---

## Checksum verification failed

**Symptom:**
```
sha256sum: WARNING: 1 computed checksum did NOT match
```

**Cause:** The downloaded file is corrupted (network issue, partial download).

**Solution:**
```bash
# Remove the work directory and re-download
rm -rf ./qemu-release
bash scripts/download-and-run-qemu.sh
```

---

## SCP file transfer issues

### Permission denied when copying files

**Solution:** Use the explicit password form or set up SSH keys:

```bash
# Copy a file in (use sshpass for scripted use)
scp -P 2222 myfile.txt root@localhost:/tmp/
# Password: root

# Copy a file out
scp -P 2222 root@localhost:/var/log/syslog ./
```

### SCP with host key verification error

**Symptom:** `WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!`

**Cause:** You booted a different release — the host key changed.

**Solution:**
```bash
# Remove the stale key
ssh-keygen -R "[localhost]:2222"
ssh -p 2222 root@localhost
```

### Large file transfers are slow

QEMU uses user-mode networking with a 10 Mbps simulated link. For large
transfers, consider:

```bash
# Copy multiple files at once with tar over SSH
tar czf - /path/to/files | ssh -p 2222 root@localhost 'tar xzf - -C /tmp'
```

---

## Services not running

**Symptom:** `systemctl status medtech-vitals-publisher` shows `failed` or `inactive`.

**Diagnosis:**
```bash
# Check service status
systemctl status medtech-vitals-publisher

# View service logs
journalctl -u medtech-vitals-publisher -n 50

# Check for dependency failures
systemctl list-dependencies medtech-vitals-publisher
```

**Common causes:**

1. **mosquitto not started** — services depend on it:
   ```bash
   systemctl start mosquitto
   systemctl start medtech-vitals-publisher
   ```

2. **Missing Python module:**
   ```bash
   journalctl -u medtech-vitals-publisher | grep "ModuleNotFoundError"
   ```

3. **Restart all services:**
   ```bash
   systemctl restart mosquitto
   systemctl restart medtech-vitals-publisher
   systemctl restart medtech-edge-analytics
   systemctl restart medtech-clinician-ui
   ```

---

## MQTT data not flowing

**Symptom:** `mosquitto_sub -t "medtech/#" -v` shows no output.

**Diagnosis:**
```bash
# Check broker is running
systemctl status mosquitto

# Check publisher is running and sending
systemctl status medtech-vitals-publisher
journalctl -u medtech-vitals-publisher -f

# Publish a test message
mosquitto_pub -t "test/ping" -m "hello"
mosquitto_sub -t "test/#" -v
```

**Wait time:** The vitals publisher sends data every 10 seconds — wait at least
15 seconds before concluding there is no data.

---

## Port 2222 already in use

**Symptom:**
```
qemu-system-aarch64: -netdev user,...: could not set up host forwarding rule
```
Or SSH connects to the wrong host.

**Solution:**
```bash
# Find what is using port 2222
ss -tlnp | grep 2222

# Kill the conflicting process (replace PID with the actual PID)
kill <PID>

# Or use a different port (requires script modification or run-qemu.sh editing)
```

---

## WSL2 specific issues

### SSH works in WSL but not from Windows host

WSL2 uses a NAT network. To access port 2222 from Windows:

```powershell
# In an elevated PowerShell window:
netsh interface portproxy add v4tov4 listenport=2222 listenaddress=0.0.0.0 connectport=2222 connectaddress=<WSL2-IP>
```

Get WSL2 IP:
```bash
# In WSL2
ip addr show eth0 | grep 'inet '
```

### QEMU crashes immediately in WSL2

WSL2 may not support hardware virtualization for nested VMs. Run with software
emulation only (no KVM):
```bash
# The default script already uses software emulation (no -enable-kvm flag)
bash scripts/download-and-run-qemu.sh
```

---

## Getting more help

1. Check the [QUICK_REFERENCE.md](QUICK_REFERENCE.md) for copy-paste commands.
2. Open an issue at the GitHub repository with:
   - Your OS and WSL version (if applicable)
   - The full error message
   - Output of `bash scripts/download-and-run-qemu.sh --dry-run`
