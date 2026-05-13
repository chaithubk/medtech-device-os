# First-Boot SSH Key Provisioning

For public-hardened release images, SSH access is not enabled by default. This guide explains how to provision your SSH public key on first boot.

This flow applies to both `core-image-minimal` and `core-image-medtech` images.

---

## What Happens on First Boot

When you boot a MedTech Device OS image for the first time:

1. The first-boot setup wizard opens on the serial console
2. You paste one SSH public key line
3. The key is stored as `medadmin` authorized key
4. Password login remains disabled
5. All future access uses SSH key-based authentication

---

## Step 1: Prepare Your SSH Key (Host)

On your host computer, check if you have an SSH key:

```bash
# Check if key exists
ls ~/.ssh/id_medtech
```

If not, create one:

```bash
# Generate Ed25519 key (recommended)
ssh-keygen -t ed25519 -f ~/.ssh/id_medtech -N "" -C "medtech@device"

# OR generate RSA key (if Ed25519 unavailable)
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_medtech -N "" -C "medtech@device"
```

Display your public key:

```bash
cat ~/.ssh/id_medtech.pub
```

Output will look like:
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHlahII4BW7uNRgtBfCADGQA7Lnfz/df5pz6OLmejKv0 medtech@device
```

**Copy the entire line** — you'll paste it into the device during first boot.

---

## Step 2: Boot the MedTech Device OS Image

Boot the image in QEMU or your target device. The first-boot setup wizard appears on `ttyAMA0` before a normal login prompt.

---

## Step 3: First-Boot SSH Key Provisioning

1. **SSH key provisioning prompt appears automatically:**

   You'll see a screen like:
   ```
   ╔════════════════════════════════════════════════════════════════════╗
   ║                    MedTech Device OS - First Boot                  ║
   ║                   SSH Key Provisioning Setup                       ║
   ╚════════════════════════════════════════════════════════════════════╝

   To enable secure SSH access, you need to provide your SSH public key.
   
   ...instructions...
   
   Press Enter when ready to paste your SSH public key:
   ```

2. **Follow the on-screen prompts:**
   - Press Enter
   - Paste your SSH public key (from Step 1) using Ctrl+Shift+V or right-click
   - Press Enter

3. **Success screen:**
   ```
   ╔════════════════════════════════════════════════════════════════════╗
   ║               SSH Key Provisioning Complete ✓                      ║
   ╚════════════════════════════════════════════════════════════════════╝

   Your SSH public key has been provisioned successfully.
   Password-based login is now PERMANENTLY DISABLED.
   ```

---

## Step 4: Connect via SSH from Host

After provisioning, exit the serial console (type `exit`) and connect via SSH from your host:

```bash
# For QEMU (port forward localhost:2222 → guest:22)
ssh -i ~/.ssh/id_medtech -p 2222 medadmin@localhost

# For physical device on network
ssh -i ~/.ssh/id_medtech medadmin@<device-ip>
```

You should now have shell access without entering a password.

---

## Troubleshooting

### "SSH key already provisioned; skipping setup"

The first-boot setup already ran. The service only runs once. 

If you need to change your SSH key, manually edit:
```bash
sudo nano ~/.ssh/authorized_keys
```

### "Invalid SSH public key format"

Make sure you pasted the **entire line** starting with `ssh-ed25519` or `ssh-rsa`.

Do NOT include shell prompts (`$`) or any extra whitespace.

### Pasting key doesn't work in serial console

Some terminal emulators have limited copy-paste support. Try:
- Use your terminal's right-click paste menu
- Try Ctrl+Shift+V instead of Ctrl+V
- Or manually type the key (not practical for long keys)
- If on Windows with WSL: use WSL terminal emulator, not cmd.exe

### Lost private key — cannot log in

If you lose your private key (`~/.ssh/id_medtech`), you cannot log in remotely.

Your options:
1. Rebuild the image with a different public key in `.secrets/medtech-admin-key.pub` and redeploy
2. For QEMU: kill the VM and boot again (ephemeral image)
3. For physical device: request physical console access or full device reset

**Recommendation:** Back up your private key:
```bash
# Secure backup
cp ~/.ssh/id_medtech ~/backup/id_medtech.backup
chmod 600 ~/backup/id_medtech.backup
```

---

## Security Notes

- No default login password is baked into the image for `medadmin`.
- After SSH key provisioning, password login is **completely disabled** (`usermod -p '*' medadmin`).
- The first-boot setup service runs only once (`ConditionFirstBoot=yes`).
- For production deployments, provision public keys via build-time or controlled first-boot process.

---

## For Development Builds

If you're building locally and want to skip the interactive setup:

1. Put your SSH public key in `.secrets/medtech-admin-key.pub` **before building**:
   ```bash
   cat ~/.ssh/id_medtech.pub > .secrets/medtech-admin-key.pub
   ```

2. Build the image:
   ```bash
   bitbake core-image-medtech
   ```

3. Boot and SSH directly (no first-boot prompt):
   ```bash
   ssh -i ~/.ssh/id_medtech -p 2222 medadmin@localhost
   ```

---

## See Also

- [SSH Provisioning Guide](ssh-provisioning.md) — detailed SSH architecture
- [Quick Start User](../getting-started/quick-start-user.md) — complete download-and-boot guide
- [Deployment Troubleshooting](deployment-troubleshooting.md) — SSH connection issues
