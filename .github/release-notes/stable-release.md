## MedTech Device OS — `{{IMAGE}}`

| Field | Value |
|---|---|
| Version | `{{TARGET_TAG}}` |
| Channel | `{{CHANNEL}}` |
| Commit | [`{{SHORT_SHA}}`]({{REPO_URL}}/commit/{{COMMIT}}) |
| SSH mode | `{{SSH_MODE}}` |

---

## Quick Start

1. One-time host setup:

```bash
bash scripts/setup-host-qemu-prereqs.sh
```

2. Download and boot this release:

```bash
bash scripts/download-and-run-qemu.sh --release {{TARGET_TAG}}
```

3. Verify integrity:

```bash
sha256sum -c SHA256SUMS
```

---

## SSH Login

`public-hardened`
- First boot asks for your SSH public key on the serial console.
- Generate if needed:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_medtech -N ""
cat ~/.ssh/id_medtech.pub
```

- Login:

```bash
ssh -i ~/.ssh/id_medtech -p 2222 medadmin@localhost
```

`internal-keyed`
- Login with the private key matching the baked-in public key:

```bash
ssh -i <matching-private-key> -p 2222 medadmin@localhost
```

Password login and root login are disabled.
