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

[0.1.0]: https://github.com/yourname/hermes-sparc-package/releases/tag/v0.1.0
