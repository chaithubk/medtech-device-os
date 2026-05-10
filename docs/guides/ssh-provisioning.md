# SSH Key Provisioning Guide

How to set up SSH public key authentication for the MedTech Device OS image.

---

## Quick Start (3 Steps)

### 1. Generate SSH keypair (first time only)

```bash
# Ed25519 (recommended: fast, secure, modern)
ssh-keygen -t ed25519 -f ~/.ssh/id_medtech -N "" -C "you@example.com"

# OR RSA (if Ed25519 unavailable)
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_medtech -N "" -C "you@example.com"
```

Creates:
- `~/.ssh/id_medtech` — private key (keep safe, never share)
- `~/.ssh/id_medtech.pub` — public key (safe to share)

### 2. Add public key to build config

**Option A: Auto-detect from `.secrets/` (recommended)**

```bash
cat ~/.ssh/id_medtech.pub > .secrets/medtech-admin-key.pub
```

The build system automatically detects and uses this file.

**Option B: Manual override in `yocto/build/conf/local.conf`**

```bash
# Add one line (no line breaks):
MEDTECH_ADMIN_AUTHORIZED_KEY = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFx7... you@example.com"
```

### 3. Rebuild and SSH

```bash
# Build (key auto-provisioned into image)
bitbake -c cleansstate core-image-medtech && bitbake core-image-medtech

# Boot (Terminal 1)
bash scripts/run-qemu.sh

# Login (Terminal 2, after 20+ seconds)
ssh -i ~/.ssh/id_medtech -p 2222 medadmin@localhost
```

---

## How It Works

```
Host SSH keypair generated
        ↓
Public key added to .secrets/medtech-admin-key.pub
        ↓
bitbake wrapper auto-detects key
        ↓
Exported as MEDTECH_ADMIN_AUTHORIZED_KEY environment variable
        ↓
medtech-image.bbclass writes key to image rootfs:
  /home/medadmin/.ssh/authorized_keys (mode 600)
        ↓
Image built and booted in QEMU
        ↓
OpenSSH validates: your private key ↔ public key in authorized_keys
        ↓
SSH login successful
```

### Build-Time Provisioning Details

1. **Auto-detect** (`scripts/bitbake` wrapper):
   - Checks if `.secrets/medtech-admin-key.pub` exists
   - Reads file if placeholder is NOT present
   - Exports content as `MEDTECH_ADMIN_AUTHORIZED_KEY` env var

2. **Template creation** (`scripts/quick-setup.sh`):
   - Creates `.secrets/medtech-admin-key.pub` on first run
   - Contains placeholder and instructions

3. **Key provisioning** (`medtech-image.bbclass`):
   - Creates `.ssh/` directory in medadmin home (mode 700)
   - Writes public key to `authorized_keys` (mode 600)
   - Sets correct ownership (medadmin:medadmin)

4. **SSH policy** (`openssh_%.bbappend`):
   - Installs sshd config drop-in: `/etc/ssh/sshd_config.d/10-medtech-dev.conf`
   - Enforces: `PermitRootLogin no`, `PasswordAuthentication no`
   - Only public key authentication allowed

---

## SSH Login Examples

### Basic SSH connection

```bash
# Using explicit key
ssh -i ~/.ssh/id_medtech -p 2222 medadmin@localhost

# Using default SSH key (id_rsa or id_ed25519)
ssh -p 2222 medadmin@localhost

# With verbose output (debugging)
ssh -v -i ~/.ssh/id_medtech -p 2222 medadmin@localhost
```

### With SSH config alias (optional convenience)

Add to `~/.ssh/config`:

```
Host medtech-qemu
    HostName localhost
    Port 2222
    User medadmin
    IdentityFile ~/.ssh/id_medtech
    StrictHostKeyChecking no
```

Then: `ssh medtech-qemu`

### Using sudo inside VM

The `medadmin` account has passwordless sudo:

```bash
# Inside VM after SSH login:
sudo systemctl status mosquitto
sudo cat /etc/shadow
sudo -i  # Drop to root shell
```

### File transfer with SCP

```bash
# Copy file into VM
scp -i ~/.ssh/id_medtech -P 2222 /tmp/localfile.txt medadmin@localhost:/tmp/

# Copy file out of VM
scp -i ~/.ssh/id_medtech -P 2222 medadmin@localhost:/var/log/syslog ./
```

---

## Troubleshooting

### "Permission denied (publickey)"

**Cause 1: Key not in image**
```bash
# Rebuild required after adding key
bitbake -c cleansstate core-image-medtech && bitbake core-image-medtech
```

**Cause 2: Wrong private key or not provided**
```bash
# Verify private key matches public key
ssh-keygen -y -f ~/.ssh/id_medtech
# Should output public key, no errors
```

**Cause 3: Private key permissions wrong**
```bash
chmod 600 ~/.ssh/id_medtech
ls -la ~/.ssh/id_medtech  # Should show: -rw-------
```

### "Connection refused" or "Connection timeout"

Image still booting (takes 20-40 seconds):
```bash
sleep 30 && ssh -i ~/.ssh/id_medtech -p 2222 medadmin@localhost
```

### Stale host key fingerprint

When switching between releases:
```bash
ssh-keygen -R "[localhost]:2222"
ssh -i ~/.ssh/id_medtech -p 2222 medadmin@localhost
```

### Build warning: "MEDTECH_ADMIN_AUTHORIZED_KEY is empty"

Your key file has the placeholder:
```bash
grep "REPLACE" .secrets/medtech-admin-key.pub
# Should NOT match anything

# Fix: add your actual key
cat ~/.ssh/id_medtech.pub > .secrets/medtech-admin-key.pub
```

---

## Verification After Build

```bash
# SSH into VM
ssh -i ~/.ssh/id_medtech -p 2222 medadmin@localhost

# Inside VM, verify your key is provisioned
cat ~/.ssh/authorized_keys

# Verify root login is disabled
su root  # Should fail

# Verify sudo works (no password needed)
sudo whoami  # Outputs: root

# View SSH policy
cat /etc/ssh/sshd_config.d/10-medtech-dev.conf
```

---

## Multi-Developer Setup

Each developer:

1. Generates own keypair:
   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/id_medtech -N ""
   ```

2. Adds their public key:
   ```bash
   cat ~/.ssh/id_medtech.pub > .secrets/medtech-admin-key.pub
   ```

3. **Do NOT share private keys**

4. Builds their own image:
   ```bash
   bitbake core-image-medtech
   ```

5. Each gets their own image with their key provisioned

---

## File Locations Reference

| File | Purpose | Location |
|------|---------|----------|
| Private key (HOST) | Your SSH login credentials | `~/.ssh/id_medtech` |
| Public key (HOST) | To share or copy | `~/.ssh/id_medtech.pub` |
| Auto-detect template | Where build system reads key | `.secrets/medtech-admin-key.pub` |
| Build config | Alternative: manual override | `yocto/build/conf/local.conf` |
| Provisioning logic | Bakes key into image | `yocto/meta-medtech/classes/medtech-image.bbclass` |
| SSH policy | Enforces key-only auth | `yocto/meta-medtech/recipes-core/openssh/files/medtech-dev-sshd.conf` |
| Inside image (read-only) | Provisioned public key | `/home/medadmin/.ssh/authorized_keys` |

---

## Security Best Practices

1. **Private key protection**
   - Keep in `~/.ssh/` with mode 600
   - Never commit to git
   - Use `ssh-agent` for additional protection

2. **Key rotation** — Generate new keypairs periodically (annually recommended)

3. **No default credentials** — Zero static passwords baked in

4. **Production deployment** — Provision keys through secure CI/CD pipeline

---

## See Also

- [ssh-provisioning-advanced.md](ssh-provisioning-advanced.md) — Technical deep dive (architecture, environment chain)
- [../getting-started/quick-start-developer.md](../getting-started/quick-start-developer.md) — Developer workflow including build setup
- [../guides/deployment-troubleshooting.md](../guides/deployment-troubleshooting.md) — Full SSH troubleshooting section
