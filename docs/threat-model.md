<!-- SPDX-License-Identifier: Apache-2.0 -->

# Threat model

How data enters, moves through, leaves and is stored by ClimateShield, and what an
adversary can do at each boundary. Drawn from the code in this repository and from the
UNICEF submission (RFPS-NYH-2026-503931) where that commits to something not yet built.

Two systems are described throughout, because they differ enormously in exposure:

- **Today** — the demonstrator. Fictional population, mock channel, local development
  chain, aggregates-only public API, no authentication anywhere.
- **At pilot** — what the submission commits to. Real parental-consented child and
  guardian records, two live county pilots, a carrier, a public chain, an authenticated
  MCP surface.

A control that is adequate today may be the single largest risk at pilot. Where that is
true, this document says so rather than reporting one number.

Companion documents: [risk-register.md](risk-register.md) scores and owns each risk;
[go-live-gates.md](go-live-gates.md) is the subset that must be true before one real
child's record is entered; [compliance-map.md](compliance-map.md) maps the external
obligations.

**What this does not cover.** No penetration test has been run against this system. No
formal verification has been attempted. This is a structured reading of the code by its
authors, not an independent assessment, and it will miss what authors miss.

## Assets, in order of what their loss would cost

| # | Asset | Where it lives | Loss means |
|---|---|---|---|
| 1 | Child and guardian identifiers — names, phone numbers, national IDs | `guardians`, `children` (`*_enc` columns, AES-256-GCM) | A named child's vaccination status and location disclosed. Irreversible for a family; reportable to the ODPC within 72 hours |
| 2 | `children.date_of_birth` | **Plaintext** column (`0005_registry.up.sql:16-23`) | A direct quasi-identifier, deliberately unencrypted so due-date computation works. Joined with sub-county it re-identifies |
| 3 | `PII_KEY_HEX` | Environment only, never in the database | Every `*_enc` column decrypts. One key, no rotation path, no versioning |
| 4 | Per-child HMAC keys | `sealed.child_keys`, **cleartext `bytea`** (`0007_ledger.up.sql:44-48`) | Ledger leaves become linkable to children, and erasure's core guarantee — that destroying the key makes past leaves unlinkable — fails retroactively |
| 5 | Integrity of the immunization record | `immunization_events` (append-only trigger), `event_leaves`, `daily_roots`, the anchor | The tamper-evidence claim is the project's distinguishing technical claim. A silent alteration that verifies clean destroys it |
| 6 | The alert decision | `risk_scores` → `alerts` | A suppressed or fabricated alert has a health consequence. A wrongly-addressed one discloses a child's status to a stranger |
| 7 | The project's own claims | `README.md`, `/v1/model`, the dashboard | The discipline of never overclaiming is an asset. One careless edit converts an honest demonstrator into a misleading one |

Assets 3 and 4 are worth stating together: they are held in the same deployment, and at
present the same database role reads both `guardians` and `sealed.child_keys`. Separating
them is the highest-value structural change available.

## Adversaries

Ordered by how likely they are to matter, not by sophistication.

| Adversary | Capability | Motivation | Today | At pilot |
|---|---|---|---|---|
| **Unauthenticated internet caller** | Any HTTP request to a published port | Curiosity, disruption, scraping | Can exhaust memory via the stale cache, and can write to the registry if the base compose file is used | Same, plus the registry writes become permanent ledger entries about real children |
| **A neighbour or employer** | Repeated polling of `/v1/stats` and `/v1/ledger/summary` | Find out whether a specific household's child is unvaccinated | Harmless — fictional population | **Serious.** Differencing against k≥10 in a small sub-county is the most likely real privacy failure |
| **A malicious or mistaken guardian** | Can receive SMS, reply, and hold a recycled SIM | Nuisance, or innocent | No effect | Wrong-number disclosure; STOP not honoured; another family's child named in a message |
| **Compromised or lost CHW handset** | Holds field data, and at pilot an offline-first app with local records | Theft, resale | Not applicable | A whole catchment's records in one pocket. The signed policy requires secure wipe on disposal; nothing enforces it |
| **Hostile insider with database access** | Full read/write as the single superuser role | Coercion, curiosity, fraud | Can alter `daily_roots` (verify catches it) and read every `*_enc` column if they also hold the key | Same, against real children, with no role separation to slow them and no audit trail of reads |
| **Compromised upstream** | Open-Meteo response, an npm or Go module, a base image, a GitHub Action | Supply-chain foothold | Unbounded JSON into the ingestor; a fork PR runs with default token scope | Same, but the blast radius now includes a production database of children's records |
| **Carrier or aggregator staff** | See every message body in transit | Curiosity, resale | Nothing is sent | Every alert names a child and a county. SMPP has no TLS configured |
| **Chain observer** | Reads every anchored root forever | Analysis, linkage | Local chain, deleted by `make down` | A permanent public record of which days had immunization activity, on a chain nobody can retract |
| **Prompt injector** | Can write to `areas.name`, `risk_scores.explanation` or `climate_observations.source` | Make the model say something | Real today: those fields are interpolated into the prompt unescaped. Grounding check is the only barrier | At pilot the model gains tools, and the injection target becomes a cross-record tool call |
| **Authenticated MCP client** | A valid OAuth 2.1 token for one county | Reach another county's or another child's record | Not applicable | The submission names this the gravest ethical risk. Authorization must sit outside the model |

## Trust boundaries

Each section names what crosses, what is checked, and what is not.

### B1. Internet → Caddy → publicapi

**Crosses:** arbitrary HTTP, arbitrary query strings.
**Checked:** `format` against an allow-list (`publicapi/encode.go:30-42`); `lang` (`facts.go:53-55`);
dates strictly parsed (`handlers.go:217-226`); `limit` clamped to 1000 (`handlers.go:57-64`);
`month` range-checked (`evidence.go:417`). Server timeouts are set
(`httpx/server.go:49-52`). Caddy sets `Referrer-Policy`, `X-Content-Type-Options` and
`X-Frame-Options` (`Caddyfile:41-48`), and restricts `/metrics` to private ranges
(`Caddyfile:30-34`).

**Not checked:**
- **No rate limiting anywhere** — not in Go, not in Caddy, not in nginx.
- **No request size limit**, no per-request timeout beyond the 30s write deadline.
- `disease` is not validated at all (`publicapi/server.go:118`); an unknown value returns 200 and
  an empty set rather than 400.
- **No CSP and no HSTS** anywhere. The three headers Caddy sets are prod-overlay only;
  the local and demo paths serve none (`web/nginx.conf` sets nothing).
- The stale cache key includes `req.URL.RawQuery` (`publicapi/server.go:316`) and the cache has no
  TTL, no eviction and no size bound (`stale.go` has no `delete`), so an attacker mints
  unbounded permanent entries. `storedAt` is recorded (`stale.go:41,54`) and never read.
- The Prometheus middleware labels by `r.URL.Path` (`metrics/metrics.go:59`), so every
  distinct 404 creates a permanent series, exposed on `/metrics`.

### B2. Internet → registry

**This is the sharpest boundary in the system today.**

`RecordImmunization` is a **mutating** RPC that appends to an append-only, Merkle-anchored
table. `GetDueSummary` returns a per-child row set for the entire population with no limit
and no pagination.

Neither has any authentication or authorization. The handler is mounted with no
interceptors (`registry/service.go:191`), and a repository-wide search finds no auth
middleware of any kind — the only `Authorization` header in the codebase is *outbound*, to
the LLM (`openaicompat.go:149`).

The base `docker-compose.yml` publishes it on **all interfaces** (`docker-compose.yml:185`),
alongside Postgres with the password `climateshield` (`docker-compose.yml:13`). Only the
production overlay closes them (`deploy/docker-compose.prod.yml:32-33`). The control is
therefore *which command the operator typed*, which is not a control.

At pilot, the submission commits to role-based access where a CHW sees only their own
catchment. Nothing in the repository implements any part of that.

### B3. Service → PostgreSQL

**Crosses:** every query, including decrypted PII in the notifier's working set.
**Checked:** all production SQL is sqlc-parameterised; no string-concatenated SQL exists on
any request path. The append-only trigger is enforced in the database
(`0005_registry.up.sql:54-68`), not in application code, and `UPDATE` is refused under all
conditions.

**Not checked:**
- **Every service connects as the same superuser role.** There is no `GRANT`, `CREATE ROLE`
  or `REVOKE` anywhere in the repository. The ingestor, predictor, briefing service and
  public API all hold full read/write/DDL on `guardians` and on `sealed.child_keys`.
- The `sealed` schema is *physical* separation with **zero authorization separation**. Its
  isolation is enforced by a grep in `scripts/contract-checks.sh:30-41`, which a new query
  file can simply not trip.
- **Every DSN shipped carries `sslmode=disable`** — `.env.example`, `config.go:31`,
  `docker-compose.yml:32`, `deploy/docker-compose.prod.yml:78`,
  `scripts/deploy-droplet.sh:76`. Traffic carrying decrypted names and plaintext
  `date_of_birth` is unencrypted in transit in every configuration this project ships.
- The append-only trigger covers `UPDATE` and `DELETE` per row. `TRUNCATE` is not covered,
  and the trigger can be dropped by the role the application connects as.

### B4. Process → `sealed.child_keys`

Per-child HMAC keys are generated with `crypto/rand` (`encrypted.go:70-76`) and stored as
**cleartext `bytea`** — they are not wrapped under `PII_KEY_HEX`. The migration says so
itself (`0007_ledger.up.sql:36-41`).

Consequence: a database dump is sufficient to link every ledger leaf to a child, and the
erasure guarantee — that destroying the key makes past leaves unlinkable — protects only
against a future reader, never against anyone who took a copy first.

### B5. Ingestor → Open-Meteo

**Crosses:** untrusted JSON from the public internet, straight into the database.

The HTTP client sets a 30s timeout (`openmeteo/client.go:33`) and requires status 200. TLS
verification is Go's default; no `InsecureSkipVerify` exists anywhere.

**Not checked:**
- **No response size cap.** `resp.Body` is passed directly to `ParseOpenMeteo`
  (`client.go:61`), which calls `json.NewDecoder(r).Decode` (`source.go:66`) with no
  `io.LimitReader`. The other two external clients *do* bound their reads — the EVM client
  at 4 MiB (`evm/rpc.go:63`) and the LLM client at 1 MiB (`openaicompat.go:157`) — so this
  is an inconsistency, not a design decision.
- **No cap on the number of days returned.** `FORECAST_DAYS` is a request parameter only;
  the response length is never checked against it, and each day becomes an individual
  upsert with no batching (`ingest.go:18-32`).
- **No value sanity bounds.** Precipitation and temperature are taken verbatim as `float64`,
  and no `CHECK` constraint exists on those columns, so `1e308` or `-500 °C` stores cleanly
  and then feeds the predictor.
- `OPENMETEO_BASE_URL` is unvalidated — no scheme check — and Go's default client follows
  up to 10 redirects with no host allow-list.

### B6. Ledger → JSON-RPC → chain

**Today:** `anvil`, loopback-bound (`docker-compose.yml:90`), running well-known unlocked
development accounts. Anyone reaching `:8545` controls the chain, including the roots that
are the tamper-evidence claim. Any container on the compose network can reach it.

**Checked:** the read-back. Each root is written, then re-read with `eth_call rootOf(day)`
and compared before the day is reported anchored; a mismatch is an error, never a silent
success (`evm/anchor.go:266-287`). On-chain code is compared against the committed runtime
bytecode (`evm/anchor.go:182-191`). The contract restricts writes to a single publisher set
once in the constructor (`RootAnchor.sol:48-55`).

**Not checked:**
- **Zero confirmations.** `waitReceipt` accepts the first receipt returned
  (`evm/anchor.go:214-236`), and both read-backs use block tag `"latest"`. The strings
  `reorg`, `finality` and `confirmations` appear **nowhere** in the repository.
- The node signs, via `eth_sendTransaction` — no key exists here, which is correct today
  and becomes a custody problem the moment a funded public-L2 key is required.
- No gas limit, no fee fields, no nonce tracking, no retries, and the JSON-RPC response
  `id` is decoded but never compared to the request's.
- `AnchorExistsForRoot` keys on `(leaf_day, anchor_type, root)` and **omits `chain_id` and
  `contract_address`** (`queries/ledger.sql:72-80`). After a chain reset, days anchored on
  the old contract are never re-anchored, and verify reports `mismatch` for them
  permanently.
- Transport is plain HTTP by default (`ANCHOR_RPC_URL`), with no `tls.Config` anywhere.

### B7. Briefing → LLM

**Crosses:** a fact sheet, and a language, into a model. Today an opt-in local model; at
pilot a self-hosted AfriqueQwen-8B in Kenya.

**Checked, and checked well:** the `FactSheet` type structurally cannot hold a child, a
guardian, a phone number or a sub-k count (`facts/facts.go:89-103`), and a test asserts it
on the actual bytes. Every draft passes a grounding check or is refused, and refused text is
never served, stored or logged (`generate.go:252-267`). Generation never happens on a
request path. Asking for a generator without its credential fails startup.

**Not checked:**
- **Database free text is interpolated into the prompt with no delimiting.** `areas.name`,
  `risk_scores.explanation` and `climate_observations.source` all reach the canonical JSON
  that forms the user message (`openaicompat.go:199-205`), and `prompt_v1.txt` contains no
  instruction to disregard instructions found in data.
- Known grounding bypasses, all visible in `ground.go`: names in all-caps or at the start of
  a sentence are exempt (`ground.go:100,445-447`); phone-shaped runs of 8 digits or fewer
  pass the `>= 9` gate (`redact.go:43`); `allowedNumbers` scans the *entire* fact JSON with a
  bare number regex (`ground.go:191-197`), so any digit appearing anywhere — a year, a `14`
  inside a driver name — is globally allowed; a sentence naming a disease with no tier token
  is never level-checked; and `forbidden_claim` is a fixed substring list that paraphrase
  defeats.
- **No `max_tokens` on the OpenAI-compatible path** — only the 1 MiB read cap bounds a reply.

### B8. Notifier → Channel → carrier

**Today:** the mock channel writes `var/outbox.jsonl` at mode `0644` — world-readable —
with no rotation and no size cap (`notify/mock/mock.go:50-53`). Each line contains the **full
rendered message body**, which includes the child's first name and county. Erasure does not
touch this file.

**At pilot:** `internal/notify/smpp` is constructed with no `tls.Config` — the library's
plain-TCP path — and `SMPP_PASSWORD` is passed as a plain string, never redacted. There is
no unbind, no re-bind after a dropped connection, no delivery-receipt handling and no
retry. The package doc says outright that it has never met a carrier.

Dedup is check-then-act (`notifier/service.go:116-125`) with **no `UNIQUE (child_id,
risk_score_id)` constraint** on `alerts` and `MaxWorkers: 2`, so two concurrent jobs for the
same score can both send.

Quiet hours are correct for Kenya (fixed UTC+3, no DST, documented at `clock/clock.go:4-5`)
but are evaluated once per job, so a dispatch loop crossing 21:00 is not re-checked.

### B9. Browser → dashboard → tile server

React escapes everywhere except one place: the MapLibre popup uses `setHTML` with an
un-escaped `${g.area}` (`web/src/map.ts:136-137`). That value comes from `areas.name` in
Postgres. Anyone who can write that column gets stored XSS in every session that opens a map
popup — and with no CSP anywhere, nothing constrains what the injected script may do.

The dashboard also loads `https://demotiles.maplibre.org/style.json` (`map.ts:85`), which
contradicts the claim in `Caddyfile:42-43` and `index.html:20-22` that it makes no
third-party requests. That remote file additionally chooses the tile, sprite and glyph URLs
the page then fetches.

### B10. CI → container registry → production

No `permissions:` block exists in any workflow, so `GITHUB_TOKEN` inherits the repository
default — which on `pull_request` from forks, combined with `npm ci` executing the
lockfile's transitive install scripts, is the highest-leverage supply-chain gap here. All
four actions float on major tags. There is no dependency scanning, no SBOM, no CVE check, no
secret scanning, and `npm ci --no-audit` explicitly disables npm's own advisory check.

Base images are mixed: `anvil` and `ollama` are digest-pinned, but `caddy:2-alpine` — a
**major-version** tag — is the only internet-facing container.

### B11. Planned boundaries, not yet built

- **MCP → OAuth 2.1 clients.** Record-level authorization must be enforced server-side,
  outside the model, with a prompt-injection suite proving zero cross-record access. No
  authorization layer of any kind exists to build this on.
- **CHW app → API.** Offline-first, on-device ONNX, local records on a handset in the field.
- **DHIS2 / MoH.** Identity matching and onward disclosure, under someone else's controller.
- **KoboToolbox.** A second store of household personal data, outside this codebase and
  outside this threat model.

## The lifecycle, stage by stage

### Intake

| | Today | At pilot |
|---|---|---|
| **Sources** | Open-Meteo or committed fixtures | Plus CHW-collected child and guardian records, historical facility case data, KoboToolbox household surveys |
| **Controls** | Idempotent upsert; source name set by us, not the remote; fixtures deterministic | Documented best-interests assessment and verified parental consent before collection; ODPC-registered processor; signed DPAs |
| **Gaps** | No size cap, no value bounds, unvalidated base URL, redirects followed | All of the above, plus: no authentication on the ingestion RPC; no field-device controls; consent capture has no implementation |

### Processing

| | Today | At pilot |
|---|---|---|
| **Controls** | Deterministic scoring; predictor name and version stamped on every row; annotation cannot change a level; ONNX fails closed | Plus drift monitoring, challenger-in-shadow, per-stratum recall floor |
| **Gaps** | `NaN` scores as the 100th percentile and therefore **HIGH**; climatology artifact digest checked only in tests, never at runtime; two published cutoffs cannot fire | Plus: training-data bias toward sub-counties where reporting is already strong; intervention bias; 2–6 week label lag |

### Output

| | Today | At pilot |
|---|---|---|
| **Controls** | k≥10 suppression before response; two named contract tests run by name in CI; never-500 with an explicit stale flag; fixed length-checked SMS templates; generated text labelled, grounded or not served | Plus native-speaker review gates per language |
| **Gaps** | Differencing against per-cell k; suppression flags are themselves a channel; `TotalDays` and job counts unsuppressed; Connect stale cache mixes callers' briefings; XSS sink in the map popup | Plus wrong-number disclosure, duplicate sends, no STOP path |

### Storage

| | Today | At pilot |
|---|---|---|
| **Controls** | AES-256-GCM on PII columns; fail-closed dev-key guard; append-only trigger in the database; per-child keys in a separate schema | Plus Kenyan data-centre primary (Reg. 26), column-level encryption, role-based access |
| **Gaps** | No AAD, so ciphertexts are not bound to row or column and `phone_enc`/`name_enc` swap undetected; no key rotation at all; HMAC keys in cleartext under the same role; `date_of_birth` plaintext; **no backups, no retention, no restore drill** | Plus: retention commitments (24-month alert logs) with nothing to enforce them |

### Access

| | Today | At pilot |
|---|---|---|
| **Controls** | Public tier is read-only; registry unpublished in the production overlay; logging passes through a redacting handler | Plus OAuth 2.1, tiered access, CHW scoped to own catchment, MCP audit logs |
| **Gaps** | **No authentication or authorization anywhere**; redaction covers only string attributes and only ≥9-digit runs, so `slog.Any` of a struct or error passes PII through and 8-digit Kenyan national IDs are never matched; no audit trail of reads | Plus: the whole authorization model is unbuilt |

## Data flow, as committed

The submission's own diagram (Template 2, p11) traces collection → lawful basis → storage →
processing → outputs. Restated so the two can be diffed:

1. **Non-personal path.** Climate data from Open-Meteo, CHIRPS v3 and ERA5-Land on a
   schedule → `climate_observations` → feature builder → predictor → county dashboard and
   open dataset. No lawful-basis question arises; nothing here is personal data.
2. **Personal path.** Child record and guardian record, collected at a health facility by a
   trained CHW after a **best-interests assessment** and **verified parental consent**, with
   a DPIA filed with the Commissioner beforehand → encrypted columns on a Kenyan primary →
   joined with forecast risk, consent state and quiet hours by the trigger engine → health
   ledger → SMS/USSD to the guardian, prioritised list to the CHW, and a **single daily
   Merkle root** to the public L2.
3. **Retention.** Immunization record per MoH rules; alert logs 24 months; climate data
   indefinitely, as it is not personal.
4. **Erasure.** Under DPA s.40: delete the record and destroy that child's HMAC key, after
   which nobody — including Jarida — can demonstrate what the root committed to for that
   subject.

Three divergences between that flow and this repository are load-bearing, and are carried as
risks rather than resolved here: CHIRPS and ERA5 are stubs that fail cleanly; the erasure
path has no caller; and the anchor is a local development chain.
