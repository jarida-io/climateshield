<!-- SPDX-License-Identifier: Apache-2.0 -->

# Deploying the ClimateShield demo

For a **demonstration deployment carrying fictional seed data only**. The demo
population in `internal/store/seed` is entirely synthetic — invented names, a
fake `+2547000001xx` phone range — and nothing here is fit to hold real
records about real children. See "Before this could hold real data" at the end.

Run these on the host yourself. Nothing in this document should be pasted into
a chat window, an issue, or a commit.

---

## 0. Which overlay you want

Two, and the choice costs you a pillar:

| Overlay | For | What it gives up |
|---|---|---|
| `deploy/docker-compose.prod.yml` | A host with **4 GB RAM** that builds its own images | Nothing. The chain anchor runs and `/v1/ledger/anchors/verify` reports `verified`. |
| …plus `deploy/docker-compose.smallhost.yml` | A host too small to build or to run `anvil` | **The chain anchor.** No chain is started, the ledger runs `ANCHOR_MODE=local`, and the verify endpoint reports `unavailable` with its reason — permanently, by configuration. |

**The live demonstration at <https://climateshield.jarida.io> runs the second
one**, on a 458 MB droplet. That is why the chain-anchor pillar is demonstrated
on a local `make up` and not on the public host. Sections 1–8 describe the prod
path; section 9 describes the smallhost path and what it costs.

## 1. Prepare the host

Debian or Ubuntu. **4 GB RAM** (on DigitalOcean, `s-2vcpu-4gb`): the peak is
the first build, which compiles eight Go binaries and bundles the dashboard.
2 GB is enough to *run* the stack but not reliably to build it — npm has been
seen to die with "Exit handler never called" on a 2 GB box. For anything
smaller, build the images elsewhere and use the smallhost overlay in section 9.
As root:

```bash
apt-get update && apt-get install -y docker.io docker-compose-plugin git
systemctl enable --now docker
```

**Lock down SSH before anything else is exposed.** Password authentication on
a public host is the single most attacked surface you have:

```bash
ssh-copy-id root@YOUR_HOST          # from your laptop, first
# then on the host:
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart ssh
```

Firewall — only HTTP, HTTPS and SSH:

```bash
ufw default deny incoming && ufw allow OpenSSH && ufw allow 80 && ufw allow 443 && ufw --force enable
```

## 2. Get the code

```bash
git clone https://github.com/jarida-io/climateshield.git
cd climateshield
```

`main` is what you want. Confirm what you have:

```bash
git log --oneline -1
```

Two things this stack starts that are easy to overlook when reading the base
compose file:

- **`anvil`** — a single-node EVM **development** chain (id 31337) that the
  ledger anchors each day's Merkle root to and reads back from. It is not a
  public network, it holds no value, and its history is deleted along with the
  database by `down -v`. The base file publishes it on `127.0.0.1:8545` so a
  reviewer can run `cast` against it from the host; **the production overlay
  stops publishing 8545 entirely**, and the chain stays reachable only from the
  ledger and the public API inside the compose network. The anchor and its
  verification endpoint keep working either way.
- **`briefing`** — writes the county briefings. Its default generator is a
  deterministic template; no language model runs and no credential is involved
  unless you deliberately set `BRIEFING_GENERATOR`.

## 3. The shortest version, from your laptop

If you have `doctl` authenticated, one command creates the droplet and deploys
to it:

```bash
doctl auth init                  # once; you paste your own token
./scripts/create-droplet.sh      # creates a paid droplet, then deploys
```

Defaults are `s-2vcpu-4gb` in `fra1` on Ubuntu 24.04, deploying the ref you
currently have checked out; override with `SIZE=`, `REGION=`, `REF=`. It
refuses to create a droplet with no SSH key on it, reuses an existing droplet
of the same name, and prints how to destroy it. Secrets are generated on the
droplet and never leave it.

## 4. The short version, on the host

Everything from here — secrets, firewall, build, seed and verification — is in
one idempotent script. Run it on the host and skip to section 8:

```bash
./scripts/deploy-droplet.sh
```

It never overwrites an existing `.env`, so re-running it after a `git pull`
updates the deployment in place and keeps the secrets generated the first time.
The sections below are what it does, for anyone who would rather do it by hand
or needs to change one step.

## 5. Generate secrets **on the host**

They are created here and never leave. Do not reuse a value you have typed
anywhere else.

```bash
cat > .env <<EOF
POSTGRES_USER=climateshield
POSTGRES_PASSWORD=$(openssl rand -hex 24)
POSTGRES_DB=climateshield
DATABASE_URL=postgres://climateshield:PLACEHOLDER@postgres:5432/climateshield?sslmode=disable
PII_KEY_HEX=$(openssl rand -hex 32)

CLIMATE_SOURCE=fixture
NOTIFY_CHANNEL=mock
PREDICTOR=rules
LOG_LEVEL=info

# A domain gives you automatic HTTPS. A bare IP cannot get a certificate,
# so use :80 and accept plain HTTP for an IP-only demo.
SITE_ADDRESS=:80
EOF

# Point DATABASE_URL at the password just generated.
sed -i "s|:PLACEHOLDER@|:$(grep '^POSTGRES_PASSWORD=' .env | cut -d= -f2)@|" .env
chmod 600 .env
```

Note what is **absent**: `PII_ALLOW_DEV_KEY`. Without it the services refuse to
start on the published placeholder key, so a deployment that skips this step
fails loudly instead of running with encryption that protects nothing.

`CLIMATE_SOURCE=fixture` keeps the demo deterministic and offline. Set
`openmeteo` for live forecasts — free, no API key, but the risk levels will
then reflect real weather rather than the documented scenario.

## 6. Make the outbox writable, then deploy

Do the first step or the mock channel fails silently. Every service runs as UID
10001 and the mock channel appends to `/outbox`, a bind mount of `./var`. Created
by root it is mode 755 and unwritable by that user, so every alert dispatch dies
with `permission denied` while the queue fills with retries and the `alerts`
table stays empty. This ran undetected in production for four weeks; Docker
Desktop on macOS hides it because its bind mounts ignore the container UID. See
[NOTES.md](../NOTES.md#three-real-bugs-and-where-each-was-caught).

```bash
mkdir -p var && chown 10001:10001 var && chmod 775 var
docker compose -f docker-compose.yml -f deploy/docker-compose.prod.yml up -d --build
docker compose -f docker-compose.yml -f deploy/docker-compose.prod.yml ps
```

First build compiles eight Go binaries and the dashboard — several minutes.

## 7. Seed the demo population and run the pipeline

The overlay carries a one-shot `demo` service behind a profile, so the demo
runs *inside* the compose network and resolves `postgres`, `registry` and
`publicapi` by name:

```bash
docker compose -f docker-compose.yml -f deploy/docker-compose.prod.yml \
  --profile demo run --rm demo
```

Do not try to run `cmd/demo` from the host. This overlay deliberately publishes
no port for Postgres or the registry, so a host-side run cannot reach them —
and reopening those ports to seed a demonstration would undo the one security
property this overlay exists to provide.

## 8. Verify

```bash
curl -s localhost/health
curl -s localhost/v1/risk/current | head -c 300
curl -s localhost/v1/model | grep -o '"note":"[^"]*"' | head -4
curl -s localhost/v1/ledger/anchors/verify | grep -o '"status":"[a-z]*"'
```

The last one depends on which overlay you deployed:

- **prod overlay:** `verified`, once the ledger has swept at least one day.
- **prod + smallhost:** `unavailable`, permanently, with the reason
  `this deployment runs ANCHOR_MODE=local, so roots are recorded in the anchors
  table of its own database and there is no independent chain copy to compare
  against`. That is the designed answer, not a broken one — there is no chain
  on that host to read back from. It is never a fabricated match.

Then open the dashboard in a browser at your host address.

### What the prod overlay's rehearsal established

Measured on 2026-09-10 against the production overlay with real generated
secrets — not the development placeholder — before it was ever pointed at a
paid host:

- `up -d --build --wait` starts **twelve containers**: nine report healthy
  (Postgres, the six working services, the registry and the public API), the
  dashboard and Caddy declare no healthcheck and are waited for as running, and
  the one-shot `migrate` applies migrations and exits 0. The fail-closed key
  guard accepts a genuine `PII_KEY_HEX` and refuses the placeholder, which is
  the point. Under the smallhost overlay it is eleven, `anvil` being disabled.
- `--profile demo run --rm demo` seeds and runs the pipeline from inside the
  compose network, reaching `postgres`, `registry` and `publicapi` by name.
- **Caddy is the only process publishing a host port.** Measured with `nc`
  from outside: 80 open; 5432, 8080, 8081, 8082 and 8545 all refused. Postgres,
  the registry, the public API, the dashboard container and the development
  chain are reachable only inside the compose network. That rehearsal had no
  domain attached, so 80 was the only open port; with a domain in
  `SITE_ADDRESS`, 443 is open too and 80 redirects to it — measured against
  <https://climateshield.jarida.io>, which has 80 and 443 open and everything
  else refused.
- Through Caddy on port 80: `/health` returned ok, `/v1/ledger/anchors/verify`
  returned `verified` with the database root and the chain root identical, and
  `/v1/stats` withheld the two counties under ten.

**Confirm the database is not exposed** — this should fail from your laptop:

```bash
nc -vz YOUR_HOST 5432        # expect: refused
```

If it connects, the overlay was not applied. Stop and fix it.

---

## 9. The smallhost overlay: a host that can neither build nor run a chain

[`deploy/docker-compose.smallhost.yml`](docker-compose.smallhost.yml) exists for
a host below the 4 GB floor in section 1 — the live demonstration runs it on a
458 MB droplet. Its own header comment is the authoritative version; this is the
summary.

**It does not build.** Every service runs a prebuilt `:deploy-amd64` image
loaded onto the host with `docker load`. Build them on a workstation for
`linux/amd64` and ship them:

```bash
docker buildx build --platform linux/amd64 --build-arg CMD=<svc> \
  -f deploy/go.Dockerfile -t climateshield-<svc>:deploy-amd64 --load .
docker save climateshield-*:deploy-amd64 | gzip -1 > images.tar.gz
scp images.tar.gz root@HOST: && ssh root@HOST \
  'gunzip -c images.tar.gz | docker load'
```

Build the dashboard image from an already-built `web/dist` rather than running
npm under emulation — the bundle is static assets and identical on every
architecture, so emulating the build only buys you the memory failure.

**It runs no chain.** The foundry image is 585 MB and anvil's own memory is more
than such a box has spare, so `anvil` is disabled and the ledger runs
`ANCHOR_MODE=local`: daily Merkle roots are recorded in the anchors table of
this system's own database and nowhere else.

That is a **real loss of function**, not a configuration detail. The chain
anchor is one of the three things the funding proposal promised, and on a host
running this overlay it is not demonstrated. Nothing lies about it: the anchor
note on `GET /v1/ledger/summary` is computed from the newest anchor row, so it
says no blockchain is written to by this system; `GET /v1/ledger/anchors/verify`
reports `unavailable` with that reason; and the dashboard's History view reports
the same. To demonstrate the pillar, deploy without this overlay on a host with
room for the chain — 2 GB of RAM is a sensible floor, 4 GB if you also want to
build there.

```bash
docker compose -f docker-compose.yml \
               -f deploy/docker-compose.prod.yml \
               -f deploy/docker-compose.smallhost.yml up -d
```

---

## Operating it

```bash
C="docker compose -f docker-compose.yml -f deploy/docker-compose.prod.yml"
$C logs -f publicapi        # follow a service
$C pull && $C up -d --build # update
$C down                     # stop (keeps the volume)
$C down -v                  # stop and DELETE the database
```

## What this deployment is

- **Fictional data only.** Every guardian and child is invented.
- **No SMS is sent.** `NOTIFY_CHANNEL=mock` records what it would send.
- **The public surface is aggregates only**, k≥10 suppressed, enforced by a
  contract test in CI.
- **Postgres, the registry API and the development chain are not reachable from
  the internet.** Caddy is the only public process.
- **Under the prod overlay, the chain the ledger anchors to is a local
  development chain** started by this deployment. Nothing here writes to any
  public network, and no surface calls it public, immutable or decentralised.
- **Under the smallhost overlay there is no chain at all.** Daily roots are
  recorded only in this system's own `anchors` table, which is why the verify
  endpoint reports `unavailable` there and says why.

## Before this could hold real data

Not a checklist for today — a statement of what is missing. From
[NOTES.md](../NOTES.md):

1. **Key management.** `PII_KEY_HEX` sits in a file on the host. Real
   deployments need OpenBao or equivalent, and a rotation procedure.
2. **Ledger key isolation.** Per-child HMAC keys live in a separate schema but
   the same database and role. Production needs a separate role with
   schema-scoped grants.
3. **An erasure endpoint.** `ForgetChild` is a tested library function with no
   way to invoke it. Holding real records without an operable
   right-to-erasure path is not defensible.
4. **Backups**, and a restore you have actually rehearsed.
5. **A demonstrated delivery path.** No SMS has ever been sent by this system,
   so the last hop between an alert and a guardian is unproven. See
   [docs/roadmap.md](../docs/roadmap.md).
