<!-- SPDX-License-Identifier: Apache-2.0 -->

# Roadmap

What each pillar does today, the next milestone, and the test that decides
whether it was reached. An acceptance test here is a real thing that can pass
or fail — a Go test name, a command whose output can be compared, or a named
person's sign-off. "Looks better" is not one.

**No dates.** Most of these milestones are blocked on data, an account or a
person's review, none of which is ours to schedule. Those blockers are listed
at the end as dependencies, not as plans.

| Pillar | Today | Next milestone | Acceptance test |
|---|---|---|---|
| **Prediction model** | Four published threshold rules in `internal/predict/rules.go` decide every risk level. A fitted climatology (3,780 quantiles over 18,195 windows) annotates each score with its driver's exceedance; `PREDICTOR=climatology` promotes it to the deciding scorer. See [model-card.md](model-card.md). | Outcome validation: how the rules and the climatology would have performed against recorded outbreaks. | A test over a committed outbreak dataset reporting per-rule hit and false-alarm counts, published on `GET /v1/model` — or a written finding in [model-card.md](model-card.md) if they do not perform. Blocked: D1. |
| **Model reproducibility** | `make climatology-digest` hashes the committed artifact offline. `make climatology` rebuilds it from the archive but has never been run here. Two tests prove the generator re-emits the committed file byte for byte and reproduces its per-month sample counts. | Prove a rebuild from the archive returns the same artifact. | A human runs `make climatology` and the SHA-256 it prints equals `acc41f6890e10eccd16e0052f533a3e7737dcd0da71d723d968c815541c41c8d`. A difference is investigated and recorded before anything else changes. |
| **Threshold validation** | Two of the four published cutoffs cannot fire in the monitored counties. Reported on `GET /v1/model`, in [threshold-validation.md](threshold-validation.md), on the dashboard's Model view, and guarded by `TestPublishedTemperatureThresholdsAreUnreachableInReferenceDecade`. | A funder decision on the pneumonia and meningitis rules: amend, re-scope, or accept them as inert. | A proposal amendment, or a written decision to keep them, referenced from [threshold-validation.md](threshold-validation.md). The code changes only after that. Blocked: D5. |
| **Generative AI — briefings** | One briefing per county per language from an aggregate fact sheet. Default generator is a deterministic template that labels itself. Every model draft passes a grounding check or is rejected, and rejected text is never served. `make up-ai` was run on 2026-09-10 against qwen2.5:1.5b: six drafts, **all six refused**, violation kinds recorded. | A model draft that *passes* the check and is served as model text. The 1.5B model could not; whether any deployable model can is untested. | `curl -s "localhost:8080/v1/briefings?area=Kisumu&lang=en"` returns `generator: "openai"` with a real model name, `grounded: true`, and the model's own text rather than the template. No pass rate is quoted until that exists. |
| **Generative AI — language** | English and Kiswahili templates, both written by the implementer. Every surface says the Kiswahili is unreviewed. | A named Kiswahili speaker reviews the SMS and briefing templates. | Corrections merged, the "not reviewed" label replaced by the reviewer's name and date on the Briefing view and in `NOTES.md`, and `TestTemplateSWFits160Septets` still passing. Blocked: D4. |
| **Chain anchor** | Each day's Merkle root is written to the `RootAnchor` contract on the development chain this stack starts and read back with `eth_call` before the day is reported anchored. `/v1/ledger/anchors/verify` re-runs the check live. The public demo host is too small for the chain and runs `ANCHOR_MODE=local`, so this pillar is shown by `make up` and not there. | Decide whether a public-network anchor is wanted at all, and if so how its signing key is funded and held. | Not a code milestone until the key question is answered. If yes: an anchor to a public testnet whose transaction hash resolves in a block explorer the assessor picks, the same read-back check passing, and `chain_label` naming that network. Blocked: D6. |
| **Tamper-evident record** | Per-child HMAC leaves, RFC 6962 trees, inclusion proofs, an append-only trigger, and `ledger.ForgetChild` as a tested library function. | Make erasure operable: an audited endpoint invoking `ForgetChild`, plus ledger key isolation at the database-role level. | A test that calls the endpoint, asserts the records are gone, asserts previously published roots still verify, and asserts the audit line contains no PII — plus a test that the ledger role cannot read `sealed.child_keys` through any other query file. |
| **Guardian messaging** | Bilingual GSM-7 templates, consent gate, quiet hours, per-child dedup, a Channel port. The mock channel records `would_send` and transmits nothing. `internal/notify/smpp` compiles and binds lazily but has never met a carrier. | One real message to one handset, with the delivery receipt recorded. | A manual run against a carrier sandbox in which one alert reaches one test handset and the row's status is `sent` with a receipt stored — the only circumstance in which anything here may write `sent`. Blocked: D2. |
| **Immunization schedule** | 16 KEPI doses seeded, with due ages and an assumed 14-day overdue grace period. | Confirm the schedule and the grace period against MoH guidance. | A KEPI officer confirms each due age and the grace period in writing; the seed data is corrected where it differs and `NOTES.md` assumption 1 is replaced by the citation. Blocked: D3. |
| **Public surface** | Aggregates only, k≥10 suppression, never-500 reads with a stale cache, two contract tests run by name in CI. The endpoint side was exercised against a real outage on 2026-09-11: with Postgres stopped, `/v1/risk/current` returned 200 with `X-Data-Stale: true` and a complete last-good body while `/health` returned 503. | See the dashboard's stale banner render during that outage. Nobody has watched the browser half. | A screenshot of the dashboard during `docker compose stop postgres` showing the banner under the nav, recorded in `NOTES.md`. |
| **Operability** | Production and smallhost compose overlays, TLS via Caddy, a fail-closed PII key guard, and a deployment guide written to be run by a human. | The five gaps in [deploy/README.md](../deploy/README.md): key management, ledger role isolation, an invocable erasure path, rehearsed backups, and a demonstrated delivery path. | A restore drill: destroy the volume, restore from backup, and have `make demo`'s inclusion proof verify against a root committed before the destruction. |

## Dependencies, not dates

Each of these is something this repository cannot produce for itself.

**D1 — Outbreak surveillance data.** This system holds none, which is why no
accuracy, sensitivity or specificity figure appears anywhere in it. County-level
case counts for the four diseases over a period overlapping the reference decade
would make outcome validation possible.

**D2 — A carrier sandbox and a test handset.** The Channel port is the riskiest
untested boundary here. Until it is proven, `sent` is a status no row in this
database has ever held.

**D3 — A KEPI officer.** The dose codes and due ages are standard; the point at
which a due dose becomes *overdue* is an assumption in the seed data, and
everything the notifier does about overdue children rests on it.

**D4 — A Kiswahili reviewer.** The grounding check catches invented facts; it
does not judge grammar, and the 2026-09-10 run bears that out — the Kiswahili
drafts failed on `level_mismatch`, a grounding failure, not a grammar verdict.
The cheapest item here, and the one most likely to embarrass the project in
front of the people it is for.

**D5 — A proposal amendment.** The pneumonia and meningitis cutoffs are
contractual. [threshold-validation.md](threshold-validation.md) recommends
measuring cold stress on daily minimum temperature and either re-scoping the
meningitis rule to arid northern counties or dropping it — but amending a
published number is a funder decision, not a commit.

**D6 — A funded signing key.** A public-network anchor needs a key with gas in
it, and this project's zero-credentials rule forbids holding one. The
development-chain anchor demonstrates the mechanism — write, read back, refuse
to report success on a mismatch — and stops exactly where a funded key would be
required.
