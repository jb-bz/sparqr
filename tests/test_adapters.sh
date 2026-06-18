#!/usr/bin/env bash
# tests/test_adapters.sh — Verify each HITL adapter defines the required
# three functions (probe, notify, await_reply) with the right signatures.
# Does NOT need any adapter's actual surface to be running.
#
# Run: bash tests/test_adapters.sh

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_ROOT="$(cd "$TEST_DIR/.." && pwd)"

PASS=0
FAIL=0
ok()   { printf "  \033[32m✓\033[0m %s\n" "$*"; PASS=$((PASS+1)); }
fail() { printf "  \033[31m✗\033[0m %s\n" "$*"; FAIL=$((FAIL+1)); }
hdr()  { printf "\n\033[1m[%s]\033[0m\n" "$*"; }

# Source the registry
# shellcheck source=../lib/adapters/hitl/_registry.sh
source "$PKG_ROOT/lib/adapters/hitl/_registry.sh"

# ── Each adapter defines probe/notify/await_reply ──────────────────────
hdr "HITL adapters define all 3 functions"
for adapter in $(hitl_list_adapters); do
  for fn in probe notify await_reply; do
    if declare -F "hitl_${adapter}_${fn}" >/dev/null; then
      ok "hitl_${adapter}_${fn}"
    else
      fail "hitl_${adapter}_${fn} not defined"
    fi
  done
done

# ── terminal probe returns 0 (always available) ───────────────────────
hdr "terminal probe always returns 0"
if hitl_terminal_probe; then
  ok "hitl_terminal_probe returned 0"
else
  fail "hitl_terminal_probe did not return 0"
fi

# ── tui probe returns 0 (file-based, always available) ────────────────
hdr "tui probe returns 0 (always available)"
if hitl_tui_probe; then
  ok "hitl_tui_probe returned 0"
else
  fail "hitl_tui_probe did not return 0"
fi

# ── webui/workspace/official-dashboard probes return 1 when not running ─
hdr "UI adapter probes return 1 when their surface is not running"
for adapter in webui workspace official-dashboard; do
  if hitl_${adapter}_probe; then
    warn_msg="  ! $adapter probe unexpectedly returned 0 (surface IS running? test env may not match)"
    printf "\033[33m%s\033[0m\n" "$warn_msg"
  else
    ok "$adapter probe correctly returned 1 (surface not running)"
  fi
done

# ── Summary ────────────────────────────────────────────────────────────
printf "\n══════════════════════════════════════════════════════\n"
printf "  %d pass  ·  %d fail\n" "$PASS" "$FAIL"
printf "══════════════════════════════════════════════════════\n"

[[ "$FAIL" -eq 0 ]] || exit 1
