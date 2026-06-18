# Refinement: <feature or system name>

> Stage 5 of SPARC+Design. TDD implementation, debugging, security hardening. The output is working, tested, secure code.

## What was built

<one paragraph: what code was added/modified, where, and why. Link to files using relative paths.>

## TDD Cycle

For each unit of behavior, follow RED → GREEN → REFACTOR. Record the cycle here.

### Cycle 1: <behavior — e.g. "AuthService.signup creates a user">
- **RED**: wrote `test_signup_creates_user`; ran; failed (no implementation). Commit: `<sha>`.
- **GREEN**: wrote minimal `AuthService.signup`. Ran tests; passed. Commit: `<sha>`.
- **REFACTOR**: extracted hashing into helper. Tests still pass. Commit: `<sha>`.

### Cycle 2: <behavior — e.g. "AuthService.signup rejects duplicate emails">
- **RED**: …
- **GREEN**: …
- **REFACTOR**: …

### Cycle 3: <behavior>
…

## Test Results

```
$ pytest tests/ -v --tb=short
==================== test session starts ====================
collected 47 items

tests/test_auth_service.py::test_signup_creates_user PASSED
tests/test_auth_service.py::test_signup_rejects_duplicate PASSED
tests/test_auth_service.py::test_login_returns_tokens PASSED
tests/test_auth_service.py::test_login_rejects_bad_password PASSED
…
==================== 47 passed in 2.34s ====================
```

- **Total tests**: 47
- **Pass**: 47
- **Fail**: 0
- **Skip**: 0
- **Coverage**: 87% (target was 80%)

## Code Changed

| File | Change | LOC | Notes |
|---|---|---|---|
| `src/auth/service.py` | new | 142 | AuthService class |
| `src/auth/routes.py` | new | 56 | FastAPI router |
| `src/auth/schemas.py` | new | 48 | Pydantic models |
| `tests/test_auth_service.py` | new | 124 | 12 tests, all pass |
| `src/main.py` | modified | +3 | register auth router |

## Security Hardening Checklist

- [ ] Input validation on all endpoints (Pydantic)
- [ ] Argon2id with proper parameters (memory cost, time cost, parallelism)
- [ ] JWT signing key from env, not hardcoded
- [ ] JWT expiration enforced
- [ ] Refresh tokens rotated on use
- [ ] Rate limiting on /auth/* (per-IP and per-account)
- [ ] No PII logged
- [ ] No stack traces leaked in error responses
- [ ] HTTPS-only in production (HSTS, secure cookies)
- [ ] SQLAlchemy parameterized queries (no string concat)
- [ ] Dependencies scanned (`pip-audit`, `safety`)
- [ ] Secrets scan (`gitleaks`, `trufflehog`)

## Debugging Log

Any non-obvious bugs that took more than 2 minutes to find. Use the systematic-debugging skill.

### Bug 1: <one-line>
- **Symptom**: <what we saw>
- **Investigation**: <what we tried, what ruled out>
- **Root cause**: <what it actually was>
- **Fix**: <the change>
- **Prevention**: <how to catch this earlier next time>

(If no non-obvious bugs, this section can be brief.)

## Performance Notes

- **Measured p50 / p95**: <values>
- **Budget met**: yes/no
- **If not, why**: …

## Open Items for Completion Stage

- <anything the Completion stage should verify or do>
