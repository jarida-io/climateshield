<!-- SPDX-License-Identifier: Apache-2.0 -->

# Contributing to ClimateShield

ClimateShield is an open-source climate-health early warning system for Kenya.
Contributions are welcome across backend, data, frontend and documentation.
Read the non-negotiable rules below first: several come from a funding
agreement rather than from taste, and breaking one fails CI.

## Development setup

You need **Go 1.26** (what `go.mod` and the build image use), **Docker** (the
database and the tests), and **Node 22** (the dashboard only). Nothing else:
`buf`, `sqlc` and the protobuf plugins are pinned as `go.mod` tool
dependencies, and the Makefile fetches a pinned `golangci-lint` into `./bin`.

```bash
git clone https://github.com/jarida-io/climateshield.git
cd climateshield
cp .env.example .env
make up      # full stack; several minutes on a cold Docker cache, ~1 min after
make demo    # end-to-end pipeline against committed fixtures
make verify  # everything CI runs
```

`make verify` must pass before you open a pull request. It runs formatting,
`go vet`, `golangci-lint`, the build, all tests, the coverage gate, `buf lint`,
the contract checks, `tsc --noEmit` and the web build.

## Non-negotiable rules

These fail CI, and most exist because breaking them would breach the funding
agreement:

1. **Dependencies must be open source and free**, and the system must build,
   test and run with **zero credentials**. Excluded by the agreement, approved
   alternative in brackets: TimescaleDB, Redis 7.4+ (Valkey), Mapbox GL v2+
   (MapLibre), Terraform and Vault (OpenTofu, OpenBao), Redpanda, Arbitrum
   Nitro, RapidPro, Weights & Biases server, Codecov, hardcoded Infura or
   Alchemy endpoints, Fiber, GORM. If you think you need one, open an issue
   rather than substituting silently.
2. **No output may imply an action that did not happen.** If a mock adapter is
   active, the output says so (`[mock] would send N alerts`). No fabricated
   benchmark, accuracy or performance figure anywhere, comments and
   documentation included.
3. **No personal data on any public surface**, and no per-child hash. Counts
   derived from people are k≥10 suppressed.
4. **Never log PII.** Use the typed wrappers in `internal/platform/logging`.
5. **Coverage must stay ≥80%** over `./internal/...`, excluding generated code.
6. **Every first-party source file carries**
   `SPDX-License-Identifier: Apache-2.0` — `.go`, `.ts`, `.tsx`, `.proto`,
   `.sql`, `.sol`. `scripts/contract-checks.sh` fails the build if one is
   missing.
7. **Do not delete or rename the contract tests** (`TestContract_PIILeak`,
   `TestContract_KAnonymity`). CI runs them by name.
8. **Risk thresholds live only in `internal/predict/rules.go`.** They are
   published in the funding proposal; changing one requires a proposal
   amendment, not a pull request.

## Coding standards

- Standard Go style: `gofmt`, `go vet` and `golangci-lint` clean.
- **Test-first for pure logic** — thresholds, Merkle trees, canonical
  serialization, template rendering, suppression. A reviewer must be able to
  trust these by reading a test.
- **No test may access the network.** Use committed fixtures and `httptest`;
  database tests use testcontainers via `internal/store/testdb`.
- SQL is hand-written in `internal/store/queries` and compiled by sqlc. Run
  `make generate` after changing a query or the protobuf contract, and commit
  the generated output.
- Keep `cmd/*/main.go` thin — configuration and signal handling only,
  delegating to `internal/<service>.Run`.

## Pull requests

- Use [Conventional Commits](https://www.conventionalcommits.org/):
  `feat(publicapi): …`, `fix(ledger): …`, `docs: …`, `ci: …`.
- Explain **why** in the commit body, not just what changed.
- One logical change per pull request; keep generated-code updates in the same
  commit as the source change that caused them.
- Paste your `make verify` output in the description.
- Update [NOTES.md](NOTES.md) if you change what is real versus stubbed.

## Reporting issues

Use the bug-report template in `.github/ISSUE_TEMPLATE`. For anything with
security or privacy implications — especially a suspected data leak on a public
surface — email **hello@jarida.io** instead of filing a public issue.

Be respectful and constructive. This project handles data about children;
assume every design discussion carries that weight.

## Licence

Contributions are licensed under the [Apache License 2.0](LICENSE).
