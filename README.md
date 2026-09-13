<!-- SPDX-License-Identifier: Apache-2.0 -->

# ClimateShield

**Climate-responsive early warning for child immunization in Kenya.**

Climate data comes in. Outbreak risk is scored per county against the published
thresholds. Guardians of under-vaccinated children are selected for alerting on a
**mock channel that records what it would send and sends nothing**. A county
briefing is written from the aggregates in English and Kiswahili. Immunization
events go into a tamper-evident ledger whose daily root is anchored to the local
development chain this stack starts. County aggregates are published on a free,
unauthenticated, read-only API, and a dashboard lets anyone check each claim
against live data.

Built by [Jarida One](https://jarida.io) with support from the UNICEF Innovation
Fund. [Apache 2.0](LICENSE).

Read next: [NOTES.md](NOTES.md) — what is stubbed and what is thin ·
[docs/model-card.md](docs/model-card.md) — is it a model ·
[docs/threshold-validation.md](docs/threshold-validation.md) — are the thresholds
any good · [docs/roadmap.md](docs/roadmap.md) — what each pillar needs next.

## See it running

<https://climateshield.jarida.io> serves `main` from DigitalOcean's smallest tier
(458 MB RAM) behind Caddy with automatic TLS. The risk map, the Model view, the
briefings, the k-anonymity table and every `/v1/` endpoint are live there. That
host is too small for the chain, so it runs
[the smallhost overlay](deploy/docker-compose.smallhost.yml) and three things are
deliberately absent:

| Absent there | What that means |
|---|---|
| The development chain | `ANCHOR_MODE=local` — roots go to that deployment's own `anchors` table and nowhere else, and `GET /v1/ledger/anchors/verify` answers `unavailable` with its reason. **The chain anchor is not demonstrated on the public host**; `make up` below demonstrates it. |
| A language model | `BRIEFING_GENERATOR=mock` — briefings come from the deterministic template that labels itself on its first line. |
| SMS | Nothing is sent there, as nothing is sent anywhere in this system. |

[deploy/README.md](deploy/README.md) explains both overlays and which to use.

## What the proposal promised, and what runs today

Every "See it yourself" was run against this stack on 2026-09-13. They assume
`make up && make demo` has run once; before that there is no data, and an empty
answer is not a failure.

| Pillar | What runs today | Status | See it yourself |
|---|---|---|---|
| **Prediction model** | Four published threshold rules decide every risk level. A fitted climatology — 3,780 empirical quantiles over 18,195 fourteen-day windows of ERA5 reanalysis — annotates every stored score with how unusual that weather was, and can be promoted to the deciding scorer with `PREDICTOR=climatology`. | Runs. Not validated against any disease outcome; this repository holds no outbreak data. | Dashboard → **Model**; `GET /v1/model` |
| **Threshold validation** | Two of the four published cutoffs (pneumonia, meningitis) cannot fire in the five monitored counties. Reported, not amended — they are contractual. | Runs, and is the most useful result here. | `go test ./internal/predict -run TestPublishedTemperatureThresholdsAreUnreachableInReferenceDecade` |
| **Generative AI — county briefings** | One briefing per county per language, written from an aggregate fact sheet. The default generator is a deterministic template that says so on its first line; a language model is opt-in. Every model draft is checked against the fact sheet, and a failing draft is rejected rather than served. | Runs by default with no model. A local open-weights model was run once, on 2026-09-10: all six drafts were refused by the grounding check and the labelled template was served instead. | Dashboard → **Briefing**; `GET /v1/briefings?area=Kisumu&lang=en` |
| **Blockchain — chain anchor** | Each day's Merkle root is written to a `RootAnchor` contract and read back with `eth_call` before the day is reported as anchored. A read-back mismatch is an error. | Runs under `make up`. A **local development chain**, not a public network; its history is deleted by `make down`. | Dashboard → **History**; `GET /v1/ledger/anchors/verify` |
| **Tamper-evident immunization record** | Per-child HMAC-SHA256 leaves, RFC 6962 Merkle trees, inclusion proofs, append-only events enforced by a database trigger, and a guarded erasure path. | Runs. `ForgetChild` is a tested library function with no endpoint calling it. | `make demo` prints an inclusion proof for an event it recorded moments earlier |
| **Guardian messaging** | Bilingual GSM-7 templates, consent gate, quiet hours, per-child dedup, and a Channel port. | Runs to the channel boundary. The default channel records what it would send and sends nothing. | Dashboard → **Messaging**; `var/outbox.jsonl` after `make demo` |
| **No personal data on a public surface** | Aggregates only, k≥10 suppression on every count derived from people. Ledger leaves are per-child HMACs and are never published; only whole-day roots are. | Enforced by two contract tests CI runs by name. | `go test ./internal/publicapi -run 'TestContract_' -v` |
| **Zero credentials, one command** | `cp .env.example .env && make up && make demo` on a clean machine, offline once images are pulled. | Runs. | Quick start below |
| **Coverage gate ≥80%** | Statement coverage over `./internal/...`, excluding generated code. | Green. | `go run ./scripts/covergate -profile coverage.out -threshold 80` |

## Quick start

```bash
cp .env.example .env
make up
make demo
```

`make up` starts eleven containers — ten long-running (Postgres, seven Go
services, `anvil` the local development chain, the dashboard) plus a one-shot
migration that exits 0 — and waits for every health check. The first run compiles
the Go binaries and the dashboard, which takes several minutes on a cold Docker
cache; later runs come up in about a minute. `make down` removes everything,
including the database volume and the development chain's history.

Dashboard: <http://localhost:8081>. Public API:
<http://localhost:8080/v1/risk/current>.

`make demo` ingests a committed fixture scenario, so weather, drivers and risk
levels are identical on every machine; dates, roots, transaction hashes and counts
come from the run. Abridged from a run on 2026-09-13, `[…]` marking a cut:

```
requesting ingest from: fixture (committed demo scenario, not live weather)
  ⚠ Kisumu   cholera     HIGH   (peak_rainfall_mm_14d = 74.0, rules v1.0.0)
    […17 further county × disease rows…]
5 elevated (HIGH/MEDIUM) county-disease pairs

--- Same weather, both scorers (kisumu, 14-day window from 2026-08-07) ---
  disease      published thresholds                    reference climatology
  cholera      HIGH   74.0mm [at the record extreme]   HIGH   74.0mm [at the record extreme]
  pneumonia    LOW    28.1C [top 59.5%]                LOW    18.1C [top 61.5%]
    […malaria, meningitis…]
neither column is validated against disease outcomes: this system holds none.
only the active predictor above wrote scores or triggered alerts; the other column
was computed by this demo for comparison and sent nothing.

--- Alerts ---
  skipped_consent      4
  would_send           35
[mock] would send 35 alerts
(mock channel active: NO SMS was sent; see var/outbox.jsonl for the rendered messages)

--- Tamper-evident ledger ---
  2026-09-13: 3 leaves, root 83851d642d18d45d…
    anchored: chain id 31337 (local development chain started by this stack — not a public network)
              read-back rootOf(day) == database root: OK
  inclusion proof for event 2864a415…: OK (leaf 1 of 3 under root 83851d642d18d45d…)

--- County briefing ---
  Generated by a deterministic template — no language model ran. Template template-v1, facts 65061fce6e15.
  | [mock] no language model ran — deterministic template.
  | Cholera: HIGH. peak 14-day rainfall of 74.0mm is at or above the HIGH threshold of 60mm. […]
```

The demo reports the source it *actually* scored from, read back from the database
rather than assumed from its own configuration, so it cannot claim fixture data
while showing live numbers. `make demo-live` runs the same flow against live
Open-Meteo forecasts, so the risk levels will differ.

## The prediction model

Two scorers ship. `PREDICTOR=rules` is the default, and in the default deployment
the published thresholds decide **every** level.

| Disease | Driver | HIGH | MEDIUM |
|---|---|---|---|
| Cholera | 14-day peak rainfall | ≥ 60 mm | ≥ 30 mm |
| Malaria | 14-day peak rainfall | ≥ 40 mm | ≥ 20 mm |
| Pneumonia | 14-day mean max temp | ≤ 16 °C | ≤ 19 °C |
| Meningitis | 14-day mean max temp | ≥ 39 °C | ≥ 36 °C |

They come from the funding proposal, live only in
[`internal/predict/rules.go`](internal/predict/rules.go), and every cutoff has
at / just-below / just-above boundary tests.

> **⚠ Two of the four cutoffs cannot fire.** Across ten years of ERA5 reanalysis
> (2015–2024, 18,195 fourteen-day windows, five counties) the coldest 14-day mean
> maximum is 19.9 °C against a pneumonia cutoff of 16 °C, and the hottest is
> 35.2 °C against a meningitis cutoff of 39 °C. The thresholds are unchanged here:
> they are contractual, and amending them is a proposal decision, not a commit.
> The finding is reported instead — in
> [docs/threshold-validation.md](docs/threshold-validation.md), in the per-rule
> `note` on `GET /v1/model`, and in a test that fails if it stops being true.

`PREDICTOR=climatology` scores each window against that county's own distribution
for that calendar month (5 counties × 12 months × 3 drivers × 21 quantile steps =
3,780 quantiles, embedded in the binary as a 63 KB artifact). It reports an
**exceedance of the climate driver** — "this window is in the most extreme 2% of
the last decade for this county and month". That is a property of the weather, not
a probability of an outbreak; where no reference distribution exists it reports
"not scored" rather than a confident LOW. A percentile is defined in every
climate, which is why it still works for the two diseases whose absolute cutoffs
do not.

Under the default `rules` scorer the exceedance is an **annotation**: measured
after the fact, recorded on every score with one explaining sentence, and moving
nothing. It appears on the Model view, on `/v1/risk/current` and
`/v1/risk/history`, in the fact sheet behind `/v1/briefings`, and in the demo
block above. Every `risk_scores` row records the predictor name and version that
produced it.

Neither scorer is machine learning and neither has been trained on health data.
[docs/model-card.md](docs/model-card.md) is the canonical statement of intended
use, method, evaluation and limitations. The reference artifact is rebuilt by
`make climatology`, a developer-only tool reading the free, keyless Open-Meteo
archive; nothing in `make up`, `make demo`, the tests or CI runs it. Its committed
digest is `acc41f68…c41c8d`, published as `referenceSha256` on `GET /v1/model`.

```bash
go test ./internal/predict -run TestPublishedTemperatureThresholdsAreUnreachableInReferenceDecade -v
curl -s localhost:8080/v1/model | jq -c '.rules[] | {disease, note}'
make climatology-digest    # hashes the committed artifact; makes no network request
```

## The ledger and its chain anchor

Every immunization event recorded through the registry is canonically serialized,
hashed into a per-child HMAC-SHA256 leaf, and folded into that day's RFC 6962
Merkle tree. `immunization_events` is append-only, enforced by a database trigger:
`UPDATE` is always rejected, `DELETE` only inside the guarded right-to-erasure
transaction. Individual leaves are never published; only whole-day roots are.

With `ANCHOR_MODE=evm`, the compose default, each day's root is also written to a
small `RootAnchor` contract and read back with `eth_call` before the day is
reported as anchored. A mismatch is an error, never a silent success. The chain is
`anvil`, started by this repository's own `docker compose`, chain id 31337; every
surface derives that label from `eth_chainId` at runtime rather than hard-coding
it. `GET /v1/ledger/anchors/verify` runs a live `rootOf(day)` call and returns
`verified`, `mismatch`, or `unavailable` with a plain reason — never an invented
match. The contract is compiled once by `make contract` with a digest-pinned
`solc` image; ABI and bytecode are committed and a test fails if they drift, so
nothing at build, test or run time needs `solc`.

Ask the API, then ask the chain directly and compare the two hex strings:

```bash
curl -s localhost:8080/v1/ledger/anchors/verify | jq '{status, dbRootHex, chainRootHex, chainLabel}'
docker compose exec anvil cast call $(curl -s localhost:8080/v1/ledger/anchors/verify | jq -r .contractAddress) \
  "rootOf(bytes32)(bytes32)" \
  $(curl -s localhost:8080/v1/ledger/anchors/verify | jq -r .dayBytes32) \
  --rpc-url http://127.0.0.1:8545
```

To watch it catch a tamper, change `daily_roots.root` for one day in Postgres and
call verify again: it returns `mismatch` and names the day. Restoring the row
returns it to `verified`.

## County briefings

The briefing service turns aggregates this system already publishes into a county
summary in English and Kiswahili, and prints the fact sheet beside it so every
sentence can be checked against the numbers it was allowed to use. The default
generator is a deterministic template, and every briefing it writes begins with
`[mock] no language model ran — deterministic template.` That is why `make up`
works offline with zero credentials.

A language model is opt-in: `BRIEFING_GENERATOR=openai` for a locally hosted
open-weights model behind an OpenAI-compatible endpoint (`make up-ai` starts
Ollama + qwen2.5:1.5b, Apache-2.0, still no credential), or
`BRIEFING_GENERATOR=anthropic` for the Claude API, which reads `ANTHROPIC_API_KEY`
— a key this repository never ships and CI never sets. Asking for a generator
without its credential fails startup rather than silently serving templates while
claiming a model.

Why a model cannot invent anything here:

- **It never sees a person.** The `FactSheet` type has no field for a child, a
  guardian, a phone number or a count below the k≥10 threshold, asserted on the
  actual bytes that leave the process.
- **Every draft is checked against its fact sheet.** A number not traceable to the
  sheet, another county, an unscored disease, a disease at the wrong tier, an
  accuracy or outbreak-prediction claim, an "SMS sent" claim in either language, a
  person- or phone-shaped string, or a model writing our own `[mock]` label — each
  rejects the draft.
- **A rejected draft is never served, stored or logged.** The labelled template is
  served instead and the violation kinds are published on `/v1/briefings`.
- **No generated text reaches a guardian.** Alert SMS comes only from the fixed,
  length-checked templates in `internal/notify`.
- **Nothing generates on the request path.** Briefings are written by a River job
  on the briefing service's own sweep; unchanged facts regenerate nothing.

What a real model actually did here is recorded in
[NOTES.md](NOTES.md#what-happened-when-a-real-model-was-actually-run).

```bash
curl -s "localhost:8080/v1/briefings?area=Kisumu&lang=en" | jq -c '{generator, model, promptVersion, grounded, status}'
go test ./internal/briefing -run TestAdversarialDrafts -v
go test ./internal/briefing/facts -run TestFactSheetHasNoPersonFields -v
```

## Limits

Stated once, here; [NOTES.md](NOTES.md) argues each at length.

- **No SMS is sent.** Alerts are recorded as `would_send`, never `sent`. Only a
  real carrier adapter may write `sent`, and none has been connected.
- **No accuracy claim.** No sensitivity, specificity, accuracy, latency, uptime or
  "families protected" figure appears in this repository, because no evaluation
  exists that would support one.
- **The chain is a local development chain**, and every surface says which.
  Nothing is written to any public network, and no surface calls this chain
  public, immutable or decentralised.
- **No language model has written a briefing this system served.** Generated text
  is labelled, grounded, or not served.
- **The Kiswahili has had no native-speaker review** — SMS and briefing templates
  alike are the implementer's.
- **`ForgetChild` has no endpoint**, the SMPP adapter has never reached a carrier,
  and the ONNX, CHIRPS and ERA5 sources are stubs that fail cleanly.
- **Nothing has run at scale.** Five counties, 28 fictional children, a few
  hundred ledger leaves.

## The dashboard

Nine views. Each lets a reviewer check a capability against running data, and each
carries an on-screen statement of what it does *not* prove.

| View | What it lets you check |
|---|---|
| **Overview** | What runs today, with a live figure per pillar and the k-anonymity table |
| **Risk map** | Current risk per county, filterable by disease |
| **Model** | Both scorers on the same weather, and how the thresholds were checked |
| **Weather** | The exact 14-day forecast window each score was computed from |
| **Briefing** | The briefing beside the fact sheet every sentence must come from |
| **Messaging** | Message outcomes, both language templates, a live GSM-7 previewer |
| **History** | Daily Merkle roots, the anchor, and a "verify on chain now" button |
| **Automation** | Job history from the queue, with optional auto-refresh |
| **Open data** | Every endpoint, runnable from the page itself |

A status strip under the nav puts the weather source, the channel
(`mock — no SMS is sent`), the active scorer and `demo population: fictional` on
every view. Charts are hand-built SVG and each ships a data table, so nothing is
gated behind colour. All forms query or preview; none writes. The one free-text
control (a child's first name in the message previewer) renders entirely in the
browser, so nothing typed into it is transmitted, logged or stored.

## Architecture

Seven Go services, one module, one Postgres database.
[docs/architecture.md](docs/architecture.md) is the reference.

```
ingestor → climate_observations → predictor → risk_scores → notifier → Channel → [mock] outbox.jsonl
registry → immunization_events → ledger → HMAC leaves → daily Merkle root → RootAnchor on anvil
risk_scores + aggregate counts → briefing → fact sheet + briefing
everything readable → publicapi → JSON / CSV / GeoJSON + Connect → dashboard
```

| Service | Port | Responsibility |
|---|---|---|
| `ingestor` | 8090 | Fetch daily forecasts for 5 counties; idempotent upsert |
| `predictor` | 8091 | Score risk, annotate with exceedance, enqueue HIGH/MEDIUM alerts |
| `notifier` | 8092 | Render bilingual SMS, respect consent and quiet hours, dispatch |
| `ledger` | 8093 | Commit events to daily Merkle trees; anchor and read back roots |
| `briefing` | 8094 | Write one county briefing per language from the fact sheet |
| `registry` | 8082 | Children, guardians, KEPI schedule, immunization events (Connect only) |
| `publicapi` | **8080** | Public read-only aggregates (REST + Connect) |
| `web` | **8081** | Demonstration dashboard |

Alongside them: `postgres`, `anvil`, and a one-shot `migrate` container. Work moves
between services through [River](https://riverqueue.com) (Postgres-backed), so no
message broker is required. Only `publicapi` and `web` are meant to be publicly
exposed; the production overlay in [`deploy/`](deploy/README.md) publishes nothing
else.

**Stack.** Go 1.26 · chi · ConnectRPC + Protobuf (buf) · PostgreSQL 16 + PostGIS ·
pgx + sqlc · golang-migrate · River · `log/slog` with mandatory PII redaction ·
Prometheus · testcontainers · TypeScript strict + React + Vite + MapLibre GL JS ·
Docker Compose · GitHub Actions. Every dependency is open source and free.

## Public API

Unauthenticated, read-only, aggregates only.

| Endpoint | Returns |
|---|---|
| `GET /health` | `200` when ready; `503` if the database is unreachable |
| `GET /metrics` | Prometheus metrics |
| `GET /v1/risk/current` | Latest risk per county × disease |
| `GET /v1/risk/history` | Historical scores; `area`, `disease`, `from`, `to`, `limit` |
| `GET /v1/stats` | Per-county counts derived from people (k≥10 suppressed) |
| `GET /v1/model` | Active scorer, thresholds, reachability, reference digest |
| `GET /v1/climatology` | Reference distribution for one county and month |
| `GET /v1/climate/series` | The forecast window each score was computed from |
| `GET /v1/ledger/summary` | Daily Merkle roots and anchors — never individual leaves |
| `GET /v1/ledger/anchors/verify` | A live `rootOf(day)` call |
| `GET /v1/briefings` | One briefing (`?area=&lang=en\|sw`), provenance, fact sheet |
| `GET /v1/alerts/summary` | Messaging outcomes, channel status, rendered templates |
| `GET /v1/pipeline` | Job history and data volumes |

Add `?format=csv` or `?format=geojson` to the risk endpoints (`csv` also on
`/v1/stats`); JSON is the default and `/v1/briefings` is JSON only. Unsupported
combinations return `400`, never `500`. The same messages are served over
ConnectRPC at `/climateshield.v1.PublicService/…`; the protobuf definitions in
[`proto/climateshield/v1`](proto/climateshield/v1) generate both the Go services
and the dashboard's TypeScript client, so no response type is written twice.

**A public read never returns 500.** Each endpoint caches its last good response;
if the database becomes unreachable that body is served with `X-Data-Stale: true`
and the dashboard says it is showing the last good response. On a cold start with a
dead database the response is an empty but structurally valid payload — still
`200`, still flagged. `/health` reports `503` independently, so monitoring sees the
truth while readers keep getting data.

**Privacy.** No child or guardian identifier, name, phone, date of birth — and no
per-child hash — appears in any response. Counts derived from people are withheld
when `0 < n < 10`, with a `*_suppressed` flag; zero and ≥10 pass through.
`TestContract_PIILeak` and `TestContract_KAnonymity` enforce both, and CI runs them
**by name** and greps for their `RUN` and `PASS` lines, because `go test -run`
exits 0 when the test it was asked for has been deleted.

```bash
docker compose stop postgres
curl -si localhost:8080/v1/risk/current | grep -i x-data-stale   # X-Data-Stale: true
curl -s -o /dev/null -w '%{http_code}\n' localhost:8080/health   # 503
docker compose start postgres
go test ./internal/publicapi -run 'TestContract_' -v
```

## Development

```bash
make verify   # fmt · vet · lint · build · test · coverage gate · buf lint · contracts · tsc · web build
make test     # tests only, with a coverage profile
make generate # regenerate protobuf (Go + TS) and sqlc output
make help     # list documented targets
```

**Toolchain.** Go 1.26 (pinned in `go.mod`; the build image is
`golang:1.26-alpine`), Docker, and Node 22 for the dashboard only. `buf`, `sqlc`
and the protobuf plugins are `go.mod` tool dependencies run via `go tool`;
`golangci-lint` is version-pinned into `./bin` by the Makefile. Nothing needs a
global install.

**Tests.** Unit tests plus database-backed tests using a throwaway PostGIS
container (testcontainers; Docker must be running). **No test touches the
network** — the Open-Meteo client, both language-model adapters and the JSON-RPC
anchor client are tested against local `httptest` servers replaying committed
golden JSON. `go test -short ./...` skips everything needing Docker. Run `go test
./... -p 2`: running every package's containers at once saturates Docker and the
integration test fails to connect.

Outbound requests happen outside the test suite, and only here: `make climatology`
reads the Open-Meteo archive, `make demo-live` and `CLIMATE_SOURCE=openmeteo` fetch
a live forecast, `make lint` downloads `golangci-lint`, `make up` pulls images,
`make up-ai` pulls a model, and the dashboard's basemap comes from a public tile
server. Without that basemap the map says so plainly and the county markers and
risk levels stay accurate.

**Coverage.** The gate is ≥80% of statements over `./internal/...`, enforced by
[`scripts/covergate`](scripts/covergate) in `make verify` and CI. Generated code
(`internal/gen`, `internal/store/db`) is excluded; nothing else is, and the
exclusions are policy recorded in [CONTRIBUTING.md](CONTRIBUTING.md). The gate is
green; per-package figures and the weakest packages are in [NOTES.md](NOTES.md).

```bash
make test && go run ./scripts/covergate -profile coverage.out -threshold 80
```

## Configuration

Copy `.env.example` to `.env`. Every value there is a working development default
and none is a credential; `.env` is gitignored. These change behaviour most:

| Variable | Default | Meaning |
|---|---|---|
| `PREDICTOR` | `rules` | `rules` or `climatology`. Read from the environment; not in `.env.example` |
| `CLIMATE_SOURCE` | `fixture` in `.env.example`; `openmeteo` in code and compose | Deterministic offline fixtures, or live forecasts. An ingestor started without `.env` fetches live |
| `NOTIFY_CHANNEL` | `mock` | `mock` (sends nothing) or `smpp` |
| `ANCHOR_MODE` | `evm` in `.env.example` and compose; `local` in code | `local` records a row in this system's own database only; `evm` also writes and reads back the `RootAnchor` contract |
| `BRIEFING_GENERATOR` | `mock` | `mock` (template, no model), `openai` (OpenAI-compatible endpoint), or `anthropic` (Claude API, needs `ANTHROPIC_API_KEY` — a key this project does not have, need or ship) |
| `PII_KEY_HEX` | 64-char dev value | AES-256-GCM key for encrypted columns. Generate per deployment: `openssl rand -hex 32` |
| `PII_ALLOW_DEV_KEY` | `true` in `.env.example`; `false` otherwise | Services refuse to start on the published placeholder key unless this is `true`. The production overlay never sets it |
| `ONNX_MODEL_PATH` | *(empty)* | Not implemented; a non-empty value fails startup rather than silently falling back. Read from the environment; not in `.env.example` |

## Operational notes

- **The outbox directory must be writable by UID 10001.** On Linux, `./var` — the
  host side of the `/outbox` bind mount — is root-owned mode 755 when created by
  root and the services run unprivileged, so every dispatch fails with `permission
  denied` and the `alerts` table stays empty. Docker Desktop on macOS hides this.
  `scripts/deploy-droplet.sh` chowns it; a hand-rolled deployment must too. This
  shipped once and went unnoticed for four weeks — see
  [NOTES.md](NOTES.md#three-real-bugs-and-where-each-was-caught).
- **Quiet hours.** No alert is dispatched between 21:00 and 07:00 East Africa Time
  (fixed UTC+3; Kenya observes no DST). Jobs landing in the window are rescheduled
  to the next 07:00 rather than dropped, which is why a demo run inside that window
  honestly reports zero alerts.
- **Consent.** `consent_log` is append-only and the most recent row per guardian
  decides. A guardian whose latest action is `OPT_OUT` is skipped and recorded as
  `skipped_consent`.
- **Data protection.** Child names, guardian names, phone numbers and national IDs
  are stored only as AES-256-GCM ciphertext, with the key supplied via
  `PII_KEY_HEX` and never stored in the database. Logging goes through a redacting
  handler that masks phone-shaped strings even when a caller forgets the typed
  wrappers.
- **Erasure.** `ledger.ForgetChild` deletes a child's records, scrubs the child
  linkage from ledger leaves and destroys the child's HMAC key — after which
  previously published roots still verify, but nothing links those leaves to a
  person.

## Not in scope

USSD, an Android app, ONNX inference, model training, FHIR/DHIS2 integration, real
SMS delivery, anchoring to a public chain, authentication, multi-tenancy,
Kubernetes, and an admin UI. [NOTES.md](NOTES.md) says where each boundary sits in
the code; [docs/roadmap.md](docs/roadmap.md) says what each would need.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). All first-party files carry
`SPDX-License-Identifier: Apache-2.0`; `make verify` fails if one is missing. For
anything with security or privacy implications — especially a suspected data leak
on a public surface — email **hello@jarida.io** rather than opening a public issue.
