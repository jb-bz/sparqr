## What does this change?

<!-- One sentence. -->

## Why?

<!-- One sentence on the workflow problem. -->

## How was it tested?

- [ ] `bash tests/test_setup.sh` passes
- [ ] `bash tests/test_kanban.sh` passes
- [ ] `bash tests/test_adapters.sh` passes
- [ ] `bash tests/test_e2e.sh` passes
- [ ] I ran the example in `examples/hello-sparc/` end-to-end
- [ ] I added a new test for this change

## Checklist

- [ ] `CHANGELOG.md` updated under `[Unreleased]`
- [ ] If this is a new HITL/notify adapter, it's registered in `lib/adapters/hitl/_registry.sh` / `lib/adapters/notify/_registry.sh`
- [ ] If this is a new CLI verb, it shows up in `sparc --help` and `sparc <verb> --help`
- [ ] If this changes public behavior, docs/ updated
