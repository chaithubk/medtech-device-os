## MedTech Device OS — `{{IMAGE}}`

| Field | Value |
|---|---|
| **Version** | `{{VERSION}}` |
| **Channel** | prerelease |
| **Commit** | [`{{SHORT_SHA}}`]({{REPO_URL}}/commit/{{COMMIT}}) |
| **SSH Mode** | `{{SSH_MODE}}` |

> **Prerelease build** — generated automatically from `{{BRANCH}}` for testing. For a stable release see [latest]({{REPO_URL}}/releases/latest).

---

## Run the Image

**One-time QEMU setup** (first use only):

```bash
bash scripts/setup-host-qemu-prereqs.sh
```

**Download and boot:**

```bash
bash scripts/download-and-run-qemu.sh --tag {{VERSION}}
```

The script downloads, verifies checksums, and boots QEMU. When ready it prints:

```
  ✓ SSH daemon is responding

Connect now:
  ssh -i ~/.ssh/id_medtech -p 2222 medadmin@localhost
```

---

## SSH Access (`{{SSH_MODE}}`)

**`public-hardened`** — no key is baked in. On first boot a wizard runs on the
console and prompts you to paste your SSH public key. Generate one if needed:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_medtech -N ""
cat ~/.ssh/id_medtech.pub   # paste this at the first-boot prompt
```

Log in after provisioning:

```bash
ssh -i ~/.ssh/id_medtech -p 2222 medadmin@localhost
```

**`internal-keyed`** — use the private key matching the baked-in public key:

```bash
ssh -i <matching-private-key> -p 2222 medadmin@localhost
```

> Password login and root login are disabled on all builds.

---

## Verify Checksums

```bash
sha256sum -c SHA256SUMS
```
