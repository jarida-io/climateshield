<!-- SPDX-License-Identifier: Apache-2.0 -->

# Risk feasibility matrix

Every risk in [risk-register.md](risk-register.md), assessed a second time — not for how bad
it is, but for **how feasible it is to do something about it**. The register answers "what could
go wrong". This answers "what can we actually fix, in what order, and what is not ours to fix".

Read with [go-live-gates.md](go-live-gates.md), which states what must be true before real
children's data enters. The gates are the destination; this is the route.

**What this does not cover.** Feasibility here is an engineering and organisational judgement by
the team, not a costed plan. Effort figures are order-of-magnitude, not estimates anyone has
committed to. Nothing here changes a risk's severity — a risk that is hard to fix is not less
dangerous for being hard.

## How to read a row

**Severity** is likelihood multiplied by impact, carried over from the register (1 to 25).

**Feasibility** is how readily the mitigation can be carried out, on the evidence available today.

| | |
|---|---|
| 5 | In-house, under a day, no dependency. Do it this week |
| 4 | In-house, a few days, nothing blocking |
| 3 | Weeks of work, or needs a modest external input |
| 2 | A project in its own right, or depends on persuading someone outside the team |
| 1 | Not yet actionable. Blocked on a regulator, a funder, a carrier or data we do not hold |

**Effort** S is a day or less, M two to five days, L one to three weeks, XL more than three weeks.

**Control** IN is entirely ours; EXT needs an outside party; MIX needs both.

**Cost** is money beyond our own labour: 0 none, L low, M moderate, H high.

**Band** is derived, not assigned:

| Band | Rule | Meaning |
|---|---|---|
| Do now | severity 12 or more, feasibility 4 or more | High harm, low friction. Start here |
| Project | severity 12 or more, feasibility 3 or less | High harm, real work. Needs a plan and a slot |
| Quick fix | severity under 12, feasibility 4 or more | Cheap enough to clear while passing |
| Monitor | severity under 12, feasibility 3 or less | Not worth displacing anything above |
| Blocked | feasibility 1 | Someone outside the team has to move first |

## Where the register sits

| Band | Risks | Rough effort |
|---|---|---|
| Do now | 20 | 46 working days |
| Project | 34 | 314 working days |
| Quick fix | 38 | 40 working days |
| Monitor | 17 | 108 working days |
| Blocked | 6 | 101 working days |
| **Total** | **115** | **608 working days** |

That total is engineering time only. It excludes the regulator's clock, the county's legal
review, the carrier's sandbox and the outbreak data none of it can proceed without.

## The 34 changes that need a day or less

In-house, no dependency, a day or less each. Together they close several of the highest-severity
rows in the register, which is the strongest argument for doing them before anything larger.

| ID | Risk | Sev | What it takes |
|---|---|---|---|
| C3 | Postgres published with a known password | 20 | Remove the published port from the base compose |
| B7 | Outbox file holds message bodies | 16 | Mode 0600 and rotation, or drop the mock channel at pilot |
| D1 | Default GITHUB_TOKEN scope on fork PRs | 15 | Least-privilege permissions block on every workflow |
| K1 | 99% uptime commitment against no restart policy | 15 | Add a restart policy to every long-running service |
| D3 | No dependency or vulnerability scanning | 12 | govulncheck plus Dependabot; drop --no-audit |
| G1 | NaN driver scores as HIGH | 12 | Explicit NaN and Inf guards with boundary tests |
| N4 | Overclaim discipline broken by a single edit | 12 | A CI check on user-facing claim words |
| A7 | Cross-border transfer via a hosted LLM | 10 | Remove or hard-block the hosted-model path in pilot builds |
| D2 | Unpinned GitHub Actions | 10 | Pin all four actions to a commit SHA |
| H6 | Hosted-model config footgun | 10 | Same one-line block as A7 |
| B4 | People-derived counts bypass suppression | 9 | Route the remaining counts through Suppress |
| C5 | Metrics label-cardinality explosion | 9 | Label by route pattern, not raw path |
| C7 | Cross-caller briefing leak under outage | 9 | Include request arguments in the Connect cache key |
| F5 | Re-anchoring gap after a chain change | 9 | Add chain id and contract address to the idempotence key |
| N2 | Quarterly reporting against signed policies | 9 | Publish the three signed policies and set the cadence |
| C8 | Stored XSS via areas.name | 8 | Escape the value or set it as a DOM property |
| E4 | Hex key used directly, no KDF | 8 | Reject low-entropy keys at startup |
| C12 | Unbounded ingest response | 6 | Size cap, day cap, value bounds, scheme check |
| D4 | Floating base image on the edge | 6 | Pin the Caddy image by digest |
| D6 | Open-licence obligation narrows future choices | 6 | Accepted by design; already shapes dependency choices |
| E5 | Dev-key guard has narrow scope | 6 | Widen the guard to every binary that can hold a key |
| G3 | Climatology artifact integrity unverified at runtime | 6 | Compare the digest at startup, not only in tests |
| I3 | Duplicate sends | 6 | Unique constraint plus a migration |
| K6 | Never-500 hides an outage from monitoring | 6 | Monitor /health rather than the data endpoints |
| F9 | Merkle construction | 5 | Already correct. Keep the property tests green |
| H10 | Fact sheet cannot carry a person | 5 | Already structural. Keep the assertion test |
| F10 | Contract write access | 4 | Already correct. Verify the publisher at startup |
| G10 | Predictor provenance hides the annotator | 4 | Accepted by design and surfaced on the API |
| H3 | No max_tokens on the OpenAI path | 4 | Send max_tokens on the OpenAI-compatible path |
| I7 | Quiet-hours edge case | 4 | Re-check quiet hours inside the dispatch loop |
| K7 | No web healthcheck | 4 | Add a healthcheck to the web container |
| M5 | Field staff engagement obligations | 4 | Already met by the signed policy |
| N5 | Attribution audit not done | 4 | Audit attribution across repositories |
| I11 | Name injection into the SMS body | 2 | Bounded already by GSM-7 and length checks |

## What is blocked, and on whom

| ID | Risk | Sev | Waiting on |
|---|---|---|---|
| J1 | False negative — no alert before a real outbreak | 20 | The same outcome data as G4 |
| F3 | Signing-key custody on a public chain | 16 | A funder decision on holding and funding a signing key |
| G4 | Sparse-surveillance bias | 16 | County outbreak surveillance data |
| H4 | Cross-record tool call through MCP | 15 | An authorization layer that does not yet exist (C1) |
| G2 | Two published cutoffs cannot fire | 10 | A funder amendment to two published thresholds |
| L3 | DHIS2 identity matching | 8 | Scheduled for the fourth quarter by design |

Four of these six are the roadmap's own stated dependencies (D1, D5 and D6). They are not
oversights, and no amount of engineering will clear them.

## Critical path

Four items gate a disproportionate share of the register. Sequencing matters more than
parallelism here.

1. **C1, authentication and authorization** (Project, XL). Directly blocks H4 and H5, and is a
   prerequisite for A5 and I2. Nothing in the messaging, erasure or data-interface work can be
   finished without it. It is the single largest unlock in the document.
2. **E1, binding ciphertext to its location** (Project, L). E2 and E3 touch the same storage and
   require the same re-encryption pass. Doing them as one piece of work saves migrating the same
   data three times.
3. **I5, a carrier sandbox** (Blocked on an external party, M). Gates I2, I4, I6 and effectively
   I8. Worth starting the commercial conversation before the engineering is ready, because the
   waiting is the long part.
4. **G4, outbreak surveillance data** (Blocked, XL). Gates G5 through G8 and J1, J2 — the whole
   question of whether the prediction works. Nothing else in the register substitutes for it.

## The matrix

### A. Legal and regulatory

| ID | Risk | Sev | Feas | Effort | Control | Cost | Blocked by | Band | Route |
|---|---|---|---|---|---|---|---|---|---|
| A8 | Children Act 2022 reporting duty not operationalised | 15 | 4 | M | IN | 0 | — | Do now | Process, focal point and register; no engineering |
| A5 | Consent not demonstrably obtained, or not withdrawable | 25 | 2 | XL | MIX | 0 | S1 | Project | Field consent process plus a withdrawal path that needs an identity |
| A1 | Processing children's health data without ODPC registration | 15 | 3 | M | EXT | L | — | Project | Submit now; the wait is the regulator's, not ours |
| A2 | DPIA not filed 60 days before collection | 12 | 3 | L | MIX | 0 | — | Project | Writing is in-house; the 60-day clock is not |
| A10 | Erasure obligation unmeetable against a public chain | 12 | 2 | S | EXT | 0 | F3 | Project | Rests on a regulator's reading we cannot pre-empt |
| A4 | Controller/processor split unclear in practice | 12 | 2 | M | EXT | 0 | — | Project | County legal review sets the pace |
| A7 | Cross-border transfer via a hosted LLM | 10 | 5 | S | IN | 0 | — | Quick fix | Remove or hard-block the hosted-model path in pilot builds |
| A3 | DPIA findings bind the build after it is written | 9 | 4 | S | IN | 0 | A2 | Quick fix | Write the DPIA against this register so its findings are already true |
| A6 | Data localisation breached | 8 | 4 | M | IN | M | — | Quick fix | Choose a Kenyan provider; cost is recurring hosting |
| A9 | VASP Act 2025 assessment contested | 6 | 3 | S | EXT | M | — | Monitor | One legal opinion; our effort is briefing counsel |

### B. Privacy and re-identification

| ID | Risk | Sev | Feas | Effort | Control | Cost | Blocked by | Band | Route |
|---|---|---|---|---|---|---|---|---|---|
| B7 | Outbox file holds message bodies | 16 | 5 | S | IN | 0 | — | Do now | Mode 0600 and rotation, or drop the mock channel at pilot |
| B5 | Contract tests give false assurance | 16 | 4 | M | IN | 0 | — | Do now | Enumerate the router; assert all four stats fields |
| B6 | PII in logs | 12 | 4 | M | IN | 0 | — | Do now | Redact non-string attributes; widen the identifier pattern |
| B1 | Differencing attack against k≥10 | 20 | 2 | L | IN | 0 | — | Project | Release-level privacy accounting, not a per-cell tweak |
| B8 | Finer geography raises re-identification | 20 | 2 | L | MIX | 0 | B1 | Project | Needs real sub-county denominators to re-derive k |
| B2 | Suppression flags are themselves a channel | 16 | 3 | M | IN | 0 | B1 | Project | Coupled to B1; fixing flags alone moves little |
| B4 | People-derived counts bypass suppression | 9 | 5 | S | IN | 0 | — | Quick fix | Route the remaining counts through Suppress |
| B3 | Ledger day-shape disclosure | 9 | 4 | S | IN | 0 | — | Quick fix | Suppress TotalDays or coarsen the per-day partition |

### C. Application and infrastructure security

| ID | Risk | Sev | Feas | Effort | Control | Cost | Blocked by | Band | Route |
|---|---|---|---|---|---|---|---|---|---|
| C3 | Postgres published with a known password | 20 | 5 | S | IN | 0 | — | Do now | Remove the published port from the base compose |
| C2 | Unauthenticated writes into the append-only ledger | 20 | 4 | S | IN | 0 | — | Do now | Bind to loopback in the base compose; real fix is C1 |
| C9 | Unencrypted database traffic | 15 | 4 | M | IN | L | — | Do now | Enable TLS and issue an internal certificate |
| C4 | Stale-cache memory exhaustion | 12 | 4 | M | IN | 0 | — | Do now | Bound the cache, validate the key, add eviction |
| C6 | /v1/stats as a DoS lever | 12 | 4 | M | IN | 0 | — | Do now | Precompute the aggregate; add rate limiting |
| C1 | No authentication or authorization anywhere | 25 | 2 | XL | IN | 0 | — | Project | The keystone. Everything below waits on it |
| C5 | Metrics label-cardinality explosion | 9 | 5 | S | IN | 0 | — | Quick fix | Label by route pattern, not raw path |
| C7 | Cross-caller briefing leak under outage | 9 | 5 | S | IN | 0 | — | Quick fix | Include request arguments in the Connect cache key |
| C8 | Stored XSS via areas.name | 8 | 5 | S | IN | 0 | — | Quick fix | Escape the value or set it as a DOM property |
| C10 | No container hardening | 8 | 4 | M | IN | 0 | — | Quick fix | read_only, cap_drop, no-new-privileges, resource limits |
| C12 | Unbounded ingest response | 6 | 5 | S | IN | 0 | — | Quick fix | Size cap, day cap, value bounds, scheme check |
| C11 | Missing security headers | 6 | 4 | M | IN | 0 | — | Quick fix | CSP needs the inline style block moved out first |

### D. Supply chain and build integrity

| ID | Risk | Sev | Feas | Effort | Control | Cost | Blocked by | Band | Route |
|---|---|---|---|---|---|---|---|---|---|
| D1 | Default GITHUB_TOKEN scope on fork PRs | 15 | 5 | S | IN | 0 | — | Do now | Least-privilege permissions block on every workflow |
| D3 | No dependency or vulnerability scanning | 12 | 5 | S | IN | 0 | — | Do now | govulncheck plus Dependabot; drop --no-audit |
| D5 | Unmaintained SMPP dependency | 12 | 3 | L | IN | 0 | — | Project | Audit, fork or replace before the carrier path goes live |
| D2 | Unpinned GitHub Actions | 10 | 5 | S | IN | 0 | — | Quick fix | Pin all four actions to a commit SHA |
| D4 | Floating base image on the edge | 6 | 5 | S | IN | 0 | — | Quick fix | Pin the Caddy image by digest |
| D6 | Open-licence obligation narrows future choices | 6 | 5 | S | IN | 0 | — | Quick fix | Accepted by design; already shapes dependency choices |

### E. Cryptography and key management

| ID | Risk | Sev | Feas | Effort | Control | Cost | Blocked by | Band | Route |
|---|---|---|---|---|---|---|---|---|---|
| E2 | No key rotation path | 15 | 3 | L | IN | 0 | E1 | Project | Same storage surgery as E1; do them together |
| E3 | HMAC keys in cleartext beside the data they protect | 15 | 3 | L | IN | 0 | E1 | Project | Wrap the keys or move them out of the database |
| E4 | Hex key used directly, no KDF | 8 | 5 | S | IN | 0 | — | Quick fix | Reject low-entropy keys at startup |
| E5 | Dev-key guard has narrow scope | 6 | 5 | S | IN | 0 | — | Quick fix | Widen the guard to every binary that can hold a key |
| E1 | No AAD binds ciphertext to its row or column | 10 | 3 | L | IN | 0 | — | Monitor | Needs a re-encryption pass over existing rows |
| E6 | Ciphertext length leaks plaintext length | 4 | 3 | M | IN | 0 | — | Monitor | Padding is possible; accepting the leak is defensible |

### F. Ledger and chain

| ID | Risk | Sev | Feas | Effort | Control | Cost | Blocked by | Band | Route |
|---|---|---|---|---|---|---|---|---|---|
| F2 | Zero-confirmation acceptance | 12 | 4 | M | IN | 0 | — | Do now | Wait for confirmations before reporting anchored |
| F8 | Inclusion proofs promised publicly but unexposed | 12 | 4 | M | IN | 0 | — | Do now | The proof code exists and is tested; it needs an endpoint |
| F1 | Anchor is a local dev chain, not the public L2 promised | 15 | 2 | L | MIX | M | F3 | Project | Cannot proceed until the key question is answered |
| F5 | Re-anchoring gap after a chain change | 9 | 5 | S | IN | 0 | — | Quick fix | Add chain id and contract address to the idempotence key |
| F9 | Merkle construction | 5 | 5 | S | IN | 0 | — | Quick fix | Already correct. Keep the property tests green |
| F10 | Contract write access | 4 | 5 | S | IN | 0 | — | Quick fix | Already correct. Verify the publisher at startup |
| F4 | Gas funding runs out | 9 | 2 | S | EXT | M | F3 | Monitor | Cost model is cheap; the funded key is not ours to grant |
| F6 | Sequencer outage or L2 deprecation | 6 | 3 | M | IN | 0 | F3 | Monitor | Design work that only matters once F3 resolves |
| F11 | Leaf omits facility | 4 | 3 | M | IN | 0 | — | Monitor | Leaf format change implies a schema version |
| F7 | RPC provider as an observation point | 4 | 3 | M | IN | L | — | Monitor | Run our own node; already documented as an option |
| F3 | Signing-key custody on a public chain | 16 | 1 | S | EXT | M | — | Blocked | A funding and custody decision, not engineering |

### G. Model risk

| ID | Risk | Sev | Feas | Effort | Control | Cost | Blocked by | Band | Route |
|---|---|---|---|---|---|---|---|---|---|
| G1 | NaN driver scores as HIGH | 12 | 5 | S | IN | 0 | — | Do now | Explicit NaN and Inf guards with boundary tests |
| G5 | Intervention bias | 12 | 2 | L | IN | 0 | G4 | Project | Control cells need a training pipeline that does not exist |
| G9 | Annotation read as prediction | 9 | 4 | S | IN | 0 | — | Quick fix | Wording and placement, already partly done |
| G3 | Climatology artifact integrity unverified at runtime | 6 | 5 | S | IN | 0 | — | Quick fix | Compare the digest at startup, not only in tests |
| G10 | Predictor provenance hides the annotator | 4 | 5 | S | IN | 0 | — | Quick fix | Accepted by design and surfaced on the API |
| G6 | Label lag of 2–6 weeks | 9 | 3 | M | IN | 0 | G4 | Monitor | Train only on closed label windows |
| G7 | Model targets missed | 9 | 3 | M | IN | 0 | G4 | Monitor | Publishing regardless of outcome is the cheap half |
| G8 | Fairness floor gamed | 8 | 2 | L | IN | 0 | G4 | Monitor | Per-stratum floor enforced in the promotion gate |
| G4 | Sparse-surveillance bias | 16 | 1 | XL | EXT | 0 | — | Blocked | Blocked on outbreak surveillance data we do not hold |
| G2 | Two published cutoffs cannot fire | 10 | 1 | S | EXT | 0 | — | Blocked | A published threshold is a funder decision |

### H. Generative AI, LLM and MCP

| ID | Risk | Sev | Feas | Effort | Control | Cost | Blocked by | Band | Route |
|---|---|---|---|---|---|---|---|---|---|
| H5 | OAuth 2.1 scope design errors | 15 | 2 | XL | IN | 0 | C1 | Project | Scope design is meaningless without identities |
| H9 | Language quality below usable | 12 | 2 | M | EXT | L | — | Project | Needs named native speakers per language |
| H6 | Hosted-model config footgun | 10 | 5 | S | IN | 0 | — | Quick fix | Same one-line block as A7 |
| H1 | Prompt injection via database free text | 9 | 4 | M | IN | 0 | — | Quick fix | Delimit database text; add an ignore-instructions clause |
| H7 | Self-hosted model availability | 6 | 4 | M | IN | 0 | — | Quick fix | Fallback already exists and is labelled |
| H8 | Open-weight licence drift | 6 | 4 | S | IN | 0 | — | Quick fix | Pin the model and watch the licence |
| H10 | Fact sheet cannot carry a person | 5 | 5 | S | IN | 0 | — | Quick fix | Already structural. Keep the assertion test |
| H3 | No max_tokens on the OpenAI path | 4 | 5 | S | IN | 0 | — | Quick fix | Send max_tokens on the OpenAI-compatible path |
| H2 | Grounding-check bypass | 9 | 3 | L | IN | 0 | — | Monitor | Close the known bypasses or accept them in writing |
| H4 | Cross-record tool call through MCP | 15 | 1 | XL | IN | 0 | C1 | Blocked | No authorization layer exists to build this on |

### I. Messaging and last-mile delivery

| ID | Risk | Sev | Feas | Effort | Control | Cost | Blocked by | Band | Route |
|---|---|---|---|---|---|---|---|---|---|
| I1 | Wrong-number disclosure | 20 | 3 | L | MIX | 0 | — | Project | Number verification at enrolment plus a content decision |
| I2 | STOP not honoured | 20 | 2 | L | MIX | 0 | C1,I5 | Project | Inbound path, an identity, and a carrier |
| I10 | SMS cost dominates running cost | 12 | 3 | S | EXT | 0 | — | Project | Model the cost once a tariff is quoted |
| I4 | Plaintext SMPP credentials and traffic | 12 | 3 | M | MIX | 0 | I5 | Project | TLS depends on what the carrier supports |
| I5 | Carrier path entirely unproven | 12 | 2 | M | EXT | L | — | Project | Blocked on a carrier sandbox and a test handset |
| I8 | USSD session state | 12 | 2 | XL | IN | 0 | I5 | Project | USSD does not exist in the codebase at all |
| I3 | Duplicate sends | 6 | 5 | S | IN | 0 | — | Quick fix | Unique constraint plus a migration |
| I7 | Quiet-hours edge case | 4 | 5 | S | IN | 0 | — | Quick fix | Re-check quiet hours inside the dispatch loop |
| I11 | Name injection into the SMS body | 2 | 5 | S | IN | 0 | — | Quick fix | Bounded already by GSM-7 and length checks |
| I6 | Delivery target missed | 9 | 2 | M | EXT | 0 | I5 | Monitor | Cannot measure delivery before delivering |
| I9 | Aggregator and shortcode dependency | 9 | 2 | M | EXT | M | — | Monitor | Aggregator terms and shortcode are commercial |

### J. Clinical, safety and safeguarding

| ID | Risk | Sev | Feas | Effort | Control | Cost | Blocked by | Band | Route |
|---|---|---|---|---|---|---|---|---|---|
| J7 | Child Safeguarding Policy not operationalised | 20 | 4 | M | IN | 0 | — | Do now | Process, briefings, register and focal point |
| J9 | Overdue grace period is an unconfirmed assumption | 16 | 3 | S | EXT | 0 | — | Project | One KEPI officer confirming a number in writing |
| J6 | Caregiver distrust of unfamiliar SMS | 16 | 2 | L | EXT | M | — | Project | Community sensitisation before launch |
| J8 | CHW handset holds a catchment's records | 15 | 2 | XL | IN | M | — | Project | Device management and an offline-first client |
| J2 | False alarms cause alert fatigue | 12 | 3 | M | IN | 0 | G4 | Project | Alert budget cap is implementable; tuning is not |
| J3 | Over-reliance on an unvalidated signal | 12 | 3 | M | MIX | 0 | — | Project | Training and wording alongside the county |
| J5 | Unreviewed Kiswahili reaches guardians | 12 | 3 | S | EXT | L | — | Project | One named reviewer. The cheapest item in the register |
| J4 | Stocking decisions on an unvalidated signal | 12 | 2 | M | EXT | 0 | — | Project | Baseline must come from participating facilities |
| J1 | False negative — no alert before a real outbreak | 20 | 1 | XL | EXT | 0 | G4 | Blocked | No outcome data, so no measurement of misses |

### K. Operational and availability

| ID | Risk | Sev | Feas | Effort | Control | Cost | Blocked by | Band | Route |
|---|---|---|---|---|---|---|---|---|---|
| K1 | 99% uptime commitment against no restart policy | 15 | 5 | S | IN | 0 | — | Do now | Add a restart policy to every long-running service |
| K2 | No backups and no rehearsed restore | 15 | 4 | M | IN | L | — | Do now | Automated dump, offsite copy, and one rehearsed restore |
| K3 | No retention or expiry | 12 | 4 | M | IN | 0 | — | Do now | Expiry jobs for alert logs and observations |
| K5 | Silent failure goes unnoticed | 9 | 4 | M | IN | L | — | Quick fix | Alerting on the silent paths, starting with dispatch |
| K6 | Never-500 hides an outage from monitoring | 6 | 5 | S | IN | 0 | — | Quick fix | Monitor /health rather than the data endpoints |
| K7 | No web healthcheck | 4 | 5 | S | IN | 0 | — | Quick fix | Add a healthcheck to the web container |
| K4 | Two-node deployment has no redundancy | 9 | 3 | M | IN | M | — | Monitor | Redundancy costs nodes; conflicts with the efficiency policy |

### L. Integration and field data

| ID | Risk | Sev | Feas | Effort | Control | Cost | Blocked by | Band | Route |
|---|---|---|---|---|---|---|---|---|---|
| L1 | KoboToolbox is a second personal-data store | 16 | 4 | M | IN | 0 | — | Do now | Bring the survey store into the DPIA and this model |
| L2 | Historical facility case data | 12 | 2 | M | EXT | 0 | — | Project | Facilities control the release and its anonymisation |
| L4 | Processor for another controller's data | 12 | 2 | M | EXT | 0 | A4 | Project | Same county agreement as A4 |
| L5 | ICD-10/11 coding errors | 6 | 3 | L | IN | 0 | — | Monitor | Coding work once the data exists |
| L3 | DHIS2 identity matching | 8 | 1 | XL | EXT | 0 | — | Blocked | Deferred to the fourth quarter by design |

### M. Organisational and sustainability

| ID | Risk | Sev | Feas | Effort | Control | Cost | Blocked by | Band | Route |
|---|---|---|---|---|---|---|---|---|---|
| M1 | Key-person concentration | 16 | 3 | L | IN | 0 | — | Project | Documented handover and a second pair of hands |
| M2 | Five founders, component-split ownership | 12 | 3 | M | IN | 0 | — | Project | Cross-training against the component split |
| M5 | Field staff engagement obligations | 4 | 5 | S | IN | 0 | — | Quick fix | Already met by the signed policy |
| M3 | No revenue today against three projected channels | 9 | 2 | XL | EXT | 0 | M4 | Monitor | Revenue follows the county contracts |
| M4 | County contracts unsigned | 9 | 2 | L | EXT | 0 | — | Monitor | Buying decision follows demonstrated use |

### N. Contractual and reputational

| ID | Risk | Sev | Feas | Effort | Control | Cost | Blocked by | Band | Route |
|---|---|---|---|---|---|---|---|---|---|
| N4 | Overclaim discipline broken by a single edit | 12 | 5 | S | IN | 0 | — | Do now | A CI check on user-facing claim words |
| N1 | Committed capability not delivered | 16 | 2 | XL | MIX | 0 | — | Project | The programme itself. Tracked by the gates |
| N2 | Quarterly reporting against signed policies | 9 | 5 | S | IN | 0 | — | Quick fix | Publish the three signed policies and set the cadence |
| N3 | Halfway open-source obligation | 8 | 4 | M | IN | 0 | — | Quick fix | Attribution audit and the dataset release |
| N5 | Attribution audit not done | 4 | 5 | S | IN | 0 | — | Quick fix | Audit attribution across repositories |

## How to use this

Work the bands in order, not the classes. The register is organised by kind of risk because that
is how it is reviewed; this document is organised by what can move, because that is how it is
delivered.

Three observations worth carrying into planning:

- **The quick-fix list is unusually productive.** A day or less each, no dependencies, and between
  them they close several severity-15 and severity-20 rows. There is no scheduling argument for
  leaving them.
- **The Project band is small but dominant.** It contains the work that actually determines whether
  a pilot is possible, and almost all of it converges on authentication and on storage.
- **Blocked does not mean idle.** Every blocked row has a first move that belongs to a person rather
  than a compiler: brief counsel, write to the county, open the carrier conversation, ask for the
  data. Those letters cost nothing and the waiting starts the day they are sent.
