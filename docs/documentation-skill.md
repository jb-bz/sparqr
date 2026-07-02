# Software Documentation Base

This document is a thorough-but-concise outline of the documentation
that should ship with any software project. It is designed to be
folded into a documentation skill — the goal being that any code an
agent (or human) produces is **always** accompanied by a complete,
understandable doc base.

The target is a project that is:

- small enough to read in a sitting
- serious enough to be used by people other than the author
- version-controlled (git)
- released in some form (a library, a CLI, a service, a script, a package)

The minimum viable doc base is **7 documents**. The recommended
doc base is **11**. The full doc base (when justified) is **14**.

## Why ship documentation

Three reasons, in order of importance:

1. **The next contributor can't read your mind.** Whether the next contributor is you in 3 months, a teammate, or an external user, they need to know what this is, why it exists, and how to use it. Without that, the code is unmaintainable.
2. **The doc base IS the project.** Most users will never read the source. They read the README. They skim the changelog. The doc base is the public face of the work; the code is the implementation detail behind it.
3. **Docs force clarity.** Writing "what is this for" in two paragraphs is harder than writing it in two pages. The constraint of being clear to a stranger surfaces assumptions you didn't know you were making.

The inverse is also true: a project without docs is hostile. Every user pays a "what is this and how do I use it" tax on first contact. A 200-word README eliminates that tax.

## The minimum viable doc base (7 files)

For any project — library, script, CLI, service — the following 7
files are non-negotiable. They are the floor. A project without
these is not "done" in any meaningful sense.

### 1. `README.md` — the front door

**Length:** 50–500 lines. Anything over 800 is a sign that the README has become a manual and the manual should be its own file.

**Required sections, in order:**

1. **Title + one-line description** — what this is, in one sentence
2. **Status / badges** — build status, test status, version, license (if applicable)
3. **"What is this?" / "Why does this exist?"** — 2–4 paragraphs explaining the problem this solves. Not the implementation — the *problem*.
4. **"Show me"** — the smallest possible example that shows the thing working. Code, not prose.
5. **"How do I install / use it?"** — the actual installation or usage steps. Bullet points or a short code block. Link to deeper docs for the long version.
6. **"How do I extend / contribute?"** — the contribution path. Even if it's just "open an issue."
7. **License + acknowledgments** — if applicable

**Strong README anti-patterns:**

- Starting with "What is X?" without first saying what X is *for* (most users don't know yet)
- Installation steps that assume dependencies the user doesn't have ("just install our 12-prerequisite toolchain")
- A "Quick start" that takes 30 minutes
- Screenshots of "this is the project" without showing it doing something
- A blank or 1-paragraph README that says "see the wiki"

### 2. `CHANGELOG.md` — what changed, when, and why

**Length:** Grows over time. Newest entries at top. No upper limit but trim to the relevant at any moment.

**Format:** Per-release sections, with dates, organized as:
- Version number (e.g., `## [1.2.0] - 2026-06-15`)
- Grouped bullet points: `### Added`, `### Changed`, `### Fixed`, `### Removed`, `### Deprecated`
- Each bullet is a concrete change a user can observe, not internal refactors (those go in the commit log, not the changelog)

**Rules:**

- **Every release gets a changelog entry.** Even if it's just "no user-facing changes" — say so.
- **Link from the version number** to the release tag / commit, when possible.
- **Use semantic versioning.** Major for breaking changes, minor for new features, patch for bug fixes.
- **Pre-release versions are first-class:** `## [1.2.0-rc1] - 2026-06-10` then `## [1.2.0] - 2026-06-15`.
- **Keep a "Unreleased" section** at the top for the in-progress version. Update it as work lands; cut a release entry when you tag.

**Strong changelog anti-patterns:**

- "Various improvements" (what improvements?)
- Mixing user-facing changes with internal refactors (call them out separately or omit the internal ones)
- Dates in the wrong format (use ISO 8601: `2026-06-15`)
- Skipping patch versions because "nothing changed" (silent patches erode trust)

### 3. `LICENSE` — the legal wrapper

**Length:** The full text of the license you chose. 1–500 lines depending on license. MIT and Apache 2.0 are common; BSD-3-Clause, ISC, and MPL-2.0 are fine alternatives. AGPL and SSPL have specific use cases. **No license = "all rights reserved" by default in most jurisdictions**, which is usually not what you want.

**Strong license anti-patterns:**

- No license file at all
- A license that doesn't match the code (e.g., MIT headers in code with GPL LICENSE)
- "All rights reserved" unless you really mean it
- Copy-pasting a license you don't understand

### 4. `CONTRIBUTING.md` — how to contribute

**Length:** 50–300 lines. More is fine for large projects.

**Required content:**

- How to set up a development environment
- How to run the tests
- How to submit a change (branch, commit message style, PR template, etc.)
- Coding style (or link to a style guide)
- Code of conduct link (or "be excellent to each other")
- How to file a bug

**Strong CONTRIBUTING anti-patterns:**

- "Just send a PR" with no other info (users don't know what you consider a good PR)
- Outdated setup instructions that don't match the current codebase
- A wall of legal language with no actual contribution workflow
- Missing entirely

### 5. `docs/INSTALL.md` (or section in README) — how to install

**When to have a separate file:** when installation is non-trivial — multiple steps, dependencies, environment variables, build steps, platform-specific notes.

**Required content:**

- Prerequisites (versions, dependencies)
- The actual install command(s)
- Verification step (how do I know it worked?)
- Platform-specific gotchas (macOS / Linux / Windows)
- Common failure modes and fixes

**Strong INSTALL anti-patterns:**

- "Just run `make install`" (without explaining what that does or what it requires)
- Hidden environment variables
- "Works on my machine" (no platform notes)

### 6. `docs/TROUBLESHOOTING.md` (or section) — when things go wrong

**Required content:**

- The 5–10 most common failure modes
- What they look like (the error message, the symptom)
- Why they happen
- How to fix them

**Strong TROUBLESHOOTING anti-patterns:**

- Generic "check the logs" (which logs? what should they say?)
- Problem→fix pairs without the diagnostic step (how do I confirm this is the problem I'm hitting?)
- Out of date (the only thing worse than no troubleshooting guide is one that points to a thing that no longer exists)

### 7. `docs/FAQ.md` — the things people actually ask

**Required content:** the 5–10 questions that come up repeatedly. The best source for these is your issue tracker, support channel, and your own memory of "people keep asking me this."

**Strong FAQ anti-patterns:**

- Made-up questions you think people might ask (vs. questions they actually ask)
- Single-line answers with no context
- "Just RTFM" tone
- Stale answers (the linked docs moved)

## The recommended doc base (11 files)

The minimum viable 7 is the floor. For projects that will be used,
extended, or shared, the following 4 additional documents are
strongly recommended.

### 8. `docs/ARCHITECTURE.md` — how it works

**When to have one:** when the codebase has more than ~500 lines, or has multiple components, or has architectural decisions that aren't obvious from reading the code.

**Required content:**

- The 30-second mental model (1 paragraph + 1 diagram if you can)
- The major components and their responsibilities
- The data flow (input → ... → output)
- The key architectural decisions and *why* they were made (this is the most important part — not just *what* but *why*)
- What was explicitly *not* done and why (often more useful than what was done)

**Strong ARCHITECTURE anti-patterns:**

- A UML diagram that no one reads
- "The code is self-documenting" (it isn't, for anyone who didn't write it)
- 5000 words when 500 would do
- Architecture-as-aspirational-document (showing the future, not the present)

### 9. `docs/ROADMAP.md` — where this is going

**When to have one:** when the project has a non-trivial future (more than "fix bugs as they come in"). Optional for libraries with a single maintainer; essential for anything with a roadmap of multiple releases.

**Required content:**

- The next 1–3 releases, with point estimates
- The stories in each release
- A per-release retrospective section (what was planned, what shipped, what surprised us, what we'd do differently, velocity)
- A "what we're explicitly NOT building" section (this is the most under-used part of roadmaps — it sets expectations and prevents wasted effort)

**Strong ROADMAP anti-patterns:**

- Aspirational lists with no estimates
- "We'll see" or "TBD" entries
- No retrospective section (the meta-problem: the plan that doesn't learn from the past is just a wish list)
- A roadmap that's never updated

### 10. `docs/HITL.md` (or `INTERACTION.md`) — how humans interact

**When to have one:** when the project involves human-in-the-loop decisions, manual approvals, or interactive use. Especially relevant for AI/agent projects, content tools, or anything that pauses for human input.

**Required content:**

- The interfaces (CLI commands, web UIs, API endpoints) that humans use
- The decision points where human input is required
- The options at each decision point
- Examples of expected use

**Strong HITL anti-patterns:**

- "See the code" (the whole point of the doc is to AVOID having to read the code)
- Undocumented defaults (the system does X unless... unless what?)
- Implicit decisions (the system uses "the obvious" setting without telling you what that is)

### 11. `docs/SECURITY.md` — how to report vulnerabilities, what the security model is

**When to have one:** for any project with users. Strongly recommended for anything that handles data, auth, or money.

**Required content:**

- How to report a vulnerability (email, security@, GitHub Security Advisories, etc.) — make this *easy* to find
- The security model (what's trusted, what's not, what the threat model is)
- Supported versions for security updates
- A disclosure timeline (when reporters can expect acknowledgment, when fixes will land)
- CVE / advisory history if applicable

**Strong SECURITY anti-patterns:**

- No security policy (users will find ways to report vulnerabilities that are worse than a security@ email)
- A "we'll fix it eventually" disclosure timeline (vague timelines erode trust)
- Threat model that's never written down (then there's no shared understanding of what the project defends against)

## The full doc base (14 files, when justified)

For projects that are mature, widely used, or have a community around them, the following 3 additional documents round out the doc base.

### 12. `docs/COMMANDS.md` — the canonical command reference

**When to have one:** for any CLI tool or project with more than ~5 distinct commands. Also useful for libraries with many entry points.

**Format:** One section per command. For each command:
- A one-paragraph narrative (when to use it, key flags, examples)
- A verbatim `--help` block at the bottom (capture from the actual binary, not a paraphrase)
- A common-pitfalls or error-codes section if applicable

**Strong COMMANDS anti-patterns:**

- Hand-written "what we think the help says" (drift from reality)
- Missing flags (better to capture the live output than to remember)
- No examples (people learn from examples, not from prose)

### 13. `docs/retrospectives/vX.Y.Z.md` — per-release retros

**When to have one:** for any project that has shipped at least 2 releases. The retro is what makes release N+1 better than release N.

**Format:** One file per release, organized as:
- What we said we'd do (the plan)
- What we actually shipped (the reality)
- What surprised us (the learning)
- What we'd do differently (the commitments)
- Implications for the next release (the action items)

**Strong retrospective anti-patterns:**

- Generic advice that doesn't reference the actual release
- Skipped or stale retros (the value compounds over time)
- Confessional tone (the retro is for learning, not for blaming)
- Hidden from the public (retros are part of the project's transparency; private ones are usually because they say unflattering things, which is exactly the wrong reason to keep them private)

### 14. `docs/screenshots/` — visual documentation

**When to have:** always, for any project with a UI. The doc base that has screenshots is 5x more usable than the one without.

**What to include:**
- The 3–5 most important screens (the ones a new user sees first)
- The 3–5 most-confusing screens (where users get stuck)
- One screenshot per "main thing this project does"
- The screenshots should be captured against a *real running instance* of the project, not a mockup

**Strong screenshot anti-patterns:**

- Stock photos / generic images
- Screenshots from a different version than the current one
- Mockup screenshots (a screenshot of a Figma file isn't a screenshot of the project)
- Captions that say "this is the dashboard" instead of explaining what the user should do here

## Standard sections in any code project

Beyond the files, every project benefits from a few standard
sections. Use them as a checklist when starting a new project.

### Top-level project layout

```
project/
├── README.md              # required: front door
├── CHANGELOG.md           # required: what changed
├── LICENSE                # required: legal
├── CONTRIBUTING.md        # required: how to contribute
├── .gitignore             # what not to commit
├── .editorconfig          # consistent editor settings
├── src/                   # source code (or lib/, app/, etc.)
├── tests/                 # tests (mirror src/ structure)
├── docs/                  # the long-form docs
│   ├── INSTALL.md
│   ├── TROUBLESHOOTING.md
│   ├── FAQ.md
│   ├── ARCHITECTURE.md
│   ├── ROADMAP.md
│   ├── COMMANDS.md       # for CLI projects
│   ├── SECURITY.md
│   ├── HITL.md           # for interactive projects
│   ├── retrospectives/    # one per release
│   └── screenshots/
├── examples/              # usage examples (mirror this doc)
│   └── hello-world/
├── README.md
├── sparc.config.yaml.example   # or your tool's config
└── ...
```

### Required sections in `CONTRIBUTING.md`

```
# Contributing

## Setup
[Step-by-step dev environment setup]

## Tests
[How to run them, what they cover]

## Pull request process
[Branch, format, reviewers, CI]

## Coding style
[Or link to a style guide]

## Bug reports
[How to file — link to issue template]
```

### Required sections in `CHANGELOG.md`

```
# Changelog

## [Unreleased]
[in-progress changes]

## [X.Y.Z] - YYYY-MM-DD
### Added
### Changed
### Fixed
### Removed
### Deprecated
```

### Required sections in a release retrospective

```
# Retrospective: vX.Y.Z

## What we said we'd do
[The plan from the ROADMAP or release doc]

## What we actually shipped
[What landed, with the velocity data]

## What surprised us
[The learning, ideally auto-generated from commit analysis]

## What we'd do differently
[Concrete commitments for the next release]

## Implications for the next release
[Link the "what we'd do differently" to specific stories]
```

## Embedded best practices

These are not files, but patterns that should appear throughout the
doc base.

### 1. The 30-second test

> Can a competent engineer who has never seen this project understand what it is and how to use it within 30 seconds of opening the README?

If not, the README has failed. Fix it before doing anything else.

### 2. The honest "no" answer

> Does the doc accurately say "this doesn't work" or "this is broken" where that's true?

Most projects lie by omission. They document the happy path and never say "this is the known-broken thing; don't use it." An honest doc that says "this is broken" is more trustworthy than a glossy doc that omits the truth. The "Known limitations" section in a README is high-leverage.

### 3. The "show me, don't tell" rule

> Can a user reproduce the example by copy-pasting from the README?

Code blocks in READMEs must work as-is. No "[insert your API key here]" without a clear "step 1: get an API key at https://...". No "$variable" without setting it. The first time a user copy-pastes and it doesn't work, you've lost them.

### 4. The "stay current" rule

> When did someone last run the example to verify it still works?

A doc that's wrong is worse than no doc. Date the example ("last verified: 2026-06-15") or add a CI step that runs the example. A stale doc teaches users to distrust the docs.

### 5. The "single source of truth" rule

> Is each fact stated exactly once?

If "the install command" appears in README, INSTALL, CONTRIBUTING, and TROUBLESHOOTING, four docs can drift apart. Pick one as canonical and have the others link to it. Markdown links (`[see INSTALL.md](INSTALL.md)`) are cheap.

### 6. The "ship the doc with the change" rule

> When did the doc for this change ship — at the same time as the change, or after?

Every code change should come with a doc change in the same commit (or PR). "I'll update the docs later" is how doc bases rot. If a doc change is too big for the same commit, the PR description should say what doc updates are needed before merge.

### 7. The "metadata is part of the doc" rule

> Does the package's metadata match its docs?

- The package version (`package.json`, `setup.py`, `pyproject.toml`, etc.) should match the latest changelog entry
- The README's "latest version" badge should match
- The install command should install that exact version
- The CLI's `--version` should print that exact version

If any of these drift, the user gets a worse experience and doesn't know why.

## Adapting this to your project

This is a *baseline*, not a prescription. Adjust by:

- **Project type:**
  - Library → focus on API docs, examples, version compat
  - CLI → focus on COMMANDS.md, INSTALL, FAQ
  - Service → focus on ARCHITECTURE, TROUBLESHOOTING, SECURITY, RUNBOOK
  - Framework / agent orchestrator → focus on EXTENDING, HITL, METHODOLOGY
  - Personal script → README + CHANGELOG is enough; skip the rest

- **Project size:**
  - < 100 lines: README + CHANGELOG. That's it.
  - 100–1000 lines: add LICENSE, INSTALL.
  - 1000–10,000 lines: add the recommended 11 files.
  - > 10,000 lines or multiple contributors: the full 14.

- **Project audience:**
  - Just you: the minimum viable 7 (you'll thank yourself later)
  - Small team: the recommended 11
  - Public / community: the full 14, with screenshots, SECURITY, and a public CODE_OF_CONDUCT

## Closing

The doc base is the project. The code is the implementation. Most
of the value the user gets comes from the docs — the README is the
first contact, the CHANGELOG is the trust signal, the INSTALL is
the on-ramp, the ARCHITECTURE is the "how does it work" answer, the
ROADMAP is the "where is this going" signal, the COMMANDS is the
reference, the FAQ is the "did anyone else hit this" answer, the
retros are the "we're learning" signal, the screenshots are the
"is this for me" answer.

Ship the code with the docs. Every time. Without exception. This
document is the recipe.
