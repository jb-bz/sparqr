# Changelog

All notable changes to the Hermes SPARC Orchestration Package will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-06-17

### Added
- Initial release of the SPARC+Design orchestration package for Hermes Agent
- 6-stage pipeline: Specification → Design → Pseudocode → Architecture → Refinement → Completion
- Design phase (community extension, between Specification and Pseudocode)
- 7 named profiles (6 stage agents + 1 reviewer) for hermes-agent
- Hermes Kanban as durable coordination substrate (parent→child task_link DAG)
- Human-in-the-loop gate via `kanban_block` / `kanban_comment` / `kanban_unblock` conventions
- UI-agnostic orchestrator with pluggable HITL adapters
  - `terminal` adapter (always available, in-CLI prompts)
  - `tui` adapter (Hermes `/kanban` slash command in the TUI)
  - `webui` adapter (nesquena/hermes-webui on :8787)
  - `workspace` adapter (outsourc-e/hermes-workspace on :3000)
  - `official-dashboard` adapter (built-in `hermes dashboard` on :9119)
- 5 skills for the running Hermes: `sparc-pipeline-orchestrator`, `sparc-hitl-watcher`, `sparc-stage-spec`, `sparc-stage-design`, `sparc-stage-helpers`
- 6 artifact templates (specification, design, pseudocode, architecture, refinement, completion)
- `setup.sh` — imports the package into a running Hermes without touching the Hermes install
- `sparc` CLI with subcommands: `init`, `pipeline`, `stage`, `hitl`, `doctor`, `adapters`, `stages`
- `sparc-pipeline` orchestrator daemon (watches kanban DB, spawns stage agents)
- `sparc-doctor` validator (checks setup, profiles, kanban board, adapters, model config)
- `examples/hello-sparc/` end-to-end working example
- Full documentation: INSTALL, ARCHITECTURE, HITL, ADDING-STAGES, TROUBLESHOOTING, FAQ
- Test suite (`tests/test_setup.sh`, `test_kanban.sh`, `test_adapters.sh`, `test_validators.sh`, `test_e2e.sh`)

### Known limitations
- No separate chat-gateway notify channel in v0.1.0. The HITL adapter IS the notification — users see review requests in whichever UI they configured. A separate `notify:` channel (Telegram / Discord / Slack / Signal / email) is planned for v0.2.0.
- Hermes Kanban's fixed 7-status state machine means stage progress is encoded via profile assignment + task title prefix, not custom columns
- No cross-board task linking (Hermes Kanban limitation, not the package's)

[0.1.0]: https://github.com/jb-bz/sparqr/releases/tag/v0.1.0

## [0.2.0] - 2026-06-18

### Added
- **Event-driven polling** (story 1): reduced orchestrator poll interval from 3s to 250ms. Uses Hermes Kanban's `task_events` SQLite table for change detection. Configurable via `SPARC_POLL_INTERVAL_SEC`.
- **Stale-task reaper** (story 3, 5 pts): detects `running` tasks whose agent PID has died (crash, OOM, Ctrl-C) and re-queues them as `ready` with a `[REAPED attempt N/M ...]` comment. After max_attempts reaps, blocks the task with `[REAP-BLOCKED]` for human intervention. PID file lives at `$LOG_DIR/sparc-stage-<stage>-<task>.pid`.
- **Reviewer checklist skill** (story 4, 5 pts): `sparc-reviewer-checklist` skill teaches the reviewer agent to verify artifacts against spec acceptance criteria, post structured reviews, and `kanban_block` with a verdict (APPROVE / REJECT / REDIRECT). Profile updated to load the skill.
- **Per-stage model routing** (story 5, 5 pts): `sparc.config.yaml` gains a `models:` section to route cheap stages (spec, design, pseudocode) to faster models and expensive stages (architecture, refinement, completion) to stronger ones. New `lib/config.sh` is the first YAML parser in the codebase — portable, dependency-free (no yq or python3 required).
- **Integration test suite** (story 6, 14 pts scaffolded): new `tests/integration/` directory with VCR-style record-replay harness, Docker compose for real Hermes, and CI integration. Framework ships with 1 placeholder test; recording real sessions is a v0.2.1 task once the official Hermes Docker image is available.
- **CI workflow** (story 7, 3 pts): GitHub Actions with shellcheck, full test suite on every PR, integration tests on main merges only.
- **Prerequisites check** (story 8, 3 pts): `lib/preflight.sh` + `sparc-doctor --pre-install` checks bash ≥4.0, hermes, sqlite3, curl, jq before `setup.sh` runs. Detects missing tools early.
- **Single-user story documented** (story 9, 1 pt): README and ROADMAP now explicitly note that multi-user / teams is a v1.0 feature.

### Changed
- **ROADMAP.md** restructured: v0.2.0 fully scoped with 9 stories, sizes in Fibonacci story points (no human time), velocity calibration against v0.1.0 baseline. v0.3.0 / v0.4.0 / v1.0.0 plans added.
- **Hermes version compatibility** (was story 2, re-scoped from 8 pts to 2 pts): instead of building a runtime shim, the `lib/kanban.sh` header now records the tested-against Hermes version, the minimum compatible version, and the one known quirk (the `set` → `update` fallback in `sparc_kanban_set_status`). Real breakage detection is delegated to story 6's integration tests.
- **Estimates reformatted from human-time to story points** throughout the project (per user feedback): all "weeks / months / days" references removed; all sizes use Fibonacci (1, 2, 3, 5, 8, 13).
- **Retrospective system** (`docs/retrospectives/`): v0.1.0 retrospective written after-the-fact; v0.2.0 retrospective written as part of the release. Future releases will follow this pattern.

### Fixed
- **Function-hoisting bug in bash** (`bin/sparc-pipeline`): function definitions were below the case statement that called them. Bash doesn't hoist function definitions like JavaScript. Caught by `test_e2e.sh` before shipping.
- **`tests/test_preflight.sh` env-dependence**: test assumed hermes wasn't on PATH in dev env; now strips PATH inside the test only. Deterministic.

### Tests
- 237 unit tests across 9 suites (was 111 in v0.1.0; +126 from this release)
- 1 placeholder integration test (record-replay framework in place; real recordings are a v0.2.1 task)

### Known limitations (carried forward)
- **Story 6 scaffolded, not fully recorded**: the integration test framework works but no real Hermes sessions have been recorded yet. Recording requires either a real Hermes install or the official Docker image (not published yet). See [docs/integration/README.md](../tests/integration/README.md).
- **Reaper is PID-only**: doesn't catch alive-but-stuck agents. Time-based fallback is a v0.3.0 story.
- **Per-stage YAML schema**: the parser accepts the YAML subset we use but isn't formally validated. JSON schema is a v0.3.0 story.

[0.2.0]: https://github.com/jb-bz/sparqr/releases/tag/v0.2.0

## [Unreleased]

### Planned for v0.3.0 ("Make it pleasant")
- Structured HITL gate types (approval / confidence / sampling / exception) — 13 pts, must be split
- `sparc status` command — 3 pts
- Artifact reconciler — 5 pts
- Log rotation — 2 pts
- JSON schema for `sparc.config.yaml` — 3 pts

See `ROADMAP.md` Part 3 for the full v0.3.0 plan.

## [0.2.1] - 2026-06-20

### Fixed
- **Critical bug from v0.2.0**: `lib/*.sh` files had sentinel-var guards against double-sourcing. Bash functions don't carry over `exec` boundaries, but env vars do. So `bin/sparc`'s `exec` of subcommand scripts lost function definitions. **Every `sparc <subcommand>` was failing in production with "command not found" errors.** The 237 unit tests passed because they source libs directly without going through the dispatcher. This bug was masked in unit tests; v0.2.1's integration testing caught it.
- **`lib/kanban.sh` matched a hypothetical Hermes CLI, not real Hermes.** Real Hermes v0.17.0 uses `promote`/`complete`/`block`/`archive`/`claim` for status changes (not `set`/`update --status`) and `create <title>` with positional title (not `--title`). All status transitions and task creation now use real verbs.
- **`[UREFINEMENT]` stage-prefix bug**: bash 3.2's `sed 's/^./\U&/'` produces literal `\U` instead of `UREFINEMENT`. Replaced with portable awk.

### Added
- **Real-Hermes-verified integration tests**: 3 tests, 11 assertions total:
  - `test_setup_against_hermes.sh` — board init + DAG creation
  - `test_single_stage_run.sh` — state transitions (claim/complete)
  - `test_two_stage_pipeline.sh` — parent → child DAG with completion
- **Record-replay harness actually works end-to-end** (v0.2.0's was broken in 6 ways; v0.2.1 fixed them all).
- **Container runtime selection in `setup.sh`**: new step 5/7 asks docker/orbstack/none; persists choice as `SPARC_RUNTIME`.
- **CI integration step uncommented** with graceful degradation: runs replay-mode tests, attempts re-recording if Docker is available, skips cleanly otherwise.

### Changed
- **`TESTED_AGAINST` comment** in `lib/kanban.sh` now reads "Hermes Agent v0.17.0 (2026-06-19 build, upstream 5a53e0f0)" — verified by smoke test, not a placeholder.
- **CI workflow** uses `SPARC_RUNTIME` env var with default 'docker'; users can override via repo variable.

### Tests
- 237 unit tests pass (unchanged from v0.2.0)
- 11 integration test assertions pass (was 0 in v0.2.0)
- Integration tests run in REPLAY mode by default (fast, no Docker); RECORD mode captures real Hermes output

### Known limitations (carried forward)
- Re-recording step in CI is a no-op until the official Hermes Docker image is published
- v0.2.1 integration tests don't spawn real LLM agents (state transitions only); full orchestrator e2e is a v0.3.0+ candidate

[0.2.1]: https://github.com/jb-bz/sparqr/releases/tag/v0.2.1

[Unreleased]: https://github.com/jb-bz/sparqr/compare/v0.2.1...HEAD
