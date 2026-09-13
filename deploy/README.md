<!-- SPDX-License-Identifier: Apache-2.0 -->

# Deploying the ClimateShield demo

This deploys a **demonstration carrying fictional data only**. The seed
population in `internal/store/seed` is invented, down to a fake
`+2547000001xx` phone range. Nothing here is fit to hold real records about
real children — see [Before this could hold real data](#before-this-could-hold-real-data).
Run these commands on the host yourself; none of it belongs in a chat window,
an issue or a commit.

## Pick an overlay

| Overlay | Host it is for | What you get |
|---|---|---|
| `deploy/docker-compose.prod.yml` | 4 GB RAM, builds its own images | Everything. The ledger runs `ANCHOR_MODE=evm` against the development chain this stack starts, and `/v1/ledger/anchors/verify` reports `verified`. |
| …plus `deploy/docker-compose.smallhost.yml` | Too small to build or to run `anvil` | No chain. Prebuilt images only, `ANCHOR_MODE=local`, and the verify endpoint reports `unavailable` with its reason — permanently, by configuration. |

4 GB is the floor for the prod overlay because the first build compiles eight
Go binaries and bundles the dashboard; npm has been seen to die on a 2 GB box.
The smallhost overlay's own header comment is authoritative on building images
elsewhere and shipping them; read it before using it.

**The live demo at <https://climateshield.jarida.io> runs the smallhost
overlay** on a 458 MB droplet, so the chain anchor is demonstrated by a local
`make up` and not there.

## Deploy it

From your laptop, if `doctl` is authenticated — creates a paid droplet and
deploys to it:

```bash
doctl auth init                  # once; you paste your own token
./scripts/create-droplet.sh      # defaults: s-2vcpu-4gb, fra1, Ubuntu 24.04
```

Or on a fresh Debian/Ubuntu host, as root:

```bash
git clone https://github.com/jarida-io/climateshield.git
cd climateshield && ./scripts/deploy-droplet.sh
```

`scripts/deploy-droplet.sh` installs Docker, restricts `ufw` to SSH/80/443,
generates the secrets on the host, makes `./var` writable by UID 10001, builds
and starts the prod overlay, seeds the demo inside the compose network, and
verifies. It is idempotent and never overwrites an existing `.env`, so
re-running it after a `git pull` updates in place and keeps the first run's
secrets. Read the script for the detail of any step you want to do by hand.

Three things worth knowing before you run it:

- It generates `PII_KEY_HEX` and omits `PII_ALLOW_DEV_KEY`, so a deployment
  that skips secret generation fails to start rather than encrypting with the
  published placeholder key.
- `chown 10001:10001 var` is not optional. Services run as UID 10001 and the
  mock channel appends to that bind mount; a root-owned `var` makes every
  dispatch fail with `permission denied` while the `alerts` table stays empty.
  This ran undetected for four weeks — Docker Desktop on macOS hides it
  ([NOTES.md](../NOTES.md#three-real-bugs-and-where-each-was-caught)).
- `CLIMATE_SOURCE=fixture` keeps the demo deterministic and offline. Set
  `openmeteo` for live forecasts — free, no key — and risk levels then follow
  real weather rather than the documented scenario.

For the smallhost overlay, load the prebuilt images first, then:

```bash
docker compose -f docker-compose.yml \
               -f deploy/docker-compose.prod.yml \
               -f deploy/docker-compose.smallhost.yml up -d
```

## The live host

<https://climateshield.jarida.io> serves `main` from a 458 MB droplet, ten
containers, TLS from Caddy. Caddy is the only process publishing a host port:
80 and 443 are open, and 5432, 8080, 8081, 8082 and 8545 are refused from
outside. Postgres, the registry, the public API and the dashboard container are
reachable only inside the compose network.

Two things it deliberately does not do, and says so on every surface:

- **No chain.** `ANCHOR_MODE=local`: daily Merkle roots are recorded in the
  `anchors` table of its own database and nowhere else. The anchor note on
  `/v1/ledger/summary` says no blockchain is written to by this system, and
  `/v1/ledger/anchors/verify` reports `unavailable` with that reason. This is a
  real loss of function, not a detail: the chain anchor is one of the three
  pillars the funding proposal promised, and it is not demonstrated there.
- **No message is sent.** `NOTIFY_CHANNEL=mock` records `would_send` and
  transmits nothing; `BRIEFING_GENERATOR=mock` writes the deterministic
  template with no model. See [docs/architecture.md](../docs/architecture.md).

## Verify

```bash
H=https://climateshield.jarida.io    # or localhost for your own deployment
curl -s $H/health
curl -s $H/v1/risk/current | head -c 300
curl -s $H/v1/model | grep -o '"note":"[^"]*"' | head -2
curl -s $H/v1/stats                                   # counties under ten withheld
curl -s $H/v1/ledger/anchors/verify | grep -o '"status":"[a-z]*"'
```

The last line reports `verified` under the prod overlay once the ledger has
swept a day, and `unavailable` under smallhost. `unavailable` is the designed
answer where there is no chain to read back from; it is never a fabricated
match. Then open the dashboard in a browser at the host address.

Finally, confirm the database is not exposed. From your laptop,
`nc -vz YOUR_HOST 5432` must be refused; if it connects, the overlay was not
applied.

## Operating it

```bash
C="docker compose -f docker-compose.yml -f deploy/docker-compose.prod.yml"
$C logs -f publicapi        # follow a service
$C pull && $C up -d --build # update
$C down                     # stop (keeps the volume)
$C down -v                  # stop and DELETE the database
```

## Before this could hold real data

Not a checklist for today — a statement of what is missing. From
[NOTES.md](../NOTES.md):

1. **Key management.** `PII_KEY_HEX` sits in a file on the host. Real
   deployments need OpenBao or equivalent, and a rotation procedure.
2. **Ledger key isolation.** Per-child HMAC keys live in their own schema but
   share the database role. Production needs schema-scoped grants.
3. **An erasure endpoint.** `ForgetChild` is a tested library function with no
   way to invoke it.
4. **Backups**, and a restore you have actually rehearsed.
5. **A demonstrated delivery path.** No message has ever left this system, so
   the last hop to a guardian is unproven —
   see [docs/roadmap.md](../docs/roadmap.md).
