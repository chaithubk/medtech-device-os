# PRD-004 — MedTech Device OS (Hardened Embedded Linux)

| Field | Value |
|---|---|
| **Document ID** | PRD-004 |
| **Product** | MedTech Device OS |
| **Repo** | `chaithubk/medtech-device-os` |
| **Author** | MedTech R&D |
| **Status** | Active |
| **Last Updated** | 2026-05-13 |

> **Zero PHI Declaration:** This repository contains no patient data. All service configurations reference synthetic vitals from the MedTech Vitals Publisher. No PHI or PII is embedded in the OS image, recipes, or configuration files. This platform is an educational R&D prototype only.

---

## 1. Opportunity

Medical devices deployed in clinical environments operate under a fundamentally different risk profile than enterprise software:

1. **Physical security**: The device is in a shared clinical space. Any unauthorized shell access is a potential HIPAA breach vector.
2. **Software integrity**: An altered edge analytics binary that suppresses a sepsis alarm could cause patient harm. The OS must cryptographically enforce software integrity.
3. **Supply chain transparency**: FDA premarket submissions require a complete Software Bill of Materials (SBOM) to document all third-party components and their vulnerability status.
4. **Deterministic build reproducibility**: A device that behaves differently across production units — due to non-reproducible builds — is a regulatory defect, not just a software bug.
5. **Offline resilience**: Clinical networks experience routine outages. The device must operate fully offline with zero degradation of alarm functionality.

No general-purpose Linux distribution satisfies all five requirements simultaneously. Yocto Linux addresses all five: it produces a minimal, reproducible, auditable, read-only embedded image tailored precisely to the MedTech service stack.

The **MedTech Device OS** is the hardened Yocto Linux image that runs the MedTech service stack — vitals publisher, edge analytics, clinician UI — as managed systemd units on a read-only rootfs, with automated SPDX 2.2 SBOM generation and a QEMU ARM64 CI validation pipeline that de-risks the software stack before committing to NXP i.MX8MP hardware.

### Strategic Value

| Value | Description |
|---|---|
| **FDA Readiness** | SPDX 2.2 SBOM and read-only rootfs directly address FDA premarket cybersecurity guidance |
| **Hardware Cost Avoidance** | QEMU CI validation eliminates the need for physical device farms during early development |
| **Zero-Downtime Integrity** | Read-only rootfs prevents accidental or malicious modification of service binaries |
| **Reproducible Compliance** | BitBake produces bit-identical images across builds; mandatory for IEC 62304 §8 configuration management |

---

## 2. Target Audience

### Primary Users (Technical)

| Persona | Need |
|---|---|
| **Embedded Linux Engineer** | A maintainable Yocto layer (`meta-medtech`) with clean service recipes, a KAS configuration, and a CI pipeline that validates the image in QEMU before every merge |
| **Device Security Engineer** | A read-only rootfs, dm-verity enforcement path, and automated SBOM generation to satisfy cybersecurity design requirements |
| **Platform Integration Engineer** | Confidence that services deployed in Docker Compose (`medtech-platform`) behave identically on the Yocto OS image |

### Secondary Users (Clinical & Regulatory)

| Persona | Need |
|---|---|
| **Regulatory Affairs Manager** | An SPDX 2.2 SBOM artifact per release, read-only rootfs architecture documented in the Design History File |
| **Hospital DevOps / Biomed Engineer** | A stable, versioned device image that can be validated offline and deployed via OTA without physical re-imaging |
| **Clinical Risk Manager** | Evidence that the inference binary on the deployed device is cryptographically identical to the validated release artifact |

---

## 3. Product Vision

> Provide a hardened, reproducible, FDA-ready Yocto Linux image that runs the MedTech service stack on clinical-grade ARM64 hardware with a read-only rootfs, automated SBOM generation, and QEMU-validated CI — so that the device can be certified, deployed, and trusted in a clinical environment.

---

## 4. Success Metrics

| Metric | Target | Measurement Method |
|---|---|---|
| QEMU boot-to-service-ready time | **< 90 seconds** | CI workflow wall-clock time |
| SBOM completeness | **100% of packages** with SPDX 2.2 license and version fields | `bitbake -c create-spdx` validation script |
| Read-only rootfs enforcement | **0 writable paths** under `/usr`, `/bin`, `/lib`, `/sbin` | Mount table audit in CI |
| CI image build reproducibility | **Bit-identical image** across two independent builds from the same inputs | SHA-256 image digest comparison |
| Contract version parity with latest release | **0 days** lag after automated contract drift PR merge | `contracts/contract-pin.json` sync workflow |
| Service recovery after crash | **< 30 seconds** via systemd restart | QEMU integration test |

---

## 5. Scope

### In Scope

- `meta-medtech` Yocto layer with recipes for:
  - `medtech-vitals-publisher`
  - `medtech-edge-analytics`
  - `medtech-clinician-ui`
  - `medtech-system` (telemetry contract schema installation)
- KAS YAML configuration for reproducible build setup
- Read-only rootfs configuration (`IMAGE_FEATURES += "read-only-rootfs"`)
- Automated SPDX 2.2 SBOM generation per release
- QEMU ARM64 boot and service validation in CI
- `contracts/contract-pin.json` machine-readable contract version pin
- Automated contract drift detection and SRCREV bump workflows
- Release promotion workflow with SBOM artifact attachment

### Out of Scope

- OTA (Over-The-Air) update infrastructure (planned for v3.x)
- dm-verity runtime integrity enforcement (planned for v3.x pre-production)
- Secure boot key provisioning
- Hardware bring-up for NXP i.MX8MP (post-QEMU phase)

---

## 6. Functional Requirements

### FR-001: Service Recipes

The `meta-medtech` layer MUST provide Yocto recipes for `medtech-vitals-publisher`, `medtech-edge-analytics`, and `medtech-clinician-ui` that:
- Pin `SRCREV` to a release-tagged commit SHA
- Install service binaries and configuration to the rootfs
- Install systemd unit files with `Restart=on-failure`
- Source environment files from a controlled path (e.g., `/etc/medtech/<service>.env`)

### FR-002: Telemetry Contract Installation

The `medtech-system` recipe MUST install the vendored telemetry contract schema to:
- `/usr/share/medtech/contracts/vitals/vitals.schema.json`
- `/usr/share/medtech/contracts/schemas/vitals/vitals.schema.json`

### FR-003: Read-Only Rootfs

The image MUST be built with `IMAGE_FEATURES += "read-only-rootfs"`. The build MUST fail if any recipe attempts to write to rootfs paths at runtime.

### FR-004: SBOM Generation

Every release build MUST invoke `bitbake -c create-spdx <image>` and produce an SPDX 2.2 JSON artifact. The artifact MUST be attached to the GitHub Release.

### FR-005: Contract Pin Metadata

`contracts/contract-pin.json` MUST exist and contain:
- `contract_repo`, `tag`, `commit_sha`, `schema_path`
- `installed_paths` (array of runtime schema paths)
- `yocto_recipe_path` (path to `medtech-system.bb`)
- `synced_at_utc`

### FR-006: Automated Contract Drift

A GitHub Actions workflow MUST detect when the upstream contract releases a new version and automatically open a PR that updates:
- `contracts/contract-pin.json`
- `SRCREV` and version variable in `medtech-system.bb`

### FR-007: Service SRCREV Automation

A GitHub Actions workflow MUST detect when a consumer service repo releases a new version and automatically open a PR that updates the corresponding recipe `SRCREV` and a `contracts/service-pins.json` file.

---

## 7. Non-Functional Requirements

| ID | Requirement | Standard Reference |
|---|---|---|
| NFR-001 | Image MUST be built reproducibly (bit-identical given identical inputs) | IEC 62304 §8 (configuration management) |
| NFR-002 | SBOM MUST cover 100% of installed packages with license, version, and supplier | FDA Cybersecurity Premarket Guidance (2023) |
| NFR-003 | Read-only rootfs MUST be enforced at mount level, not software convention | HIPAA §164.312(c) (integrity controls) |
| NFR-004 | All services MUST restart automatically after crash within 30 seconds | IEC 60601-1-8 §5.2 (alarm system availability) |
| NFR-005 | CI MUST validate QEMU boot and service communication before any image is promoted | ISO 14971 §10 (verification) |
| NFR-006 | `contracts/contract-pin.json` MUST be updated within 24 hours of a contract release | Program governance SLA |

---

## 8. Regulatory & Standards Alignment

| Standard | Relevance to This Product |
|---|---|
| **IEC 60601-1-8:2006+AMD1:2012** | Device OS is the substrate on which the physiological alarm system runs. Read-only rootfs and systemd restart policies directly address §5.2 (alarm system availability) and §6.3 (alarm response time preservation across reboots). |
| **ISO 14971:2019 §7** | Read-only rootfs is a risk control for the hazard "unauthorized modification of inference binary." SBOM is a risk control for the hazard "unknown vulnerable third-party component." |
| **IEC 62304:2015 §8** | BitBake produces a reproducible software item configuration. `SRCREV` pinning in recipes constitutes item-level change control. SBOM constitutes the software architecture document at release. |
| **FDA Cybersecurity Premarket Guidance (Sep 2023)** | SPDX 2.2 SBOM is explicitly required. The guidance also recommends post-market SBOM update procedures, which the automated contract/SRCREV drift workflows partially satisfy. |
| **NIST SP 800-193 (Platform Firmware Resiliency)** | Read-only rootfs + planned dm-verity constitutes a Protection mechanism under the Detect/Protect/Recover triad. |
| **HL7 FHIR / IHE IUA** | Device identity and OS version can be surfaced as FHIR `Device` resource attributes for EHR audit logs. |

---

## 9. Risks & Mitigations (ISO 14971 Format)

| Risk | Likelihood | Severity | Risk Control |
|---|---|---|---|
| Service binary modified post-deployment | Low | Critical (inference tampering) | Read-only rootfs; planned dm-verity |
| SBOM incomplete — vulnerable package undetected | Medium | High (FDA citation; patient risk) | `create-spdx` validation step in release CI |
| Contract version on device lags latest — parse failure | Medium | High (inference starved) | Automated contract drift PR within 24 hours |
| QEMU build non-reproducible across runners | Low | High (regulatory defect) | Pinned Yocto layer revisions in KAS YAML |
| systemd service fails silently after OOM | Low | High (no alarm) | `Restart=on-failure`; OOM score pinning in unit files |

---

## 10. Dependencies

| Dependency | Repo | Note |
|---|---|---|
| Telemetry Contract | `medtech-telemetry-contract` | Schema installed to rootfs; pin tracked in `contract-pin.json` |
| Vitals Publisher | `medtech-vitals-publisher` | Service binary + env deployed as systemd unit |
| Edge Analytics | `medtech-edge-analytics` | Service binary + TFLite model + env deployed as systemd unit |
| Clinician UI | `medtech-clinician-ui` | Service binary deployed as systemd unit |

---

## 11. Open Questions

1. When should dm-verity runtime integrity enforcement be added? (Pre-NXP hardware phase vs. first pilot deployment?)
2. Should the device OS support A/B partition updates for zero-downtime OTA in v3.x?
3. Should `medtech-contract-info` be surfaced as a REST endpoint (e.g., port 8080) for biomed engineer device audit queries?
