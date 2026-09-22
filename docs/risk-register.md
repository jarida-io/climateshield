<!-- SPDX-License-Identifier: Apache-2.0 -->

# Risk register

Every risk this project carries, across the data lifecycle, for the system as built and the
system the UNICEF submission (RFPS-NYH-2026-503931) commits to.

Read with [threat-model.md](threat-model.md), which describes the boundaries these risks sit
on, [risk-feasibility.md](risk-feasibility.md), which assesses how readily each one can be acted
on and in what order, and [go-live-gates.md](go-live-gates.md), which is the subset that blocks a
real pilot.

## How to read a row

**Likelihood** — the chance this happens at least once during the twelve-month investment
period, assuming today's controls and no further work.

| | |
|---|---|
| 1 | Would require an unlikely combination of circumstances |
| 2 | Plausible but not expected |
| 3 | More likely than not |
| 4 | Expected unless something changes |
| 5 | Already happening, or certain on the current path |

**Impact** — the worst realistic consequence, weighted toward harm to a child or family
rather than to the company.

| | |
|---|---|
| 1 | Annoyance; no lasting effect |
| 2 | Internal cost or rework |
| 3 | A contractual commitment missed, or a service outage |
| 4 | A reportable data-protection breach, a wrong clinical signal acted on, or loss of the funder's confidence |
| 5 | A named child's health data disclosed, a child harmed, or the integrity claim falsified |

**Exposure** — when the risk bites: `now` (the demonstrator as deployed), `pilot` (the moment
real children's data enters), `scale` (beyond the two pilot counties).

**Evidence** — a file, a test, or a page of the submission. No row is a bare assertion.

Scores assume today's state. A mitigation listed as *planned* has not reduced the score.

---

## A. Legal and regulatory

The submission makes these Q1 activities, owned by the Chief Security Officer, and sequences
them **before any household data collection**. That sequencing is itself the control.

| ID | Risk | Trigger | L | I | Exposure | Mitigation | Residual | Owner | Evidence |
|---|---|---|---|---|---|---|---|---|---|
| A1 | Processing children's health data without ODPC registration | Collection begins before the certificate issues | 3 | 5 | pilot | Registration is a Q1 gate; no collection until the certificate and ≥2 signed DPAs exist | Timing slip, not omission | CSO | T3 Q1 M6 A1 |
| A2 | DPIA not filed 60 days before collection | Fieldwork scheduled against a slipping DPIA | 3 | 4 | pilot | Regs. 49–52 require it; Reg. 52 treats silence after 60 days as approval, so the clock must start early | Schedule pressure | CSO, COO | T3 Q1 M6 A2 |
| A3 | DPIA findings bind the build after it is written | The assessment concludes something the architecture cannot deliver | 3 | 3 | pilot | Write the DPIA against this register, not against intentions; treat its conclusions as requirements | Rework | CSO | — |
| A4 | Controller/processor split unclear in practice | County signs a DPA but behaves as if Jarida decides purposes | 3 | 4 | pilot | Written agreement under s.46; the county is controller, Jarida processor | Operational drift | CSO, CEO | T2 p10 |
| A5 | Consent not demonstrably obtained, or not withdrawable | No implementation of consent capture or STOP | **5** | 5 | pilot | `consent_log` exists and is append-only with latest-wins, but nothing writes it from the field and no STOP path exists | **Open** | CSO | `0005_registry.up.sql:29-35`; `ForgetChild` has no caller |
| A6 | Data localisation breached | Any component holding personal data hosted outside Kenya | 2 | 4 | pilot | Reg. 26 requires a Kenyan primary; the procurement policy already commits to Kenyan providers | Vendor choice | CSO | Policy 1 §3 |
| A7 | Cross-border transfer via a hosted LLM | Convenience switch to a hosted API | 2 | 5 | pilot | The submission forbids it (s.48); `BRIEFING_GENERATOR=anthropic` exists in code and would do exactly this | **Config-level footgun** | CSO | `briefing/service.go:67` |
| A8 | Children Act 2022 reporting duty not operationalised | A safeguarding concern arises in the field with no route | 3 | 5 | pilot | Policy names the COO as focal point and requires reporting to the county children's officer or police | Policy exists, process does not | COO | Policy 2 §4 |
| A9 | VASP Act 2025 assessment contested | A regulator reads the anchor as a virtual-asset activity | 2 | 3 | pilot | The assessment rests on statutory definitions not being met — there is **no express carve-out** and no CBK or CMA guidance on point | Legal opinion advisable | CSO, CEO | T2 p17 |
| A10 | Erasure obligation unmeetable against a public chain | A subject requests erasure after a root is anchored publicly | 3 | 4 | pilot | Only a daily aggregate root is published; erasure destroys the child's key. Rests on EDPB 02/2025, which a regulator may read differently | Argued, not settled | CSO | T2 p16 |

## B. Privacy and re-identification

| ID | Risk | Trigger | L | I | Exposure | Mitigation | Residual | Owner | Evidence |
|---|---|---|---|---|---|---|---|---|---|
| B1 | **Differencing attack against k≥10** | Poll `/v1/stats` before and after a known enrolment | 4 | 5 | pilot | k is applied **per cell, not per release**; counts recompute live with no query auditing | **Open — the most likely real privacy failure** | CSO | `suppress.go:21-26`; `handlers.go:126-129` |
| B2 | Suppression flags are themselves a channel | Read the four booleans per county over time | 4 | 4 | pilot | Each flag discloses that a count is in [1,9]; four correlated counts per county narrow it further | Open | CSO | `handlers.go:126-129` |
| B3 | Ledger day-shape disclosure | Read `/v1/ledger/summary` daily | 3 | 3 | pilot | Per-day leaf counts are suppressed, but `TotalDays` is raw and the three-way partition per day profiles activity | Open | CSO | `evidence.go:232,246` |
| B4 | People-derived counts bypass suppression | River `notify` job counts published raw | 3 | 3 | now | None — `JobKindStatus.Count` tracks dispatch volume and is unsuppressed | Open | CSO | `evidence.go:399` |
| B5 | Contract tests give false assurance | A new endpoint or field ships uncovered | 4 | 4 | now | Tests run by name in CI with RUN/PASS grepped. But `TestContract_PIILeak` probes a **hard-coded path list omitting `/v1/climatology`**, calls every Connect procedure with `{}`, and is a sentinel test; `TestContract_KAnonymity` asserts **only `children_registered`** | **Open** | CSO | `pii_contract_test.go:137-165,217-228` |
| B6 | PII in logs | `slog.Any` of a struct or an error carrying a name | 3 | 4 | pilot | Redaction covers **only string attributes** and only ≥9-digit runs; the default branch passes values through untouched | **Open** — 8-digit Kenyan national IDs are never matched | CSO | `redact.go:100-115,43` |
| B7 | Outbox file holds message bodies | Anyone with filesystem or backup access | 4 | 4 | now | File is mode **0644**, unbounded, holds child first name and county, and **erasure does not touch it** | Open | CSO | `notify/mock/mock.go:50-53` |
| B8 | Finer geography raises re-identification | Submission moves to sub-county resolution | 4 | 5 | pilot | k≥10 was chosen against county populations; sub-county cells are far smaller | Needs a re-derived k | CSO, CPO | T2 p10 |

## C. Application and infrastructure security

| ID | Risk | Trigger | L | I | Exposure | Mitigation | Residual | Owner | Evidence |
|---|---|---|---|---|---|---|---|---|---|
| C1 | **No authentication or authorization anywhere** | Any request to any service | **5** | 5 | now | None. No interceptors, no middleware, no tokens — on the public API *or* the mutating registry | **Open** | CSO | `registry/service.go:191` |
| C2 | Unauthenticated writes into the append-only ledger | Reach `:8082` | 4 | 5 | now | Base compose publishes it on all interfaces; only the prod overlay closes it | Depends on which command was typed | CSO | `docker-compose.yml:185` vs `deploy/docker-compose.prod.yml:32-33` |
| C3 | Postgres published with a known password | Base compose used on a reachable host | 4 | 5 | now | Prod overlay closes it | Same fragility as C2 | CSO | `docker-compose.yml:10,13` |
| C4 | **Stale-cache memory exhaustion** | Thousands of junk query strings | 4 | 3 | now | None — key includes `RawQuery`, no TTL, no eviction, no size bound, no rate limit to slow it | **Open** | CSO | `publicapi/server.go:316`; `stale.go` |
| C5 | Metrics label-cardinality explosion | Requests to distinct 404 paths | 3 | 3 | now | None — labelled by `r.URL.Path`, exposed on `/metrics` | Open | CSO | `metrics/metrics.go:59` |
| C6 | `/v1/stats` as a DoS lever | Repeated unauthenticated requests | 4 | 3 | now | None — loads every child and every event into maps per request, no rate limit | Open | CSO | `handlers.go:137-181` |
| C7 | Cross-caller briefing leak under outage | Database down, two callers | 3 | 3 | now | Connect cache keys **ignore request arguments**, so one caller's county and language is served to another | Open | CSO | `publicapi/server.go:259-261` |
| C8 | Stored XSS via `areas.name` | Anyone who can write that column | 2 | 4 | now | None — `setHTML` with an un-escaped value, outside React, with **no CSP anywhere** | Open | CTO, CSO | `web/src/map.ts:136-137` |
| C9 | Unencrypted database traffic | Any network position between service and Postgres | 3 | 5 | pilot | **Every DSN shipped sets `sslmode=disable`** — carrying decrypted names and plaintext DOB | Open | CSO | `config.go:31`; `deploy/docker-compose.prod.yml:78` |
| C10 | No container hardening | Container escape or resource abuse | 2 | 4 | pilot | Services run as UID 10001, but **no** `read_only`, `cap_drop`, `no-new-privileges`, memory or PID limits exist on any container | Open | CSO | compose files |
| C11 | Missing security headers | Any browser session | 3 | 2 | now | Caddy sets three; **no CSP, no HSTS anywhere**, and the local/demo path serves none | Open | CTO | `Caddyfile:41-48`; `web/nginx.conf` |
| C12 | Unbounded ingest response | Hostile or compromised upstream | 2 | 3 | now | None — no `io.LimitReader`, no day cap, no value bounds, unvalidated base URL, redirects followed | Open | CSO | `source.go:66`; `client.go:61` |

## D. Supply chain and build integrity

| ID | Risk | Trigger | L | I | Exposure | Mitigation | Residual | Owner | Evidence |
|---|---|---|---|---|---|---|---|---|---|
| D1 | **Default `GITHUB_TOKEN` scope on fork PRs** | A malicious pull request | 3 | 5 | now | None — no `permissions:` block in any workflow, while `npm ci` runs lockfile install scripts | **Open — highest-leverage supply-chain gap** | CSO | `.github/workflows/ci.yml` |
| D2 | Unpinned GitHub Actions | Tag repointed upstream | 2 | 5 | now | None — all four float on major tags | Open | CSO | `ci.yml:13,15,46,99` |
| D3 | No dependency or vulnerability scanning | A CVE lands in a dependency | 4 | 3 | now | None — no govulncheck, Dependabot, SBOM, CodeQL or secret scanning; `npm ci --no-audit` disables even npm's check | Open | COO | `ci.yml:56` |
| D4 | Floating base image on the edge | `caddy:2` rebuilt with a regression | 2 | 3 | now | anvil and ollama are digest-pinned; the **internet-facing** container is not | Open | CSO | `deploy/docker-compose.prod.yml:47` |
| D5 | Unmaintained SMPP dependency | A defect on the SMS path | 3 | 4 | pilot | Pinned to an untagged 2021 pseudo-version with no releases since | Open | COO | `go.mod` |
| D6 | Open-licence obligation narrows future choices | A needed component is not openly licensed | 3 | 2 | pilot | Already drove real decisions (RapidPro rejected on licence; TimesFM rejected on weights) | Accepted, by design | CEO | T2 pp3-4 |

## E. Cryptography and key management

| ID | Risk | Trigger | L | I | Exposure | Mitigation | Residual | Owner | Evidence |
|---|---|---|---|---|---|---|---|---|---|
| E1 | **No AAD binds ciphertext to its row or column** | Insider swaps `phone_enc` between rows, or `name_enc` for `phone_enc` | 2 | 5 | pilot | None — `Seal`/`Open` pass `nil` AAD, so both decrypt cleanly and nothing detects it | **Open** | CSO | `encrypted.go:99,112` |
| E2 | **No key rotation path** | Key suspected compromised, or staff departure | 3 | 5 | pilot | None — no key ID, no versioning, no multi-key decrypt. Rotating orphans **every** ciphertext permanently | **Open** | CSO | `encrypted.go:81-83` |
| E3 | HMAC keys in cleartext beside the data they protect | Any database dump | 3 | 5 | pilot | Separate schema, but same instance, same role, unwrapped `bytea`. The migration says so itself | **Open — defeats erasure retroactively** | CSO | `0007_ledger.up.sql:36-48` |
| E4 | Hex key used directly, no KDF | Weak but non-placeholder key chosen | 2 | 4 | pilot | Dev-key guard is fail-closed for the **published placeholder only**; there is no entropy check | Open | CSO | `encrypted.go:47-52` |
| E5 | Dev-key guard has narrow scope | A deployment without the notifier | 2 | 3 | pilot | Only the notifier and demo load a key, so only they can refuse | Open | CSO | `notifier/service.go:44-45` |
| E6 | Ciphertext length leaks plaintext length | Observer of the database | 2 | 2 | pilot | JSON-marshalled before sealing, so name and phone lengths are observable | Accepted | CSO | `encrypted.go:87` |

## F. Ledger and chain

| ID | Risk | Trigger | L | I | Exposure | Mitigation | Residual | Owner | Evidence |
|---|---|---|---|---|---|---|---|---|---|
| F1 | Anchor is a local dev chain, not the public L2 promised | Assessor checks the pillar | **5** | 3 | now | Labelled honestly everywhere, derived at runtime from `eth_chainId`; the public host says `unavailable` with a reason | Honest, but the commitment is unmet | CSO | README; T2 p15 |
| F2 | **Zero-confirmation acceptance** | A reorg drops the anchoring transaction | 3 | 4 | pilot | None — first receipt accepted, both read-backs use `"latest"`, and `reorg`/`finality`/`confirmations` appear **nowhere** in the repository | **Open** | CSO | `evm/anchor.go:214-236` |
| F3 | Signing-key custody on a public chain | Key needed to anchor | 4 | 4 | pilot | Today the node signs and no key exists here — which is why this is unsolved rather than solved. Conflicts with the zero-credentials rule | **Open** | CSO | `evm/abi.go:9-11` |
| F4 | Gas funding runs out | Prepayment under-estimated over 12 months + | 3 | 3 | pilot | Event-emission rather than storage cuts cost ~20×; prepayment planned | Estimate unvalidated | CEO, CSO | T2 p16 |
| F5 | Re-anchoring gap after a chain change | Contract redeployed or chain reset | 3 | 3 | now | None — idempotence key omits `chain_id` and `contract_address`, so pre-change days report `mismatch` **permanently** | Open | CSO | `queries/ledger.sql:72-80` |
| F6 | Sequencer outage or L2 deprecation | The L2 stops, or sunsets | 2 | 3 | pilot | No forced-inclusion path, no migration plan for a record with a decade-long life | Open | CSO | — |
| F7 | RPC provider as an observation point | Managed endpoint used | 2 | 2 | pilot | Endpoints configurable, own node documented as an option | Low | CSO | T2 p16 |
| F8 | Inclusion proofs promised publicly but unexposed | Anyone asked to verify their own record | 4 | 3 | pilot | `BuildProof`/`VerifyProof` are correct and tested but have **no HTTP endpoint** | Open | CSO | T3 Q3 M3 A1 |
| F9 | Merkle construction | — | 1 | 5 | now | **Already mitigated.** RFC 6962 with leaf/node domain separation and the correct split — no second-preimage, no duplicate-last-node malleability | Low | CSO | `ledger/merkle.go:17-20,123-128` |
| F10 | Contract write access | Arbitrary caller submits a root | 1 | 4 | pilot | **Already mitigated.** Single publisher set in the constructor, no setter, no owner privileges, zero root rejected | Low | CSO | `RootAnchor.sol:40-55` |
| F11 | Leaf omits `facility` | A facility edit is not tamper-evident | 2 | 2 | pilot | Canonical event covers five fields; `facility` is stored but not committed, and there is no schema version in the leaf | Open | CSO | `ledger/canonical.go:18-24` |

## G. Model risk

| ID | Risk | Trigger | L | I | Exposure | Mitigation | Residual | Owner | Evidence |
|---|---|---|---|---|---|---|---|---|---|
| G1 | **`NaN` driver scores as HIGH** | A malformed or missing upstream value | 3 | 4 | now | None — `NaN` fails every comparison, falls through to the 100th percentile, and yields **HIGH**. No `IsNaN`/`IsInf` check exists in the package | **Open** | CPO, CSO | `predict/climatology.go:118-137` |
| G2 | Two published cutoffs cannot fire | Pneumonia and meningitis rules in the monitored counties | 5 | 2 | now | **Already handled well** — reported on `/v1/model`, in `threshold-validation.md`, on the dashboard, and guarded by a test that fails if it stops being true | Awaiting a funder decision | CPO | `docs/threshold-validation.md` |
| G3 | Climatology artifact integrity unverified at runtime | A substituted embedded artifact | 2 | 3 | now | Digest is **computed and published but compared to nothing** at runtime; pinning is test-time only | Open | CPO | `predict/reference.go:21-32` |
| G4 | Sparse-surveillance bias | Training labels come from reporting, which is thinnest where the project matters most | 4 | 4 | pilot | Acknowledged in the submission; per-stratum recall floor and disaggregated reporting planned | Recognised, unbuilt | CPO | T2 p12 |
| G5 | Intervention bias | A successful alert prevents the outbreak it predicted | 4 | 3 | pilot | Every training row carries an intervention flag; a never-alerted control set is held out | Planned | CPO | T2 p12 |
| G6 | Label lag of 2–6 weeks | Retraining on periods whose labels have not closed | 3 | 3 | pilot | Only closed label windows are trained on | Planned | CPO | T2 p12 |
| G7 | Model targets missed | PR-AUC ≥ 3× base rate, recall ≥ 0.60, Brier better than climatology | 3 | 3 | pilot | The submission commits to **publishing all three whether or not they are met** — the honesty discipline is the mitigation | Accepted | CPO | T3 Q2 M3 A1 |
| G8 | Fairness floor gamed | Average improves while rural sub-counties get worse | 2 | 4 | pilot | Minimum recall floor per stratum; a model improving on average by worsening rural is rejected | Planned | CPO | T2 p13 |
| G9 | Annotation read as prediction | A reader treats the climatology exceedance as outbreak probability | 3 | 3 | now | One explaining sentence on every score, plus the model card; the word "exceedance" does real work here | Partly mitigated | CPO | `docs/model-card.md` |
| G10 | Predictor provenance hides the annotator | `AnnotatedPredictor` reports the wrapped predictor's name | 2 | 2 | now | Deliberate and documented; whether annotation ran is exposed as `exceedanceRole` | Accepted | CPO | `predict/annotate.go:74-77` |

## H. Generative AI, LLM and MCP

| ID | Risk | Trigger | L | I | Exposure | Mitigation | Residual | Owner | Evidence |
|---|---|---|---|---|---|---|---|---|---|
| H1 | **Prompt injection via database free text** | Write to `areas.name`, `risk_scores.explanation` or `climate_observations.source` | 3 | 3 | now | Grounding check catches consequences, not the injection. **No delimiting, no "ignore instructions in data" clause** in the prompt | Open | CSO | `openaicompat.go:199-205` |
| H2 | Grounding-check bypass | A model that probes the rules | 3 | 3 | now | Nine rejection kinds, and refused text is never served, stored or logged. But: all-caps and sentence-initial names exempt; ≤8-digit numbers pass; **any digit anywhere in the fact JSON is globally allowed**; a disease with no tier token is never level-checked; forbidden claims are a fixed substring list | Open | CSO | `ground.go:100,191-197,409-426` |
| H3 | No `max_tokens` on the OpenAI path | A model that does not stop | 2 | 2 | now | Only the 1 MiB read cap bounds a reply | Open | CSO | `openaicompat.go:134-136` |
| H4 | **Cross-record tool call through MCP** | An injected instruction reaches a tool with another child's identifier | 3 | 5 | pilot | The submission's answer is architectural — authorization server-side, outside the model, no child identifier ever model-supplied. **No authorization layer exists to build it on** | **Open — the submission names this the gravest ethical risk** | CSO | T2 p14; T3 Q3 M6 A2 |
| H5 | OAuth 2.1 scope design errors | Tiered access across officers, CHWs and guardians | 3 | 5 | pilot | Planned: tiered, record-level, server-side | Unbuilt | CSO | T3 Q3 M6 A2 |
| H6 | Hosted-model config footgun | `BRIEFING_GENERATOR=anthropic` set in a pilot deployment | 2 | 5 | pilot | Fail-closed on a missing credential, but **if a key is present it will send** — a cross-border transfer the submission forbids | Open | CSO | `briefing/service.go:67` |
| H7 | Self-hosted model availability | The node serving the model is down | 3 | 2 | pilot | Deterministic template fallback, labelled — a genuinely good design | Low | CSO | `generate.go:252-267` |
| H8 | Open-weight licence drift | A model's licence changes | 2 | 3 | pilot | Model and tool layer sit behind interfaces; swap without touching calling code | Low | CPO | T2 p14 |
| H9 | Language quality below usable | Dholuo and Kikuyu weaker than Swahili | 4 | 3 | pilot | Quality floor per language; a language that cannot clear it stays fully human-authored | Planned, honest | CTO | T2 p15 |
| H10 | Fact sheet cannot carry a person | — | 1 | 5 | now | **Already mitigated.** Structural — the type has no field for one, asserted on the bytes that leave the process | Low | CSO | `facts/facts.go:89-103` |

## I. Messaging and last-mile delivery

| ID | Risk | Trigger | L | I | Exposure | Mitigation | Residual | Owner | Evidence |
|---|---|---|---|---|---|---|---|---|---|
| I1 | **Wrong-number disclosure** | Recycled SIM, mistyped number, shared handset | 4 | 5 | pilot | None. The message names the child's first name, county and vaccine | **Open — the most likely route to a real disclosure** | COO, CSO | `notify/template.go:20-21` |
| I2 | STOP not honoured | A guardian replies STOP | **5** | 4 | pilot | Committed in the submission. **No inbound path, no handler, and `ForgetChild` has no caller** | **Open** | CSO | T2 p10 |
| I3 | Duplicate sends | Two concurrent dispatch jobs | 3 | 2 | now | Check-then-act with **no `UNIQUE (child_id, risk_score_id)`** and `MaxWorkers: 2` | Open | COO | `0008_alerts.up.sql`; `notifier/service.go:116-125` |
| I4 | Plaintext SMPP credentials and traffic | Any network position to the carrier | 3 | 4 | pilot | **No `tls.Config`**; `SMPP_PASSWORD` passed as a plain string, never redacted | Open | CSO | `smpp/smpp.go:32` |
| I5 | Carrier path entirely unproven | First real message | 4 | 3 | pilot | Honestly stated: wired, never tested; no unbind, no re-bind, no receipts, no retry | Open | COO | `smpp/smpp.go:4-6` |
| I6 | Delivery target missed | ≥90% success across 50 test messages, then at scale | 3 | 3 | pilot | CHW follow-up protocol for failures, <10% unreached | Planned | COO | T3 Q3 M1 |
| I7 | Quiet-hours edge case | A dispatch loop crosses 21:00 | 2 | 2 | now | Correct for Kenya (fixed UTC+3, no DST, documented), but evaluated **once per job** | Low | COO | `notify/quiet.go:19-36` |
| I8 | USSD session state | Shared or borrowed handset mid-session | 3 | 4 | pilot | Unbuilt — no USSD exists anywhere in the repository | Open | COO | T2 p7 |
| I9 | Aggregator and shortcode dependency | Africa's Talking price change, or shortcode lapse | 3 | 3 | scale | Channel port with interchangeable adapters; shortcode prepaid 15 months past grant | Partly mitigated | CEO | T2 p9 |
| I10 | SMS cost dominates running cost | Volume grows with coverage | 4 | 3 | scale | Acknowledged: per-message cost is the dominant recurring cost, hence batching and fewest-messages design | Recognised | CEO | T2 p14 |
| I11 | Name injection into the SMS body | A crafted child name | 1 | 2 | pilot | `strings.NewReplacer` does not rescan replacements, so a name cannot expand a placeholder; GSM-7 and 160-septet limits bound it. Semantic content is not sanitised | Low | COO | `notify/template.go:53-58` |

## J. Clinical, safety and safeguarding

| ID | Risk | Trigger | L | I | Exposure | Mitigation | Residual | Owner | Evidence |
|---|---|---|---|---|---|---|---|---|---|
| J1 | **False negative** — no alert before a real outbreak | Model or rules miss | 4 | 5 | pilot | Recall at a fixed alert budget is a headline metric precisely because a miss costs a child's health while a false alarm costs one SMS | Inherent; must be measured, not eliminated | CPO | T2 p12 |
| J2 | False alarms cause alert fatigue | Too many alerts per sub-county | 3 | 4 | pilot | Alert budget capped at ≤1 per sub-county per month | Planned | CPO, COO | T3 Q2 M3 A1 |
| J3 | Over-reliance on an unvalidated signal | A health worker treats output as a verdict | 3 | 4 | pilot | Stated in the submission: climate is not the only driver, so output is one input to county decision-making, not a verdict. Every surface carries what it does not prove | Partly mitigated | CPO | T2 p12 |
| J4 | Stocking decisions on an unvalidated signal | Wastage or shortage from a wrong forecast | 3 | 4 | pilot | Wastage measured against a pre-pilot baseline at ≥4 facilities | Planned | COO | T3 Q4 M3 A1 |
| J5 | Unreviewed Kiswahili reaches guardians | Live pilot with current templates | 4 | 3 | pilot | Labelled unreviewed on every surface; ≥80% comprehension testing with 10+ community members is a Q1 gate | Gate exists, review does not | CTO | T3 Q1 M3 A2 |
| J6 | Caregiver distrust of unfamiliar SMS | Alerts ignored, or read as a scam | 4 | 4 | pilot | Their own stated top-3 risk: co-designed language, community sensitisation before launch, response rate tracked as a core success metric | Planned | COO | T1 p4 |
| J7 | **Child Safeguarding Policy not operationalised** | Any field activity involving children | 4 | 5 | pilot | Policy is signed and specific — no unsupervised contact, written criminal-record confirmation, COO as focal point, confidential register, mandatory reporting. **Nothing in the repository implements any of it** | **Open** | COO | Policy 2 §4 |
| J9 | **Overdue grace period is an unconfirmed assumption** | Every alert about an overdue child | 4 | 4 | pilot | The 14-day grace period is seed-data assumption, not MoH guidance, and everything the notifier does about overdue children rests on it. Recorded as assumption 1 in `NOTES.md` and as dependency D3 in `roadmap.md` | **Open — needs a KEPI officer in writing** | CPO, COO | `internal/registry/schedule.go:30`; `roadmap.md` D3 |
| J8 | CHW handset holds a catchment's records | Loss or theft in the field | 3 | 5 | pilot | Offline-first app is planned; device wipe on disposal is committed in policy | Unbuilt | CSO | Policy 3 §3 |

## K. Operational and availability

| ID | Risk | Trigger | L | I | Exposure | Mitigation | Residual | Owner | Evidence |
|---|---|---|---|---|---|---|---|---|---|
| K1 | **99% uptime commitment against no restart policy** | Any service crashes, or the host reboots | **5** | 3 | now | None — only Caddy has `restart: unless-stopped`. Every application service defaults to `no`, so a reboot brings up Caddy alone | **Open** | CSO | `deploy/docker-compose.prod.yml:48`; compose files |
| K2 | **No backups and no rehearsed restore** | Disk loss, or an erroneous `down -v` | 3 | 5 | now | None. No `pg_dump`, no snapshot, no restore script anywhere in the repository | **Open** | CSO | repo-wide |
| K3 | No retention or expiry | Unbounded growth; 24-month alert-log commitment | 4 | 3 | pilot | None — `climate_observations` and `briefings` grow monotonically forever; no `DELETE` by age exists | Open | CSO | `queries/climate.sql:3-15` |
| K4 | Two-node deployment has no redundancy | One node fails | 3 | 3 | scale | Deliberate — compute sized to workload, committed in the environmental policy | Accepted, but conflicts with K1 | CSO | Policy 3 §2 |
| K5 | Silent failure goes unnoticed | A failure mode with no alarm | 3 | 3 | now | The outbox UID bug is the worked example: shipped once, unnoticed for four weeks, documented. `/health` reports independently of the stale path, which is good design | Partly mitigated | CSO | `NOTES.md` |
| K6 | Never-500 hides an outage from monitoring | Database down, status codes watched | 3 | 2 | now | `/health` returns 503 independently and the header flags staleness — correct, but a monitor watching only `/v1/` sees 200 forever | Low, by design | CSO | `publicapi/server.go:346-360` |
| K7 | No `web` healthcheck | nginx container wedges | 2 | 2 | now | Prod depends on it with `condition: service_started` only | Low | CTO | `docker-compose.yml:221-228` |

## L. Integration and field data

| ID | Risk | Trigger | L | I | Exposure | Mitigation | Residual | Owner | Evidence |
|---|---|---|---|---|---|---|---|---|---|
| L1 | KoboToolbox is a second personal-data store | Household surveys, 500 per county | 4 | 4 | pilot | Outside this codebase and outside this threat model. Must be in the DPIA | Open | CSO, CPO | T3 Q2 M1 A1 |
| L2 | Historical facility case data | ≥12 months from ≥2 facilities per county | 3 | 4 | pilot | Committed as anonymised; anonymisation not verified by us | Open | CPO | T3 Q2 M1 A2 |
| L3 | DHIS2 identity matching | Integration scoping, then linkage | 2 | 4 | scale | Q4 scoping document only; no integration in the investment period | Deferred | CSO | T3 Q4 M2 A2 |
| L4 | Processor for another controller's data | County shares records inbound | 3 | 4 | pilot | Written DPAs define the split | Planned | CSO | T2 p10 |
| L5 | ICD-10/11 coding errors | 100% of case data coded | 2 | 3 | pilot | Q4 deliverable | Deferred | CPO | T3 Q4 M2 A1 |

## M. Organisational and sustainability

| ID | Risk | Trigger | L | I | Exposure | Mitigation | Residual | Owner | Evidence |
|---|---|---|---|---|---|---|---|---|---|
| M1 | **Key-person concentration** | One person owns security, compliance, data governance, backend architecture and the chain | 4 | 4 | now | None. The org chart assigns all of it to the CSO, and this register names him in 40+ rows | **Open** | CEO | Template 4 |
| M2 | Five founders, component-split ownership | Any departure | 3 | 4 | scale | Ownership is documented per component, which helps continuity and worsens concentration | Partly mitigated | CEO | T2 p9 |
| M3 | No revenue today against three projected channels | Year two | 3 | 3 | scale | Year one funded; hosting and shortcode prepaid 15 months past grant; county contracts structured to follow demonstrated use | Planned | CEO | Template 6 p1 |
| M4 | County contracts unsigned | Buying decision never arrives | 3 | 3 | scale | Two counties engaged through the pilot; de-risked by embedding in workflows first | Planned | CEO | Template 6 p1 |
| M5 | Field staff engagement obligations | Part-time coordinators and collectors | 2 | 2 | pilot | Policy requires written paid contracts and forbids unpaid interns for core delivery | Mitigated | CEO | Policy 1 §3 |

## N. Contractual and reputational

| ID | Risk | Trigger | L | I | Exposure | Mitigation | Residual | Owner | Evidence |
|---|---|---|---|---|---|---|---|---|---|
| N1 | **Committed capability not delivered** | Assessor checks USSD, ONNX, public chain, MCP, CHW app, stocking dashboard | 4 | 4 | now | The repository is honest about each gap, and `docs/roadmap.md` states what each needs. Honesty is not delivery | **Open — see go-live-gates.md** | CEO, CSO | README "Not in scope" vs T2 |
| N2 | Quarterly reporting against signed policies | Reporting cycle arrives | 3 | 3 | now | Committed in Appendix 1: report quarterly and publish each policy in the public repository. **The policies are not in this repository** | Open | CEO | Appendix 1 |
| N3 | Halfway open-source obligation | Month 6 | 2 | 4 | pilot | Already largely met — Apache 2.0 throughout, SPDX enforced by `make verify`. Dataset publication and the ≥1 logged external access are not | Partly met | CSO | T3 Q2 M6 A2 |
| N4 | **Overclaim discipline broken by a single edit** | One careless README or dashboard change | 3 | 4 | now | Strong today: no accuracy, uptime or "families protected" figure appears anywhere, and a test guards the threshold finding. But nothing prevents a future edit | Open — worth a CI check | CSO | README "Limits" |
| N5 | Attribution audit not done | Final compliance review | 2 | 2 | pilot | Q3 activity: 100% of repositories carrying correct Apache 2.0 attribution | Planned | CSO | T3 Q3 M4 A2 |

---

## Unverified — needs a human

Not scored, because scoring them would be invention.

1. **Whether the two counties will sign DPAs, and on what terms.** Everything in class A
   downstream of A4 assumes they will.
2. **The real cost of SMS at pilot volume.** I10 is rated on the submission's own statement,
   not on a quoted tariff.
3. **Whether the ODPC accepts the EDPB 02/2025 reasoning on anchoring** (A10, F-class). No
   Kenyan guidance on immutability or distributed ledgers exists; the submission says so.
4. **Whether a funded signing key can be held at all** under the zero-credentials rule (F3).
   This is a policy decision, not an engineering one.
5. **Whether Dholuo and Kikuyu output can clear a native-speaker quality floor** (H9, J5).
   The one real model run to date had all six drafts refused.
6. **Actual re-identification risk at sub-county resolution** (B8). Needs the population
   denominators, which this repository does not hold.
7. **Whether any deployable open-weight model can pass the grounding check** (H2). Untested
   beyond a 1.5B model that could not.
