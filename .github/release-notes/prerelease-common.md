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
bash scripts/download-and-run-qemu.sh --release {{VERSION}}
```

The script downloads, verifies checksums, and boots QEMU. When ready it prints:

```
  ✓ SSH daemon is responding

Connect now:
  ssh -i ~/.ssh/id_medtech -p 2222 medadmin@localhost
```

---

## SSH Access: {{SSH_MODE}}

{{SSH_LOGIN_SECTION}}

---

## Security

- Password login is **disabled**
- Root login is **disabled**
- Only SSH key-based authentication is allowed

---

## Verify Checksums

```bash
sha256sum -c SHA256SUMS
```
