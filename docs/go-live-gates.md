<!-- SPDX-License-Identifier: Apache-2.0 -->

# Go-live gates

What must be demonstrably true **before one real child's record is entered into this
system**, and what must additionally be true before it grows beyond the two pilot counties.

A gate here is a real thing that can pass or fail: a test name, a command whose output can be
compared, a document with a reference number, or a named person's signature. "Looks better"
is not a gate. This follows the convention already set in [roadmap.md](roadmap.md).

Each gate names the risk it closes, from [risk-register.md](risk-register.md).

**No dates.** Several gates depend on a regulator, a county or a carrier, none of which is
ours to schedule. The order within each tier is the order they should be attempted, because
later gates depend on earlier ones.

---

## Tier 0 — Legal. Nothing else starts until these pass.

These are Q1 activities in the submission, and the submission sequences them **before any
household data collection**. That sequencing is the control; breaking it is the risk.

| # | Gate | Passes when | Closes |
|---|---|---|---|
| L1 | ODPC registration as a data processor | The registration certificate exists and its number is recorded in a compliance register in this repository | A1 |
| L2 | Data Protection Impact Assessment filed | The DPIA is filed with the Commissioner and acknowledged, **at least 60 days before** the first household visit; the submission reference is recorded | A2 |
| L3 | The DPIA's findings are reflected in this register | Every technical control the DPIA asserts appears here as a mitigation with a gate, not as a claim | A3 |
| L4 | Data-processing agreements signed | At least two written DPAs with county health departments acting as controllers, under s.46, executed and logged | A4, L4 |
| L5 | Consent capture designed and reviewed | A documented flow covering the best-interests assessment, verified parental consent, and withdrawal — reviewed against the ODPC Children's Data Guidance Note before any code is written against it | A5 |
| L6 | Safeguarding process live | Focal point named in writing, criminal-record confirmations collected for every person doing fieldwork with children, confidential register created, and the Children Act 2022 reporting route written down and briefed | A8, J7 |
| L7 | Cross-border transfer foreclosed | `BRIEFING_GENERATOR=anthropic` cannot be reached in a pilot deployment — either removed from the pilot build or blocked by a startup assertion, with a test | A7, H6 |

## Tier 1 — Data protection technical. Before real data is stored.

| # | Gate | Passes when | Closes |
|---|---|---|---|
| D1 | Database role separation | A test proves the ledger role cannot read `sealed.child_keys` through any query file, and that the public API role cannot read `guardians` at all. Requires real `GRANT`s, not a grep | E3, C1 |
| D2 | TLS to the database | No shipped configuration contains `sslmode=disable`; a test asserts the connection is encrypted | C9 |
| D3 | AAD binds ciphertext to its location | `Seal`/`Open` pass a non-nil AAD derived from table, column and row id; a test proves a ciphertext moved between rows or columns **fails to decrypt** | E1 |
| D4 | Key rotation possible | A key id is carried in the blob, a multi-key decrypt path exists, and a re-encryption routine runs end to end in a test against a populated database | E2 |
| D5 | HMAC keys not stored in the clear | `sealed.child_keys` rows are wrapped under a separate key, or held outside the database; a dump alone no longer links leaves to children | E3 |
| D6 | Erasure is invocable | An authenticated, audited endpoint calls `ForgetChild`. A test asserts the records are gone, previously published roots still verify, the audit line contains no PII, and the outbox entry for that child is removed too | A5, I2, B7 |
| D7 | STOP is honoured end to end | An inbound reply of STOP reaches the consent log and triggers D6 within a stated time; a test drives it | A5, I2 |
| D8 | Retention enforced | Alert logs expire at 24 months and the job that does it is tested; `climate_observations` and `briefings` have a stated, implemented policy | K3 |
| D9 | Backups exist and a restore has been rehearsed | The volume is destroyed, restored from backup, and `make demo`'s inclusion proof verifies against a root committed before the destruction | K2 |
| D10 | Suppression re-derived for the geography actually published | k is justified against the real sub-county denominators, and a differencing test polls the API across a simulated enrolment and fails if the delta is recoverable | B1, B2, B8 |
| D11 | Suppression flags and residual counts closed | `TotalDays` and the River job counts either go through `Suppress` or are removed; a test covers each | B3, B4 |
| D12 | Contract tests made structural | `TestContract_PIILeak` enumerates the router rather than a hard-coded list, exercises Connect procedures with **non-empty** arguments, and covers every output format; `TestContract_KAnonymity` asserts **all four** stats fields plus the ledger and alert counts | B5 |
| D13 | Log redaction covers non-string values | `slog.Any` of a struct or an error is redacted, and the pattern matches 7–8 digit Kenyan national IDs; tests for both | B6 |
| D14 | Outbox hardened or removed | Mode `0600`, rotated and size-capped, or the mock channel is not deployed at pilot at all | B7 |

## Tier 2 — Security. Before the system is reachable by anyone outside the team.

| # | Gate | Passes when | Closes |
|---|---|---|---|
| S1 | Authentication exists | The registry rejects unauthenticated calls; a test asserts it. This is the single largest gap in the system | C1, C2 |
| S2 | Authorization is record-level | A CHW can read only their own catchment; a test asserts a cross-catchment read fails | C1, H4 |
| S3 | No service is published by accident | A test or script fails if Postgres or the registry is reachable on a non-loopback interface in the deployed configuration. The current control is which command the operator typed | C2, C3 |
| S4 | Stale cache bounded | Size cap, TTL and eviction, keyed on validated parameters rather than raw query strings; a test proves junk query strings cannot grow it without bound | C4, C7 |
| S5 | Connect cache keys include their arguments | A test proves a briefing request for one county and language never returns another's, under a simulated outage | C7 |
| S6 | Metrics cardinality bounded | 404s do not create series; labelled by route pattern, not raw path | C5 |
| S7 | Rate limiting in place | Repeated unauthenticated `/v1/stats` requests are throttled; a test asserts it | C6, C4 |
| S8 | XSS sink removed | The map popup escapes or uses DOM properties; a CSP is served on every path including the local one; a test asserts both | C8, C11 |
| S9 | Ingest bounded | Response size cap, day-count cap and value sanity bounds on climate ingestion, with a scheme check on the base URL and redirects not followed | C12 |
| S10 | Containers hardened | `read_only`, `cap_drop: [ALL]`, `no-new-privileges`, memory and PID limits on every container; restart policies on every long-running service | C10, K1 |
| S11 | CI hardened | A least-privilege `permissions:` block on every workflow, all actions SHA-pinned, `govulncheck` and a dependency scan in the pipeline, `--no-audit` removed | D1, D2, D3 |
| S12 | Base images pinned by digest | Including `caddy` — the only internet-facing container | D4 |
| S13 | Overclaim guard | A CI check fails the build if an accuracy, uptime, sensitivity, specificity or "families protected" figure appears in user-facing text without a cited evaluation | N4 |

## Tier 3 — Delivery. Before a message reaches a real guardian.

| # | Gate | Passes when | Closes |
|---|---|---|---|
| M1 | Carrier path proven | One alert reaches one test handset through a carrier sandbox and the row's status is `sent` with a stored receipt — **the only circumstance in which anything here may write `sent`** | I5 |
| M2 | Duplicate sends impossible | `UNIQUE (child_id, risk_score_id)` on `alerts`, with a test driving two concurrent dispatch jobs | I3 |
| M3 | SMPP transport secured | TLS configured, credentials redacted in every log path, re-bind after a dropped connection tested | I4 |
| M4 | Wrong-number risk reduced | Number verified at enrolment; a documented decision on what a message may name, tested against the case where the handset has changed hands | I1 |
| M5 | Quiet hours re-checked mid-loop | A dispatch crossing 21:00 EAT stops; a test drives it | I7 |
| M6 | Language reviewed | A named Kiswahili speaker signs off the SMS and briefing templates; the "not reviewed" label is replaced by their name and date. No language is enabled for automated drafting before it clears its quality floor | J5, H9 |
| M7 | Comprehension tested | ≥80% comprehension among 10+ community members, recorded | J6 |

## Tier 4 — Scale. Beyond the two pilot counties.

| # | Gate | Passes when | Closes |
|---|---|---|---|
| X1 | Model targets published | PR-AUC, recall at the fixed alert budget and Brier are reported against a temporally held-out window, **whether or not the targets are met** | G7 |
| X2 | Fairness floor enforced | Per-stratum recall reported and a challenger that improves on average while worsening rural sub-counties is rejected, in code | G4, G8 |
| X3 | `NaN` cannot score HIGH | Explicit `IsNaN`/`IsInf` guards with boundary tests on both scorers | G1 |
| X4 | Artifact verified at runtime | The climatology digest is compared, not merely computed and published | G3 |
| X5 | Public anchor decided and, if adopted, funded | A written decision on the signing key. If yes: an anchor whose transaction hash resolves in a block explorer the assessor picks, confirmations waited for rather than accepting the first receipt, and the re-anchoring gap after a contract change closed | F2, F3, F4, F5 |
| X6 | Inclusion proofs public | An endpoint serves a proof for a record, verifiable with a published script by a guardian, a facility or an auditor | F8 |
| X7 | MCP authorization proven | Record-level authorization enforced server-side outside the model, with a prompt-injection suite passing with **zero cross-record tool calls** | H4, H5 |
| X8 | Prompt injection defended at the source | Database free text is delimited or sanitised before it reaches a prompt; the grounding checker's known bypasses are closed or accepted in writing | H1, H2 |
| X9 | Key-person risk reduced | At least one other person can run a release, hold the compliance register and operate the key material; documented and rehearsed | M1 |
| X10 | Device lifecycle enforced | CHW handset enrolment, loss procedure and the committed secure-wipe-on-disposal, with the disposal register the environmental policy promises | J8 |

---

## How to use this

The tiers are not a schedule, they are a dependency order. Tier 0 gates depend on regulators
and counties, so they should be started first even though they are not engineering work.
Tier 1 and 2 are almost entirely within the team's control and are the bulk of the
engineering effort. Tier 3 depends on a carrier sandbox. Tier 4 is the investment period's
second half.

Two observations worth carrying into planning:

- **Tier 1 D1–D5 are one coherent piece of work.** Role separation, TLS, AAD, rotation and
  key wrapping all touch the same storage layer, and doing them separately means migrating
  the same data three times.
- **S1 is the keystone.** Erasure (D6), STOP (D7), record-level access (S2) and the entire
  MCP surface (X7) all require an identity to authorise against. Nothing downstream of it
  can be built first.
