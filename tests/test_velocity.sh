#!/usr/bin/env bash
# tests/test_velocity.sh — Unit tests for bin/sparc-velocity (v0.4.1 story 4d).

set -uo pipefail

PASS=0
FAIL=0
ok()   { echo "  ✓ $*"; PASS=$((PASS+1)); }
fail() { echo "  ✗ $*"; FAIL=$((FAIL+1)); }

PKG_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VEL="$PKG_ROOT/bin/sparc-velocity"

if ! python3 -c "import yaml" 2>/dev/null; then
  echo "  ⚠  python3 pyyaml not available — skipping test_velocity.sh"
  exit 0
fi

TESTDIR=$(mktemp -d -t sparqr-velocity-test-XXXXXX)
cd "$TESTDIR"
trap "cd / && rm -rf $TESTDIR" EXIT

# ── 1. --help
echo "── 1. help ──"
out=$("$VEL" --help 2>&1)
echo "$out" | grep -qi "velocity" && ok "help mentions velocity" || fail "no help"

# ── 2. with no retros and no stories.yaml
echo "── 2. no data ──"
out=$("$VEL" 2>&1)
echo "$out" | grep -q "no retros" && ok "warns when no retros or stories" || fail "no warning"

# ── 3. with stories.yaml only
echo "── 3. stories-only mode ──"
mkdir -p .sparc
cat > .sparc/stories.yaml <<'EOF'
schema_version: 1
default_release: v0.5.0
stories:
  - id: aaa-111
    name: story A
    points: 3
    status: done
    release: v0.5.0
  - id: bbb-222
    name: story B
    points: 5
    status: in-progress
    release: v0.5.0
  - id: ccc-333
    name: story C
    points: 13
    status: deferred
    release: v0.5.0
EOF
out=$("$VEL" 2>&1)
echo "$out" | grep -q "v0.5.0" && ok "shows v0.5.0 release" || fail "no v0.5.0 in output"
echo "$out" | grep -qE "0\.[0-9]+x|1\.00x" && ok "shows velocity ratio" || fail "no ratio: $out"
echo "$out" | grep -q "1/  3" && ok "shows done/total (1 of 3)" || fail "no done/total: $out"

# ── 4. JSON output
echo "── 4. JSON output ──"
out=$("$VEL" --json 2>&1)
echo "$out" | python3 -c "import json, sys; d = json.loads(sys.stdin.read()); assert isinstance(d, list)" && ok "JSON output parses" || fail "JSON doesn't parse"
echo "$out" | python3 -c "import json, sys; d = json.loads(sys.stdin.read()); assert any(r.get('velocity') for r in d)" && ok "JSON has velocity data" || fail "JSON no velocity"

# ── 5. CSV output
echo "── 5. CSV output ──"
out=$("$VEL" --csv 2>&1)
echo "$out" | head -n 1 | grep -q "release,estimated,actual,velocity" && ok "CSV has header" || fail "CSV no header"
n=$(echo "$out" | wc -l | tr -d ' ')
[[ "$n" -ge 2 ]] && ok "CSV has $n rows" || fail "CSV only has $n rows"

# ── 6. with retros
echo "── 6. with retros ──"
mkdir -p docs/retrospectives
cat > docs/retrospectives/v0.4.0-rc1.md <<'EOF'
# v0.4.0-rc1 retro

- **Estimated:** 16 pts
- **Shipped:** 16 pts
EOF
out=$("$VEL" 2>&1)
echo "$out" | grep -q "v0.4.0-rc1" && ok "shows v0.4.0-rc1 from retro" || fail "no rc1 in output"

# ── 7. filter to specific release
echo "── 7. filter ──"
out=$("$VEL" v0.5.0 2>&1)
echo "$out" | grep -q "v0.5.0" && ok "filter shows v0.5.0" || fail "filter wrong"
echo "$out" | grep -q "v0.4.0-rc1" && fail "filter leaked other release" || ok "filter excludes other releases"

# ── Summary
echo ""
echo "══════════════════════════════════════════════════════"
echo "  $PASS pass  ·  $FAIL fail"
echo "══════════════════════════════════════════════════════"
[[ $FAIL -eq 0 ]]