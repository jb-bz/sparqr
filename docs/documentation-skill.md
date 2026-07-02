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

## Methodology: story points, velocity, retrospectives

The practices below are the methodology half of a complete doc base.
They make the planning and reflection side of a project
reproducible across sessions and other humans. They are independent
of any specific project management tool — the doc base can be
implemented in a spreadsheet, a YAML file in the repo, a kanban
board's metadata, or any combination.

If the project uses these practices, the `docs/ROADMAP.md` and
`docs/retrospectives/vX.Y.Z.md` files in the doc base become
substantively richer: instead of "TBD" or aspirational lists, the
roadmap has point-estimated stories, and the retro has actual
velocity data and concrete "what we'd do differently" items
sourced from the release's actual work.

### Story points

**Concept:** Story points are a unit of effort estimate for
individual pieces of work. They are used to plan releases, track
velocity, and identify work that is too large.

**The point scale:** Fibonacci: 1, 2, 3, 5, 8, 13. Why Fibonacci?
The gaps between values grow as estimates get bigger, which is
exactly what you want — small stories are easy to differentiate
(1 vs 2 vs 3), large stories are not (12 vs 13 vs 14 — they're all
"huge"). **Reject other values.** The scale is intentionally
non-linear; allowing 4 or 6 or 10 reintroduces the false precision
that Fibonacci is designed to remove.

**The 13-pt rule:** A 13-pt story is a code smell. It means "I
don't know what this is." Split it into sub-stories of 1/2/3/5/8
pts each. The 13-pt label exists as an upper bound to force the
split — it's the warning, not the size. Story-tracking tools should
emit a warning at add time and warn again at validation time
(warn-don't-fail; splits happen mid-work and failing CI on a
planning issue is hostile).

**Story fields:** Each story has at minimum:
- An id (stable; safe to rename the name without changing the id)
- A name (human-readable; used to generate the id)
- Points (one of 1/2/3/5/8/13)
- Status (`planned`, `in-progress`, `done`, `deferred`)
- Release (which version this story is for)

Optionally:
- Notes (free-form, for "why" and "constraints")
- Created_at (timestamp)
- Sub-stories (list of child ids on the parent)
- Parent_story (id on each child, linking back)

**The minimum fields are non-negotiable.** Without status, you
can't tell what is being worked on. Without release, you can't
compute velocity. Without id, you can't reference a story in
commits or PRs ("see story X" requires X to be a stable string).

**Per-project storage:** The ledger lives with the project (a
YAML file in the repo, a spreadsheet in the project folder, a
database the project owns). **Per-project, not per-user**, so the
ledger travels with the repo and survives team changes. The
concrete storage mechanism is a project decision — text file
in git is the most auditable; kanban tool metadata is the most
collaborative; spreadsheet is the lowest-friction but doesn't
survive team changes.

**The "split" operation:** When a 13-pt story is split, the
sub-stories are first-class entries (not nested under the
parent). The parent is marked `deferred` with a reference to its
sub-stories; the children carry a `parent_story` link. This
matters because queries like "show me all in-progress work in
release v0.5.0" should return the sub-stories, not the
already-deferred parent. Nesting hides the real active work.

**Strong story-points anti-patterns:**

- **Spreadsheets owned by one person** — they don't survive a
  team change. Put the ledger with the project.
- **Skipping the 13-pt rule** — "it's just 13 pts, I can do it in a
  week" is exactly when you should split. The 13 is a forcing
  function, not a measurement.
- **Tracking velocity per story** — velocity is per-release. A
  single story doesn't have a velocity; it has a "done on time"
  or "ran long" flag.
- **Allowing non-Fibonacci values** — invites false precision. The
  scale is the scale.
- **Archiving old stories on each release** — the ledger
  accumulates. Don't archive; just mark `deferred` or `done`.

### Velocity tracking

**Concept:** Velocity is the ratio of estimated points to actual
points for a given release. It tells you whether your estimates
are accurate, whether the team is improving, and whether the
release is on track.

**Formula:** `velocity = actual_points / estimated_points`. A
velocity of 1.00 means on target. Less than 1 means under-shipped
(estimates were too optimistic, or work was deferred). Greater
than 1 means over-shipped (estimates were too conservative, or
scope grew).

**The table format:** Each release gets a row in the velocity
table. The columns are: `RELEASE`, `EST` (estimated points),
`ACTUAL` (shipped points), `RATIO` (actual/estimated), `DONE/TOTAL`
(stories done vs planned), `DEF` (stories deferred), and `NOTES`
(qualitative flag like "on target" / "under" / "over").

**Reading velocity over time:** One release's velocity is noise.
Three or more releases show a trend. If velocity is consistently
0.7, the team is under-estimating by ~30% — either tighten
estimates or accept the new normal. If velocity drifts from 1.0
to 0.5 over three releases, something is degrading (morale,
tooling, scope creep). The trend is the signal, not the absolute
value.

**When to ship:** A release is "on target" if velocity is in the
0.9–1.1 range. Below 0.5, it's a "shipped but under" — something
was promised and didn't happen. Above 1.1, it's "over" — scope
grew or estimates were loose.

**Auto-generating the velocity table:** The table is computable
from the story ledger filtered by release + the released flag.
Tools that show velocity in real time (vs. only in retros) let
the team see drift mid-release, not just at the end. This is
worth the small effort to set up.

**Strong velocity anti-patterns:**

- **Per-story velocity** — meaningless; stories have a "done on
  time" or "ran long" flag, not a ratio.
- **Gaming the number** — "let's just lower our estimates so
  velocity goes up." Velocity is a signal, not a metric to
  optimize.
- **Ignoring the trend** — "we shipped 1.2 this release, the team
  is crushing it!" may be a sign of under-estimating, not of
  shipping more.
- **Velocity without context** — raw ratios without the story
  list are useless. Always include the per-story breakdown.

### Retrospectives

(See the **Required sections in a release retrospective** block
above for the file format. This section is the *why* and *how*.)

**Concept:** A retrospective is a structured reflection on a
release. The point is not to assign blame but to capture what was
learned so the next release can avoid the same mistakes and
replicate the same wins.

**When to write the retro:** Right after the release, while
context is fresh. A post-commit hook (or equivalent automation)
that triggers on a release tag is a good prompt — it nudges the
human to write the retro, but the writing is the human's job.

**The "what surprised us" section is the highest-value part.**
It's where real learning lives. It's the only section that can be
auto-generated (from commit analysis); the rest requires human
thought.

**Auto-generating "what surprised us" from git:** Look at commit
messages between the previous release tag and the current one.
Cluster by pattern:
- Bug-fix commits ("fix", "bug", "broken", "crash", "regression")
  → "more bug fixes than expected; here's what was broken"
- Documentation commits ("docs", "readme", "comment") → "documentation
  work was significant; we may be under-documenting day-to-day"
- Performance commits ("perf", "fast", "slow", "optim", "cache")
  → "performance was a concern, here's what we found"
- Dependency commits ("package.json", "requirements", "lib/") → "we
  updated or consolidated dependencies, here's why"
- Test commits ("test_", "spec", "add test") → presence or absence
  is a signal of test discipline

The output is real prose generated from actual history. Not
boilerplate. **Don't pretend the auto-generation is the whole
retro** — the "what we'd do differently" and "implications" sections
still require human thought.

**The retrospective is a public artifact.** Retros are part of
the project's transparency. Private ones are usually because they
say unflattering things, which is exactly the wrong reason to keep
them private. The project learns more from an honest public retro
than from a sanitized private one.

**Strong retrospective anti-patterns:**

- Generic advice that doesn't reference the actual release ("we
  should communicate better" — what does that mean for *this*
  release?)
- Skipped or stale retros (the value compounds over time; the
  third retro is more valuable than the first because you can
  start to see trends)
- Confessional tone (the retro is for learning, not for
  blaming)
- Skipping the "implications" section (the retro is a
  planning input; if it doesn't feed the next release, it's a
  diary entry)

### Releases and the planning convention

**Release naming:** Semantic versioning. `vMAJOR.MINOR.PATCH`.
Pre-release: `vMAJOR.MINOR.PATCH-rc1`. Tags only on a release
commit.

**Release-by-release structure:** Each release is a release
candidate first, then a stable tag. `v0.5.0-rc1` ships when the
work is done; `v0.5.0` ships when the rc has been validated.
This catches "I thought it was ready" bugs before the stable tag
is on everyone's machine.

**The 13-pt rule applies to release planning too:** A release
with 13+ unplanned pts should be split. A release should fit in
a story-points estimate where 1-3 are small releases, 5-8 are
typical, 13 means "split me."

**Velocity per release:** Tracked in the retro. The
"shipped pts / estimated pts" ratio. Velocity is per-release, not
per-story. A release with velocity 1.0 and 5 stories done is a
clean release. A release with velocity 0.4 and 13 stories
deferred is a "we learned we don't know how to scope" release.

### The post-commit hook (or equivalent)

**Pattern:** A small automation that runs on every commit (or
every release tag) and prompts the human to do the methodology
work. The point is to make the methodology practice survive
across sessions and other humans — without a nudge, the retro
gets forgotten.

**Minimum viable version:** On every commit, check if the commit
message or latest tag matches a version pattern (`vX.Y.Z`). If so,
print a non-blocking reminder: "release v0.5.0 detected — run
the retro command." The reminder is a nudge, not an enforcement.

**The reminder is non-blocking.** It exits 0 regardless. The
point is the nudge, not the enforcement. Hooks that fail the
commit on missing metadata are hostile; hooks that print a tip
are helpful.

**What gets posted:** Just a tip-line in the commit output. No
file modification, no git push, no global state.

### Methodology anti-patterns (the meta-meta list)

The methodology has its own anti-patterns, separate from the
doc-base anti-patterns. The big ones:

1. **The methodology is a tool, not a practice.** If the ledger
   lives in a spreadsheet that only the lead maintains, the
   methodology is a tool, not a practice. Put it in the repo.
2. **Skipping the 13-pt rule** — see "Story points" above.
3. **Writing the retro without data** — "velocity was 0.9, what
   surprised us was complexity" is filler. "We under-shipped
   by 10% because the bash 3.2 shim took 2 days" is a retro.
4. **Auto-generating everything in the retro** — the "what
   surprised us" can be auto-generated. The "what we'd do
   differently" and "implications" sections cannot. Don't
   pretend the auto-generation is the whole retro.
5. **Tracking velocity per story** — see "Velocity tracking"
   above.
6. **Recommitting the ledger on every release** — the ledger
   accumulates over the life of the project. Don't archive old
   stories; just mark them `deferred` or `done`.
7. **Gating the methodology behind a tool** — the practices work
   without any software — a text file, a spreadsheet, a notebook.
   The tooling is a convenience, not a prerequisite.
8. **Skipping the post-release retro** — the retro is what
   makes release N+1 better than release N. The "we'll do it
   later" pattern means it never happens.

---

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
