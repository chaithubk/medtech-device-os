# ADR-004 — Selection of QEMU ARM64 for Initial Software Validation

| Field | Value |
|---|---|
| **ADR ID** | ADR-004 |
| **Title** | Selection of QEMU ARM64 for Initial Software Validation Before NXP i.MX8MP Hardware |
| **Status** | Accepted |
| **Date** | 2026-05-13 |
| **Deciders** | MedTech R&D, Systems Architect, Hardware Lead |
| **Affected Repos** | `medtech-device-os` |

---

## Context

The MedTech device OS is being built for deployment on **NXP i.MX8MP**-class ARM64 hardware — a quad-core Cortex-A53 processor with integrated NPU, targeting clinical-grade bedside device form factors. The Yocto build system (`meta-medtech`) produces an ARM64 Linux image.

A fundamental program sequencing question arose early in the project:

> **Should software stack development, CI/CD pipeline construction, and design verification testing proceed on physical NXP i.MX8MP hardware from day one?**

Two options were evaluated:

### Option A: Physical Hardware Development from Day One

Procure NXP i.MX8MP development boards (e.g., EVK) as the primary development and CI target. All Yocto builds, service integration, and inference latency tests run on real hardware.

### Option B: QEMU ARM64 Emulation for Initial Validation, Physical Hardware Later

Use QEMU's `virt` machine with ARM64 CPU emulation as the primary CI and early validation target. Migrate to physical NXP i.MX8MP hardware in a subsequent phase when the software stack is stable and the hardware board bring-up team is ready.

---

## Decision

**QEMU ARM64 emulation (Option B) is selected for the initial validation phase.**

The Yocto image is built for `MACHINE = "qemuarm64"`, and CI validation runs boot and service integration tests using `runqemu`. All core software functionality — service startup, MQTT communication, TFLite inference, systemd unit management, read-only rootfs — is validated in QEMU before any physical hardware is required.

The transition to NXP i.MX8MP hardware is explicitly planned for a subsequent program phase and is tracked as a milestone in the device OS roadmap.

---

## Rationale

### 1. De-Risk the Software Stack Before Hardware Commitment

Physical NXP i.MX8MP development boards have a lead time of 8–16 weeks. More importantly, physical hardware introduces a second variable — board bring-up, BSP driver stability, hardware defects — on top of the software stack complexity. Attempting to debug a TFLite inference latency regression on hardware while simultaneously troubleshooting a UART driver issue is a productivity and schedule risk.

QEMU allows the software team to develop, test, and validate the full application stack — vitals publisher, edge analytics, clinician UI, systemd units, read-only rootfs — completely independently of hardware availability and BSP maturity.

### 2. CI/CD Velocity

A scalable, automated CI pipeline is a program-level competitive advantage. Every merge to the device OS repository runs a full build and QEMU boot test in under 90 seconds. This would be impossible to replicate at scale with a shared physical hardware farm in the early phase — provisioning, flashing, and managing physical boards in CI requires infrastructure investment that is not justified until the software stack is stable.

QEMU provides a **GitHub Actions-compatible, ephemeral, reproducible emulation environment** at zero hardware cost. This enables:
- Branch-level integration testing
- Per-commit boot regression detection
- Parallel CI execution across multiple virtual boards

### 3. Instruction Set Architectural Fidelity

QEMU ARM64 emulates the ARMv8-A instruction set, which is the same ISA as the NXP i.MX8MP Cortex-A53 cores. This means:
- Compiled ARM64 binaries run identically in QEMU and on hardware
- TFLite inference produces identical numerical outputs
- Yocto image configuration (rootfs layout, systemd unit behavior, read-only enforcement) is validated correctly
- The only gap is hardware-specific peripherals (MIPI-DSI display, I2C sensors, NPU) — none of which are in scope for the current validation phase

### 4. Program Cost and Resource Optimization

Physical hardware development from day one requires:
- Board procurement costs (NXP EVK: ~$300–500/unit; 3–5 units for parallel CI: $1,500–2,500)
- Hardware bring-up engineering time (estimated 4–8 weeks for a stable BSP)
- Physical infrastructure (test rack, power, cables, KVM switches)
- Board failure and replacement logistics

QEMU eliminates all of these costs during the initial software validation phase, deferring hardware investment to the point where it provides maximum value — when the software stack is proven and hardware-specific peripheral integration begins.

### 5. Regulatory Benefit: Reproducible Design Verification Evidence

IEC 62304 §5.7 requires integration testing evidence that is reproducible and traceable. QEMU produces bit-identical test execution environments across every CI run, every runner, and every point in time. Physical hardware test results can vary due to hardware drift, thermal conditions, or board-to-board variation.

QEMU-based design verification evidence is:
- Fully reproducible: same inputs always produce same outputs
- Traceable: CI run logs are stored with the GitHub Actions run record
- Archivable: QEMU boot logs are artifacts attached to every release

---

## Consequences

### Positive

- Software team can develop and validate the full stack without hardware availability
- CI pipeline runs at GitHub Actions scale (parallel, ephemeral, zero hardware cost)
- Reproducible, archivable design verification evidence for IEC 62304 §5.7
- No hardware procurement risk on the critical path
- QEMU `virt` machine boot provides clean separation of software and hardware concerns

### Negative

- QEMU does not emulate NXP i.MX8MP-specific peripherals (I2C, MIPI-DSI, CAN bus, NPU)
- QEMU ARM64 CPU performance is approximately 5–10× slower than physical Cortex-A53 — TFLite latency benchmarks on QEMU are not representative of production hardware performance
- Real-world memory and storage throughput characteristics differ from physical eMMC/LPDDR4

### Neutral

- Hardware-specific validation (NPU delegate, display, sensor drivers) is explicitly deferred to the NXP bring-up phase
- The Yocto image configuration uses `MACHINE = "qemuarm64"` in CI; the production `MACHINE = "imx8mp-evk"` config is maintained in a separate layer and switched at the hardware bring-up milestone

---

## QEMU Validation Scope vs. Hardware Validation Scope

| Validation Area | QEMU ARM64 | Physical NXP i.MX8MP |
|---|---|---|
| Yocto image boot | ✅ | ✅ |
| systemd service startup | ✅ | ✅ |
| MQTT broker + publisher | ✅ | ✅ |
| TFLite inference (correctness) | ✅ | ✅ |
| Read-only rootfs enforcement | ✅ | ✅ |
| SBOM generation | ✅ | ✅ |
| TFLite inference latency (< 100 ms) | ⚠️ (QEMU is slower; not representative) | ✅ (required for IEC 60601-1-8 compliance) |
| NPU delegate acceleration | ❌ | ✅ (future phase) |
| Display / MIPI-DSI | ❌ | ✅ (future phase) |
| I2C hardware sensor input | ❌ | ✅ (future phase) |

---

## Alternatives Considered

| Alternative | Reason Rejected |
|---|---|
| Physical NXP EVK from day one | Hardware procurement lead time; BSP maturity risk; CI scalability cost; hardware failure disrupts development |
| Raspberry Pi 4 (ARM64) as proxy hardware | Different SoC; no NXP BSP; inference latency numbers not transferable to i.MX8MP; creates false confidence in hardware-specific behavior |
| x86_64 Docker simulation only | Does not validate ARM64 instruction set compatibility; SIMD/NEON TFLite paths untested; not valid design verification evidence for ARM64 device |
| Cross-compilation testing only (no emulation) | Does not validate runtime behavior; systemd unit management, rootfs layout, and service communication cannot be tested without a running OS |

---

## Standards References

| Standard | Relationship to This Decision |
|---|---|
| **IEC 62304:2015 §5.7** | Integration testing in QEMU constitutes valid design verification evidence provided the test environment is documented and its limitations (QEMU vs. hardware gaps) are explicitly recorded (this ADR). |
| **ISO 14971:2019 §10** | QEMU CI provides a reproducible verification environment for risk controls (e.g., "service restarts within 30 seconds after crash"). |
| **IEC 60601-1-8:2006+AMD1:2012** | QEMU latency benchmarks are explicitly **not** used to satisfy the < 100 ms alarm response time requirement. Physical NXP i.MX8MP hardware validation is required for that specific compliance claim. This is documented as a program milestone gate. |
| **FDA Software Premarket Guidance (2023)** | This ADR constitutes the documented "design verification strategy" rationale, explicitly recording which tests apply to QEMU and which are deferred to hardware, as required for the Software Development Plan. |

---

## Review Date

This decision expires and must be revisited when:
- NXP i.MX8MP EVK hardware is available and BSP is stable in the Yocto layer
- Physical inference latency validation is required for IEC 60601-1-8 §6.3 compliance evidence
- NPU delegate integration begins

At that milestone, this ADR transitions from "Accepted" to "Superseded" and a new ADR documents the hardware validation strategy.
