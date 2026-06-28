# FAQ

**Navigation:** [What is SPARC?](#what-is-sparc) · [Design phase](#why-design-isnt-pure-sparc) · [Profiles & skills](#do-i-need-all-6-profiles) · [Kanban](#can-i-run-this-without-hermes-kanban) · [External PM tools](#can-i-use-planeso--linear--jira-instead-of-hermes-kanban) · [Other agents](#can-i-use-this-with-claude-code--cursor--aider) · [Relationship to other projects](#is-this-the-same-as-ruvnetruflo) · [Comparison](#how-does-this-compare-to-autogen--crewai--langgraph) · [Memory & parallelism](#do-the-stage-agents-share-memory) · [Implementation](#why-bash-not-python) · [License](#how-is-this-licensed) · [Contributing](#how-do-i-contribute) · [Roadmap](#whats-the-roadmap) · [Help](#where-do-i-ask-a-question)

---

## Quick links

- **What is sparqr?** See the [README](../README.md).
- **How does it work?** See [ARCHITECTURE.md](ARCHITECTURE.md).
- **How do I install?** See [INSTALL.md](INSTALL.md).
- **What commands are available?** See [COMMANDS.md](COMMANDS.md) — canonical CLI reference.
- **How do I add a new stage or HITL surface?** [ADDING-STAGES.md](ADDING-STAGES.md) · [HITL.md](HITL.md).
- **What's the roadmap?** See [ROADMAP.md](../ROADMAP.md) for the plan, and [docs/retrospectives/](retrospectives/) for what we actually shipped.
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

You CAN mirror Hermes Kanban state to Plane.so / Linear / Jira as a read-only dashboard (see [HITL.md § Mirroring to an external PM tool](HITL.md#mirroring-to-an-external-pm-tool)). A first-class external-PM integration is planned for v0.4.0.

## Can I use this with Claude Code / Cursor / Aider?

The package is Hermes-specific. The methodology (SPARC+Design) is universal; you could reimplement the orchestrator for Claude Code or Cursor. The hermes-kanban substrate is the constraint, not the methodology.

## Is this the same as ruvnet/ruflo?

No. Ruflo is a different project by the same author. Ruflo is a multi-agent swarm framework with its own CLI; this package is a methodology + orchestrator for Hermes. We use the same `ruvnet/sparc` methodology as inspiration but are not derived from Ruflo.

## How does this compare to AutoGen / CrewAI / LangGraph?

Those are general-purpose multi-agent frameworks. This package is a methodology + glue on top of Hermes, not a framework. See `research.md` in the package parent directory for a detailed comparison.

## Do the stage agents share memory?

Yes — via Hermes's memory subsystem. Each stage agent reads from `~/.hermes/memories/` (USER.md, MEMORY.md, plus any project-specific memories) before the stage runs. Findings from earlier stages land in the comment thread on the kanban task; later stages read those threads via the parent task's comments. The cross-stage context is the kanban DAG plus the comment threads.

If you're using `hermes-workspace` as your HITL adapter, the Memory panel in the workspace UI shows what each agent sees.

---

## What's `sparc story` for? Why not just track points in a spreadsheet?

`sparc story` is the methodology layer for point tracking. Three things it adds beyond a spreadsheet:

1. **Per-repo ledger** (`.sparc/stories.yaml`) — stories travel with the project, so any clone has the velocity context
2. **The 13-pt rule** — `add` with 13 pts emits a warning, `split` creates sub-stories as top-level entries, `config validate` warns on unsplit 13-pt stories in `planned`/`in-progress` status
3. **Velocity data feeds retros** — `sparc retro` reads the ledger to populate the "What we actually shipped" section with actual point totals, and `sparc velocity` reads it to compute ratios

The 13-pt rule is the methodology's main value-add over a spreadsheet. Without it, teams silently let 13-pt stories slip; with it, the warning surfaces in every `config validate` run.

---

## What's `sparc retro`? Do I have to write anything?

`sparc retro` auto-generates a retrospective file from your git log and story ledger. **You do not have to write anything** — the script produces:

- The "What we said we'd do" section (pulled from ROADMAP)
- The "What we actually shipped" section (with velocity data from `.sparc/stories.yaml`)
- The "What surprised us" section (analyzed from your commit messages between the previous and current release tag — real prose, not boilerplate)
- Templated stubs for "What we'd do differently" and "Implications for the next release" (you fill these in, or accept the auto-hints)

The workflow:

```bash
git tag v0.5.0                          # post-commit hook nudges you
sparc retro v0.5.0 --dry-run           # preview to stdout
sparc retro v0.5.0                     # writes docs/retrospectives/v0.5.0-WIP.md
# edit the file, commit, rename to v0.5.0.md when finalized
```

The output is a starting point — review, edit, commit. The "What surprised us" section is the most useful part: it's generated from actual commit patterns (bug-fix clusters, docs work, perf changes, dependency updates, test coverage gaps).

---

## What's `sparc velocity` for?

`sparc velocity` reads all `docs/retrospectives/v0.*.md` and prints a table:

```
$ sparc velocity
RELEASE         EST  ACTUAL  RATIO   DONE/  - DEF   NOTES
v0.4.0-rc1       16      16  1.00x      3/  3   0   on target
v0.4.1           12      12  1.00x      5/  5   0   on target
```

Use it to:

- **Check velocity trends over time** — are you consistently under- or over-estimating?
- **Pick up velocity from a fresh clone** — `sparc velocity` works with no setup, just reads the retro files
- **Compare releases** — JSON/CSV output (`--json` or `--csv`) for spreadsheet analysis

The "on target" / "under" / "over" labels in the NOTES column flag releases that drifted significantly from the estimate.

---

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

The canonical roadmap is **[ROADMAP.md](ROADMAP.md)** — read it for the full reasoning, gap analysis, version-by-version plan, what we're explicitly NOT building, and open questions for the maintainer.

The short version (latest release is v0.4.1; v0.4.0 stable pending):

- **v0.1.0** — core package, 6 stages, 5 skills, 5 HITL adapters. Shipped.
- **v0.2.0** — "make it work reliably": event-based poller, kanban CLI compat shim, stale-task reaper. Shipped.
- **v0.2.1** — "make it actually work against real Hermes": bash 3.2 sed fix, hermes-gateway integration tests, ROADMAP.md as a doc not just a comment. Shipped.
- **v0.3.0** — "make it pleasant": events store, gates, `sparc config validate`, `sparc reconciler`, `sparc logrotate`, `sparc status`. Shipped.
- **v0.4.0-rc1** — "make it adoptable" (rc1): `sparc new`, hosted demo via `demo/sparqr.sh`, tutorial repo. Shipped. (3 of 6 stories: dashboard/notify/video deferred to v0.4.0 stable.)
- **v0.4.1** — "make it a methodology": `sparc story`, `sparc retro`, `sparc velocity`, 13-pt warnings in config-validate, post-commit hook. **Shipped 2026-06-27 (13/13 pts, velocity 1.00).**
- **v0.4.0 stable** — pending: tag + release when notify channels + video walkthrough land.
- **v0.5.0** — local web dashboard, hermes-workspace integration, multi-human coordination.
- **v1.0.0** — "make it a product": stable CLI surface with semver, Hermes marketplace publication, optional multi-user mode

Have a feature request? [Open an issue](https://github.com/jb-bz/sparqr/issues/new?template=feature_request.md) — features get triaged against the roadmap before being added.

## Where do I report a bug?

File an issue on GitHub. Use the bug report template (`.github/ISSUE_TEMPLATE/bug_report.md`).

## Where do I ask a question?

GitHub Discussions (if enabled) or open an issue. For security issues, see [SECURITY.md](../SECURITY.md) — but note that as of v0.1.0 we don't have one. If you discover a security issue, file a private issue or contact the maintainers directly.
