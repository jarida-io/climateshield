<!-- SPDX-License-Identifier: Apache-2.0 -->

# Compliance map

Every external obligation this project has taken on, and where it is met — in the code, in a
signed policy, or not yet at all.

This is the artefact a UNICEF reviewer, a county health department or the Office of the Data
Protection Commissioner would ask for. It deliberately does not argue: each row states the
obligation, the current position, and the gate that closes it from
[go-live-gates.md](go-live-gates.md).

**Status** is one of: **Met** · **Partial** · **Not started** · **N/A**. Status is assessed
against the repository as it stands, not against intent.

---

## Kenya Data Protection Act, 2019 (Cap. 411C)

| Obligation | Where | Status | Position | Gate |
|---|---|---|---|---|
| Registration of data controllers and processors | s.18–20 | **Not started** | Committed as a Q1 activity, before any household data collection | L1 |
| Children's data — parental consent and best-interests assessment | s.33 | **Not started** | `consent_log` exists, is append-only and latest-wins; nothing writes it from the field | L5 |
| Sensitive personal data — health status | s.2, s.44–46 | **Partial** | PII columns are AES-256-GCM encrypted; `date_of_birth` is deliberately plaintext; no AAD, no rotation | D3, D4 |
| Processing by or under a healthcare provider's responsibility | s.46 | **Not started** | Written DPA with each county as controller | L4 |
| Right to erasure | s.40 | **Partial** | `ForgetChild` is implemented and tested — deletes records, scrubs leaf linkage, destroys the child's HMAC key, and past roots still verify. **It has no caller and no endpoint** | D6 |
| Restriction on cross-border transfer | s.48 | **Partial** | Self-hosted model committed; `BRIEFING_GENERATOR=anthropic` exists in code and would transfer if a key were present | L7 |
| Security of processing | s.41 | **Partial** | Encryption at rest, append-only trigger, redacting logs, k≥10 on the public surface. **No authentication, no authorization, no role separation, no TLS to the database, no backups** | S1, S2, D1, D2, D9 |
| Notification of breach (72 hours) | s.43 | **Not started** | No incident process exists in the repository | — |

## Data Protection (General) Regulations, 2021 (LN 263)

| Obligation | Where | Status | Position | Gate |
|---|---|---|---|---|
| Data localisation for health data | Reg. 26 | **Not started** | Primary instance in a Kenyan data centre committed in the submission and in the Local Procurement Policy | L1 |
| Data Protection Impact Assessment | Regs. 49–52 | **Not started** | Filed at least 60 days before collection; Reg. 52 treats silence after 60 days as approval | L2, L3 |

## ODPC guidance

| Obligation | Status | Position | Gate |
|---|---|---|---|
| Guidance Note for Processing Children's Data | **Not started** | Named as the standard for the consent and best-interests flow in both the submission and the signed safeguarding policy | L5 |

## Children Act, 2022

| Obligation | Status | Position | Gate |
|---|---|---|---|
| Reporting a child at risk of harm to the county children's officer or the police | **Partial** | Required by the signed policy, which names the COO as focal point. No process, register or briefing exists | L6 |

## Kenya Virtual Asset Service Providers Act, 2025

| Obligation | Status | Position | Gate |
|---|---|---|---|
| VASP licensing | **N/A, by assessment** | Assessed as out of scope: no custodial wallet, exchange, transfer, brokerage or advisory service, and no token issued. The assessment rests on **statutory definitions not being met rather than an express carve-out**, and no CBK or CMA guidance exists on the point | A9 — a legal opinion is advisable before the public anchor goes live |

## Employment Act, 2007

| Obligation | Status | Position |
|---|---|---|
| Non-discrimination (s.5), written contracts, statutory deductions, working hours | **Met, by policy** | Equal Opportunity, Labour Rights and Child Safeguarding Policy, adopted and signed 8 August 2026. Field personnel on written paid contracts; no unpaid volunteers for core delivery |

## Signed company policies (Technical Appendix 1)

All three were adopted and signed by the board on 8 August 2026, and the Appendix commits to
**publishing each one in the project repository** and reporting against them quarterly.

| Policy | Reference | Status | Note |
|---|---|---|---|
| Local Procurement and Local Economy Policy | JOL-SP-01 | **Partial** | Signed. Commits to Kenyan development and hosting, ≥80% of procurement spend in Kenya, and a procurement log maintained by the CSO and reviewed quarterly. **Not present in this repository** |
| Equal Opportunity, Labour Rights and Child Safeguarding Policy | JOL-SP-02 | **Partial** | Signed. Its child-safeguarding clauses are operational requirements — no unsupervised contact, written criminal-record confirmation, confidential register, mandatory reporting. **Nothing in the repository implements them, and the policy is not published here** |
| Environmental and Resource Efficiency Policy | JOL-SP-03 | **Partial** | Signed. Commits to a two-node deployment, on-device inference where practical, a NEMA-licensed e-waste handler, and **secure wiping of devices holding personal data before disposal, recorded in a register**. Not present here |

Publishing the three policies in this repository is a small, cheap action that closes risk
N2 and part of J7.

## UNICEF Funding Agreement — technical clauses

| Obligation | Committed | Status | Position | Gate |
|---|---|---|---|---|
| Open-source publication of all project IP | Apache 2.0, 100% of active repositories, by month 6 | **Partial** | Apache 2.0 throughout and SPDX enforced by `make verify`; attribution audit and dataset publication outstanding | N3, N5 |
| Unit test coverage ≥80% | Contractual | **Met** | Statement coverage over `./internal/...`, enforced in `make verify` and CI by `scripts/covergate` | — |
| Public real-time data endpoint | Live before the halfway point, publicly accessible without authentication | **Met** | Unauthenticated, read-only, aggregates only, REST + Connect, CSV/GeoJSON | — |
| **99% endpoint uptime** | First month, re-confirmed at year-end | **Not met** | No restart policy on any application service, no backups, no rehearsed restore, no monitoring in the repository | S10, D9 |
| Merkle inclusion proofs exposed publicly | Verification endpoint, no authentication | **Not started** | `BuildProof`/`VerifyProof` are implemented and correct but have no HTTP endpoint | X6 |
| Public L2 anchor | ≥90 consecutive daily roots, Solidity coverage ≥80% | **Not started** | Local development chain only; labelled honestly on every surface | X5 |
| Dataset published with ≥1 logged external access | Month 6 | **Not started** | — | N3 |
| Quarterly reporting against the sustainability commitments | Appendix 1 | **Not started** | — | N2 |

## UNICEF Responsible Data for Children

The RD4C principles are not a contractual clause here, but they are the frame UNICEF assesses
child-data work against, and the project already satisfies several structurally.

| Principle | Position |
|---|---|
| Participatory | Community engagement mapped real population data; comprehension testing with community members is a Q1 gate; co-design of alert language is the stated mitigation for caregiver distrust |
| Professionally accountable | Named owners per component; the CSO holds child health-data governance. Concentrated in one person — see M1 |
| People-centric | SMS and USSD on feature phones chosen precisely because smartphone-only services exclude the target population |
| Prevention of harms across the data lifecycle | The strongest area: k≥10 suppression, per-child HMAC leaves never published, structural inability of the fact sheet to hold a person, append-only records, labelled generated text |
| Proportional | Five counties, aggregates only, no diagnosis or identity number in the climate path |
| Protective of children's rights | Erasure implemented in principle but **not invocable**; consent capture not built. The two largest gaps against this principle |
| Purpose-driven | One purpose, stated: anticipating climate-linked outbreaks so health resources move before cases appear |

---

## Summary of what is genuinely met today

Worth stating plainly, because the rest of this document is a list of gaps and that is not
the whole picture:

- Apache 2.0 throughout, SPDX enforced by the build.
- Coverage gate at ≥80%, green, with generated code excluded as documented policy.
- A public, unauthenticated, read-only aggregates API that never returns 500 and flags stale
  data honestly.
- k≥10 suppression applied before any people-derived count reaches a response, guarded by two
  contract tests CI runs **by name** — with the limits of those tests recorded as B5 rather
  than glossed.
- A correct RFC 6962 Merkle implementation with proper domain separation.
- A read-back check on every anchor that refuses to report success on a mismatch.
- Generated text that is labelled, grounded, or not served — and a fact sheet that
  structurally cannot carry a person.
- No accuracy, uptime or impact figure anywhere in the repository, because no evaluation
  supports one.

The gap is not that the engineering is careless. It is that the system was built to be
honest about a demonstrator, and the obligations above are the ones that attach the moment a
real child's record enters it.
