# sparqr — Roadmap

**Status:** Working document. v0.1.0 shipped. This file is the result of a critical review of what we built and a forward-looking plan.

**Last updated:** 2026-06-19
**Owner:** jb-bz (the user) + Hermes Agent (drafting)

---

## How to read this document

- **Part 1 — Critical review of v0.1.0.** What's actually weak, what I underestimated, what I'm worried will bite us.
- **Part 2 — Gap analysis.** Concrete things missing, categorized by severity.
- **Part 3 — Roadmap.** Three versions out (v0.2, v0.3, v1.0) with explicit priorities, "skip" candidates, and acceptance criteria.
- **Part 4 — Specific other improvements.** Smaller ideas worth picking up in v0.2.0 alongside the headline features.
- **Part 5 — What I'm explicitly NOT recommending**, with reasons.

The point of this document isn't to commit to every item. It's to give you a clear map of the design space so you can make trade-off decisions, and to capture the reasoning while it's fresh.

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

**What to do:** Add a `lib/kanban_compat.sh` shim layer. Try the modern verb first, fall back to the legacy verb, log a warning. The hermes-agent team ships breaking changes occasionally and we shouldn't have to chase them. Also: add a CI test that runs against a pinned Hermes version, so we know within minutes if a Hermes release breaks us.

## 1.3 The artifact model is dual-store, but the dual store isn't transactional

**What I mean:** When a stage agent calls `sparc_artifact_publish`, it writes to disk AND mirrors to the kanban comment thread. If the disk write succeeds but the kanban call fails, the artifact is on disk but not in kanban. The next stage's agent reads the kanban thread for context and doesn't see the artifact. We log a warning but don't recover — the user has to manually re-mirror.

**Why I didn't make it transactional:** SQLite + filesystem don't have a unified transaction model. The two stores are independent. Solving this properly would require either (a) writing artifacts only to one place and treating the other as a derived view, or (b) implementing a write-ahead log and a background reconciler.

**What to do (v0.2.0):** Background reconciler. Every minute, scan `docs/sparc/<board>/<stage>/*.md` on disk and verify each one is in its kanban task's comment thread. If not, append it. Idempotent, runs as a separate small script, no impact on the main orchestrator loop.

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

**What I mean:** `setup.sh` runs in ~2 minutes, but only the package-side stuff. Before that you need: a working Hermes install (5-10 min if from scratch), Bitwarden Secrets Manager set up (15 min for first-time), a GitHub PAT (5 min), and 1-2 minutes of answering prompts. Realistic first-install time: 30-45 minutes. The "5 minute" claim will make experienced devs feel lied to when they hit the BSM setup wall.

**What to do:** Update the README to "5 minutes if you already have Hermes + BSM set up; 30-45 minutes for a clean install." And add a "Prerequisites check" script that runs first and tells you what's missing before you commit to the 30-minute flow.

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

**What to do (v0.2.0):** Add a stale-task reaper. The orchestrator, on every tick, checks for tasks in `running` state whose associated PID (stored in a sidecar file or in the kanban task metadata) is no longer alive. If a task is stale for >5 minutes, mark it `ready` with a comment "[REAPED] Agent crashed, retrying" and let the next tick re-spawn it. Add a `failure_limit` per task so it doesn't loop forever — after N crashes, mark it `blocked` with reason "agent crashes exceeded retry limit."

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

## v0.2.0 — "Make it work reliably" (~6-8 weeks of focused work)

**Theme:** v0.1.0 has the right shape. v0.2.0 makes it not-stupid.

**Headline features:**

1. **Event-based poller** (gap 1.1). SQLite trigger + sidecar table. 250ms polling on the sidecar instead of 3s on the whole kanban. Backward-compatible: if the trigger doesn't fire (older Hermes), fall back to current 3s polling.
2. **Kanban CLI compat shim** (gap 1.2). Try modern verbs, fall back to legacy. Log warnings. Catches Hermes CLI renames automatically.
3. **Stale-task reaper** (gap 1.9). Tasks in `running` for >5 min with dead PID → re-queue as `ready` with a `[REAPED]` comment. Per-task `failure_limit` to bound retries.
4. **Reviewer checklist skill** (gap 1.4). `sparc-reviewer-checklist` skill that teaches the reviewer agent to verify artifact against spec's acceptance criteria, post structured review, then `kanban_block` with the review as reason.
5. **Per-stage model routing** (was in v0.2.0 roadmap). `sparc.config.yaml` gains:
   ```yaml
   models:
     spec: anthropic/claude-haiku-4
     design: anthropic/claude-haiku-4
     pseudocode: anthropic/claude-haiku-4
     architecture: anthropic/claude-sonnet-4
     refinement: anthropic/claude-sonnet-4
     completion: anthropic/claude-sonnet-4
   ```
   Defaults to the active profile's model. Token cost reduction of ~60-70% on typical pipelines.
6. **Integration test suite** (gap 1.6). `tests/integration/` with a Docker compose file that spins up a real Hermes. Marked slow. CI runs it on every PR. First 3 tests: `setup.sh` against real Hermes, single-stage run end-to-end, two-stage pipeline with HITL.
7. **CI workflow** (gap). GitHub Actions: shellcheck on every push, full test suite on every PR, integration tests on main merges.
8. **Prerequisites check** (gap 1.7). `sparc-doctor --pre-install` (or just better doctor) detects missing Hermes / BSM / git / jq / sqlite before the user runs `setup.sh`.
9. **Single-user story documented** (gap 1.10). One line in README: "⚠️ Single-user. Multi-user / teams is a v1.0 feature."

**Acceptance criteria for v0.2.0:**
- All 111 existing tests still pass
- ≥5 new integration tests pass against real Hermes
- shellcheck clean on all `.sh` files
- Polling latency is 250ms instead of 3s
- A pipeline that runs to completion without manual intervention (autonomous mode, with reviewer gates disabled)
- A pipeline where every gate is human-reviewed and the human uses *only* the Hermes TUI to interact

**What I'm explicitly NOT doing in v0.2.0:** chat-gateway notify channels, JSON schema for config, observability/dashboard, structured gate types, the Plane.so mirror. Each is in a later version with reasoning.

## v0.3.0 — "Make it pleasant" (~3 months after v0.2.0)

**Theme:** v0.2.0 works. v0.3.0 makes you want to keep using it.

1. **Structured HITL gate types** (gap 1.5). `gate: { type: approval | confidence | sampling | exception, params: {...} }`. The four patterns from agentpatterns.ai. Approval is the current behavior; the other three are new.
2. **Confidence-threshold auto-approve.** Stage agents self-report confidence (0-1). If above threshold, skip the gate. Default threshold 0.9. Configurable per-stage.
3. **Sampling.** Configurable % of stage outputs get human review even if confident. Default 10%. Each project's review rate tracked over time.
4. **Exception-only mode.** Review only on failure: validator rejects, agent self-reports low confidence, or specific keyword in artifact. Everything else auto-approves. For "I just want a safety net" users.
5. **`sparc status`** command. Single view of all running pipelines, their current stage, time-in-stage, token cost.
6. **Artifact reconciler** (gap 1.3). Background script that runs every minute, syncs disk artifacts to kanban comment threads. Idempotent.
7. **Log rotation**. `sparc-pipeline.log` rotates at 50MB, keeps last 5.
8. **JSON schema for `sparc.config.yaml`** (was in v0.2.0 roadmap). Catches typos at config time. Optional `sparc config validate` command.

**Acceptance criteria for v0.3.0:**
- All v0.2.0 tests still pass
- A pipeline can run with `gate: sampling, percent: 5` and produce no surprises
- `sparc status` accurately reports state across 3+ concurrent pipelines
- Reconciler runs for 24 hours with no manual intervention and keeps disk/kanban in sync

## v0.4.0 — "Make it adoptable" (~5 months after v0.3.0)

**Theme:** v0.3.0 is excellent for power users. v0.4.0 makes it approachable.

1. **`sparc new` interactive project template.** Asks: web app? CLI? Library? Internal tool? Each maps to different stage defaults, HITL gate placement, and recommended model routing.
2. **Hosted demo.** A `sparqr.sh` script that spins up sparqr + Hermes + webui in a sandbox. The user can try the full pipeline in their browser without installing anything. The killer feature for adoption.
3. **Local web dashboard.** Single-user, localhost-only. Shows all running pipelines, click a task to see its artifact and stage history. This is the user's "I want sparqr in hermes-webui" feature from the original conversation. Build it as a separate service (`sparc-dashboard`) that the user runs alongside Hermes.
4. **Chat-gateway notify channels** (re-introduced from earlier plan). Telegram, Discord, Slack, Signal. Properly pluggable. Auto-detected from existing Hermes gateway config.
5. **Video walkthrough.** A 5-minute "from zero to first pipeline" video. Embed in README.
6. **Tutorial repo.** `sparqr-tutorial` — a step-by-step example with a real (toy) project, commits, screenshots.

**Acceptance criteria for v0.4.0:**
- A new user can go from `git clone` to a running pipeline in under 15 minutes following only the README
- `sparqr.sh` demo works in a Codespace
- ≥50 GitHub stars (realistic for a niche tool that's well-positioned)

## v1.0.0 — "Make it a product" (~9 months after v0.1.0)

**Theme:** v0.4.0 is excellent. v1.0.0 makes it safe to depend on.

1. **Stable CLI surface.** Semver guarantees. Deprecation policy: at least one minor version with deprecation warnings before removal.
2. **Hermes marketplace publication.** `hermes skills install https://github.com/jb-bz/sparqr` works.
3. **Multi-user mode.** Optional. A "team" profile (multiple reviewers, round-robin assignment, comment threads visible to all). Backwards-compatible with single-user.
4. **External PM tool integration.** Optional mirror to Plane.so / Linear / Jira. The user explicitly said no to this in v0.1.0; if they adopt those tools later, the v1.0 mirror is the right time. Or they don't adopt them and this never ships.
5. **A paid-hosting option.** (Out of scope for the open-source project; this is for whoever maintains it commercially.)
6. **Long-term support commitment.** 12-month LTS releases.

**Acceptance criteria for v1.0.0:**
- No breaking CLI changes for 12 months after v1.0.0 release
- `hermes skills install <url>` works end-to-end
- At least 100 active installs (download stats from npm or a similar signal)

---

# Part 4 — Specific other improvements worth picking up

These are smaller ideas that don't fit neatly into the versioned milestones but are worth doing alongside the headline features.

## 4.1 `sparc diff` — see what a stage changed

Right now you can see artifacts in `./docs/sparc/<board>/<stage>/<task-id>.md` but you can't see "what did refinement actually change vs. architecture?" `sparc diff <task>` would show artifact-by-artifact diffs across stages. Cheap, useful for understanding agent behavior.

## 4.2 `sparc retry <task>` — manually re-run a stage

When a stage produces a bad artifact, the orchestrator only retries automatically on crash. If the artifact is bad but the agent didn't crash, you have to manually `sparc hitl redirect <task> "..."`. A `sparc retry <task>` verb would be one less thing to remember.

## 4.3 `sparc pause` and `sparc resume` — graceful control of the daemon

The orchestrator can be `start`ed and `stop`ped. But there's no "pause" — let the current stage finish, then stop accepting new stages. Useful when you want to step away but don't want to kill the in-flight work. A small feature, big quality-of-life win.

## 4.4 `--dry-run` flag on `sparc pipeline start`

Run one tick without spawning any agents or modifying state. Just shows what *would* happen. Invaluable for debugging "why isn't the pipeline advancing?"

## 4.5 Per-stage `--max-attempts` instead of pipeline-wide `failure_limit`

Currently a task has one `failure_limit`. If a stage fails 3 times, the whole pipeline halts. A common pattern is "refinement might need 3 retries but completion only needs 1." Make it per-stage.

## 4.6 A `sparc lint` that checks `sparc.config.yaml` schema

Not as heavy as the v0.3.0 JSON schema. Just a quick sanity check: does the board exist? Are the profiles valid? Does the disk_dir exist and is it writable? Catches the most common config errors at `sparc init` time.

## 4.7 A `sparc doctor --fix` mode

`doctor` reports problems. `--fix` would attempt to repair the most common ones: missing skills (re-install), wrong path (re-link), stale PID file (clear). Don't try to fix everything — just the easy wins.

## 4.8 A `--verbose` / `--quiet` flag on every CLI verb

For piping into scripts and for debugging. Trivial to add, big UX win.

## 4.9 Default model selection that respects `~/.hermes/config.yaml`

The orchestrator currently spawns `hermes -p <profile> chat -q "..."` and lets the profile's default model win. But it could explicitly pass `--model <X>` per stage if the per-stage model routing is set. This is a small change with big cost-savings implications.

## 4.10 A "stage cost" report in `sparc status`

Show how many tokens each stage used, how much $ that was (if you have pricing data), and compare across runs. Helps you find which stage to optimize for cost. Defer to v0.3.0 if v0.2.0 is too packed.

---

# Part 5 — What I'm explicitly NOT recommending

Sometimes the right call is to not build something. Here's what I'm saying "no" to and why.

## 5.1 A custom web UI for sparqr in v0.x

The user asked for this in the original conversation ("I want sparqr in hermes-webui"). My recommendation: **don't build it in v0.x**. Reasons:

- The hermes-webui and hermes-workspace already have kanban boards. sparqr uses Hermes Kanban. The existing boards show the state. The user already has a web UI.
- Building a custom web UI is a 3-6 month project by itself. It would dominate v0.2.0 or v0.3.0.
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

*End of roadmap document. Last review: 2026-06-19. Next review: after v0.2.0 release.*
