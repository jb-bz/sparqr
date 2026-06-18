# Specification: <feature or system name>

> Stage 1 of SPARC+Design. The artifact downstream stages build on. Get this right; the rest follows.

## Goal

<one paragraph, restate the problem in your own words. Why does this exist? Who is it for? What does success look like?>

## User Stories

### US-1: <title>
As a <persona>, I want <action>, so that <benefit>.

**Acceptance Criteria:**
- Given <context>, When <action>, Then <outcome>.
- Given <context>, When <action>, Then <outcome>.
- Given <context>, When <action>, Then <outcome>.

### US-2: <title>
As a <persona>, I want <action>, so that <benefit>.

**Acceptance Criteria:**
- Given <context>, When <action>, Then <outcome>.
- Given <context>, When <action>, Then <outcome>.

### US-3: <title>
...

## Success Metrics

- **<metric name>**: <target value with units>. Example: "p95 latency < 200ms"
- **<metric name>**: <target>. Example: "test coverage ≥ 80%"
- **<metric name>**: <target>. Example: "zero P0 bugs in first 30 days"
- **<metric name>**: <target>. Example: "MAU ≥ 1000 within 90 days"

## Constraints

- **Language / framework**: <e.g. Python 3.11+, FastAPI>
- **Deployment**: <e.g. self-hosted on user's Mac, no external SaaS>
- **Data privacy**: <e.g. no PII leaves the device>
- **Rate limits**: <e.g. must work within Anthropic API tier 2>
- **Browser support**: <e.g. latest 2 versions of Chrome/Safari/Firefox>
- **Dependencies**: <e.g. no new npm packages without prior approval>

## Spike Tasks (unknowns to research first)

- [ ] <question 1 — e.g. "What OAuth provider does the user already use?">
- [ ] <question 2 — e.g. "Is the existing auth middleware capable of MFA, or do we need a new one?">
- [ ] <question 3 — e.g. "What's the actual data shape of X?">

## Out of Scope

- <feature X — explicitly NOT in this spec, save for v2>
- <feature Y — explicitly NOT in this spec, save for v2>
- <migration path for legacy data — not in this spec>

## Open Questions

- <any question that must be resolved before/during the next stage>
