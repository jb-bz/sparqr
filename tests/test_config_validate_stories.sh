#!/usr/bin/env bash
# tests/test_config_validate_stories.sh — Tests for v0.4.1 story 4b
# (config-validate warns on 13-pt stories without failing).

set -uo pipefail

PASS=0
FAIL=0
ok()   { echo "  ✓ $*"; PASS=$((PASS+1)); }
fail() { echo "  ✗ $*"; FAIL=$((FAIL+1)); }

PKG_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="$PKG_ROOT/bin/sparc-config"

if ! python3 -c "import yaml" 2>/dev/null; then
  echo "  ⚠  python3 pyyaml not available — skipping"
  exit 0
fi

TESTDIR=$(mktemp -d -t sparqr-config-validate-XXXXXX)
cd "$TESTDIR"
trap "cd / && rm -rf $TESTDIR" EXIT

# Need a minimal sparc.config.yaml that matches the schema
cat > sparc.config.yaml <<'EOF'
board: test-board
hitl_adapter: terminal
profiles: {}
EOF

# ── 1. no stories.yaml → no warning
echo "── 1. no stories.yaml ──"
out=$("$CONFIG" validate 2>&1)
echo "$out" | grep -q "valid" && ok "config still validates" || fail "config didn't validate"
echo "$out" | grep -q "13-pt" && fail "warning fired when no stories" || ok "no warning when no stories.yaml"
[[ $? -eq 0 ]] && rc=0 || rc=$?

# ── 2. 13-pt story in planned → warning fires, exit 0
echo "── 2. 13-pt in planned ──"
mkdir -p .sparc
cat > .sparc/stories.yaml <<'EOF'
schema_version: 1
default_release: v0.4.1
stories:
  - id: big-001
    name: Big story
    points: 13
    status: planned
    release: v0.4.1
  - id: small-002
    name: Small story
    points: 3
    status: done
    release: v0.4.1
EOF
out=$("$CONFIG" validate 2>&1); rc=$?
echo "$out" | grep -q "13-pt" && ok "warning fires on 13-pt story" || fail "no warning"
echo "$out" | grep -q "big-001" && ok "warning names the story id" || fail "story id not in warning"
echo "$out" | grep -q "needs split" && ok "warning explains split needed" || fail "no split reminder"
[[ $rc -eq 0 ]] && ok "exit code is 0 (warn, not fail)" || fail "exit code is $rc"

# ── 3. 13-pt story already split → no warning
echo "── 3. 13-pt already split ──"
cat > .sparc/stories.yaml <<'EOF'
schema_version: 1
default_release: v0.4.1
stories:
  - id: big-001
    name: Big story
    points: 13
    status: planned
    release: v0.4.1
    sub_stories:
      - sub-001
      - sub-002
EOF
out=$("$CONFIG" validate 2>&1)
echo "$out" | grep -q "already split" && ok "split story gets 'already split' marker" || fail "no marker"

# ── 4. 13-pt in 'done' status → no warning (already shipped)
echo "── 4. 13-pt in done ──"
cat > .sparc/stories.yaml <<'EOF'
schema_version: 1
default_release: v0.4.1
stories:
  - id: big-001
    name: Big story
    points: 13
    status: done
    release: v0.4.1
EOF
out=$("$CONFIG" validate 2>&1)
echo "$out" | grep -q "13-pt" && fail "warning fires for done story" || ok "no warning for done story"

# ── 5. multiple 13-pt stories
echo "── 5. multiple 13-pt ──"
cat > .sparc/stories.yaml <<'EOF'
schema_version: 1
default_release: v0.4.1
stories:
  - id: big-001
    name: Story 1
    points: 13
    status: planned
    release: v0.4.1
  - id: big-002
    name: Story 2
    points: 13
    status: in-progress
    release: v0.4.1
  - id: small-003
    name: Story 3
    points: 5
    status: done
    release: v0.4.1
EOF
out=$("$CONFIG" validate 2>&1)
echo "$out" | grep -q "2 13-pt" && ok "warning counts multiple stories" || fail "no count"
echo "$out" | grep -q "big-001" && ok "names big-001" || fail "no big-001"
echo "$out" | grep -q "big-002" && ok "names big-002" || fail "no big-002"

# ── Summary
echo ""
echo "══════════════════════════════════════════════════════"
echo "  $PASS pass  ·  $FAIL fail"
echo "══════════════════════════════════════════════════════"
[[ $FAIL -eq 0 ]]