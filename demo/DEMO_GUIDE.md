# Chaos Canary — Demo Guide

A presenter runbook for showing this project to an audience.
Total runtime: **~15 minutes** (Act 1 alone works in 5 minutes and needs no Sauce account).

---

## The story you're telling

> "Mobile apps don't fail on the device — they fail on the network. But how do you
> *test* that on a real phone? This project routes all traffic from a real iPhone in
> the Sauce Labs cloud back through a local proxy that sabotages it on purpose:
> errors, latency, flakiness. Watch the app — and the tests — react to chaos
> in real time."

Three beats:

1. **Chaos is programmable infrastructure** — four side-by-side proxies, each with a personality.
2. **It works against real devices in the cloud** — Sauce Connect tunnels pull device traffic back to your machine.
3. **Tests assert resilient behavior** — the same XCUITests expect *different* outcomes per chaos mode.

Audience take-away: chaos testing isn't a Netflix-scale luxury; it's a docker-compose file and four environment variables.

---

## Pre-demo checklist (do this 30–60 min before presenting)

| # | Check | Command |
|---|-------|---------|
| 1 | Docker Desktop running | `docker info` |
| 2 | Docker image pre-built (first build is slow — never build live) | `docker compose build` |
| 3 | `.env` exists with real Sauce credentials | `cp .env.example .env` and edit |
| 4 | App + test runner pre-built (**no Apple ID needed** — the build is unsigned and Sauce Labs re-signs on-device) | `demo/demo_sauce.sh normal --rebuild` once, or see README |
| 5 | `saucectl` installed & authenticated | `saucectl --version` |
| 6 | Sauce Labs dashboard open in a browser tab | app.saucelabs.com |
| 7 | Vendetta against flaky Wi-Fi | rehearse Act 1 as fallback (needs nothing but Docker) |

**Golden rule:** everything that *can* be pre-built before the demo, is.

---

## Act 0 — Architecture (2 min, slides/terminal only)

Draw the loop on the whiteboard or open `chaos-testing-architecture.svg`:

```
Real iPhone (Sauce cloud)  ──►  Sauce Connect tunnel  ──►  mitmproxy  ──►  Internet
        runs XCUITests           (4 named tunnels)        (injects chaos)
```

Then flash these two files — they're the whole idea in 60 lines:

- `docker-compose.yml` — "four parallel chaos environments, one `up` command"
- `chaos_programmable.py` — "the entire chaos engine is this one Python file"

**Talking point:** `CHAOS_*` environment variables are the only control surface.
Same image, same script — the *compose file* decides each proxy's personality.

---

## Act 1 — Local quick-fire: the proxies by themselves (5 min)

*No Sauce account, no Xcode build, no cloud — just Docker and curl.
This is also your emergency fallback if the cloud betrays you.*

```bash
demo/demo_local.sh
```

What it does, live:

| Proxy | Port | Chaos personality | What the audience sees via curl |
|-------|------|-------------------|---------------------------------|
| normal | 8086 | none | `HTTP 200` instantly |
| failure | 8082 | force 503 | `HTTP 503` |
| latency | 8084 | +5 s delay | `HTTP 200` in ~5 s — *visibly slow* |
| random | 8088 | 25% failures, dice-rolled | 10 requests, mixed 200/404/500/502/503 |

The script ends by opening all four **mitmweb UIs** (ports 8081/8083/8085/8087).
Click a flow, show its request/response — this is the "flight recorder" moment.

**Narration tip for the random act:** "28 lines of Python just made this endpoint
as reliable as production. Your staging environment will never be this honest."

---

## Act 2 — Full stack: real device meets chaos (8–10 min)

*Requires Sauce credentials and the pre-built app (see checklist).*

```bash
demo/demo_sauce.sh all        # or a single mode: normal / failure / latency / random
```

The script brings up proxies **and** tunnels, waits for each tunnel to report
`Sauce Connect is up`, then hands off to `run_chaos_test.sh`.

While tests run, narrate across **three screens at once**:

1. **Sauce Labs dashboard** — a real iPhone launches ChaosCanary and taps the button.
2. **mitmweb UI** — the device's request appears *in your local proxy*, mid-flight.
3. **Terminal** — saucectl streams results.

What each run asserts (great moment to open the matching test file):

| Mode | Test | Asserts |
|------|------|---------|
| normal | `testHappyPathNetworkRequest` | `Success: 200` appears |
| failure | `testApiFailureChaosExperiment` | `Failure: 503` appears — error handling works |
| latency | `testApiLatencyChaosExperiment` | request succeeds *and* takes > 4 s |

**Punchline:** the failure-mode test *passing* means the app **handled** the 503
gracefully. You're not testing that the network works — you're testing that the
app survives when it doesn't.

---

## Act 3 — Q&A parking lot

Leave the stack running (`docker compose down` only after questions).
Impress-the-architect answers:

- *"Can I target a specific endpoint?"* — `CHAOS_TARGET_API`; omit it to hit everything.
- *"Can I change chaos rates without code changes?"* — they're env vars in `docker-compose.yml`.
- *"What about Android / Espresso?"* — same tunnel + proxy pattern; saucectl supports it identically.
- *"CI integration?"* — `run_chaos_test.sh all` is one command; gates on saucectl exit codes.

---

## Troubleshooting (keep this open on a second screen)

| Symptom | Fix |
|---------|-----|
| `Cannot connect to the Docker daemon` | Start Docker Desktop |
| Tunnel stuck before "Sauce Connect is up" | `docker compose logs tunnel-<mode>` — usually bad credentials or stale tunnel name; `docker compose down` and retry |
| saucectl: app files missing | run `demo/demo_sauce.sh <mode> --rebuild` once |
| xcodebuild: "No Accounts / No profiles" | You're building with signing enabled — the scripts pass `CODE_SIGNING_ALLOWED=NO` on purpose; Sauce re-signs on-device. Or add your Apple ID in Xcode → Settings → Accounts and sign for real |
| Random mode shows all 200s | dice were kind (0.75¹⁰ ≈ 5.6%); re-run — or lower the odds live: edit `CHAOS_FAILURE_RATE`, `docker compose up -d proxy-random-failure` |
| Nothing intercepting in mitmweb | confirm you're looking at the right UI port (compose file is the source of truth) |

## Reset / cleanup

```bash
demo/demo_local.sh --cleanup   # tear down just the proxy act
docker compose down            # full teardown: proxies + tunnels + network
```

---

## File map for the demo

| File | Role in the demo |
|------|------------------|
| `demo/demo_local.sh` | Act 1: narrated curl-through-the-proxies demo |
| `demo/demo_sauce.sh` | Act 2: full Sauce Labs stack wrapper |
| `docker-compose.yml` | the four chaos environments |
| `chaos_programmable.py` | the chaos engine |
| `run_chaos_test.sh` | underlying saucectl runner |
| `ChaosCanaryUITests/InteractiveUITests.swift` | the assertions that make chaos *testable* |
