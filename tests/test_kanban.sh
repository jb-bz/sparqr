#!/usr/bin/env bash
# tests/test_kanban.sh — Verify the lib/kanban.sh wrapper's interface.
# Does NOT need a running Hermes — we mock the hermes CLI.
#
# Run: bash tests/test_kanban.sh

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_ROOT="$(cd "$TEST_DIR/.." && pwd)"

# Set up a fake hermes binary on PATH
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT
mkdir -p "$TMPDIR/bin"
cat > "$TMPDIR/bin/hermes" <<'MOCK_EOF'
#!/usr/bin/env bash
# Mock hermes — echoes args, exits 0.
echo "MOCK hermes called: $*"
exit 0
MOCK_EOF
chmod +x "$TMPDIR/bin/hermes"
export PATH="$TMPDIR/bin:$PATH"
export SPARC_HERMES_BIN="$TMPDIR/bin/hermes"

# Source the lib
# shellcheck source=../lib/kanban.sh
source "$PKG_ROOT/lib/kanban.sh"

PASS=0
FAIL=0
ok()   { printf "  \033[32m✓\033[0m %s\n" "$*"; PASS=$((PASS+1)); }
fail() { printf "  \033[31m✗\033[0m %s\n" "$*"; FAIL=$((FAIL+1)); }
hdr()  { printf "\n\033[1m[%s]\033[0m\n" "$*"; }

# ── Function existence ────────────────────────────────────────────────
hdr "kanban wrapper functions exist"
for fn in sparc_kanban_board_init sparc_kanban_create_task sparc_kanban_link \
          sparc_kanban_set_status sparc_kanban_comment sparc_kanban_block \
          sparc_kanban_unblock sparc_kanban_complete \
          sparc_kanban_watch_ready sparc_kanban_watch_blocked; do
  if declare -F "$fn" >/dev/null; then
    ok "$fn defined"
  else
    fail "$fn missing"
  fi
done

# ── board_init: idempotent, handles missing board ─────────────────────
hdr "board_init behavior"
# First call: should try to create (since board doesn't exist in mock)
out=$(sparc_kanban_board_init "test-board" --name "Test Board" --icon "🎯" 2>&1) || true
if echo "$out" | grep -qE "(creating|already exists)"; then
  ok "board_init output is sensible"
else
  fail "board_init output: $out"
fi

# ── create_task with parent ───────────────────────────────────────────
hdr "create_task with parent"
out=$(sparc_kanban_create_task "test-board" "spec" "Build a CLI" "TASK-001" 2>&1) || true
if echo "$out" | grep -q "MOCK hermes called"; then
  ok "create_task invoked hermes CLI"
else
  fail "create_task did not invoke hermes: $out"
fi

# ── block sets status and adds comment ────────────────────────────────
hdr "block sets status + comment"
out=$(sparc_kanban_block "test-board" "TASK-001" "needs review" 2>&1) || true
mocks_called=$(echo "$out" | grep -c "MOCK hermes called" || true)
if [[ "$mocks_called" -ge 2 ]]; then
  ok "block invoked hermes (>= 2 calls: set status + comment)"
else
  fail "block only made $mocks_called hermes call(s): $out"
fi

# ── complete sets status to done ──────────────────────────────────────
hdr "complete sets status to done"
out=$(sparc_kanban_complete "test-board" "TASK-001" 2>&1) || true
if echo "$out" | grep -qE "(set|update) .* --status done"; then
  ok "complete set status=done"
else
  fail "complete output: $out"
fi

# ── Summary ────────────────────────────────────────────────────────────
printf "\n══════════════════════════════════════════════════════\n"
printf "  %d pass  ·  %d fail\n" "$PASS" "$FAIL"
printf "══════════════════════════════════════════════════════\n"

[[ "$FAIL" -eq 0 ]] || exit 1
