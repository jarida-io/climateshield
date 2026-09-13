# Architecture

What the code in this repository does, drawn from the code. Every box below is
a Go package or a container in `docker-compose.yml`; every arrow is a call or a
job made somewhere in `internal/` or `cmd/`. Nothing here describes a plan.

Superseded prototype diagrams are in
[`reference/prototype-docs/`](../reference/prototype-docs/README.md). They
describe a different system and several of their claims were never
substantiated.

## Services

Seven long-running services and three one-shot commands, from one Go module.
Each `cmd/*/main.go` does configuration and signal handling only and delegates
to `Run` in its package.

| Service | Port | Package | What it does |
|---|---|---|---|
| `ingestor` | 8090 | `internal/climate/ingestor` | Pulls a 14-day forecast per county from Open-Meteo (free, no API key) or from committed fixtures. |
| `predictor` | 8091 | `internal/predict` | Scores four diseases against the published thresholds. |
| `notifier` | 8092 | `internal/notify/notifier` | Renders alerts and hands them to the channel. The mock channel appends to `var/outbox.jsonl`. |
| `ledger` | 8093 | `internal/ledger` | Folds each day's leaves into a Merkle root and anchors it. |
| `briefing` | 8094 | `internal/briefing` | Writes county briefings; deterministic template by default. |
| `registry` | 8082 | `internal/registry` | Child, guardian and immunization records. **Internal only.** |
| `publicapi` | 8080 | `internal/publicapi` | Read-only, unauthenticated REST + Connect. |

Alongside them: PostgreSQL 16 + PostGIS (domain tables and River queues),
`anvil` on 8545 — a local development chain this stack starts — and the
dashboard on 8081 (React + Vite + MapLibre), which reads the public API over
types generated from the same protobuf schema.

`registry` is the only service that touches child and guardian records. The
production overlay publishes no port for it; it is reachable inside the compose
network only.

## The pipeline

River jobs, one queue per working service, so a service never fetches a job
kind it has no worker for. Each service runs its own in-process schedule
(`internal/jobs/schedule.go`): River elects one leader per database, and a
shared leader starved every other service's periodic work.

1. `climate_ingest` fires every `INGEST_INTERVAL`. The ingestor upserts
   `climate_observations`, idempotent on area + date + issue time, and enqueues
   `risk_predict` per area.
2. The predictor reads the most recently issued 14-day window, scores four
   diseases, writes `risk_scores` stamped with the predictor name and version,
   and enqueues `alert_dispatch` for elevated scores only.
3. The notifier finds children due or overdue in that county, applies consent
   and quiet hours, renders one GSM-7 message per child in their language, and
   inserts `alerts` with status `would_send`.

**The mock channel transmits nothing.** It records what it would have sent.
Only a real carrier adapter may write status `sent`, and no row in this
database has ever held it.

Scoring is deterministic and the thresholds are contractual: they live in
`internal/predict/rules.go` and nowhere else. Two of the four published cutoffs
cannot be reached in the monitored counties — see
[`threshold-validation.md`](threshold-validation.md). That finding is served on
`/v1/model` and deliberately not "fixed" in code.

## The immunization record

Doses recorded through the registry become leaves; each day's leaves fold into
one Merkle root; the root is anchored. Individual leaves are never published: a
leaf is a per-child HMAC, and publishing one would put a per-child artifact on
a public surface.

1. A dose is appended to `immunization_events`. A trigger rejects UPDATE;
   DELETE is possible only inside the erasure flag.
2. The event is canonically serialized (fixed field order, UTC) and HMAC-SHA256
   into `event_leaves` under that child's key from `sealed.child_keys`, a
   separate schema referenced from exactly one query file.
3. Each day's leaves fold into one RFC 6962 Merkle root in `daily_roots`.
4. The root is written to the `anchors` table, and when `ANCHOR_MODE=evm` also
   to the `RootAnchor` contract — then read back with `eth_call rootOf(day)`
   and compared before the day is reported anchored.
5. `/v1/ledger/summary` publishes whole-day roots only.

Two properties, stated plainly because they are easy to overclaim:

- The chain in `docker-compose.yml` is a **local development chain started by
  this stack**. Its history does not outlive `make down`. Nothing here writes
  to any public network, and no surface in this repository calls it public,
  immutable or decentralised. Where a host is too small to run it,
  `ANCHOR_MODE=local` records roots in the `anchors` table only and the verify
  endpoint says so — see [`../deploy/README.md`](../deploy/README.md).
- **Erasure still works.** `ForgetChild` deletes the records, scrubs the leaf
  linkage and destroys that child's HMAC key, making their leaves permanently
  unlinkable while previously published roots continue to verify.

## The county briefings

The briefing service builds an aggregate **fact sheet** for a county — the same
numbers the public API publishes, through the same k≥10 suppression — and turns
it into prose. Nothing generates on a request path: the service sweeps on
`BRIEFING_SWEEP_INTERVAL`, and a county whose fact-sheet hash has not changed
regenerates nothing.

`BRIEFING_GENERATOR` selects the writer. The default, `mock`, is a
deterministic template that labels itself `[mock] no language model ran`.
`openai` points at a local open-weights server; `anthropic` uses the Claude API
and requires `ANTHROPIC_API_KEY`, which this repository never ships. A model
draft is served only if it passes a grounding check against the same fact
sheet; otherwise the labelled template is served instead.

A draft is refused for a number not traceable to the fact sheet, another
county, an unscored disease, a disease at the wrong tier, an accuracy or
outbreak-prediction claim, an "SMS sent" claim in either language, a person- or
phone-shaped string, or a model writing the `[mock]` label itself. Refused text
is never served, stored or logged — only the kinds of violation are published,
because repeating the text would repeat what the check exists to stop.

No generated text ever reaches a guardian. Alert messages come only from the
fixed, length-checked templates in `internal/notify`.

## The public surface

One read-only tier serves REST and Connect from the same protobuf messages, and
the dashboard's TypeScript types are generated from that schema — there are no
hand-written response interfaces. `Suppress` applies **k≥10** to every
people-derived count before it reaches a response.

Reads never return 500: a failing database serves the last good response with
`X-Data-Stale: true`, and the dashboard says so under the nav rather than
presenting cached figures as current. Two contract tests guard the surface and
are run by name in CI — `TestContract_PIILeak` walks it looking for anything
child-shaped, and `TestContract_KAnonymity` fails the build if a count below
ten ever reaches a public response, in JSON or in the CSV export.

## Storage

| Table | What it holds |
|---|---|
| `areas` | The five monitored counties, with centroids. Sub-county level is schema-only. |
| `climate_observations` | Ingested forecast windows, keyed by area, forecast date and issue time. |
| `risk_scores` | One row per area, disease and forecast date, stamped with the predictor that produced it. |
| `children`, `guardians`, `consent_log` | Registry records. PII encrypted at rest; consent is append-only and the most recent entry decides. |
| `vaccine_schedule` | The seeded KEPI doses and their due ages. |
| `immunization_events` | Doses given. Append-only, enforced by a database trigger. |
| `event_leaves`, `daily_roots`, `anchors`, `anchor_contracts` | The ledger: per-child HMAC leaves, daily Merkle roots, anchor receipts and the deployed contract per chain. |
| `sealed.child_keys` | Per-child HMAC keys, in their own schema. Referenced from exactly one query file. |
| `alerts` | What the alert path did for each child and score, including outcomes that were skipped and why. |
| `briefings` | One briefing per county per language, with its generator, model, prompt version, fact sheet and that sheet's hash. A refused draft is stored with status `rejected` and its reasons; the body stored is the labelled template, never the model's text. |
| River tables | Durable job queues with real retry history. |

## What runs where

`make up` starts Postgres, runs migrations, then the seven services, the
development chain and the dashboard. `make demo` drives one pass of the whole
pipeline against committed fixtures and prints what it did. Both need zero
credentials, and every dependency is open source and free.
