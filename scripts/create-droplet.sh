#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Creates a DigitalOcean droplet and deploys the ClimateShield demonstration
# to it. Run this from your LAPTOP, in a checkout of the ref you want live:
#
#   doctl auth init          # once, you paste your own token
#   ./scripts/create-droplet.sh
#
# It creates a paid resource. The size it defaults to is about $24/month at
# the time of writing; `doctl compute size list` has the current prices. Change
# it with SIZE=, and destroy the droplet with:
#
#   doctl compute droplet delete climateshield-demo
#
# Everything host-side is done by scripts/deploy-droplet.sh, which this script
# uploads and runs over SSH. Your secrets are generated ON the droplet by that
# script and are never printed, never sent anywhere, and never come back here.
set -euo pipefail
cd "$(dirname "$0")/.."

NAME="${NAME:-climateshield-demo}"
# 4 GB because the first build compiles eight Go binaries and bundles the
# dashboard; npm has been seen to die on a 2 GB box. See deploy/README.md.
SIZE="${SIZE:-s-2vcpu-4gb}"
IMAGE="${IMAGE:-ubuntu-24-04-x64}"
REGION="${REGION:-fra1}"
REF="${REF:-$(git rev-parse --abbrev-ref HEAD)}"
REPO="${REPO:-https://github.com/jarida-io/climateshield.git}"

say() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }

# --- Preconditions ----------------------------------------------------------
command -v doctl >/dev/null 2>&1 || { echo "doctl is not installed: brew install doctl" >&2; exit 1; }
if ! doctl account get >/dev/null 2>&1; then
  cat >&2 <<'MSG'
doctl is not authenticated. Run this yourself, so the token stays with you:

    doctl auth init

Then re-run this script.
MSG
  exit 1
fi

# --- SSH key --------------------------------------------------------------
# A droplet with no key on it can only be reached by password, which is the
# single most attacked surface on a public host. Refuse rather than create one.
KEY_IDS="${SSH_KEY_IDS:-$(doctl compute ssh-key list --no-header --format ID | paste -sd, -)}"
if [ -z "$KEY_IDS" ]; then
  cat >&2 <<'MSG'
Your DigitalOcean account has no SSH keys, so the droplet would be
password-only. Add one first:

    doctl compute ssh-key import my-laptop --public-key-file ~/.ssh/id_ed25519.pub

Then re-run this script, or set SSH_KEY_IDS=<id,id> to choose specific keys.
MSG
  exit 1
fi
say "Using SSH key id(s): $KEY_IDS"

# --- Create or reuse --------------------------------------------------------
if doctl compute droplet get "$NAME" >/dev/null 2>&1; then
  say "Droplet '$NAME' already exists — reusing it"
else
  say "Creating droplet '$NAME' ($SIZE, $IMAGE, $REGION)"
  doctl compute droplet create "$NAME" \
    --size "$SIZE" --image "$IMAGE" --region "$REGION" \
    --ssh-keys "$KEY_IDS" --enable-monitoring --wait \
    --format Name,PublicIPv4,Memory,Region
fi

IP="$(doctl compute droplet get "$NAME" --no-header --format PublicIPv4)"
[ -n "$IP" ] || { echo "could not read the droplet's IP" >&2; exit 1; }
say "Droplet IP: $IP"

# --- Wait for SSH -----------------------------------------------------------
say "Waiting for SSH"
for i in $(seq 1 60); do
  if ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new \
         -o ConnectTimeout=5 "root@$IP" true 2>/dev/null; then
    echo "    up after ~$((i * 5))s"
    break
  fi
  sleep 5
  [ "$i" -eq 60 ] && { echo "SSH never came up; check the console" >&2; exit 1; }
done

# --- Deploy -----------------------------------------------------------------
# The host does its own clone so the droplet, not this laptop, is the thing
# that knows how to rebuild itself. REF matters: main is not necessarily the
# ref you want (see deploy/README.md section 2).
say "Deploying ref '$REF' on the droplet"
ssh -o StrictHostKeyChecking=accept-new "root@$IP" \
  "REF='$REF' REPO='$REPO' bash -s" <<'REMOTE'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
command -v git >/dev/null 2>&1 || { apt-get update -qq && apt-get install -y -qq git; }
if [ -d /opt/climateshield/.git ]; then
  cd /opt/climateshield && git fetch --all --quiet && git checkout --quiet "$REF" && git pull --quiet --ff-only
else
  git clone --quiet "$REPO" /opt/climateshield && cd /opt/climateshield && git checkout --quiet "$REF"
fi
cd /opt/climateshield
git log --oneline -1
./scripts/deploy-droplet.sh
REMOTE

say "Deployed. Dashboard: http://$IP/"
cat <<EOF

Check it from here:
  curl -s http://$IP/health
  curl -s http://$IP/v1/ledger/anchors/verify | jq '{status, chainLabel}'

And confirm the database is NOT exposed — this must be refused:
  nc -vz $IP 5432

To destroy it when the demonstration is over:
  doctl compute droplet delete $NAME
EOF
