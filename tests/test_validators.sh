#!/usr/bin/env bash
# tests/test_validators.sh — Verify the stage validators accept good
# artifacts and reject bad ones. Uses real artifact files, no Hermes needed.
#
# Run: bash tests/test_validators.sh

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_ROOT="$(cd "$TEST_DIR/.." && pwd)"

# Use a tempdir for artifacts
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT
export SPARC_ARTIFACT_DISK_DIR="$TMPDIR/artifacts"
export SPARC_BOARD="test-board"

# Source lib
# shellcheck source=../lib/stages.sh
source "$PKG_ROOT/lib/stages.sh"
# shellcheck source=../lib/artifacts.sh
source "$PKG_ROOT/lib/artifacts.sh"
# shellcheck source=../lib/validators.sh
source "$PKG_ROOT/lib/validators.sh"

PASS=0
FAIL=0
ok()   { printf "  \033[32m✓\033[0m %s\n" "$*"; PASS=$((PASS+1)); }
fail() { printf "  \033[31m✗\033[0m %s\n" "$*"; FAIL=$((FAIL+1)); }
hdr()  { printf "\n\033[1m[%s]\033[0m\n" "$*"; }

# Helper: write an artifact
write_artifact() {
  local stage="$1" task_id="$2" content="$3"
  sparc_artifact_write "test-board" "$stage" "$task_id" "$content" >/dev/null
}

# ── spec: good passes, bad fails ──────────────────────────────────────
hdr "specification validator"
write_artifact "spec" "good" "# Specification: Test

## Goal
test goal

## User Stories
### US-1: x
As a user, I want x, so that y.

## Acceptance Criteria
- Given a, When b, Then c.

## Success Metrics
- test: 100%

## Constraints
- none

## Spike Tasks
- none

## Out of Scope
- nothing"
if sparc_validate_spec "test-board" "good" 2>/dev/null; then
  ok "good spec passes"
else
  fail "good spec should pass"
fi

write_artifact "spec" "bad-no-stories" "# Specification: Test

## Goal
test

## Success Metrics
- 1

## Constraints
- none"
if sparc_validate_spec "test-board" "bad-no-stories" 2>/dev/null; then
  fail "bad spec (no user stories) should fail"
else
  ok "bad spec (no user stories) correctly fails"
fi

# ── pseudocode: ≥5 numbered steps ──────────────────────────────────────
hdr "pseudocode validator"
write_artifact "pseudocode" "good" "# Pseudocode: Test

1. step 1
2. step 2
3. step 3
4. step 4
5. step 5
6. step 6

## Decision Points
### D1
- if x then y

## Data Structures
### S1
- field_a

## Edge Cases
- empty: ok"
if sparc_validate_pseudocode "test-board" "good" 2>/dev/null; then
  ok "good pseudocode passes"
else
  fail "good pseudocode should pass"
fi

write_artifact "pseudocode" "bad" "# Pseudocode: Test

1. only one step
2. only two"
if sparc_validate_pseudocode "test-board" "bad" 2>/dev/null; then
  fail "bad pseudocode (<5 steps) should fail"
else
  ok "bad pseudocode correctly fails"
fi

# ── architecture: Components + Data Flow + API ─────────────────────────
hdr "architecture validator"
write_artifact "architecture" "good" "# Architecture: Test

## Components
### C1
- owns: x

## Data Flow
### F1
1. a → b

## API Contract
### E1
- POST /x"
if sparc_validate_architecture "test-board" "good" 2>/dev/null; then
  ok "good architecture passes"
else
  fail "good architecture should pass"
fi

# ── completion: ≥80% checklist complete ───────────────────────────────
hdr "completion validator"
write_artifact "completion" "good" "# Completion: Test

## Verification Checklist
- [x] done 1
- [x] done 2
- [x] done 3
- [x] done 4
- [ ] not done

## What I learned
- nothing"
if sparc_validate_completion "test-board" "good" 2>/dev/null; then
  ok "good completion (80% checked) passes"
else
  fail "good completion should pass (4/5 = 80%)"
fi

write_artifact "completion" "bad" "# Completion: Test

## Verification Checklist
- [x] done 1
- [ ] not done
- [ ] not done
- [ ] not done
- [ ] not done"
if sparc_validate_completion "test-board" "bad" 2>/dev/null; then
  fail "bad completion (20% checked) should fail"
else
  ok "bad completion correctly fails"
fi

# ── Dispatcher: sparc_validate ────────────────────────────────────────
hdr "sparc_validate dispatcher"
if sparc_validate spec "test-board" "good" 2>/dev/null; then
  ok "sparc_validate spec dispatches correctly"
else
  fail "sparc_validate spec dispatch broken"
fi

if sparc_validate nosuchstage "test-board" "good" 2>/dev/null; then
  fail "sparc_validate should fail on unknown stage"
else
  ok "sparc_validate correctly rejects unknown stage"
fi

# ── Summary ────────────────────────────────────────────────────────────
printf "\n══════════════════════════════════════════════════════\n"
printf "  %d pass  ·  %d fail\n" "$PASS" "$FAIL"
printf "══════════════════════════════════════════════════════\n"

[[ "$FAIL" -eq 0 ]] || exit 1
