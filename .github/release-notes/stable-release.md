## MedTech Device OS — `{{IMAGE}}`

| Field | Value |
|---|---|
| Version | `{{TARGET_TAG}}` |
| Channel | `{{CHANNEL}}` |
| Commit | [`{{SHORT_SHA}}`]({{REPO_URL}}/commit/{{COMMIT}}) |
| SSH mode | **`{{SSH_MODE}}`** |

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

## SSH Access: {{SSH_MODE}}

{{SSH_LOGIN_SECTION}}

---

## Security

- Password login is **disabled**
- Root login is **disabled**
- Only SSH key-based authentication is allowed
