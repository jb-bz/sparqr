---
name: sparc-stage-spec
description: SPARC+Design Specification stage. Decompose goals into user stories, acceptance criteria, success metrics, and constraints. Used by the sparc-spec profile.
version: 0.1.0
author: Hermes SPARC Package
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [sparc, stage, specification, requirements]
    related_skills: [sparc-pipeline-orchestrator, sparc-stage-helpers]
    category: software-development
---

# SPARC Stage 1 — Specification

You are running the **Specification** stage of the SPARC+Design pipeline. Your job is to take a goal (and any upstream context) and produce a `specification.md` that downstream stages can act on without ambiguity.

## What "good" looks like

A good specification:

1. Has **3-7 user stories** in `As a <persona>, I want <action>, so that <benefit>` form. Not 20 — 3-7.
2. Each story has **2-5 acceptance criteria** in `Given/When/Then` form, all measurable.
3. **Success metrics** are quantitative (latency, error rate, test coverage, MAU, etc.) — not "works well".
4. **Constraints** are explicit (framework, language, deployment target, rate limits, data privacy).
5. **Unknowns** are listed as spike tasks, not papered over.

## Anti-patterns to avoid

- ❌ "The system should be fast" — unmeasurable
- ❌ "Users will like it" — unmeasurable
- ❌ Acceptance criteria that paraphrase the story ("the user can log in" — to what?)
- ❌ Skipping unknowns ("we'll figure out the auth model later")
- ❌ Putting technical implementation in the spec (that's for architecture)
- ❌ Putting UI in the spec (that's for design)

## Template

Use this exact structure (see `templates/specification.md` for the full template with field guidance):

```markdown
# Specification: <feature or system name>

## Goal
<one paragraph, restate the problem in your own words>

## User Stories
### US-1: <title>
As a <persona>, I want <action>, so that <benefit>.
**Acceptance Criteria:**
- Given <context>, When <action>, Then <outcome>.
- …

### US-2: …

## Success Metrics
- <metric>: <target value>
- …

## Constraints
- <language, framework, deployment, etc.>

## Spike Tasks (unknowns to research first)
- [ ] <question>
- [ ] …

## Out of Scope
- <explicitly NOT in this spec>
```

## Validation (enforced by the orchestrator)

The orchestrator will not advance to the Design stage unless your specification passes all three checks:

- Contains at least one `As a` or `Given/When/Then` line
- Contains a `## Acceptance Criteria` section
- Contains a `## Success Metrics` section

If you write a spec that fails validation, the orchestrator will redirect you. Listen to its guidance.

## Reference

- SPARC upstream: https://github.com/ruvnet/sparc
- See `templates/specification.md` for the full template
- See `lib/validators.sh` for the exact validation rules
