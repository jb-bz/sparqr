# Completion: <feature or system name>

> Stage 6 of SPARC+Design. Verify everything works and is ready.

## Acceptance Criteria Verification

> Walk every acceptance criterion from the Specification. Each one must be PASS, FAIL, or DEFERRED with a one-line note.

### US-1: <title>

- [x] AC-1.1: <criterion> — **PASS** (verified by `test_signup_creates_user`)
- [x] AC-1.2: <criterion> — **PASS** (verified manually per `docs/manual-test-2026-06-17.md`)
- [x] AC-1.3: <criterion> — **PASS**

### US-2: <title>

- [x] AC-2.1: <criterion> — **PASS**
- [ ] AC-2.2: <criterion> — **FAIL** — <reason, see Open Issues>
- [x] AC-2.3: <criterion> — **PASS**

### US-3: <title>
…

## Success Metrics Check

> From the spec's "Success Metrics" section.

- [x] **<metric>**: target was <X>, measured <Y> — **MET**
- [x] **<metric>**: target was <X>, measured <Y> — **MET**
- [ ] **<metric>**: target was <X>, measured <Y> — **NOT MET** — <reason>

## Test Suite

```
$ pytest tests/ -v
==================== 47 passed in 2.34s ====================
```

- **All previous tests still pass**: yes
- **New tests added**: 12
- **Total test count**: 47
- **Coverage**: 87%

## Manual Testing

> For things tests can't cover.

- [x] Tested in Chrome (latest)
- [x] Tested in Safari (latest)
- [x] Tested in Firefox (latest)
- [x] Tested on mobile breakpoint (Chrome DevTools iPhone 14)
- [x] Keyboard-only navigation works
- [x] Screen reader (VoiceOver) — all interactive elements announced
- [x] No console errors in any test
- [x] Lighthouse score: 98 performance, 100 accessibility, 100 best-practices, 100 SEO

## Documentation

- [x] README updated with new feature
- [x] Usage examples in `docs/usage.md`
- [x] API reference in `docs/api.md` (or auto-generated OpenAPI)
- [x] Troubleshooting section in `docs/troubleshooting.md`
- [x] CHANGELOG.md updated
- [x] Migration guide (if breaking change)

## Deployment

- [x] Build succeeds (`make build`)
- [x] All env vars documented in `.env.example`
- [x] Database migrations tested up and down
- [x] Smoke test in staging environment
- [ ] Production deploy — see Open Issues

## Security Final Check

- [x] `pip-audit` — no high/critical CVEs
- [x] `gitleaks` — no secrets in diff
- [x] HTTPS-only verified
- [x] Rate limiting verified under load
- [x] OWASP top 10 walk-through — no findings

## Verification Checklist

> The summary. The orchestrator's validator checks that ≥80% of these are `[x]`.

- [x] All tests pass
- [x] All acceptance criteria met (or explicitly deferred with rationale)
- [x] All success metrics met (or explicitly not met with rationale)
- [x] Code reviewed (by you, even if solo)
- [x] No `TODO` or `FIXME` left in code
- [x] No commented-out code
- [x] No debug `print()` statements left in
- [x] Documentation updated
- [x] CHANGELOG updated
- [x] Security checks passed
- [x] Manual testing complete
- [x] Performance budgets met
- [x] Accessibility verified
- [x] Browser support verified
- [x] Deployment plan ready

## Open Issues

- <any items that didn't pass and what the plan is>
- <e.g. "AC-2.2 failed: rate limiting not effective under burst load. Tracked in issue #123. Will fix in v1.1.">

## What I learned

> One paragraph for the next person. Or yourself, in three months.

<what went well, what would you do differently, what surprised you>
