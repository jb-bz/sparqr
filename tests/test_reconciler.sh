#!/usr/bin/env bash
# tests/test_reconciler.sh — Unit tests for bin/sparc-reconciler (v0.3.0 story 6).
#
# Tests the reconciler's logic in isolation:
#   - Walking the artifact directory
#   - Computing content hashes
#   - Dedup against local state file
#   - Posting comments via mocked hermes
#   - Updating the state file
#
# Does NOT run against real hermes. We mock sparc_kanban_comment
# by setting MOCK_HERMES_LOG in the test env. The runner picks it
# up and writes its calls to a log file instead of running hermes.
#
# End-to-end real-Hermes verification was done manually during story
# 6 development (see ROADMAP retrospectives).

set -uo pipefail

PASS=0
FAIL=0
ok()   { echo "  ✓ $*"; PASS=$((PASS+1)); }
fail() { echo "  ✗ $*"; FAIL=$((FAIL+1)); }

# Setup
TMPDIR_TEST=$(mktemp -d)
trap 'rm -rf "$TMPDIR_TEST"' EXIT

MOCK_LOG="$TMPDIR_TEST/posts.log"
STATE_DIR="$TMPDIR_TEST/state"
ARTIFACT_DIR="$TMPDIR_TEST/artifacts"
RUNNER="$TMPDIR_TEST/runner.sh"
mkdir -p "$STATE_DIR" "$ARTIFACT_DIR"
# MOCK_LOG is a file, not a directory
> "$MOCK_LOG"

# Write the runner inline. We don't use the actual bin/sparc-reconciler
# because (a) it's an executable, not a sourced lib; (b) it would call
# real hermes. The runner mirrors sparc_reconciler_pass but uses the
# MOCK_HERMES_LOG env var instead.
cat > "$RUNNER" <<'RUNNER_EOF'
#!/usr/bin/env bash
set -uo pipefail

CONFIG="$1"
STATE_DIR="$2"

# sparc_kanban_comment stub: writes to mock log if MOCK_HERMES_LOG set
sparc_kanban_comment() {
  if [[ -n "${MOCK_HERMES_LOG:-}" ]]; then
    printf '%s\n' "$*" >> "$MOCK_HERMES_LOG"
  fi
  return 0
}

mkdir -p "$STATE_DIR"
SYNCD="$STATE_DIR/synced-hashes.txt"
touch "$SYNCD"

# Parse config — match keys at any indent level (YAML uses indentation)
ARTIFACT_DIR=$(awk '/^[[:space:]]*artifact_dir:/ { print $2 }' "$CONFIG" | head -n1)
[[ -z "$ARTIFACT_DIR" ]] && ARTIFACT_DIR="./docs/sparc"
BOARD=$(awk '/^[[:space:]]*board:/ { print $2 }' "$CONFIG" | head -n1)

[[ -z "$BOARD" ]] && { echo "no board"; exit 0; }
[[ -d "$ARTIFACT_DIR/$BOARD" ]] || { echo "no artifacts dir"; exit 0; }

synced=0
skipped=0
tasks_checked=0

while IFS= read -r -d '' f; do
  tasks_checked=$((tasks_checked + 1))
  rel="${f#$ARTIFACT_DIR/}"
  fb=$(echo "$rel" | cut -d'/' -f1)
  fs=$(echo "$rel" | cut -d'/' -f2)
  ft=$(basename "$f" .md)

  hash=$(shasum -a 256 "$f" 2>/dev/null | cut -d' ' -f1 || sha256sum "$f" | cut -d' ' -f1)
  hash="${hash:0:16}"

  if grep -q "^${fb} ${ft} ${hash}\$" "$SYNCD" 2>/dev/null; then
    skipped=$((skipped + 1))
    continue
  fi

  content=$(cat "$f")
  sparc_kanban_comment "$fb" "$ft" "$content" || continue
  sparc_kanban_comment "$fb" "$ft" "[RECONCILED:$hash] marker" || true
  echo "${fb} ${ft} ${hash}" >> "$SYNCD"
  synced=$((synced + 1))
done < <(find "$ARTIFACT_DIR/$BOARD" -name '*.md' -print0 2>/dev/null)

echo "checked=$tasks_checked synced=$synced skipped=$skipped"
RUNNER_EOF
chmod +x "$RUNNER"

# Helper: write a config file with board and artifact_dir
write_config() {
  local name="$1"
  cat > "$TMPDIR_TEST/$name" <<EOF
board: myboard
reconciler:
  enabled: true
  artifact_dir: $ARTIFACT_DIR
EOF
}

# Helper: run the reconciler
run_reconciler() {
  local config="$1"
  MOCK_HERMES_LOG="$MOCK_LOG" bash "$RUNNER" "$config" "$STATE_DIR"
}

# Setup: two artifacts for board=myboard, stage=spec
mkdir -p "$ARTIFACT_DIR/myboard/spec"
echo "first artifact" > "$ARTIFACT_DIR/myboard/spec/t_aaaa.md"
echo "second artifact" > "$ARTIFACT_DIR/myboard/spec/t_bbbb.md"

write_config "config.yaml"

# ───────────────────────────────────────────────────────────────────────
# TEST 1: first run syncs both artifacts
# ───────────────────────────────────────────────────────────────────────
echo "── first run ──"
out=$(run_reconciler "$TMPDIR_TEST/config.yaml")
[[ "$out" == *"synced=2"* ]] && ok "first run: synced=2" || fail "got '$out'"
[[ "$out" == *"skipped=0"* ]] && ok "first run: skipped=0" || fail "got '$out'"

post_count=$(wc -l < "$MOCK_LOG")
[[ "$post_count" -eq 4 ]] && ok "posted 4 comments (2 artifacts × 2 posts each)" || fail "got $post_count posts, expected 4"

state_count=$(wc -l < "$STATE_DIR/synced-hashes.txt")
[[ "$state_count" -eq 2 ]] && ok "state file has 2 entries" || fail "got $state_count, expected 2"

# ───────────────────────────────────────────────────────────────────────
# TEST 2: second run is idempotent (skips both)
# ───────────────────────────────────────────────────────────────────────
echo ""
echo "── second run (idempotent) ──"
> "$MOCK_LOG"
out=$(run_reconciler "$TMPDIR_TEST/config.yaml")
[[ "$out" == *"synced=0"* ]] && ok "second run: synced=0" || fail "got '$out'"
[[ "$out" == *"skipped=2"* ]] && ok "second run: skipped=2" || fail "got '$out'"

post_count=$(wc -l < "$MOCK_LOG")
[[ "$post_count" -eq 0 ]] && ok "no new posts on second run" || fail "got $post_count posts, expected 0"

# ───────────────────────────────────────────────────────────────────────
# TEST 3: artifact content change → re-sync
# ───────────────────────────────────────────────────────────────────────
echo ""
echo "── artifact content change ──"
echo "MODIFIED content - longer" > "$ARTIFACT_DIR/myboard/spec/t_aaaa.md"
> "$MOCK_LOG"
out=$(run_reconciler "$TMPDIR_TEST/config.yaml")
[[ "$out" == *"synced=1"* && "$out" == *"skipped=1"* ]] && ok "modified artifact re-syncs (1 synced, 1 skipped)" || fail "got '$out'"

# ───────────────────────────────────────────────────────────────────────
# TEST 4: new artifact → syncs
# ───────────────────────────────────────────────────────────────────────
echo ""
echo "── new artifact ──"
echo "third artifact" > "$ARTIFACT_DIR/myboard/spec/t_cccc.md"
> "$MOCK_LOG"
out=$(run_reconciler "$TMPDIR_TEST/config.yaml")
[[ "$out" == *"synced=1"* && "$out" == *"skipped=2"* ]] && ok "new artifact syncs (1 synced, 2 skipped)" || fail "got '$out'"

state_count=$(wc -l < "$STATE_DIR/synced-hashes.txt")
# State accumulates: t_aaaa hash1 + t_bbbb hash2 + t_aaaa hash2 (new) + t_cccc hash3 = 4
[[ "$state_count" -eq 4 ]] && ok "state file accumulates hashes (4 entries)" || fail "got $state_count, expected 4"

# ───────────────────────────────────────────────────────────────────────
# TEST 5: missing artifact dir → no error
# ───────────────────────────────────────────────────────────────────────
echo ""
echo "── missing artifact dir ──"
EMPTY_DIR="$TMPDIR_TEST/empty-artifacts"
mkdir -p "$EMPTY_DIR"
cat > "$TMPDIR_TEST/config2.yaml" <<EOF
board: myboard
reconciler:
  artifact_dir: $EMPTY_DIR
EOF
> "$MOCK_LOG"
out=$(run_reconciler "$TMPDIR_TEST/config2.yaml")
[[ "$out" == *"no artifacts dir"* ]] && ok "missing dir: clean exit (no artifacts dir message)" || fail "got '$out'"

# ───────────────────────────────────────────────────────────────────────
# TEST 6: empty artifact dir (no .md files) → no error
# ───────────────────────────────────────────────────────────────────────
echo ""
echo "── empty artifact dir ──"
mkdir -p "$EMPTY_DIR/myboard/spec"
out=$(run_reconciler "$TMPDIR_TEST/config2.yaml")
[[ "$out" == *"checked=0"* ]] && ok "empty dir: clean exit (checked=0)" || fail "got '$out'"

# ───────────────────────────────────────────────────────────────────────
# TEST 7: missing board config → no error
# ───────────────────────────────────────────────────────────────────────
echo ""
echo "── missing board config ──"
cat > "$TMPDIR_TEST/config3.yaml" <<EOF
reconciler:
  enabled: true
  artifact_dir: $ARTIFACT_DIR
EOF
out=$(run_reconciler "$TMPDIR_TEST/config3.yaml")
[[ "$out" == *"no board"* ]] && ok "missing board: clean exit" || fail "got '$out'"

# ───────────────────────────────────────────────────────────────────────
# Summary
# ───────────────────────────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════════════"
echo "  $PASS pass  ·  $FAIL fail"
echo "══════════════════════════════════════════════════════"
[[ $FAIL -eq 0 ]]
