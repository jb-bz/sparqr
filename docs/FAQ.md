# FAQ

**Navigation:** [What is SPARC?](#what-is-sparc) · [Design phase](#why-design-isnt-pure-sparc) · [Profiles & skills](#do-i-need-all-6-profiles) · [Kanban](#can-i-run-this-without-hermes-kanban) · [External PM tools](#can-i-use-planeso--linear--jira-instead-of-hermes-kanban) · [Other agents](#can-i-use-this-with-claude-code--cursor--aider) · [Relationship to other projects](#is-this-the-same-as-ruvnetruflo) · [Comparison](#how-does-this-compare-to-autogen--crewai--langgraph) · [Memory & parallelism](#do-the-stage-agents-share-memory) · [Implementation](#why-bash-not-python) · [License](#how-is-this-licensed) · [Contributing](#how-do-i-contribute) · [Roadmap](#whats-the-roadmap) · [Help](#where-do-i-ask-a-question)

---

## Quick links

- **What is sparqr?** See the [README](../README.md).
- **How does it work?** See [ARCHITECTURE.md](ARCHITECTURE.md).
- **How do I install?** See [INSTALL.md](INSTALL.md).
- **How do I add a new stage or HITL surface?** [ADDING-STAGES.md](ADDING-STAGES.md) · [HITL.md](HITL.md).
- **Something broke?** [TROUBLESHOOTING.md](TROUBLESHOOTING.md).
- **Spotted a bug?** [File an issue](https://github.com/jb-bz/sparqr/issues/new?template=bug_report.md).

---

## What is SPARC?

[SPARC](https://github.com/ruvnet/sparc) is a methodology for AI-assisted software development with 5 phases: **S**pecification, **P**seudocode, **A**rchitecture, **R**efinement, **C**ompletion. Each phase has clear deliverables and acceptance criteria. This package extends it with a Design phase (between Spec and Pseudocode), making it 6 stages.

## Why +Design? Isn't SPARC 5 phases?

The upstream is 5. We add Design because:
- "What does this look like?" deserves a first-class review gate, not a side note in Pseudocode
- For UI-heavy features, the gap between Spec and Pseudocode is too big; Design fills it
- For non-UI features, you can skip Design (one line in `sparc.config.yaml`)

If you want pure SPARC: comment out the `design` line in your project's `sparc.config.yaml`.

## Do I need all 6 profiles?

No. They're cheap (just YAML files with config + skill references). Re-run `./setup.sh` to add or remove them.

## Do I need all 5 skills?

No. The skills are auto-loaded by the profiles. If you only run a few stages, only those skills are used. But all 5 together are <100KB on disk.

## Can I run this without Hermes Kanban?

No. Hermes Kanban is the durable coordination substrate. The package is built on top of it. Without it, there's nothing to coordinate.

## Can I use Plane.so / Linear / Jira instead of Hermes Kanban?

In v0.1.0, no. The package is tightly coupled to Hermes Kanban's verb set (`kanban_create`, `kanban_block`, etc.) and its state machine.

You CAN mirror Hermes Kanban state to Plane.so / Linear / Jira as a read-only dashboard (see [HITL.md § Mirroring to an external PM tool](HITL.md#mirroring-to-an-external-pm-tool)). A first-class external-PM integration is planned for v0.2.0.

## Can I use this with Claude Code / Cursor / Aider?

The package is Hermes-specific. The methodology (SPARC+Design) is universal; you could reimplement the orchestrator for Claude Code or Cursor. The hermes-kanban substrate is the constraint, not the methodology.

## Is this the same as ruvnet/ruflo?

No. Ruflo is a different project by the same author. Ruflo is a multi-agent swarm framework with its own CLI; this package is a methodology + orchestrator for Hermes. We use the same `ruvnet/sparc` methodology as inspiration but are not derived from Ruflo.

## How does this compare to AutoGen / CrewAI / LangGraph?

Those are general-purpose multi-agent frameworks. This package is a methodology + glue on top of Hermes, not a framework. See `research.md` in the package parent directory for a detailed comparison.

## Do the stage agents share memory?

No. Each profile has its own memory namespace. This is intentional: stage N's memory should not contaminate stage N+1's. The "memory" that flows between stages is the artifact + the kanban comment thread.

## Can two SPARC pipelines run in parallel?

Yes, as long as they use different boards. `sparc init` creates a board per project directory. Two terminals, two boards, two orchestrator daemons — they don't interfere.

To run two pipelines on the SAME board (e.g. parallel workstreams on one project), you'd need to fork the orchestrator. Not supported in v0.1.0; the kanban DAG is parent→child, not multi-root.

## Why bash, not Python?

See [ARCHITECTURE.md § Why bash?](ARCHITECTURE.md#why-bash). Short version: coordination code should be readable without a language ecosystem.

## How is this licensed?

MIT. See [LICENSE](../LICENSE).

## How do I contribute?

See [CONTRIBUTING.md](../CONTRIBUTING.md). The maintainers welcome bug reports, new adapters, new stage definitions, and docs improvements.

## What's the roadmap?

- **v0.1.0** (this release): core package, 6 stages, 5 skills, 5 HITL adapters
- **v0.2.0** (planned): event-based poller replacement, chat-gateway notify channels (Telegram / Discord / Slack / Signal / email), Plane.so mirror adapter, JSON schema for `sparc.config.yaml`
- **v0.3.0** (planned): per-stage model routing in `sparc.config.yaml` (cheap models for spec/pseudo, strong for refine/complete)
- **v1.0.0** (planned): stable CLI surface, semver guarantees, marketplace publishing

## Where do I report a bug?

File an issue on GitHub. Use the bug report template (`.github/ISSUE_TEMPLATE/bug_report.md`).

## Where do I ask a question?

GitHub Discussions (if enabled) or open an issue. For security issues, see [SECURITY.md](../SECURITY.md) — but note that as of v0.1.0 we don't have one. If you discover a security issue, file a private issue or contact the maintainers directly.
