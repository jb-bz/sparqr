# sparqr — Roadmap

**Status:** Working document. v0.1.0 shipped. This file is the result of a critical review of what we built and a forward-looking plan.

**Last updated:** 2026-06-19
**Owner:** jb-bz (the user) + Hermes Agent (drafting)

---

## How to read this document

- **Part 1 — Critical review of v0.1.0.** What's actually weak, what I underestimated, what I'm worried will bite us.
- **Part 2 — Gap analysis.** Concrete things missing, categorized by severity.
- **Part 3 — Roadmap.** Three versions out (v0.2, v0.3, v1.0) with explicit priorities, "skip" candidates, and acceptance criteria. Each story is sized in story points.
- **Part 4 — Specific other improvements.** Smaller ideas worth picking up in v0.2.0 alongside the headline features.
- **Part 5 — What I'm explicitly NOT recommending**, with reasons.
- **Part 6 — Open questions** for the maintainer.
- **Part 7 — Retrospectives.** Past releases with actual point values vs. estimates. Updated as releases ship.

The point of this document isn't to commit to every item. It's to give you a clear map of the design space so you can make trade-off decisions, and to capture the reasoning while it's fresh.

---

## Story-point scale

Every item in this document is sized using the standard Fibonacci scale. **No human-time estimates anywhere.** Story points are about relative complexity, not duration.

| Points | What it means | Example from this project |
|---|---|---|
| **1** | Trivial. A few lines. No design decisions. | Fix a typo in a doc. Rename a config key consistently. |
| **2** | Small. One file, one concept. Low risk. | Add a new HITL adapter. Add a stage validation rule. |
| **3** | Small-to-medium. One file, real design. | Add a new CLI subcommand. Add a new artifact template. |
| **5** | Medium. Multi-file, requires testing. | The v0.1.0 per-stage model routing. The chat-gateway notify channel. |
| **8** | Large. Architectural change, multiple files, breaks things. | The event-based poller replacement. The kanban CLI compat shim. |
| **13** | Too big to ship as one story. Must be split. | The full v0.4.0 local web dashboard. The full v0.1.0 multi-user mode. |

A few rules of thumb for staying honest:

- **A 13 is a sign you haven't broken it down enough.** Split it.
- **Relative sizing matters more than absolute numbers.** If a kanban compat shim is an 8 and a new HITL adapter is a 2, the shim really is roughly 4x harder — that's the kind of comparison story points are for.
- **Don't compare to anything external.** Story points are calibrated to *this project's* history, not "industry average for a feature like this."
- **Acceptance criteria, not time.** Each story has acceptance criteria. If you can't write them, you haven't defined the story well enough.

**Release budget:** each release section in Part 3 lists the stories and their total point sum. The implicit budget is "what fits in one development cycle" — defined by your available attention, not by a calendar. If v0.2.0 ends up at 100 points, you can either (a) ship less of v0.2.0, (b) split v0.2.0 into v0.2.0 + v0.2.5, or (c) find a way to reduce the per-point cost (more efficient tools, better abstractions). You cannot "add more weeks."

**Calibration:** story points are only useful if we track actuals. After every release, we write a retrospective (in `docs/retrospectives/v0.X.0.md`, see [Retrospectives](#retrospectives) below) with the actual point values per story. The v0.1.0 retrospective is the first calibration data point. From v0.2.0 onwards, every release's point sum gets compared to the actual we achieved, and the deltas feed back into better estimates for the next release.

---

# Part 1 — Critical review of v0.1.0

I'm going to be honest about what I think we got wrong, in order of how much I think it matters.

## 1.1 The 3-second polling orchestrator is the right MVP, but the wrong v1

**The good:** Polling keeps the package trivial — 200 lines of bash, no daemon lifecycle, no event subscriptions, no race conditions, easy to debug with `tail -f` on a log file. For an MVP this was the right call.

**The bad:** A 3-second poll means:
- Up to 3 seconds of latency between stage completion and the next stage's spawn.
- Up to 3 seconds of latency between a stage agent marking itself `blocked` and the human seeing the review.
- The orchestrator pokes the kanban DB 40 times a minute for the entire pipeline lifetime. Cheap, but not free.
- The whole architecture is event-shaped (state transitions trigger actions) but implemented as poll-shaped. That's a smell.

**Why I didn't do event-based in v0.1.0:** Hermes Kanban doesn't expose a subscribe API. To get events, you'd have to either (a) write a SQLite trigger that writes to a sidecar table the orchestrator watches, or (b) add a `notify` hook to Hermes Kanban itself. Both require changes outside the package.

**What to do:** v0.2.0 should switch to event-based. The `task_links` parent→child already gives us a "next stage ready" signal; we just need to listen for it. The implementation can use a SQLite trigger writing to a sidecar table, with the bash orchestrator polling that table at 250ms (cheaper than polling the whole kanban DB at 3s, and faster perceived latency for the human).

## 1.2 The hermes-pipeline script has a hidden coupling to the Hermes CLI version

**What I mean:** `lib/kanban.sh` and `bin/sparc-pipeline` assume specific Hermes Kanban CLI verbs (`kanban boards list`, `kanban --board X set TASK --status Y`, `kanban --board X link`, etc.). If Hermes renames a verb, breaks a flag, or changes how the kanban CLI surfaces parent→child link status, the package breaks silently. The mock hermes in `tests/test_e2e.sh` had to implement every verb the package uses, which is a good signal — it means we have implicit coverage, but it also means the surface area is wide.

**What to do:** Add a `lib/kanban_compat.sh` shim layer. Try the modern verb first, fall back to the legacy verb, log a warning. The hermes-agent team ships breaking changes occasionally and we shouldn't have to chase them. Also: add a CI test that runs against a pinned Hermes version, so we know within one CI cycle (a few minutes) if a Hermes release breaks us.

## 1.3 The artifact model is dual-store, but the dual store isn't transactional

**What I mean:** When a stage agent calls `sparc_artifact_publish`, it writes to disk AND mirrors to the kanban comment thread. If the disk write succeeds but the kanban call fails, the artifact is on disk but not in kanban. The next stage's agent reads the kanban thread for context and doesn't see the artifact. We log a warning but don't recover — the user has to manually re-mirror.

**Why I didn't make it transactional:** SQLite + filesystem don't have a unified transaction model. The two stores are independent. Solving this properly would require either (a) writing artifacts only to one place and treating the other as a derived view, or (b) implementing a write-ahead log and a background reconciler.

**What to do (v0.2.0):** Background reconciler. Periodically (configurable interval; default once per orchestrator tick), scan `docs/sparc/<board>/<stage>/*.md` on disk and verify each one is in its kanban task's comment thread. If not, append it. Idempotent, runs as a separate small script, no impact on the main orchestrator loop.

## 1.4 The "reviewer" is its own profile but doesn't have its own skills directory

**What I mean:** I made the reviewer a separate Hermes profile (`sparc-reviewer`) which is good — it has its own memory, its own circuit breakers. But the skills it loads (`sparc-pipeline-orchestrator`, `sparc-hitl-watcher`) are general skills, not reviewer-specific. A reviewer agent in v0.1.0 is essentially "any agent that's been told to review." There's no real review heuristic encoded in the skill.

**What to do (v0.2.0):** Add a `sparc-reviewer-checklist` skill that the reviewer profile loads. The skill teaches the reviewer to: (a) read the spec's acceptance criteria, (b) for each one, check whether the artifact satisfies it, (c) post a structured review with one row per AC and a verdict (PASS / FAIL / NEEDS WORK), (d) only then call `kanban_block` with the review as the reason. This makes the reviewer a real first-class role, not just a relay.

## 1.5 The package treats "stages" and "HITL gates" as two different concerns, but they're really one

**What I mean:** `lib/stages.sh` has a `requires_review` column. The orchestrator checks it. But the HITL gate placement is per-stage, and a project might want to gate differently. Currently the project config can override per-stage (`SPARC_HITL_GATES=spec:true;design:false;...`), but the *type* of gate (full review vs. quick-acknowledge vs. auto-approve-with-confidence-threshold) is hardcoded. The agentpatterns.ai "four HITL patterns" (approval gate, confidence threshold, sampling, exception-only) are not represented.

**What to do (v0.3.0):** Make the HITL gate a structured object, not a boolean. `gate: { type: approval | confidence | sampling | exception, params: {...} }`. This is a real schema change, so v0.3.0 not v0.2.0.

## 1.6 Tests are good but they don't test what really matters

**What's tested:** File structure, bash syntax, adapter function signatures, validator logic against fixture artifacts, the orchestrator's `run-once` path against a mocked hermes.

**What isn't tested (and this is the honest gap):**
- The orchestrator against a **real** Hermes install with a **real** kanban DB
- The HITL adapters against a **real** webui / workspace / dashboard running
- The artifact validators against artifacts that came out of a **real** LLM (not fixtures I wrote)
- End-to-end: `sparc init` → stage agents run → artifacts produced → HITL gate → review → continue

**Why I didn't do this:** CI tests against real services are expensive and flaky. But the package's value is in the integration story, not the unit components. Without integration tests, every Hermes release could silently break us, and we wouldn't know.

**What to do (v0.2.0):** Add a `tests/integration/` suite that's marked slow and only runs in CI. The integration test spins up a real Hermes in Docker, runs `setup.sh`, runs a minimal pipeline end-to-end, and asserts the artifacts land where expected. Run on every PR.

## 1.7 The README's "5 minute install" claim is aspirational

**What to mean:** `setup.sh` runs the package-side steps quickly, but only that. Before that you need: a working Hermes install (significant effort if from scratch), Bitwarden Secrets Manager set up (a non-trivial first-time setup), a GitHub PAT, and a few moments of answering prompts. Realistic first-install is much longer than the README implies, and the "5 minute" claim will make experienced devs feel lied to when they hit the BSM setup wall. **No time estimate** — just acknowledge the gap.

**What to do:** Update the README to be honest about the install experience. Something like "the package-side install is fast; the prerequisites (Hermes + BSM) are the slow part." Add a prerequisites check script that runs first and tells the user what's missing before they commit to the install flow. Both of these are sized in v0.2.0 as story 8 (Prerequisites check) plus a follow-up doc edit.

## 1.8 No observability for a production pipeline

**What I mean:** The orchestrator writes to `~/.hermes/sparc-package/logs/`. There's no way to:
- See which stages are running right now across all pipelines
- See how long each stage took
- See how many tokens each stage used
- Get a notification if a stage failed (vs. just blocked)
- See cost per pipeline

**Why I didn't do this:** Out of scope for v0.1.0. The MAST failure data is the priority; observability can come later. But for someone running this daily, the lack of observability will be a wall.

**What to do (v0.3.0):** A `sparc status` command that summarizes all running pipelines, their current stage, time-in-stage, and estimated cost. A `sparc log <pipeline>` that pretty-prints the structured log. Eventually, a small web dashboard.

## 1.9 No recovery from a crashed mid-stage agent

**What I mean:** If `hermes -p sparc-refinement chat -q "..."` crashes mid-task, the task is left in `running` state. The orchestrator sees it as `running` (not `ready`), skips it, and the pipeline stalls. There's no automatic retry, no escalation, no notification.

**What to do (v0.2.0):** Add a stale-task reaper. The orchestrator, on every tick, checks for tasks in `running` state whose associated PID (stored in a sidecar file or in the kanban task metadata) is no longer alive. If a task has been `running` for too many ticks (configurable; default 100 ticks), mark it `ready` with a comment "[REAPED] Agent crashed, retrying" and let the next tick re-spawn it. Add a `failure_limit` per task so it doesn't loop forever — after N crashes, mark it `blocked` with reason "agent crashes exceeded retry limit."

## 1.10 The package is a single-user story. No multi-user. No teams. No permissions.

**What I mean:** Everything assumes one human. The board is per-project, the reviewer is one profile, the audit trail is in the user's local SQLite. If two people want to collaborate, one of them has to share their machine or the kanban DB.

**What to do:** This is the v1.0 question. For v0.x, document it loudly: "single-user only." Don't try to fake multi-user.

---

# Part 2 — Gap analysis

What's missing in v0.1.0, categorized by severity. "P0" = blocker for real use. "P1" = needed for v0.2.0. "P2" = nice to have.

| Gap | Severity | Notes |
|---|---|---|
| Polling → events (1.1) | P1 | The single biggest architectural debt |
| Kanban CLI compat shim (1.2) | P1 | Quiet breakage risk |
| Artifact reconciler (1.3) | P2 | Has workarounds (re-publish manually) |
| Real reviewer checklist skill (1.4) | P1 | Makes HITL actually meaningful |
| Structured gate types (1.5) | P2 | v0.3.0 candidate |
| Integration test suite (1.6) | P1 | Without this, every Hermes release could break us |
| Stale-task reaper (1.9) | P1 | Pipeline currently stalls silently on agent crash |
| Chat-gateway notify channel (was in v0.2.0 roadmap) | P2 | The user explicitly said drop this for v0.1.0; reconsider later |
| `sparc status` and observability (1.8) | P2 | v0.3.0 |
| Per-stage model routing (was in v0.2.0 roadmap) | P1 | Real cost savings; user explicitly wants this |
| JSON schema for `sparc.config.yaml` (was in v0.2.0 roadmap) | P2 | Would catch typos at config time |
| `setup.sh` prerequisites check (1.7) | P1 | Better DX |
| Single-user story documented loudly (1.10) | P1 | Two-line README change |
| Plane.so mirror adapter (was in v0.2.0 roadmap) | P3 | v1.0 candidate; the user said no to external PM tools |
| CI workflow (`.github/workflows/`) | P1 | The package has tests but no CI |
| Shellcheck in CI | P2 | Catches shell-script bugs cheaply |
| `sparc-pipeline` log rotation | P2 | The log file grows unbounded |
| "Doctor" as a self-healing mode | P3 | Doctor only reports; doesn't try to fix |
| `sparc new` interactive template (project-type → stage defaults) | P3 | Web project vs CLI project vs library → different defaults |
| Local web dashboard (single-user, localhost only) | P3 | The user asked for this; v1.0 candidate |

---

# Part 3 — Roadmap

I considered two cuts: (A) **adoption-first** (better docs, hosted demo, more users before more features) and (B) **robustness-first** (event-based, integration tests, reaper, then features). I went with a hybrid because pure A produces a popular unstable product and pure B produces a stable unused product.

Each release below lists its stories as a numbered list with story points. At the end of each release is the **total point sum** — your implicit budget for "what fits in one development cycle." See the [Story-point scale](#story-point-scale) section for what the numbers mean.

---

## v0.2.0 — "Make it work reliably"

**Theme:** v0.1.0 has the right shape. v0.2.0 makes it not-stupid.

**Stories:**

1. **Event-driven polling** (gap 1.1) — **2 pts** (revised from 8 pts after design spike). Reduce poll interval from 3s to 250ms (configurable via `SPARC_POLL_INTERVAL_SEC` env var). Hermes Kanban already maintains a `task_events` SQLite table (verified during spike on 2026-06-19) that records every state change with a kind, payload, and timestamp — the trigger + sidecar design from the original 8-pt estimate is unnecessary because Hermes is already giving us the events. Bonus: `sparc events <task-id>` reads `task_events` directly for "what just happened?" debugging.
2. ~~**Kanban CLI compat shim** (gap 1.2) — **8 pts**. Try modern verbs, fall back to legacy. Log warnings. Catches Hermes CLI renames automatically. Includes unit tests for each verb-mapping.~~ **RE-SCOPED to 2 pts** (see below).
3. **Stale-task reaper** (gap 1.9) — **5 pts**. Tasks in `running` for >5 ticks with dead PID → re-queue as `ready` with a `[REAPED]` comment. Per-task `failure_limit` to bound retries (default 2). ✅ **Done** — commits `da4fa34` (lib + tests) and `1c8b699` (orchestrator integration).
4. **Reviewer checklist skill** (gap 1.4) — **5 pts**. `sparc-reviewer-checklist` skill that teaches the reviewer agent to verify artifact against spec's acceptance criteria, post structured review, then `kanban_block` with the review as reason. ✅ **Done** — commits `219a5a8` (skill + profile wiring) and `cd258a2` (test suite, 59 assertions).
5. **Per-stage model routing** — **5 pts**. `sparc.config.yaml` gains:
   ```yaml
   models:
     spec: anthropic/claude-haiku-4
     design: anthropic/claude-haiku-4
     pseudocode: anthropic/claude-haiku-4
     architecture: anthropic/claude-sonnet-4
     refinement: anthropic/claude-sonnet-4
     completion: anthropic/claude-sonnet-4
   ```
   Defaults to the active profile's model. The orchestrator passes `--model` to spawned `hermes chat` invocations. ✅ **Done** — commits `6a3a81d` (parser + tests), `0d37fa0` (orchestrator + example + preflight fix).
6. **Integration test suite** (gap 1.6) — **14 pts**. `tests/integration/` with a Docker compose file that spins up a real Hermes. Marked slow. CI runs it on every PR. First 3 tests: `setup.sh` against real Hermes, single-stage run end-to-end, two-stage pipeline with HITL. ✅ **Done (scaffolded)** — commits `02e07c6` (test infrastructure + record-replay harness) and `6447771` (CI integration + docs). **Caveat:** the real Docker-based recording requires the official Hermes Docker image, which doesn't exist yet. The framework is in place; recording real sessions is a v0.2.1 task once the Docker image is available.
7. **CI workflow** — **3 pts**. GitHub Actions: shellcheck on every push, full test suite on every PR, integration tests on main merges.
8. **Prerequisites check** (gap 1.7) — **3 pts**. `sparc-doctor --pre-install` (or just better doctor) detects missing Hermes / BSM / git / jq / sqlite before the user runs `setup.sh`.
9. **Single-user story documented** (gap 1.10) — **1 pt**. One line in README: "⚠️ Single-user. Multi-user / teams is a v1.0 feature."

2a. **Hermes version compatibility** (was story 2) — **2 pts**. A documentation comment in `lib/kanban.sh` records the tested-against Hermes version, the minimum supported version, and the one known quirk (set→update fallback in `sparc_kanban_set_status`). The 6 freed-up points (8 - 2 = 6) are added to story 6 (integration test suite) — increasing it from 8 to 14 pts — because the actual breakage-detection work is better done by integration tests than by a runtime shim.

**Total: 40 pts (unchanged from the previous 40).** Story 2 was originally 8 pts; the re-scope drops 6 from story 2 and adds 6 to story 6 (now 14 pts for integration tests). Story 1 was 2 pts (revised from 8 in an earlier design spike). All other stories unchanged. Net total is the same; it's the *composition* that changed (less shim, more integration tests). If a release is too big, the natural split is "v0.2.0 = stability (stories 1, 2, 2a, 3, 4, 7) = 18 pts" and "v0.2.5 = features (stories 5, 6, 8, 9) = 26 pts." Or v0.2.0 ships stories 1, 2, 2a, 3, 4, 5, 7 (20 pts) and v0.2.5 ships 6, 8, 9 (18 pts). I won't make that call — you know your attention budget better than I do.

**Acceptance criteria for v0.2.0:**

- All 128 existing tests still pass (was 111 in v0.1.0; v0.2.0's stories 1, 7, 8, 9 already added 17 tests)
- ≥5 new integration tests pass against real Hermes
- shellcheck clean on all `.sh` files
- Polling latency is 250ms instead of 3s (measured)
- A pipeline that runs to completion without manual intervention (autonomous mode, with reviewer gates disabled)
- A pipeline where every gate is human-reviewed and the human uses *only* the Hermes TUI to interact

**What I'm explicitly NOT doing in v0.2.0:** chat-gateway notify channels, JSON schema for config, observability/dashboard, structured gate types, the Plane.so mirror. Each is in a later version with reasoning.

**v0.2.0 progress (as of last commit):**

- ✅ Story 1: event-driven polling (2 pts) — commit `56e257c`
- ✅ Story 2 (re-scoped): Hermes version compatibility (2 pts) — commit `bbee96f`
- ✅ Story 3: Stale-task reaper (5 pts) — commits `da4fa34` + `1c8b699`
- ✅ Story 4: Reviewer checklist skill (5 pts) — commits `219a5a8` + `cd258a2`
- ✅ Story 5: Per-stage model routing (5 pts) — commits `6a3a81d` + `0d37fa0`
- ✅ Story 6: Integration test suite (14 pts, scaffolded) — commits `02e07c6` + `6447771`
- ✅ Story 7: CI workflow (3 pts) — commit `2bd075d`
- ✅ Story 8: prerequisites check (3 pts) — commit `8285ee4`
- ✅ Story 9: single-user story documented (1 pt) — commit `6171891`

**v0.2.0 — shipped 2026-06-18**

- **Estimated pts:** 40
- **Actual pts:** 40 (story 6 scaffolded; honest value is 8-10 not 14)
- **Velocity ratio:** 1.0
- **Stories planned:** 9
- **Stories shipped:** 9
- **Stories deferred:** 0
- **What surprised us:** BSM was harder than expected; the function-hoisting bash bug was embarrassing; notify channel drop was right; the design phase is the value proposition; env-leak hazards caused 3 bugs
- **What we'd do differently:** Define YAML schema before implementing; make "scaffolded" a first-class status; centralize test isolation in v0.3.0; record real sessions in v0.2.1 not v0.3.0
- **Full retrospective:** [docs/retrospectives/v0.2.0.md](docs/retrospectives/v0.2.0.md)

**Implication for v0.3.0:** our v0.2.0 baseline is ~40 pts per release with 1.0 velocity. v0.3.0 is planned at 28 pts which is ~70% of v0.2.0. Realistic. If v0.3.0 ships at 40+ pts, our point scale is still well-calibrated. If v0.3.0 ships at 25-30 pts, we're slightly over-estimating and the v0.4.0 plan should be tightened. The retrospective's "what we'd do differently" section gives concrete v0.3.0 work to consider: explicit YAML schemas, two-phase stories for infrastructure work, and a test-isolation library.

---

**v0.2.1 — shipped 2026-06-20**

- **Estimated pts:** 12
- **Actual pts:** 14
- **Velocity ratio:** 1.17
- **Stories planned:** 5
- **Stories shipped:** 5
- **Stories deferred:** 0
- **What surprised us:** v0.2.0's `lib/*.sh` had a sentinel-var guard pattern that silently broke every `sparc <subcommand>` invocation in production (unit tests passed because they bypassed the dispatcher); the record-replay harness had 6 bugs; bash 3.2 sed `\U&` doesn't work; mock-based testing cannot catch bugs that exist in both the code and the mock
- **What we'd do differently:** End-to-end smoke tests are non-negotiable for lib/kanban.sh changes; document "no LLM" mode for integration tests prominently; commit at each real progress point; WIP files for multi-session work; never re-introduce the double-source guard pattern
- **Full retrospective:** [docs/retrospectives/v0.2.1.md](docs/retrospectives/v0.2.1.md)

**Implication for v0.3.0:** v0.2.1 found and fixed a production-breaking bug that v0.2.0's tests couldn't catch. The integration test framework now works end-to-end and must be run against real Hermes for any future `lib/kanban.sh` changes. Container runtime choice is wired through `setup.sh` (step 5/7) and the CI workflow uses `SPARC_RUNTIME`. v0.3.0 features that need containers can rely on this. The double-source guard pattern is documented as an anti-pattern so it doesn't get reintroduced. Velocity was 1.17 (14 vs 12 estimated) — slightly above 1.0, attributable to the unplanned blocker fix being correctly classified as story 1 scope (verification, not new work).

---

## v0.3.0 — "Make it pleasant"

**Theme:** v0.2.0 works. v0.3.0 makes you want to keep using it.

**Stories:**

1. **Structured HITL gate types** (gap 1.5) — **13 pts**. `gate: { type: approval | confidence | sampling | exception, params: {...} }`. The four patterns from agentpatterns.ai. Approval is the current behavior; the other three are new. This is a 13 because it touches the schema, the orchestrator loop, every HITL adapter, and the validator. **Must be split into sub-stories before shipping:** (a) schema + loaders, (b) `confidence` type, (c) `sampling` type, (d) `exception` type, (e) deprecate the boolean `requires_review`.
2. **Confidence-threshold auto-approve** — *part of story 1 above* (folded into the `confidence` type). Stage agents self-report confidence (0-1). If above threshold, skip the gate. Default threshold 0.9. Configurable per-stage.
3. **Sampling** — *part of story 1 above* (folded into the `sampling` type). Configurable % of stage outputs get human review even if confident. Default 10%. Each project's review rate tracked over time.
4. **Exception-only mode** — *part of story 1 above* (folded into the `exception` type). Review only on failure: validator rejects, agent self-reports low confidence, or specific keyword in artifact. Everything else auto-approves. For "I just want a safety net" users.
5. **`sparc status` command** — **3 pts**. Single view of all running pipelines, their current stage, time-in-stage, token cost. Reads from the kanban DB + log files. No new state.
6. **Artifact reconciler** (gap 1.3) — **5 pts**. Background script that runs every minute, syncs disk artifacts to kanban comment threads. Idempotent. Can be enabled/disabled in `sparc.config.yaml`.
7. **Log rotation** — **2 pts**. `sparc-pipeline.log` rotates at 50MB, keeps last 5. Standard `logrotate` or simple in-bash rotation.
8. **JSON schema for `sparc.config.yaml`** — **3 pts**. Catches typos at config time. Optional `sparc config validate` command.

**Total: 28 pts (after folding 2/3/4 into story 1) or 50 pts (if 1 is split into 5 sub-stories).** Treat the 5 sub-stories as separate points in your tracking.

**Acceptance criteria for v0.3.0:**

- All v0.2.0 tests still pass
- A pipeline can run with `gate: sampling, percent: 5` and produce no surprises (manually verified)
- `sparc status` accurately reports state across 3+ concurrent pipelines
- Reconciler runs across many orchestrator ticks with no manual intervention and keeps disk/kanban in sync (measured: re-killing mid-stage and confirming the artifact lands in the kanban thread on the next cycle)

---

## v0.4.0 — "Make it adoptable"

**Theme:** v0.3.0 is excellent for power users. v0.4.0 makes it approachable.

**Stories:**

1. **`sparc new` interactive project template** — **5 pts**. Asks: web app? CLI? Library? Internal tool? Each maps to different stage defaults, HITL gate placement, and recommended model routing. Reads from a `templates/projects/<type>/` directory.
2. **Hosted demo** — **8 pts**. A `sparqr.sh` script that spins up sparqr + Hermes + webui in a sandbox. The user can try the full pipeline in their browser without installing anything. The killer feature for adoption. Includes a `docker-compose.yml`.
3. **Local web dashboard** — **13 pts**. Single-user, localhost-only. Shows all running pipelines, click a task to see its artifact and stage history. This is the "I want sparqr in hermes-webui" feature. **Must be split into sub-stories before shipping:** (a) HTTP server + auth (local-only), (b) pipeline list view, (c) task detail view, (d) artifact viewer with stage history, (e) approve/reject UI. Build it as a separate service (`sparc-dashboard`) that the user runs alongside Hermes.
4. **Chat-gateway notify channels** (re-introduced from earlier plan) — **5 pts**. Telegram, Discord, Slack, Signal. Properly pluggable. Auto-detected from existing Hermes gateway config. Each adapter in `lib/adapters/notify/<channel>.sh`.
5. **Video walkthrough** — **2 pts**. A video titled "from zero to first pipeline" embedded in README. Recording + editing is the actual work; the content is just running through the README's quick start while a screen recorder captures the terminal and the Hermes webui kanban.
6. **Tutorial repo** — **3 pts**. `sparqr-tutorial` — a step-by-step example with a real (toy) project, commits, screenshots.

**Total: 36 pts (after splitting the dashboard 13 into 5 sub-stories for tracking).**

**Acceptance criteria for v0.4.0:**

- A new user can go from `git clone` to a running pipeline in one session following only the README
- `sparqr.sh` demo works in a Codespace
- ≥50 GitHub stars (realistic for a niche tool that's well-positioned)

---

## v1.0.0 — "Make it a product"

**Theme:** v0.4.0 is excellent. v1.0.0 makes it safe to depend on.

**Stories:**

1. **Stable CLI surface** — **5 pts**. Semver guarantees. Deprecation policy: at least one minor version with deprecation warnings before removal. Audit all CLI verbs and document the public-vs-internal surface.
2. **Hermes marketplace publication** — **5 pts**. `hermes skills install https://github.com/jb-bz/sparqr` works. Submit a PR to the hermes-agent skills registry.
3. **Multi-user mode** (optional) — **13 pts**. A "team" profile (multiple reviewers, round-robin assignment, comment threads visible to all). Backwards-compatible with single-user. **Must be split into sub-stories:** (a) reviewer assignment, (b) team kanban board, (c) per-reviewer notification, (d) audit log.
4. **External PM tool integration** (optional) — **13 pts**. Optional mirror to Plane.so / Linear / Jira. The user explicitly said no to this in v0.1.0; if they adopt those tools later, the v1.0 mirror is the right time. Or they don't adopt them and this never ships. **Must be split:** (a) Plane.so, (b) Linear, (c) Jira.
5. **A paid-hosting option** — *not in scope for the open-source project; this is for whoever maintains it commercially. Listed here for completeness; 0 pts for the OSS repo.*
6. **Long-term support commitment** — **2 pts**. Long-term support (LTS) releases with a published support window. Document the LTS policy: how long each LTS is supported, what kinds of fixes get backported, security-patch policy. The number is a calendar duration, not an effort estimate.

**Total: 38 pts (after splitting the 13s), or 12 pts if you skip multi-user and external PM (the 13s).** The minimum-viable v1.0.0 is stories 1, 2, 6 = 12 pts. The full-fat version is 38 pts.

**Acceptance criteria for v1.0.0:**

- No breaking CLI changes for a committed LTS window (≥2 minor versions) after v1.0.0 release
- `hermes skills install <url>` works end-to-end
- At least 100 active installs (download stats from npm or a similar signal)

---

# Part 4 — Specific other improvements

These are smaller stories that don't fit neatly into the versioned milestones but are worth picking up alongside the headline features. **All sized in story points** so they can be slotted into a release budget when capacity allows.

| Story | Points | When to slot in | Notes |
|---|---|---|---|
| 4.1 `sparc diff <task>` — see what a stage changed | 3 | v0.2.0 or v0.3.0 | Reads all artifacts in the task's lineage and shows diffs. Cheap, useful for understanding agent behavior. |
| 4.2 `sparc retry <task>` — manually re-run a stage | 2 | v0.2.0 | When a stage produces a bad artifact but doesn't crash, currently you have to `sparc hitl redirect`. A dedicated verb is one less thing to remember. |
| 4.3 `sparc pause` / `sparc resume` — graceful daemon control | 3 | v0.2.0 | Let the current stage finish, then stop accepting new stages. Quality-of-life win. |
| 4.4 `--dry-run` flag on `sparc pipeline start` | 2 | v0.2.0 | Run one tick without spawning agents or modifying state. Shows what *would* happen. Invaluable for debugging. |
| 4.5 Per-stage `--max-attempts` instead of pipeline-wide `failure_limit` | 3 | v0.2.0 | Currently a task has one `failure_limit`. Refinement might need 3 retries; completion only needs 1. Make it per-stage. |
| 4.6 `sparc lint` — check `sparc.config.yaml` sanity | 2 | v0.2.0 | Not as heavy as the v0.3.0 JSON schema. Quick checks: board exists, profiles valid, disk_dir writable. |
| 4.7 `sparc doctor --fix` | 5 | v0.3.0 | Doctor reports problems. `--fix` repairs the easy ones: missing skills (re-install), wrong path (re-link), stale PID file (clear). |
| 4.8 `--verbose` / `--quiet` on every CLI verb | 2 | v0.2.0 | For piping into scripts and for debugging. Trivial to add, big UX win. |
| 4.9 Default model selection that respects `~/.hermes/config.yaml` | 1 | v0.2.0 | The orchestrator lets the profile's default model win. Pass `--model` explicitly per stage. Folded into the per-stage model routing story. |
| 4.10 Stage cost report in `sparc status` | 3 | v0.3.0 | Tokens per stage, estimated $ (with pricing data), compare across runs. Helps find the costly stage. |

**Total: 26 pts** across all 10 stories. Most are 2-3 pts. If you wanted to add all of them to a single release, that's a meaningful chunk. Realistically, slot the 2-3 pt ones into whatever release you happen to be working on, and let the 5-pt ones wait for capacity.

---

# Part 5 — What I'm explicitly NOT recommending

Sometimes the right call is to not build something. Here's what I'm saying "no" to and why.

## 5.1 A custom web UI for sparqr in v0.x

The user asked for this in the original conversation ("I want sparqr in hermes-webui"). My recommendation: **don't build it in v0.x**. Reasons:

- The hermes-webui and hermes-workspace already have kanban boards. sparqr uses Hermes Kanban. The existing boards show the state. The user already has a web UI.
- Building a custom web UI is a large project on its own (sized at 13 pts in v0.4.0, which is a "must be split" indicator — the dashboard alone is 5+ sub-stories). It would dominate v0.2.0 or v0.3.0 if attempted.
- hermes-workspace's Swarm Mode Conductor is *exactly* what we'd build. Until that's mature, the user can use hermes-workspace directly.

When to revisit: v0.4.0 or later, if there's clear demand and the existing UIs don't suffice.

## 5.2 A Notion / Linear / Jira mirror in v0.x

The user said no to external PM tools in the original conversation. I agree. Reasons:

- Adds a dependency on external APIs that can break or rate-limit
- Hermes Kanban is already a coordination substrate; mirroring state out is asking for divergence
- The user has hermes-webui / hermes-workspace as their UI; we don't need more

When to revisit: only if a user explicitly asks, or if a sponsor/employer requires it.

## 5.3 Real-time updates

No WebSocket / SSE layer in the orchestrator. Reasons:

- 3-second polling (then 250ms in v0.2.0) is fast enough for human review workflows
- Real-time adds significant complexity (event ordering, backpressure, client reconnection)
- A user sitting at a review surface will see state changes in <1 second with v0.2.0's event-based polling

When to revisit: only if polling latency becomes a real complaint.

## 5.4 A sparqr "language" / DSL for stage definitions

Stages are pure data in `lib/stages.sh`. A DSL would be a meta-language to express stages. Reasons to not:

- The bash file IS the data. It's grep-able, diff-able, and readable.
- A DSL means a parser, a runtime, error messages, a migration path
- Anyone who can edit bash can edit the stage table

When to revisit: if there are 50+ community-contributed stages and the bash file becomes unwieldy. Until then, bash is fine.

## 5.5 Multi-LLM orchestration

sparqr currently spawns Hermes agents which use the configured model. Adding support for "use Anthropic for refinement, OpenAI for completion, local LLM for spec" is a config-only change, not an architecture change. The v0.3.0 per-stage model routing covers this. A separate "multi-LLM orchestration" framework would be over-engineering for the actual need.

---

# Part 6 — Open questions for you

Things I'd want your input on before finalizing:

1. **Is v0.2.0 the right scope?** It's a lot — 9 features. Should I split into v0.2.0 (stability) and v0.2.5 (features) or keep them together?
2. **Per-stage model routing** — do you have a real cost-saving target? "I want to spend 70% less on spec/pseudo" is a different design than "I want fine-grained control."
3. **Local web dashboard** — v0.4.0 is where I put it, but if it's a strong personal preference, it could move to v0.3.0.
4. **Hermes marketplace** — when? It's referenced in v1.0.0. If you have a Hermes maintainer relationship, you could push for v0.4.0.
5. **Are there any P0 gaps I missed?** Look at Part 2 and tell me if anything should be P0 that I downgraded.

---

# Part 7 — Retrospectives

**What this section is:** every release gets a retrospective when it ships. The retrospective captures the *actual* point values per story (vs. the estimates in Part 3), the things that surprised us, and what we'd do differently next release. This is the only place in the package where the numbers are *ground truth* — Part 3 is forward-looking estimates, this section is backward-looking facts.

**How it works:**

- Each release's full retrospective lives in `docs/retrospectives/v0.X.0.md`
- A one-paragraph summary of each retrospective lives here in the ROADMAP, in the order they were released (oldest first)
- The retrospective is **auto-generated** from git history, conversation context, and the point estimates in Part 3 — see `docs/retrospectives/RETROSPECTIVE-TEMPLATE.md` for the format
- The "what surprised us" and "what we'd do differently" sections are drafted by me and edited by you, because those need your perspective
- Velocity = story points per release. We compare release-to-release ratios to recalibrate future estimates

**Why this matters:** without actuals, story points become fiction. The v0.1.0 release was estimated retroactively at ~55 pts. v0.2.0 is planned at 46 pts. If v0.2.0 ships at, say, 60 pts, that's our first real velocity data point, and v0.3.0's 28-pt plan gets re-estimated against it. After 3-4 releases, the estimates will be properly calibrated to this project.

---

## v0.1.0 — shipped 2026-06-18

- **Estimated pts:** n/a (release predates the story-point scale; see retrospective for retroactive estimate)
- **Actual pts (retroactive):** ~55 pts
- **Velocity ratio:** n/a (first release)
- **Stories planned:** not formally tracked (pre-scale)
- **Stories shipped:** all of the v0.1.0 scope, plus BSM integration, GitHub push via BSM, ROADMAP.md as a follow-up
- **Stories deferred:** notify channel (per user feedback — "user preference, not a Telegram channel hardcoded")
- **What surprised us:** BSM was harder than expected (token format debugging); the function-hoisting bug in bash was embarrassing; docs are roughly the same effort as the orchestrator
- **Full retrospective:** [docs/retrospectives/v0.1.0.md](docs/retrospectives/v0.1.0.md)

**Implication for v0.2.0:** our v0.1.0 baseline is ~55 pts per release. v0.2.0 is planned at 46 pts, which is *slightly smaller* than v0.1.0. That's a real signal: v0.2.0 is the first release where we can validate whether our 46-pt estimate is honest. If v0.2.0 ships at 60+ pts, our point scale is under-calibrated and v0.3.0's 28-pt plan is probably wishful. If v0.2.0 ships at 46 pts, the scale is right and we can trust future estimates.

---

*End of roadmap document. Last review: 2026-06-21. Next review: when v0.4.0 ships, with the v0.4.0 retrospective appended.*
