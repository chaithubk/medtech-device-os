# ADR-005 — Adoption of SPDX 2.2 for Software Bill of Materials (SBOM)

| Field | Value |
|---|---|
| **ADR ID** | ADR-005 |
| **Title** | Adoption of SPDX 2.2 for Software Bill of Materials (SBOM) |
| **Status** | Accepted |
| **Date** | 2026-05-13 |
| **Deciders** | MedTech R&D, Regulatory Affairs, Systems Architect |
| **Affected Repos** | `medtech-device-os` (primary), all repos (supply chain visibility) |

---

## Context

A **Software Bill of Materials (SBOM)** is a formal, machine-readable inventory of every software component included in a shipped product — including open-source packages, commercial libraries, and first-party components — along with their versions, licenses, and known vulnerability status.

For a medical device, an SBOM is not optional. It sits at the intersection of three converging regulatory and security mandates:

1. **FDA Cybersecurity Premarket Guidance (Sep 2023)**: Explicitly requires an SBOM as part of every medical device premarket submission. The guidance states the SBOM must be generated using a recognized standard format.
2. **Executive Order 14028 (May 2021)**: Requires all software sold to US federal entities (including VA hospitals, DoD medical facilities) to include an SBOM.
3. **Supply Chain Risk Management (SCRM)**: A device running a library with a known CVE — undetected because no SBOM was maintained — is both a patient safety risk and a regulatory defect.

Two SBOM standard formats were considered:

### Option A: SPDX (Software Package Data Exchange)

SPDX is an ISO/IEC 5962:2021 standard maintained by the Linux Foundation. SPDX 2.2 (the current production version at design time) defines a structured format for package identity, licensing, relationships, and file hashes. It is natively supported by:
- `bitbake -c create-spdx` (Yocto's built-in SBOM generation)
- GitHub Dependency Review
- NIST's SBOM tools (sbom-tool, ntia-conformance-checker)
- FDA's recommended format in the 2023 guidance

### Option B: CycloneDX

CycloneDX is an OWASP-maintained SBOM standard with strong tooling in the Java/npm/Python ecosystem. It supports vulnerability enrichment via VEX (Vulnerability Exploitability eXchange) natively.

---

## Decision

**SPDX 2.2 is selected as the SBOM standard for the MedTech device OS.**

SBOM generation is automated via `bitbake -c create-spdx <image>` in the Yocto release build pipeline. The resulting SPDX 2.2 JSON artifact is attached to every GitHub Release as a release asset.

---

## Rationale

### 1. FDA Premarket Guidance Alignment

The FDA's September 2023 cybersecurity premarket guidance explicitly names SPDX and CycloneDX as acceptable SBOM formats. It does not prescribe a single format, but SPDX has broader adoption in the embedded Linux and medical device community. More critically, SPDX is the **native output format of the Yocto build system via `create-spdx`**, making it zero-cost to generate as part of the existing BitBake pipeline.

Selecting SPDX means the SBOM is generated automatically and completely by the build system — not manually curated by an engineer. Manual SBOM maintenance is error-prone, incomplete, and constitutes a quality system deficiency under IEC 62304 §8.

### 2. Yocto Native Integration (Zero Additional Tooling)

The Yocto Project's `meta-spdxscanner` layer and the `create-spdx` BitBake class generate a complete SPDX 2.2 document that includes:
- Every installed package (recipe name, version, license, source URL)
- Package-to-package dependency relationships
- File-level checksums (SHA1/SHA256) for all installed files
- SPDX document namespace with a unique identifier per build

This is exactly the coverage required by FDA guidance. No additional SBOM tooling, scanning agent, or post-processing step is required.

### 3. Supply Chain Transparency for CVE Management

The SPDX document provides the complete package inventory needed to:
1. Query the NIST NVD (National Vulnerability Database) for CVEs affecting any installed component
2. Generate a VEX (Vulnerability Exploitability eXchange) supplement documenting which CVEs are not exploitable in the MedTech device context
3. Support the hospital IT team's vulnerability management process (most hospital security tools can ingest SPDX)

Without an SBOM, a newly disclosed CVE in a transitive dependency (e.g., `openssl` in a Yocto `busybox` dependency) would be invisible until a security researcher or regulatory auditor flagged it.

### 4. License Compliance Documentation

The MedTech device OS includes open-source components under GPL-2.0, LGPL-2.1, MIT, Apache-2.0, and BSD licenses. SPDX captures the license identifier for every package, enabling:
- Automated license compliance review (no GPL-3.0 components in read-only rootfs without copyleft review)
- License obligation documentation for FDA submission package
- Customer-facing open-source disclosure (required by GPL-2.0 for distributed devices)

### 5. ISO/IEC Standard Status

SPDX 2.2 is ratified as **ISO/IEC 5962:2021**. Using an ISO-ratified standard ensures that the SBOM is recognized by international regulatory bodies (EU MDR, Health Canada, TGA) beyond the FDA. CycloneDX is a de facto standard but does not yet hold ISO ratification at the time of this decision.

---

## SBOM Coverage Specification

The SPDX 2.2 SBOM generated for each MedTech device OS release MUST include:

| Coverage Area | SPDX Field | Requirement |
|---|---|---|
| Package name | `PackageName` | Every installed recipe |
| Package version | `PackageVersion` | Every installed recipe |
| License | `PackageLicenseConcluded` | Every installed recipe (NOASSERTION not acceptable) |
| Source URL | `PackageDownloadLocation` | Every installed recipe |
| File checksums | `FileChecksum` | SHA-256 for all installed binaries |
| Supplier | `PackageSupplier` | Where available |
| Document namespace | `DocumentNamespace` | Unique URI per build |
| SPDX version | `SPDXVersion` | SPDX-2.2 |

---

## Consequences

### Positive

- FDA-compliant SBOM generated automatically by Yocto build system at zero additional tooling cost
- Every GitHub Release has a machine-readable, complete package inventory attached
- CVE monitoring can be automated by querying NIST NVD against SPDX package list
- License compliance is documented in the Design History File per IEC 62304 §8
- ISO/IEC 5962:2021 recognition supports international regulatory submissions

### Negative

- SPDX 2.2 does not natively include VEX (Vulnerability Exploitability eXchange) documents — a VEX supplement must be generated separately if required by FDA review
- SPDX JSON schema is verbose; large images produce large SBOM files (mitigated by storing as compressed release artifact)
- `create-spdx` Yocto class requires `meta-spdxscanner` layer and adds approximately 5–10 minutes to release build time

### Neutral

- CycloneDX VEX support is noted as a future option; a CycloneDX conversion from SPDX output is feasible if hospital security teams require CycloneDX format specifically

---

## Alternatives Considered

| Alternative | Reason Rejected |
|---|---|
| CycloneDX | Excellent tooling but not natively supported by Yocto `create-spdx`; would require a secondary scanning pass; VEX support is the only significant advantage over SPDX 2.2 for this use case |
| Manual SBOM spreadsheet | Error-prone; not machine-readable; constitutes a quality system deficiency; not scalable across Yocto image builds with hundreds of packages |
| No SBOM | Incompatible with FDA premarket guidance; incompatible with hospital IT security requirements for medical device procurement |
| SWID Tags (ISO/IEC 19770-2) | Designed for software inventory management, not supply chain transparency; not referenced in FDA guidance; no Yocto native support |

---

## Standards References

| Standard | Relationship to This Decision |
|---|---|
| **FDA Cybersecurity Premarket Guidance (Sep 2023)** | Explicitly requires SBOM in premarket submissions; SPDX is a named acceptable format. This decision directly satisfies the guidance requirement. |
| **ISO/IEC 5962:2021 (SPDX 2.2)** | The SBOM is generated in an ISO-ratified standard format, supporting international regulatory recognition. |
| **NTIA Minimum Elements for a Software Bill of Materials (Jul 2021)** | SPDX 2.2 covers all seven NTIA minimum elements: supplier, component name, version, unique identifier, dependency relationships, author, and timestamp. |
| **IEC 62304:2015 §8** | SBOM constitutes the software configuration items documentation required by §8.1. Automated generation via BitBake ensures completeness and reproducibility. |
| **ISO 14971:2019 §7** | SBOM enables the identification of vulnerable third-party components as a hazard. Automated CVE scanning against the SPDX package list is a risk monitoring activity under §7. |
| **EU Cyber Resilience Act (CRA) — Proposed** | The proposed EU CRA requires SBOM for CE-marked software products. SPDX 2.2 is the expected compliant format. Adopting SPDX now future-proofs the EU market access strategy. |

---

## Review Date

This decision should be revisited if:
- SPDX 3.0 is released and adopted by FDA guidance updates — upgrade path is straightforward (Yocto `create-spdx` class will be updated)
- A VEX automation requirement emerges — consider adding CycloneDX VEX generation as a supplementary artifact alongside SPDX 2.2
- The EU Cyber Resilience Act is finalized and specifies a format requirement that differs from SPDX 2.2
