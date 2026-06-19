# Contributing to Hermes SPARC Orchestration Package

Thanks for your interest in making this package better. The maintainers welcome contributions of all sizes — bug reports, docs, new stage definitions, new HITL/notify adapters, and tests.

## Ground rules

1. **Be kind.** This is a small project; we're all here because we want better multi-agent tooling. Assume good faith.
2. **Write tests for behavior changes.** New stage, new adapter, new CLI verb — bring a test.
3. **Match the existing style.** Shell scripts use `set -euo pipefail`, 2-space indent, lowercase functions, `snake_case` vars. Skills follow the Hermes SKILL.md frontmatter spec.
4. **Don't break the public CLI.** Anything reachable from `sparc <subcommand>` is a public surface. Add new things; deprecate old things with a one-version warning.
5. **Keep it portable.** macOS and Linux are first-class. Windows is best-effort (the package itself is bash, not Python). Test on at least one of macOS/Linux before submitting.

## How to contribute

### Reporting bugs

Open an issue using the **Bug Report** template. Include:
- Hermes Agent version (`hermes --version`)
- The exact `sparc --version` output
- The exact command you ran and the exact output
- A minimal `sparc.config.yaml` (with secrets redacted)
- Your `hermes kanban boards list` and `hermes profile list` output

### Suggesting a feature

Open an issue using the **Feature Request** template. Explain the *workflow* that doesn't work today, not just the *feature* you want. A real user story beats a hypothetical API.

### Submitting code

1. Fork the repo, create a branch off `main` named `feat/<short-name>` or `fix/<short-name>`
2. Make your change. Add tests. Update CHANGELOG.md under `[Unreleased]`
3. Run the full test suite: `bash tests/test_setup.sh && bash tests/test_kanban.sh && bash tests/test_adapters.sh && bash tests/test_e2e.sh`
4. Open a pull request. Fill in the PR template. Reference any related issues with `Fixes #123`

### Adding a new HITL adapter

See `docs/HITL.md` — "Authoring a HITL adapter" section. Ship the adapter under `lib/adapters/hitl/<name>.sh`, expose one function `hitl_<name>_notify` and one `hitl_<name>_await_reply`, add it to `lib/adapters/hitl/_registry.sh`, and add a test under `tests/test_adapters.sh`.

### Adding a new notify channel

### Adding a notify channel

Notify channels (chat-gateway pings) are planned for **v0.2.0** — they live in a separate `lib/adapters/notify/` directory that doesn't exist yet in v0.1.0. If you want to add one today, see the "Adding a chat-gateway notifier" section in [HITL.md](docs/HITL.md) for the recommended workaround pattern using a custom HITL adapter.

### Adding a new SPARC stage

See `docs/ADDING-STAGES.md`. Stages are pure data (order, role, skill, profile, template) — you should not need to touch orchestrator code.

## Code review

- Maintainers will review within ~3 business days
- Reviews focus on correctness, edge cases, and tests — not style nits
- Once approved, the maintainer will squash-merge

## Release process

- `main` is always releasable
- Versions are tagged `vMAJOR.MINOR.PATCH`
- Bump MINOR for new features, PATCH for bug fixes
- CHANGELOG.md is updated in the same PR as the change
- Releases are cut by a maintainer; the GitHub release notes link to the changelog entry

## Code of conduct

Be the kind of person you'd want to debug with at 2am. That's it.
