#!/usr/bin/env bash
# tests/test_gates.sh — Unit tests for lib/gates.sh (v0.3.0 story 1b-d).
#
# Tests gate decision logic in isolation. Uses tempdir with fake
# sparc_kanban_event_log implementation (so we don't need real Hermes).

set -uo pipefail

PASS=0
FAIL=0
ok()   { echo "  ✓ $*"; PASS=$((PASS+1)); }
fail() { echo "  ✗ $*"; FAIL=$((FAIL+1)); }

# Set up a temp config and stub out sparc_kanban_event_log so gates.sh
# reads from a fake comments file instead of running real hermes.
TMPDIR_TEST=$(mktemp -d)
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# Build a config file we control
write_config() {
  cat > "$TMPDIR_TEST/sparc.config.yaml"
}

# Stub: replace sparc_kanban_event_log with a version that reads from
# a fake_comments file in TMPDIR_TEST. We override after sourcing.
setup_fake_comments() {
  cat > "$TMPDIR_TEST/comments" <<'EOF'
2026-06-20 12:00:00	comment	[CONFIDENCE=0.95] looks good
2026-06-20 12:01:00	comment	[BLOCKED] needs review
EOF
}

# Source lib/gates.sh (which transitively brings in lib/config.sh and
# lib/kanban.sh for the helpers it uses).
# shellcheck source=../lib/gates.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/gates.sh"

# IMPORTANT: override sparc_kanban_event_log AFTER sourcing the libs.
# When lib/gates.sh sources lib/kanban.sh, that defines a real
# sparc_kanban_event_log. If we defined our stub before sourcing,
# the real one would clobber it. Override AFTER all sourcing.
sparc_kanban_event_log() {
  cat "$TMPDIR_TEST/comments"
}

# ───────────────────────────────────────────────────────────────────────
# TEST 1: approval gate always requires human
# ───────────────────────────────────────────────────────────────────────
echo "── approval gate ──"
write_config <<'EOF'
gates:
  spec:
    type: approval
EOF
sparc_gate_should_auto_approve "$TMPDIR_TEST/sparc.config.yaml" myboard t_x spec
[[ $? -eq 1 ]] && ok "approval: requires human" || fail "approval: should require human"

# ───────────────────────────────────────────────────────────────────────
# TEST 2: confidence gate with high confidence → auto-approve
# ───────────────────────────────────────────────────────────────────────
echo "── confidence gate (high confidence) ──"
setup_fake_comments  # [CONFIDENCE=0.95]
write_config <<'EOF'
gates:
  design:
    type: confidence
    threshold: 0.9
EOF
sparc_gate_should_auto_approve "$TMPDIR_TEST/sparc.config.yaml" myboard t_x design
[[ $? -eq 0 ]] && ok "confidence=0.95, threshold=0.9 → auto-approve" || fail "expected auto-approve"

# ───────────────────────────────────────────────────────────────────────
# TEST 3: confidence gate with low confidence → requires human
# ───────────────────────────────────────────────────────────────────────
echo "── confidence gate (low confidence) ──"
cat > "$TMPDIR_TEST/comments" <<'EOF'
2026-06-20 12:00:00	comment	[CONFIDENCE=0.5] uncertain
EOF
sparc_gate_should_auto_approve "$TMPDIR_TEST/sparc.config.yaml" myboard t_x design
[[ $? -eq 1 ]] && ok "confidence=0.5, threshold=0.9 → needs human" || fail "expected needs-human"

# ───────────────────────────────────────────────────────────────────────
# TEST 4: confidence gate with no confidence reported → needs human
# ───────────────────────────────────────────────────────────────────────
echo "── confidence gate (no marker) ──"
cat > "$TMPDIR_TEST/comments" <<'EOF'
2026-06-20 12:00:00	comment	no marker here
EOF
sparc_gate_should_auto_approve "$TMPDIR_TEST/sparc.config.yaml" myboard t_x design
[[ $? -eq 1 ]] && ok "no confidence marker → needs human" || fail "expected needs-human"

# ───────────────────────────────────────────────────────────────────────
# TEST 5: confidence gate with [CONFIDENCE: X] (colon-space format)
# ───────────────────────────────────────────────────────────────────────
echo "── confidence gate (colon-space format) ──"
cat > "$TMPDIR_TEST/comments" <<'EOF'
2026-06-20 12:00:00	comment	[CONFIDENCE: 0.95] alt format
EOF
sparc_gate_should_auto_approve "$TMPDIR_TEST/sparc.config.yaml" myboard t_x design
[[ $? -eq 0 ]] && ok "[CONFIDENCE: 0.95] format works" || fail "alt format broken"

# ───────────────────────────────────────────────────────────────────────
# TEST 6: sampling gate — statistical test
# ───────────────────────────────────────────────────────────────────────
echo "── sampling gate (statistical) ──"
write_config <<'EOF'
gates:
  refinement:
    type: sampling
    percent: 50
EOF
n_review=0
n_auto=0
for i in $(seq 1 100); do
  if sparc_gate_should_auto_approve "$TMPDIR_TEST/sparc.config.yaml" myboard t_x refinement; then
    n_auto=$((n_auto + 1))
  else
    n_review=$((n_review + 1))
  fi
done
echo "    sampling at 50% over 100 trials: review=$n_review, auto=$n_auto"
# Should be roughly 50/50 (allow generous bounds for randomness)
if [[ $n_review -ge 30 && $n_review -le 70 ]]; then
  ok "sampling distribution looks random (review in [30,70])"
else
  fail "sampling distribution looks wrong: review=$n_review (expected 30-70)"
fi

# ───────────────────────────────────────────────────────────────────────
# TEST 7: sampling at 0% → always auto-approve
# ───────────────────────────────────────────────────────────────────────
echo "── sampling gate (0%) ──"
write_config <<'EOF'
gates:
  refinement:
    type: sampling
    percent: 0
EOF
all_auto=1
for i in $(seq 1 20); do
  if ! sparc_gate_should_auto_approve "$TMPDIR_TEST/sparc.config.yaml" myboard t_x refinement; then
    all_auto=0
  fi
done
[[ $all_auto -eq 1 ]] && ok "sampling at 0% always auto-approves" || fail "sampling at 0% should always auto-approve"

# ───────────────────────────────────────────────────────────────────────
# TEST 8: sampling at 100% → always requires review
# ───────────────────────────────────────────────────────────────────────
echo "── sampling gate (100%) ──"
write_config <<'EOF'
gates:
  refinement:
    type: sampling
    percent: 100
EOF
all_review=1
for i in $(seq 1 20); do
  if sparc_gate_should_auto_approve "$TMPDIR_TEST/sparc.config.yaml" myboard t_x refinement; then
    all_review=0
  fi
done
[[ $all_review -eq 1 ]] && ok "sampling at 100% always requires review" || fail "sampling at 100% should always require review"

# ───────────────────────────────────────────────────────────────────────
# TEST 9: exception gate — no flag → auto-approve
# ───────────────────────────────────────────────────────────────────────
echo "── exception gate (no flag) ──"
cat > "$TMPDIR_TEST/comments" <<'EOF'
2026-06-20 12:00:00	comment	looks good, no issues
EOF
write_config <<'EOF'
gates:
  completion:
    type: exception
EOF
sparc_gate_should_auto_approve "$TMPDIR_TEST/sparc.config.yaml" myboard t_x completion
[[ $? -eq 0 ]] && ok "exception with no flag → auto-approve" || fail "expected auto-approve"

# ───────────────────────────────────────────────────────────────────────
# TEST 10: exception gate — [REVIEWER_FLAG] → needs human
# ───────────────────────────────────────────────────────────────────────
echo "── exception gate (flag) ──"
cat > "$TMPDIR_TEST/comments" <<'EOF'
2026-06-20 12:00:00	comment	[REVIEWER_FLAG] missing tests
EOF
sparc_gate_should_auto_approve "$TMPDIR_TEST/sparc.config.yaml" myboard t_x completion
[[ $? -eq 1 ]] && ok "[REVIEWER_FLAG] → needs human" || fail "expected needs-human"

# ───────────────────────────────────────────────────────────────────────
# TEST 11: exception gate — [BLOCKED] in comments → needs human
# ───────────────────────────────────────────────────────────────────────
echo "── exception gate (BLOCKED) ──"
cat > "$TMPDIR_TEST/comments" <<'EOF'
2026-06-20 12:00:00	comment	[BLOCKED] something wrong
EOF
sparc_gate_should_auto_approve "$TMPDIR_TEST/sparc.config.yaml" myboard t_x completion
[[ $? -eq 1 ]] && ok "[BLOCKED] → needs human" || fail "expected needs-human"

# ───────────────────────────────────────────────────────────────────────
# TEST 12: unknown gate type → default to approval (needs human)
# ───────────────────────────────────────────────────────────────────────
echo "── unknown gate type ──"
write_config <<'EOF'
gates:
  spec:
    type: rainbow-unicorn
EOF
sparc_gate_should_auto_approve "$TMPDIR_TEST/sparc.config.yaml" myboard t_x spec
[[ $? -eq 1 ]] && ok "unknown gate type → approval (safe default)" || fail "expected approval default"

# ───────────────────────────────────────────────────────────────────────
# TEST 13: missing gates section → default to approval
# ───────────────────────────────────────────────────────────────────────
echo "── missing gates section ──"
cat > "$TMPDIR_TEST/sparc.config.yaml" <<'EOF'
board: my-board
hitl_adapter: terminal
EOF
sparc_gate_should_auto_approve "$TMPDIR_TEST/sparc.config.yaml" myboard t_x spec
[[ $? -eq 1 ]] && ok "no gates: → approval" || fail "expected approval default"

# ───────────────────────────────────────────────────────────────────────
# TEST 14: sparc_gate_resolve_blocked echoes correctly
# ───────────────────────────────────────────────────────────────────────
echo "── sparc_gate_resolve_blocked output ──"
write_config <<'EOF'
gates:
  spec:
    type: approval
EOF
result=$(sparc_gate_resolve_blocked "$TMPDIR_TEST/sparc.config.yaml" myboard t_x spec)
[[ "$result" == "needs-human" ]] && ok "approval → 'needs-human'" || fail "got '$result'"

write_config <<'EOF'
gates:
  design:
    type: confidence
    threshold: 0.9
EOF
cat > "$TMPDIR_TEST/comments" <<'EOF'
2026-06-20 12:00:00	comment	[CONFIDENCE=0.95]
EOF
result=$(sparc_gate_resolve_blocked "$TMPDIR_TEST/sparc.config.yaml" myboard t_x design)
[[ "$result" == "auto-approve" ]] && ok "confidence high → 'auto-approve'" || fail "got '$result'"

# ───────────────────────────────────────────────────────────────────────
# TEST 15: prompt instructions for each gate type
# ───────────────────────────────────────────────────────────────────────
echo "── gate prompt instructions ──"
write_config <<'EOF'
gates:
  spec:
    type: approval
  design:
    type: confidence
    threshold: 0.85
  refinement:
    type: sampling
    percent: 25
  completion:
    type: exception
EOF
out=$(sparc_gate_prompt_instructions "$TMPDIR_TEST/sparc.config.yaml" spec)
[[ "$out" == *"Gate type: approval"* ]] && ok "approval prompt correct" || fail "got: $out"

out=$(sparc_gate_prompt_instructions "$TMPDIR_TEST/sparc.config.yaml" design)
[[ "$out" == *"Gate type: confidence"* && "$out" == *"0.85"* ]] && ok "confidence prompt correct" || fail "got: $out"

out=$(sparc_gate_prompt_instructions "$TMPDIR_TEST/sparc.config.yaml" refinement)
[[ "$out" == *"Gate type: sampling"* && "$out" == *"25%"* ]] && ok "sampling prompt correct" || fail "got: $out"

out=$(sparc_gate_prompt_instructions "$TMPDIR_TEST/sparc.config.yaml" completion)
[[ "$out" == *"Gate type: exception"* && "$out" == *"REVIEWER_FLAG"* ]] && ok "exception prompt correct" || fail "got: $out"

# ───────────────────────────────────────────────────────────────────────
# Summary
# ───────────────────────────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════════════"
echo "  $PASS pass  ·  $FAIL fail"
echo "══════════════════════════════════════════════════════"
[[ $FAIL -eq 0 ]]
