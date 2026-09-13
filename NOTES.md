<!-- SPDX-License-Identifier: Apache-2.0 -->

# NOTES — what this actually is

For a reviewer deciding whether to trust it. Deliberately unflattering.
Everything here was verified by running it.

## What is built

| Area | State |
|---|---|
| Climate ingestion | Open-Meteo client (free, keyless) and a fixture source behind one `ClimateSource`. Idempotent upsert on `(area_id, forecast_date, issued_at)`, proven by test. |
| Risk scoring | Deterministic. Four diseases, published thresholds, boundary-tested at ±0.1 on every cutoff. Every row stamped with predictor and version. |
| Registry | Children, guardians, the 16-dose KEPI schedule, due/overdue computation, Connect API. PII encrypted at rest with AES-256-GCM. |
| Append-only events | Enforced in the database. `UPDATE` always rejected; `DELETE` only via a transaction-scoped erasure flag. Tests prove the trigger fires and the flag does not leak past its transaction. |
| Ledger | Canonical serialization (golden-tested), per-child HMAC-SHA256 leaves, RFC 6962 Merkle trees, inclusion proofs verified across many tree sizes, single-bit mutation property test. |
| Erasure | `ForgetChild` deletes records, scrubs leaf linkage, destroys the HMAC key; roots still verify afterwards. |
| Notification | Real to the channel boundary. Bilingual GSM-7 templates, consent gate, quiet hours, per-child-per-score dedup. The mock channel writes JSONL and sends nothing. |
| Public API | REST (JSON/CSV/GeoJSON) and Connect over the same proto messages, k≥10 suppression, last-good-response stale cache, never-500 reads. |
| Dashboard | Nine views, each backed by a live endpoint and carrying an on-screen statement of what it does not prove. A status strip repeats the weather source, the channel, the active scorer and "demo population: fictional" on every view. Types generated from protobuf. |
| Climatology predictor | Empirical per-county, per-month distributions from 18,195 historical 14-day windows (3,780 stored quantiles), embedded in the binary. Reports exceedance of the climate driver, never an outbreak probability. |
| Annotated scores | A default `PREDICTOR=rules` deployment records an exceedance annotation and one explaining sentence on every score. The published thresholds still decide every tier; the annotation moved nothing. `RulesPredictor` is byte-identical and its boundary tests untouched. |
| Chain anchor | Against a **local development chain**. Each day's root goes to a `RootAnchor` contract on the anvil node this stack starts (chain id 31337) and is read back with `eth_call` before the day is reported anchored; a mismatch is an error. `GET /v1/ledger/anchors/verify` re-runs the check live. |
| Briefing service | One briefing per county per language (en, sw) from an aggregate fact sheet. The default generator is a deterministic template that labels itself. Model drafts pass a grounding check or are rejected. |
| Threshold validation | The most useful thing here. Two of four published cutoffs are unreachable in the monitored counties. Encoded as a failing-if-untrue test and exposed on `/v1/model`. |
| Pipeline | River-backed ingest → predict → alert, plus ledger and briefing sweeps, exercised end to end by an integration test that boots all seven services. |

`make verify`, `make up` and `make demo` all pass on `main`. The demo output in
the README is pasted unedited from a real run — reused population, four consent
skips and all.

The deployed instance at <https://climateshield.jarida.io> runs that same `main`
on a 458 MB droplet, too small for the chain. There `ANCHOR_MODE=local` and
`BRIEFING_GENERATOR=mock`, so **the chain-anchor pillar is not demonstrated on
the public host**. That is a limit of the host, not the code.

## What is stubbed

| Stub | Location | Behaviour |
|---|---|---|
| ONNX predictor | `internal/predict/onnx.go` | Returns `ErrNotImplemented`. Setting `ONNX_MODEL_PATH` **fails startup** rather than silently using rules: a configured model that cannot load must never be mistaken for one that works. |
| CHIRPS, ERA5 sources | `internal/climate/{chirps,era5}/` | `TODO(Q1)`; constructors return `ErrNotImplemented`. |
| Africa's Talking | `internal/notify/at/at.go` | Returns `ErrNotConfigured`. No account, no credentials, by design. |
| SMPP channel | `internal/notify/smpp/smpp.go` | Compiles and binds lazily against `fiorix/go-smpp`, but has **never been tested against a live carrier**. Unproven. |
| Public-chain anchor | `internal/ledger/anchor/evm/` | The anchor is real but only against a local development chain. Anchoring to a public network is deliberately not wired: it needs a funded signing key, and the zero-credential rule forbids one. No surface may call this chain public, immutable or decentralised. |
| Language-model briefings | `internal/briefing/{openaicompat,anthropic}/` | Both adapters are covered by committed golden responses served by `httptest`. The openai-compatible one has been run once against a real local model and every draft was refused — see below. **No model-written briefing has ever been served.** The hosted adapter has never been called against a live API: tests may not touch the network and the repo ships no key. |
| Kiswahili wording | `internal/briefing/mock/`, `internal/notify/` | The implementer's Kiswahili, not a Kiswahili speaker's. The grounding check catches invented facts; it does not judge grammar. |

## Assumptions

1. **KEPI grace period of 14 days.** Dose codes and due ages are standard; the
   point at which a due dose becomes *overdue* is my assumption, encoded as
   `vaccine_schedule.overdue_grace_days`. Needs MoH confirmation.
2. **No disease name in SMS.** A named disease beside a named child on a
   plaintext SMS is diagnosis-adjacent and stigma-prone, so the templates say
   "outbreak risk" and a test asserts no disease name can appear. A product
   decision worth confirming: it trades specificity for privacy.
3. **Risk tier labels stay English in the Swahili template.** Reads oddly and
   should be fixed with real linguistic review.
4. **One alert per child per risk score**, naming the earliest-due vaccine only.
5. **`forecast_date` is the Africa/Nairobi calendar date**; `issued_at` is UTC.
   The predictor scores the most recently *issued* window, which is why live
   ingestion overrides fixtures.
6. **The demo population is fictional**, sized so k-anonymity has both visible
   and suppressed counties (Kisumu 12, Eldoret 11, Mombasa 3, Nakuru 2,
   Nairobi 0). Phones use a fake `+2547000001xx` range.
7. **Sub-county granularity is schema-only.** Only the five counties are seeded.
8. **Single replica per service.** Each schedules its own periodic work with
   River per-period uniqueness as the guard. Not load-tested with replicas.
9. **`imresamu/postgis:16-3.4`** is used because the official image is
   amd64-only. A different publisher, worth a supply-chain look.

## Three real bugs, and where each was caught

The first two would have shipped if I had only written unit tests:

1. **River refuses to insert a job kind absent from the inserting client's own
   `Workers` bundle.** The ingestor could never enqueue `risk_predict`; the
   pipeline stopped dead after ingestion. Fixed with insert-only clients.
2. **River elects one leader per database, and only the leader fires periodic
   jobs.** Whichever service won silently starved the others — the ledger swept
   and the ingestor never ran. Fixed by giving each service its own in-process
   schedule with per-period uniqueness.

The third was caught by deploying to a real host, four weeks after it started
failing, and it is the worst defect this project has found:

3. **The mock channel had never written a single message in production.** Every
   service runs as UID 10001; `./var`, the host side of the `/outbox` mount, is
   created by root at mode 755. The unprivileged user cannot write to it, so
   every dispatch failed with `permission denied` — for four weeks, leaving
   **586 `alert_dispatch` jobs retried or discarded and the `alerts` table
   empty**. Docker Desktop's bind mounts on macOS ignore the container UID, so
   the identical compose file works on a laptop and fails on Linux. No test and
   no amount of reading the compose file would have found it.

   Fixed: the deploy script chowns the directory before first start, and
   `docker-compose.yml` says why so nobody removes it as unexplained. On the
   droplet, 37 `would_send` and 4 `skipped_consent` appeared within a minute.

   Be blunt about what this was. This project's central claim is that no output
   implies an action that did not happen — and for four weeks a deployment
   reported an empty messaging surface that was empty for a reason nobody had
   noticed. The disclosure held: nothing ever claimed a message was sent. The
   plumbing did not.

A fourth, in my own tooling: the coverage gate summed the repeated per-binary
blocks `-coverpkg` produces, reporting 7.6% when real coverage was ~72%. It now
merges by block, keeping the highest hit count.

## Corrected from the prototype

The Python prototype printed `"SMS sent to under-vaccinated families"` while
sending nothing. That class of false output is now structurally prevented: the
mock channel records `would_send`, never `sent`, and the demo reads the climate
source back out of the database rather than trusting its own configuration. The
prototype README also carried stale thresholds (50/30/18/38) contradicting its
own code; thresholds now live in one place with boundary tests.

## Coverage

**90.6% of roughly 3,120 statements, against a gate of 80% — green.** Generated
code (`internal/gen`, `internal/store/db`) is excluded; nothing else is. The
exact covered count moves by a statement or two between runs, so compare the
percentage:

```sh
make test
go run ./scripts/covergate -profile coverage.out -threshold 80
```

Up from a red 66.8%, closed by writing tests rather than by moving the
threshold or adding an exclusion — which was the stated policy when the number
was embarrassing, and did not change once it stopped being.

Because `make test` runs with `-coverpkg=./internal/...`, a package's figure
includes coverage contributed by other packages' tests, the integration test in
particular. That answers "is this exercised anywhere in the suite", which is
higher than `go test ./internal/foo` alone would report. Where the two
disagree, say which you mean.

The number flatters pure logic over error paths. The weak spots, in order:
`internal/notify/smpp` at 58.8% — also the package whose real behaviour no test
can establish; `internal/store/testdb` (68.5%) and `internal/store` (73.8%);
`internal/notify/mock` (74.1%); `internal/platform/config` (75.0%);
`internal/climate/ingestor` (78.9%, service bootstrap). Everything else is
above 80%, and the pure logic — thresholds, Merkle, grounding, suppression — is
above 92%.

## Where this is thin — read this part

- **The thing that decides a risk level is still four `if` statements.** A
  fitted baseline annotates every score and can be promoted with
  `PREDICTOR=climatology`, but by default the published thresholds set every
  tier and trigger every alert. Neither scorer is machine learning, neither has
  been validated against outbreak data, and **no accuracy claim is made
  anywhere**. Do not let a demo imply otherwise.
- **The reference climatology has not been rebuilt from the archive here.**
  `make climatology` has never been run, so byte-identical regeneration is
  unproven. What is proven without a network: the generator re-emits the
  committed artifact byte for byte, and its windowing reproduces the committed
  per-county-per-month sample counts. Run it once and compare the digest.
- **The artifact's quantile index rule was inferred, not recovered.** The
  original generator was never in the repository. The rule is consistent with
  every committed value being an exact order statistic, but consistent is not
  confirmed; only a rebuild confirms it.
- **Nothing has run at scale.** Five counties, 28 fictional children, a few
  hundred leaves. No load test, no query plan review, no partitioning.
- **The ledger's key separation is honest but modest.** Per-child keys live in a
  `sealed` schema only the ledger's query file may reference (grep-enforced),
  but it is the same database and the same role. Production needs a separate
  role with schema-scoped grants, then external key management.
- **`ForgetChild` is not wired to an API.** A tested library function nothing
  calls.
- **The dashboard has no test runner.** `web/` has no test framework, so none of
  the TypeScript is covered by anything. The basemap needs internet and dark
  mode is not implemented.
- **The stale-data banner has not been watched render.** The endpoint half is
  demonstrated: stopping Postgres returns `200` with `X-Data-Stale: true` and a
  complete last-good body while `/health` returns `503`, and restarting it
  recovers. Nobody has watched the dashboard draw its banner during that
  outage.
- **No language model has written a briefing this system served.** One has
  written six drafts and the grounding check refused all six — see below. On the
  current default the model contributes a rejection notice and nothing else.
- **The Kiswahili has had no native-speaker review.** The cheapest outstanding
  item, and the one most likely to embarrass the project in front of the people
  it is for.
- **Error paths are thinner than happy paths.** Retry and backoff rely on
  River's untuned defaults.
- **Alert selection is naive.** Every child with any due dose in an affected
  county is alerted; no prioritisation by risk, distance or how overdue.
- **Most of the dashboard was verified in an embedded browser**, after forcing a
  viewport, because that browser reports 0×0 and will not paint on its own. The
  History view and its verify button are the exception, confirmed in a real
  browser. Responsive behaviour on mobile remains unverified. Open it in a
  normal browser before any demo.

## Dashboard notes

Every form queries or previews; none writes, because a write path on an
unauthenticated public surface would breach the read-only tier. The message
previewer accepts a child's first name and renders **entirely in the browser**,
so nothing typed there is transmitted, logged or stored. That required a second
GSM-7 septet counter in TypeScript mirroring `internal/notify/gsm7.go`. The Go
one is authoritative — it is what refuses an over-long message before anything
reaches a channel. The TypeScript copy is a duplication and a drift risk, and
is recorded here as such.

Charts are hand-built SVG rather than a library, which would add ~150KB to a
page with an uptime obligation. Several real defects were caught by rendering
them and looking rather than by reasoning: stretched coordinate systems turning
markers into ellipses, bars scaled past the top of their plot, a two-bar chart
spread across 1400px, and a map that cropped Mombasa off the edge while
claiming five counties.

The status palette was wrong on accessibility grounds — the original MEDIUM
amber sat at 2.07:1 against white label text, against a 4.5:1 floor. All three
tiers were re-stepped. The four-slot disease palette was checked for
colour-vision-deficiency separation; three slots fall below 3:1 against the page
surface, so every chart ships a table and none relies on colour alone.

The basemap comes from MapLibre's public demo tile server. It stalled
repeatedly during review with **no error event at all** — MapLibre parses tiles
in Web Workers, and when those stall the map reports nothing and never loads.
The map now frames its markers immediately rather than waiting for a style that
may never arrive, and after ten seconds says the basemap is unavailable and the
markers and risk levels below are still accurate. Any restricted or offline
deployment hits the same path.

## On calling it a "model"

A good evaluator will ask, so be ready.

The climatology predictor has **fitted parameters** — roughly 3,800 empirical
quantiles learned from real reanalysis, per county, per month, per driver — and
produces a continuous, interpretable number. That is more than four
if-statements. But it is **not** supervised learning: nothing was fitted to
health outcomes, because no outcome data exists here. It predicts nothing about
disease.

The honest sentence: *"a fitted statistical baseline over a decade of
reanalysis, used to flag climatological extremes; no disease model has been
trained or validated."* Anyone who calls that "AI" should be corrected —
including in your own slides. Long form:
[docs/model-card.md](docs/model-card.md) and
[docs/threshold-validation.md](docs/threshold-validation.md).

## On calling it "AI"

Two things here could be pointed at and called AI, and only one has a claim to
the word.

**The briefing generator can be real generative text.** When a deployment opts
in, a language model writes the county briefing, and calling that generative AI
is fair. Four things bound it:

- **Off by default.** The shipped generator is a deterministic template whose
  first line is `[mock] no language model ran — deterministic template.`
- **Grounded.** Every draft is checked against the fact sheet it was given. A
  number not traceable to the sheet, another county, an unscored disease, a
  disease at the wrong tier, an accuracy or outbreak-prediction claim, an "SMS
  sent" claim in either language, a person- or phone-shaped string, or a model
  writing our own `[mock]` label — each rejects the draft. A rejected draft is
  never served, stored or logged.
- **Labelled.** Every briefing carries its generator, model and prompt version
  alongside the hash of the fact sheet it was written from.
- **Blind to people.** `FactSheet` has no field for a child, a guardian, a phone
  or a sub-k count, and no generated text ever reaches a guardian — SMS comes
  only from the fixed, length-checked templates.

The caveat belongs in the same breath: **no model has written one of these that
this system served.** So "the generative pillar works" means the plumbing and
the refusal path work, with the refusal path now demonstrated against a live
model rather than only fixtures.

**The risk scorer is not AI, in either mode.** Neither the threshold rules nor
the fitted climatology is machine learning; nothing was trained on health
outcomes. Calling the scorer AI because a language model exists elsewhere in
the repository is exactly the borrowed credibility this project avoids.

The sentence covering both: *"a language model can write the county briefing,
and every sentence it writes is checked against the aggregates it was given;
the risk levels come from published threshold rules and a fitted weather
baseline, neither of which is machine learning."*

### What happened when a real model was run

`make up-ai` was run on 2026-09-10 against qwen2.5:1.5b served locally by
Ollama, no credential involved. The first time a language model produced text
in this system.

**Every draft was refused.** Six drafts across three sweeps (Kisumu and
Eldoret, English and Kiswahili) were rejected by the grounding check. The
recurring violation was `forbidden_claim` — the model wrote "will occur", an
outbreak prediction this system cannot support — with `possible_name`, and on
the Kiswahili drafts `level_mismatch`, restating a disease at a tier the fact
sheet did not give it. The template was served each time, and the provenance
line named the model that had failed.

Two honest readings. The good one: the guardrail fires against a real model,
not merely against fixtures, and the reader is told exactly what happened
instead of being shown plausible text. The unflattering one: a 1.5B model on
CPU is not good enough to pass this check on this task, so by default the
language model contributes nothing but a rejection notice. Whether a larger
model clears the bar is untested, and **no pass rate should be quoted
anywhere**, because the only measurement that exists is "six of six refused".

Timing: a trivial completion takes about 14 seconds cold; a full briefing runs
to minutes. That is why generation is a background job, and why the `ai`
overlay sets its own timeout and sweep interval instead of inheriting the ones
sized for the template generator — inheriting them is what made the first run
time out on every county and quietly serve templates.

## What I would do next

Ordered by how much each changes whether the system helps anyone.
[docs/roadmap.md](docs/roadmap.md) says which are blocked on somebody else.

1. **Validate the thresholds, or stop calling them a model.** Pull county
   outbreak data and reanalysis, and measure how these four rules would have
   performed. That either earns the v1 claim or redirects effort — and it is the
   only work here that changes whether the system helps anyone.
2. **Close the gap between "tested" and "operable".** Give the ledger its own
   database role with schema-scoped grants, move the PII key behind a secret
   manager, and expose `ForgetChild` through an audited endpoint. The guarantees
   are implemented; they are not administrable.
3. **Amend the pneumonia and meningitis thresholds.** Two of four rules are
   inert. The pneumonia fix is small and valuable — measure cold stress on daily
   minimum temperature, where the highland signal is real. Needs a proposal
   amendment, not a commit.
4. **Prove one real SMS path end to end.** The Channel port is the riskiest
   untested boundary. Nothing else is worth much if the last hop does not work.
5. **Get the Kiswahili reviewed** by a named speaker.
6. **Find a model that can clear the grounding check.** qwen2.5:1.5b failed six
   for six, so what is unproven is not the plumbing but whether any deployable
   model writes a draft the check accepts. Reporting "no model has yet passed"
   is respectable; quoting a pass rate before one exists is not.
