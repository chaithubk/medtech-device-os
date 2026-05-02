# AI Context — MedTech Device OS

This repository is the **QEMU / Yocto Linux device OS** for the MedTech program.

## What this repo owns
- Yocto / Poky build system
- QEMU bootable Linux image
- systemd service orchestration
- device-side runtime packages
- Qt6 runtime support for the clinician UI
- SBOM generation
- CI/CD build validation and artifact publishing

## What this repo does not own
- Docker-based platform orchestration
- cloud telemetry backend
- edge analytics logic itself
- clinician UI source code

## Program relationship
This repo is one part of the larger MedTech system. The other repos are:
- `medtech-platform` — Docker-based orchestration and simulation
- `medtech-vitals-publisher`— vitals simulation via MQTT
- `medtech-edge-analytics` — local sepsis prediction
- `medtech-clinician-ui` — Qt6 bedside dashboard
- `medtech-telemetry-cloud` — cloud telemetry ingestion and dashboards

## Key instruction for AI
Treat this repo as the **device-side embedded Linux runtime**.  
Keep changes aligned with:
- QEMU bootability
- minimal runtime dependencies
- headless/offscreen Qt6 support
- standard Yocto SBOM generation
- CI stability

## Shared telemetry contract
- vitals: timestamp, hr, bp_sys, bp_dia, o2_sat, temperature, quality, source
- prediction: timestamp, risk_score, risk_level, confidence, model_latency_ms

If a change affects this contract, it must be coordinated across the program.

## Canonical references
- `docs/program-context.md`
- `docs/project-context.md`