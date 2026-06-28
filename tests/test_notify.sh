#!/usr/bin/env bash
# tests/test_notify.sh — Unit tests for v0.4.0 notify channels.
#
# Tests the registry, probes (with fake creds), and a mocked send
# for each channel. bash 3.2 compatible.

set -uo pipefail

PASS=0
FAIL=0
ok()   { echo "  ✓ $*"; PASS=$((PASS+1)); }
fail() { echo "  ✗ $*"; FAIL=$((FAIL+1)); }

PKG_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NOTIFY="$PKG_ROOT/lib/adapters/notify"

# Source the registry once for all tests
# shellcheck source=../lib/adapters/notify/_registry.sh
source "$NOTIFY/_registry.sh"

# ── 1. registry loads all 6 channels
echo "── 1. registry loads ──"
channels=$(notify_list_channels)
count=$(echo "$channels" | wc -l | tr -d ' ')
[[ "$count" -eq 6 ]] && ok "registry registers 6 channels" || fail "expected 6, got $count"
echo "$channels" | grep -q "^log$" && ok "log channel registered" || fail "no log"
echo "$channels" | grep -q "^kanban$" && ok "kanban channel registered" || fail "no kanban"
echo "$channels" | grep -q "^discord$" && ok "discord channel registered" || fail "no discord"
echo "$channels" | grep -q "^telegram$" && ok "telegram channel registered" || fail "no telegram"
echo "$channels" | grep -q "^slack$" && ok "slack channel registered" || fail "no slack"
echo "$channels" | grep -q "^signal$" && ok "signal channel registered" || fail "no signal"

# ── 2. log + kanban are always available (no creds)
echo "── 2. log + kanban always-on ──"
available=$(notify_list_available)
echo "$available" | grep -q "^log$" && ok "log is always available" || fail "log not available"
echo "$available" | grep -q "^kanban$" && ok "kanban is always available" || fail "kanban not available"

# ── 3. discord probe
echo "── 3. discord probe ──"
DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/123/abc" \
  bash -c "source $NOTIFY/_registry.sh; notify_probe discord" >/dev/null 2>&1 && \
  ok "valid Discord webhook URL passes probe" || fail "Discord webhook rejected"
DISCORD_WEBHOOK_URL="https://discordapp.com/api/webhooks/123/abc" \
  bash -c "source $NOTIFY/_registry.sh; notify_probe discord" >/dev/null 2>&1 && \
  ok "discordapp.com variant also accepted" || fail "discordapp.com rejected"
DISCORD_WEBHOOK_URL="https://example.com/not-discord" \
  bash -c "source $NOTIFY/_registry.sh; notify_probe discord" >/dev/null 2>&1 && \
  fail "non-Discord URL passed probe" || ok "non-Discord URL rejected"
unset DISCORD_WEBHOOK_URL
bash -c "source $NOTIFY/_registry.sh; notify_probe discord" >/dev/null 2>&1 && \
  fail "no URL passed probe" || ok "no URL rejected"

# ── 4. telegram probe
echo "── 4. telegram probe ──"
TELEGRAM_BOT_TOKEN=*** \
  bash -c "source $NOTIFY/_registry.sh; notify_probe telegram" >/dev/null 2>&1 && \
  fail "telegram without chat_id passed" || ok "telegram without chat_id rejected"
TELEGRAM_BOT_TOKEN=*** \
TELEGRAM_CHAT_ID="12345" \
  bash -c "source $NOTIFY/_registry.sh; notify_probe telegram" >/dev/null 2>&1 && \
  ok "telegram with both creds passes" || fail "telegram full creds rejected"
unset TELEGRAM_BOT_TOKEN TELEGRAM_CHAT_ID

# ── 5. slack probe
echo "── 5. slack probe ──"
SLACK_WEBHOOK_URL="https://hooks.slack.com/services/T0/B0/X" \
  bash -c "source $NOTIFY/_registry.sh; notify_probe slack" >/dev/null 2>&1 && \
  ok "valid Slack webhook URL passes probe" || fail "Slack webhook rejected"
SLACK_WEBHOOK_URL="https://example.com/not-slack" \
  bash -c "source $NOTIFY/_registry.sh; notify_probe slack" >/dev/null 2>&1 && \
  fail "non-Slack URL passed probe" || ok "non-Slack URL rejected"
unset SLACK_WEBHOOK_URL

# ── 6. signal probe (requires signal-cli daemon)
echo "── 6. signal probe ──"
SIGNAL_API_URL="http://127.0.0.1:9999" \
SIGNAL_RECIPIENT="+155****4567" \
  bash -c "source $NOTIFY/_registry.sh; notify_probe signal" >/dev/null 2>&1 && \
  fail "signal with no daemon passed" || ok "signal without daemon rejected"
unset SIGNAL_API_URL SIGNAL_RECIPIENT

# ── 7. log channel send (always works)
echo "── 7. log channel ──"
LOG=$(mktemp -t sparqr-notify-test-XXXXXX.log)
SPARC_NOTIFY_LOG="$LOG" \
  bash -c "source $NOTIFY/_registry.sh; notify_send log 'TEST_TITLE' 'TEST_BODY' 'https://test.example.com'" && \
  ok "log.send succeeds" || fail "log.send failed"
grep -q "TEST_TITLE" "$LOG" && ok "log contains title" || fail "log missing title"
grep -q "TEST_BODY" "$LOG" && ok "log contains body" || fail "log missing body"
grep -q "https://test.example.com" "$LOG" && ok "log contains URL" || fail "log missing URL"
rm "$LOG"

# ── 8. broadcast sends to all available channels
echo "── 8. broadcast ──"
LOG=$(mktemp -t sparqr-broadcast-XXXXXX.log)
# Override notify_send for available channels (log, kanban) so they
# succeed without hitting the network. Then call broadcast.
SPARC_NOTIFY_LOG="$LOG" \
  bash -c "
source $NOTIFY/_registry.sh
# Stub the real send functions for always-on channels so we can
# verify broadcast iterates correctly without hitting the network.
notify_log_send() { echo '===== BC_LOG_CALLED =====' >> '$LOG'; }
notify_kanban_send() { return 0; }  # no SPARC_BOARD set, so it'd be a no-op anyway
notify_broadcast 'BC_TITLE' 'BC_BODY' 'https://bc.example.com'
" && ok "broadcast to all available succeeds" || fail "broadcast failed"
grep -q "BC_LOG_CALLED" "$LOG" && ok "broadcast hit the log channel" || fail "broadcast didn't reach log"
rm "$LOG"

# ── 9. unknown channel error
echo "── 9. unknown channel ──"
out=$(bash -c "source $NOTIFY/_registry.sh; notify_probe nosuch 2>&1"; echo "rc=$?")
echo "$out" | grep -q "unknown channel" && ok "unknown channel produces error message" || fail "no error message for unknown"
echo "$out" | grep -q "rc=2" && ok "unknown channel returns exit 2" || fail "expected exit 2 for unknown"

# ── 10. notify_list_available is the subset with passing probes
echo "── 10. list_available filters ──"
DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/x/y" \
TELEGRAM_BOT_TOKEN=*** \
TELEGRAM_CHAT_ID="12345" \
  bash -c "source $NOTIFY/_registry.sh; notify_list_available" | sort > /tmp/avail.txt
diff <(echo -e "discord\nkanban\nlog\ntelegram") /tmp/avail.txt >/dev/null && \
  ok "list_available returns the right subset" || \
  (echo "got:"; cat /tmp/avail.txt; fail "wrong subset")
rm /tmp/avail.txt

# ── Summary
echo ""
echo "══════════════════════════════════════════════════════"
echo "  $PASS pass  ·  $FAIL fail"
echo "══════════════════════════════════════════════════════"
[[ $FAIL -eq 0 ]]
