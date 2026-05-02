# Program Context — MedTech Device OS

## Purpose
This repository is the **QEMU / Yocto Linux device OS** for the MedTech program.

It is responsible for the embedded runtime layer that boots in QEMU and later on hardware. It should remain focused on the device-side execution environment, service orchestration, SBOM, and CI/CD.

---

## Role in the MedTech program
This repo owns:
- Yocto/Poky build setup
- QEMU bootable Linux image
- systemd service orchestration
- runtime package selection
- Qt6 runtime support for the clinician UI
- SBOM generation
- CI/CD build validation and artifact delivery

This repo does **not** own:
- Docker-based simulation/orchestration
- cloud telemetry
- the clinician UI source itself
- the edge analytics application logic itself

---

## Architecture expectations
### Device OS behavior
- reproducible Yocto build
- successful QEMU boot
- correct service startup ordering
- minimal runtime-only package selection
- offscreen/headless Qt6 support where needed
- standards-based SBOM generation
- CI artifact publishing

### Runtime services
The image should support the MedTech runtime stack:
- MQTT broker
- vitals publisher
- edge analytics
- clinician UI

### Build expectations
- avoid SDK/toolchain/debug bloat
- keep CI disk usage controlled
- keep the image lean and reproducible
- use standard Yocto mechanisms where possible

---

## Shared telemetry contract
### Vitals payload
- timestamp
- hr
- bp_sys
- bp_dia
- o2_sat
- temperature
- quality
- source

### Prediction payload
- timestamp
- risk_score
- risk_level
- confidence
- model_latency_ms

Any change to this contract must be aligned with the rest of the program.

---

## On-track criteria
This repo is on track if:
- the Yocto image builds
- QEMU boots successfully
- systemd services start correctly
- Qt6 works headless/offscreen when needed
- SBOM generation works
- CI is stable
- unnecessary build bloat is avoided

---

## Deviation signals
This repo is drifting if:
- SDK/toolchain/debug packages are being added unnecessarily
- Qt6 dependencies become overly complex
- SBOM logic becomes fragile or custom
- QEMU support regresses
- the image grows without reason
- service orchestration no longer reflects the MedTech runtime model

---

## Current priorities
1. Keep the image lean and runtime-focused
2. Preserve QEMU bootability
3. Keep Qt6 in the image, but allow offscreen/headless operation
4. Use standard Yocto SBOM generation
5. Make CI resilient to size and disk constraints
6. Stay aligned to the shared telemetry contract

---

## Review questions
When reviewing changes here:
- Does this belong in the device OS?
- Does this improve the QEMU/Yocto image?
- Does it increase or reduce reproducibility?
- Does it add unnecessary bloat?
- Does it preserve the shared telemetry contract?
- Does it support the program’s end goal?

---

## Summary
`medtech-device-os` is the MedTech device-side embedded Linux repo.

It should remain focused on:
- Yocto/QEMU runtime
- service orchestration
- Qt6 runtime support
- SBOM and CI
- minimal reproducible packaging