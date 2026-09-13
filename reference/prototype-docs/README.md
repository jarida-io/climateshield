# Prototype artefacts — superseded, kept for provenance

These diagrams and wireframes describe the **original Python/PHP prototype**,
not the system in this repository. They are kept because they show where the
project started and what was promised. They are **not** documentation of
anything that runs today — for that, see
[`docs/architecture.md`](../../docs/architecture.md).

Read them with these corrections in mind.

| In the prototype docs | The correction |
|---|---|
| `diagrams/risk-scoring.md` says the thresholds are "calibrated against historical KEPI surveillance reports". | No such calibration exists, and no surveillance data has ever been in this repository. The four cutoffs are the ones published in the funding proposal. Checked against a decade of reanalysis weather, **two of them are unreachable in the monitored counties** — see [`docs/threshold-validation.md`](../../docs/threshold-validation.md). |
| `diagrams/data-flow.md` and `diagrams/parent-alert-journey.md` show messages going out through Africa's Talking, with a "risk score → SMS dispatched: < 8 seconds (sandbox)" figure. | The prototype printed `"SMS sent to under-vaccinated families"` while sending nothing. The current default channel is a mock that records `would_send`, never `sent`, and every surface says so. No latency figure of any kind is claimed anywhere in the current system. |
| The example SMS names the disease ("High cholera risk") beside a named child. | The current templates say "outbreak risk" instead: a named disease next to a named child on a plaintext SMS is diagnosis-adjacent. A test asserts that no disease name can appear in a message body. |
| `diagrams/system-architecture.md` shows MySQL, PHP, Apache, session auth and an "ML Predictor — outbreak probability". | The stack is now Go services, PostgreSQL/PostGIS, ConnectRPC and a React dashboard. Nothing in this repository estimates an outbreak probability, and the ONNX predictor is a stub that fails startup rather than falling back silently. |
| `wireframes/` shows a guardian login, a child schedule screen and a USSD flow. | None was built. The current dashboard is a public, read-only, aggregate-only surface with no guardian login and no per-child screen, because per-child data must not appear on a public surface at all. |

The one thing here that remains canonical is the *shape* of the demo scenario —
a Kisumu long-rains window — which now lives as committed fixtures under
`testdata/golden/`.
