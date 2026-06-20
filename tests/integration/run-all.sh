#!/usr/bin/env bash
# run-all.sh — Run every integration test in this directory.
#
# Usage:
#   ./run-all.sh               # run with recorded sessions (fast)
#   ./run-all.sh --record      # re-record all sessions (slow; needs Docker)
#   ./run-all.sh --only name   # run a single test (by filename)
#   ./run-all.sh --verbose     # show test output, not just pass/fail

set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

# Args
RECORD=0
ONLY=""
VERBOSE=0
for arg in "$@"; do
  case "$arg" in
    --record)   RECORD=1 ;;
    --only)     shift; ONLY="${1:-}" ;;
    --verbose)  VERBOSE=1 ;;
    *)          echo "Unknown arg: $arg" >&2; exit 2 ;;
  esac
done

# Find all test files
if [[ -n "$ONLY" ]]; then
  tests=("$ONLY")
else
  tests=(test_*.sh)
fi

# Header
echo "══════════════════════════════════════════════════════"
echo "sparqr integration tests"
echo "══════════════════════════════════════════════════════"
echo "Mode:        $([[ $RECORD -eq 1 ]] && echo "RECORD" || echo "REPLAY")"
echo "Tests:       ${#tests[@]}"
echo ""

PASS=0
FAIL=0
for t in "${tests[@]}"; do
  if [[ ! -f "$t" ]]; then
    echo "  ! test file not found: $t"
    FAIL=$((FAIL+1))
    continue
  fi
  printf "  → %s ... " "$t"
  if [[ $VERBOSE -eq 1 ]]; then
    echo ""
    if RECORD=1 bash "./$t"; then
      echo "  ✓ $t"
      PASS=$((PASS+1))
    else
      echo "  ✗ $t"
      FAIL=$((FAIL+1))
    fi
  else
    if RECORD=1 bash "./$t" >/tmp/sparqr-test-$$.log 2>&1; then
      echo "✓"
      PASS=$((PASS+1))
    else
      echo "✗"
      echo "    (see /tmp/sparqr-test-$$.log for details)"
      FAIL=$((FAIL+1))
    fi
  fi
done

echo ""
echo "══════════════════════════════════════════════════════"
echo "  $PASS pass  ·  $FAIL fail"
echo "══════════════════════════════════════════════════════"

[[ $FAIL -eq 0 ]] || exit 1