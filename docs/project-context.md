# Project Context — MedTech Device OS

## Project summary
This repository builds the MedTech device-side Linux runtime as a Yocto/QEMU image.

It is the embedded execution layer for the MedTech program and should remain runtime-focused, lean, and reproducible.

---

## Current program intent
The device OS is expected to:
- boot in QEMU
- run systemd services
- host MQTT-based telemetry
- support Qt6 clinician UI runtime needs
- generate SBOM artifacts
- publish CI outputs cleanly

---

## Current concerns
- Yocto build size and disk usage
- Qt6 dependency complexity
- accidental inclusion of build-only packages
- CI instability from resource exhaustion
- SBOM correctness and maintainability

---

## Milestones
### Milestone 1
- QEMU boots
- services run
- Qt6 works headless/offscreen
- SBOM builds cleanly

### Milestone 2
- CI is stable
- image stays lean
- runtime packages are minimal
- build artifacts are reproducible

### Milestone 3
- device OS integrates cleanly with the other repos in the MedTech program

---

## Operational checklist
- [ ] Build succeeds
- [ ] QEMU boots
- [ ] systemd services start in order
- [ ] Qt6 support works
- [ ] SBOM is generated
- [ ] CI does not run out of disk space
- [ ] No unnecessary SDK/toolchain bloat
- [ ] Shared telemetry contract is preserved

---

## Review guidance
When working in this repo:
- keep changes device-side only
- keep the image lean
- avoid extra packages unless required by runtime needs
- avoid custom fragile build logic
- keep the repo aligned with the larger MedTech system

---

## Status note
This repo is part of the larger MedTech program, but it is specifically the QEMU / Yocto device OS layer.