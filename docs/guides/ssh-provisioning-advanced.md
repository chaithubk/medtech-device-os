# SSH Key Provisioning — Technical Deep Dive

Complete architecture and environment chain for SSH key provisioning.

---

## Architecture Diagram

```
┌──────────────────┐
│ Host Machine     │
│ ~/.ssh/id_*.pub  │  SSH public key created by user
└────────┬─────────┘
         │ cp to dev container
         ▼
┌─────────────────────────────────┐
│ Dev Container                   │
│ .secrets/medtech-admin-key.pub  │  Template with user's key
└────────┬────────────────────────┘
         │ bitbake wrapper auto-detects
         ▼
┌──────────────────────────────────────────┐
│ BitBake Build Environment                │
│ MEDTECH_ADMIN_AUTHORIZED_KEY env var     │  Key passed to builder
└────────┬─────────────────────────────────┘
         │ passed through su - builder
         ▼
┌───────────────────────────────────────────┐
│ medtech-image.bbclass                     │
│ IMAGE_PREPROCESS_COMMAND                  │  Called during image build
│ - medtech_provision_admin_key()           │  Writes key to rootfs
│ - medtech_configure_sudo()                │
└────────┬────────────────────────────────┘
         │ writes to rootfs before finalize
         ▼
┌────────────────────────────────────────┐
│ Image Rootfs (ext4)                    │
│ /home/medadmin/.ssh/authorized_keys    │  Key baked into image
│ /etc/sudoers.d/90-medtech-admin        │
│ /etc/ssh/sshd_config.d/10-medtech-*.  │
└────────┬─────────────────────────────┘
         │ QEMU boots image
         ▼
┌────────────────────────────────────────┐
│ Running QEMU VM                        │
│ sshd validates key at login            │  SSH key auth works
│ Port 2222 → Guest Port 22              │
└────────────────────────────────────────┘
```

---

## Environment Variable Chain

### 1. Auto-detect (scripts/bitbake wrapper)

```bash
# Check if key file exists and doesn't have placeholder
if [ -f "$DEFAULT_MEDTECH_ADMIN_KEY_FILE" ] \
    && ! grep -q "REPLACE_WITH_MEDTECH_ADMIN_PUBLIC_KEY" "$DEFAULT_MEDTECH_ADMIN_KEY_FILE" ]; then
    export MEDTECH_ADMIN_AUTHORIZED_KEY="$(cat "$DEFAULT_MEDTECH_ADMIN_KEY_FILE")"
fi
```

**Input:** `.secrets/medtech-admin-key.pub`  
**Output:** `MEDTECH_ADMIN_AUTHORIZED_KEY` env var

### 2. Root → Builder user context switch

```bash
# Preserve key when switching users (bitbake runs as builder, not root)
if [ -n "${MEDTECH_ADMIN_AUTHORIZED_KEY:-}" ]; then
    printf -v arg '%q' "$MEDTECH_ADMIN_AUTHORIZED_KEY"
    quoted_env+=" MEDTECH_ADMIN_AUTHORIZED_KEY=${arg}"
    env_cmd="export${quoted_env} && "
fi

exec su - builder -c "cd '$PROJECT_ROOT' && ... ${env_cmd}exec '$REAL_BITBAKE'${quoted_args}"
```

**Input:** `MEDTECH_ADMIN_AUTHORIZED_KEY` from auto-detect  
**Output:** Available in builder shell context

### 3. BitBake Python context

```bash
# In medtech-image.bbclass (Python code)
MEDTECH_ADMIN_AUTHORIZED_KEY ?= ""

python () {
    key = (d.getVar('MEDTECH_ADMIN_AUTHORIZED_KEY') or '').strip()
    if not key:
        bb.warn('MEDTECH_ADMIN_AUTHORIZED_KEY is empty; SSH login will remain disabled.')
}
```

**Input:** `MEDTECH_ADMIN_AUTHORIZED_KEY` from environment  
**Output:** Variable accessible in shell functions

### 4. Shell provisioning function

```bash
# In medtech-image.bbclass (called during IMAGE_PREPROCESS_COMMAND)
medtech_provision_admin_key() {
    local admin_home="${IMAGE_ROOTFS}/home/${MEDTECH_ADMIN_USER}"
    local key="${MEDTECH_ADMIN_AUTHORIZED_KEY}"  # Read from env

    if [ -n "$key" ]; then
        install -d -m 0700 "$admin_home/.ssh"
        printf '%s\n' "$key" > "$admin_home/.ssh/authorized_keys"
        chmod 0600 "$admin_home/.ssh/authorized_keys"
        chown -R ${MEDTECH_ADMIN_USER}:${MEDTECH_ADMIN_USER} "$admin_home/.ssh"
    fi
}
```

**Input:** `MEDTECH_ADMIN_AUTHORIZED_KEY` shell variable  
**Output:** `/home/medadmin/.ssh/authorized_keys` in ext4 rootfs

---

## Step-by-Step Provisioning Flow

### Step 1: Host SSH Key Generation

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_medtech -N "" -C "you@example.com"
```

**Results:**
- `~/.ssh/id_medtech` (PRIVATE, mode 600)
  ```
  -----BEGIN OPENSSH PRIVATE KEY-----
  b3BlbnNzaC1rZXktdjEAAAAABG5vbmU...
  -----END OPENSSH PRIVATE KEY-----
  ```

- `~/.ssh/id_medtech.pub` (PUBLIC)
  ```
  ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFx7kR9sOF... you@example.com
  ```

### Step 2: Copy to Dev Container

```bash
cat ~/.ssh/id_medtech.pub > .secrets/medtech-admin-key.pub
```

File: `.secrets/medtech-admin-key.pub`
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFx7kR9sOF... you@example.com
```

**Quick setup.sh creates template on first run** if file doesn't exist:
```
REPLACE_WITH_MEDTECH_ADMIN_PUBLIC_KEY
```

Auto-detect checks: **if placeholder is NOT present** → use file.

### Step 3: Build Time — Auto-detect and Export

```bash
$ bitbake core-image-medtech
```

Wrapper script (`scripts/bitbake`) executes:

```bash
auto_detect_medtech_admin_key() {
    # Skip if already set manually
    if [ -n "${MEDTECH_ADMIN_AUTHORIZED_KEY:-}" ]; then
        return 0
    fi
    
    # Check .secrets/ file and read if valid (no placeholder)
    if [ -f "$DEFAULT_MEDTECH_ADMIN_KEY_FILE" ] \
        && ! grep -q "REPLACE_WITH_MEDTECH_ADMIN_PUBLIC_KEY" "$DEFAULT_MEDTECH_ADMIN_KEY_FILE"; then
        export MEDTECH_ADMIN_AUTHORIZED_KEY="$(cat "$DEFAULT_MEDTECH_ADMIN_KEY_FILE")"
    fi
}

auto_detect_medtech_admin_key  # Call the function
```

**Environment after auto-detect:**
```bash
MEDTECH_ADMIN_AUTHORIZED_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFx7kR9sOF... you@example.com"
```

### Step 4: Context Switch (Root → Builder)

```bash
# When running bitbake as root, switch to builder user while preserving env
exec su - builder -c "cd '$PROJECT_ROOT' && bash scripts/quick-setup.sh >/dev/null && \
    source yocto/poky/oe-init-build-env yocto/build >/dev/null && \
    export MEDTECH_ADMIN_AUTHORIZED_KEY='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFx7kR9sOF... you@example.com' && \
    exec '$REAL_BITBAKE' core-image-medtech"
```

**Variable available in builder context.**

### Step 5: Image Provisioning — Call medtech_provision_admin_key()

During `IMAGE_PREPROCESS_COMMAND`, `medtech-image.bbclass` executes:

```bash
medtech_provision_admin_key() {
    local admin_home="${IMAGE_ROOTFS}/home/${MEDTECH_ADMIN_USER}"      # /path/to/image/home/medadmin
    local key="${MEDTECH_ADMIN_AUTHORIZED_KEY}"                        # ssh-ed25519 AAAA...

    if [ -n "$key" ]; then
        # Create .ssh directory with restrictive permissions (700 = rwx------)
        install -d -m 0700 "$admin_home/.ssh"
        
        # Write public key to authorized_keys file
        printf '%s\n' "$key" > "$admin_home/.ssh/authorized_keys"
        
        # Restrict file permissions (600 = rw-------)
        chmod 0600 "$admin_home/.ssh/authorized_keys"
        
        # Set correct ownership
        chown -R ${MEDTECH_ADMIN_USER}:${MEDTECH_ADMIN_USER} "$admin_home/.ssh"
    fi
}

medtech_provision_admin_key  # Executed during build
```

**Result inside ext4 image rootfs:**
```
/home/medadmin/.ssh/                         [mode: 0700, owner: medadmin:medadmin]
├── authorized_keys                          [mode: 0600, owner: medadmin:medadmin]
│   └── ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFx7kR9sOF... you@example.com
```

### Step 6: SSH Server Configuration

`openssh_%.bbappend` installs `/etc/ssh/sshd_config.d/10-medtech-dev.conf`:

```
PermitRootLogin no                    # Block SSH as root
PasswordAuthentication no              # Disable password auth
PubkeyAuthentication yes               # Enable public key auth
KbdInteractiveAuthentication no        # Disable keyboard-interactive
UsePAM yes                             # Keep PAM for account controls
```

During boot, OpenSSH reads this policy.

### Step 7: Runtime SSH Connection

**User on host:**
```bash
ssh -i ~/.ssh/id_medtech -p 2222 medadmin@localhost
```

**OpenSSH server (in guest):**

1. Receives connection on port 2222 (forwarded to 22)
2. Reads policy: `PermitRootLogin no`, `PasswordAuthentication no`
3. Waits for public key authentication
4. Client sends private key challenge
5. OpenSSH reads `/home/medadmin/.ssh/authorized_keys`
6. Compares client public key ↔ authorized_keys entries
7. If match → login grant; if no match → denied

---

## File Permissions Reference

### Critical: Private/Public Key Permissions

| File | Owner | Mode | Must Be | Why |
|------|-------|------|---------|-----|
| `~/.ssh/id_medtech` | user:user | 600 | World-unreadable | Private key compromise if readable |
| `~/.ssh/id_medtech.pub` | user:user | 644 | Any | Public, safe to share |
| `.secrets/medtech-admin-key.pub` | builder:builder | 644 | Any | Dev container, in .gitignore |

### Image Permissions

| File | Owner | Mode | Inside Image | Why |
|------|-------|------|--------------|-----|
| `/home/medadmin/.ssh/` | medadmin:medadmin | 700 | Yes | World-unexecutable (no ls for others) |
| `/home/medadmin/.ssh/authorized_keys` | medadmin:medadmin | 600 | Yes | World-unreadable, OpenSSH requires this |

**OpenSSH rejects:**
- `.ssh/` with mode 755 (world-accessible)
- `authorized_keys` with mode 644 (world-readable)

---

## Troubleshooting Reference Table

| Symptom | Check | Fix |
|---------|-------|-----|
| `Permission denied (publickey)` | Is key in image? | Rebuild: `bitbake -c cleansstate ... && bitbake ...` |
| Key not baked in | Check `.secrets/` file | Verify no `REPLACE` placeholder; `cat .secrets/medtech-admin-key.pub` |
| Build warning: empty key | Build log | Add key to `.secrets/` or set `MEDTECH_ADMIN_AUTHORIZED_KEY` in local.conf |
| Private key wrong | Match keys | `ssh-keygen -y -f ~/.ssh/id_medtech` should output public key |
| Private key permissions | Host OS | `chmod 600 ~/.ssh/id_medtech` |
| SSH_KEYGEN_INVALID_KEY | Key format | Verify `ssh-keygen -l -f ~/.ssh/id_medtech` works |
| Stale host key | Fingerprint mismatch | `ssh-keygen -R "[localhost]:2222"` |

---

## Manual Override (Bypassing Auto-detect)

In `yocto/build/conf/local.conf`:

```bash
# Set explicitly (takes precedence over auto-detect)
MEDTECH_ADMIN_AUTHORIZED_KEY = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFx7kR9sOF... you@example.com"
```

**Used for:**
- Production CI/CD pipelines (keys from secure storage)
- Multi-developer images (multiple keys concatenated)
- Temporary overrides during development

---

## Advanced: Multiple Keys in One Image

To provision multiple SSH keys (multi-developer image):

**Custom medtech-image.bbclass modification:**

```bash
medtech_provision_admin_key() {
    local admin_home="${IMAGE_ROOTFS}/home/${MEDTECH_ADMIN_USER}"
    
    install -d -m 0700 "$admin_home/.ssh"
    
    # Write MULTIPLE keys (one per line)
    cat > "$admin_home/.ssh/authorized_keys" << 'EOF'
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFx7... dev1@example.com
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGy8... dev2@example.com
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAAAg... dev3@example.com
EOF
    
    chmod 0600 "$admin_home/.ssh/authorized_keys"
    chown -R ${MEDTECH_ADMIN_USER}:${MEDTECH_ADMIN_USER} "$admin_home/.ssh"
}
```

Or **post-build (for staging/production):**

```bash
# Mount and add keys after image creation
sudo mount /path/to/image.ext4 /mnt/guest
echo "ssh-ed25519 AAAA... dev2" >> /mnt/guest/home/medadmin/.ssh/authorized_keys
sudo umount /mnt/guest
```

---

## Security Analysis

✅ **Private keys never in image** — Only public keys in authorized_keys  
✅ **No default credentials** — No root/password hash, key is only auth  
✅ **Build-time provisioning** — Cannot be changed without rebuild  
✅ **Restrictive file permissions** — 600/700 enforced by OpenSSH policy  
✅ **Account locked** — Root and medadmin passwords locked (hash: `!` or `*`)  

⚠️ **Assumptions:**
- Dev container `.secrets/` folder is `.gitignore`d (keys not in git)
- QEMU is loopback-only (127.0.0.1:2222, not network-exposed)
- Production uses CI/CD to provision keys (not manual .secrets/ method)

---

## See Also

- [SSH Provisioning Guide](ssh-provisioning.md) — Quick start and daily usage
- [Quick Start Developer](../getting-started/quick-start-developer.md) — Full developer workflow
- [Deployment Troubleshooting](deployment-troubleshooting.md) — SSH troubleshooting section
