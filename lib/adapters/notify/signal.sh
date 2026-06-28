# lib/adapters/notify/signal.sh — Notify channel: Signal via signal-cli REST API.
#
# Posts notifications to a Signal chat (DM or group) using
# signal-cli's REST API. Requires running signal-cli with
# `--http-enabled` mode. This is a non-official client; the official
# Signal Desktop app doesn't expose a public notification API.
#
# Setup:
#   1. Install signal-cli: https://github.com/AsamK/signal-cli
#   2. Register an account: signal-cli -u +1XXX register
#   3. Start the daemon: signal-cli -u +1XXX daemon --http enabled
#   4. Set SIGNAL_API_URL=http://127.0.0.1:8080 in your env
#   5. Set SIGNAL_RECIPIENT=+1XXX (your own number) or a group ID
#
# Env vars (required):
#   SIGNAL_API_URL    — base URL of signal-cli REST API
#                        (default: http://127.0.0.1:8080)
#   SIGNAL_RECIPIENT  — phone number or group ID to send to
#
# Optional:
#   SIGNAL_ACCOUNT    — the signal-cli account (default: "self" —
#                       uses the only configured account)

# notify_signal_probe
# Returns 0 if both SIGNAL_API_URL and SIGNAL_RECIPIENT are set.
notify_signal_probe() {
  if [[ -z "${SIGNAL_API_URL:-}" && "${SIGNAL_API_URL_DEFAULT:-1}" == "1" ]]; then
    # Default API URL is fine if signal-cli is reachable
    SIGNAL_API_URL="http://127.0.0.1:8080"
  fi
  if [[ -z "${SIGNAL_RECIPIENT:-}" ]]; then
    return 1
  fi
  # Probe by hitting the /v1/about endpoint
  local url="${SIGNAL_API_URL:-http://127.0.0.1:8080}"
  if ! curl -fsS --max-time 2 "$url/v1/about" >/dev/null 2>&1; then
    return 1
  fi
  return 0
}

# notify_signal_send <title> <body> [<url>]
# Sends a message via signal-cli's send endpoint.
notify_signal_send() {
  local title="$1" body="$2" url="${3:-}"
  if ! notify_signal_probe; then
    echo "signal: SIGNAL_API_URL unreachable or SIGNAL_RECIPIENT not set" >&2
    return 1
  fi

  local api_url="${SIGNAL_API_URL:-http://127.0.0.1:8080}"
  local recipient="${SIGNAL_RECIPIENT}"
  local account="${SIGNAL_ACCOUNT:-self}"
  local message
  if [[ -n "$url" ]]; then
    message="$(printf '*\u2022 %s*\n\n%s\n\n%s' "$title" "$body" "$url")"
  else
    message="$(printf '*\u2022 %s*\n\n%s' "$title" "$body")"
  fi

  local response
  response=$(curl -fsS -X POST \
    "$api_url/v2/send" \
    -H "Content-Type: application/json" \
    -d "$(SIGNAL_ACCOUNT="$account" \
         SIGNAL_RECIPIENT="$recipient" \
         SIGNAL_MESSAGE="$message" \
         python3 -c '
import json, os
print(json.dumps({
    "number": os.environ.get("SIGNAL_ACCOUNT", "self"),
    "recipients": [os.environ["SIGNAL_RECIPIENT"]],
    "message": os.environ["SIGNAL_MESSAGE"],
}))
')" 2>&1)
  local rc=$?
  if [[ $rc -ne 0 ]]; then
    echo "signal: send failed: $response" >&2
    return 1
  fi
}
