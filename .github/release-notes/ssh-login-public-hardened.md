On first boot, the system will ask for your SSH public key via the serial console:

1. Generate if needed:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_medtech -N ""
cat ~/.ssh/id_medtech.pub
```

2. Copy your public key from the output above.

3. When prompted on first boot, paste your SSH public key.

4. After provisioning, login with:

```bash
ssh -i ~/.ssh/id_medtech -p 2222 medadmin@localhost
```

This release uses **public-hardened** SSH mode: SSH access requires first-boot key provisioning via serial console.
