# lib/adapters/notify/slack.sh — Notify channel: Slack via incoming webhook.
#
# Posts notifications to a Slack channel using an Incoming Webhook.
# Create one at https://api.slack.com/messaging/webhooks and drop
# the URL into the env.
#
# Env vars (required):
#   SLACK_WEBHOOK_URL  — the webhook URL
#
# Optional:
#   SLACK_CHANNEL     — override the channel (e.g., "#sparqr-alerts")
#   SLACK_USERNAME    — override the bot username (default: "sparqr")
#   SLACK_ICON_EMOJI  — emoji to use as the icon (e.g., ":robot_face:")

# notify_slack_probe
# Returns 0 if SLACK_WEBHOOK_URL is set and looks valid.
notify_slack_probe() {
  local url="${SLACK_WEBHOOK_URL:-}"
  if [[ -z "$url" ]]; then
    return 1
  fi
  if [[ "$url" =~ ^https://hooks\.slack\.com/services/ ]]; then
    return 0
  fi
  return 1
}

# notify_slack_send <title> <body> [<url>]
# Posts a Block Kit message to the configured Slack webhook.
notify_slack_send() {
  local title="$1" body="$2" url="${3:-}"
  if ! notify_slack_probe; then
    echo "slack: SLACK_WEBHOOK_URL not set or invalid" >&2
    return 1
  fi

  # Build Block Kit payload. Title is a header block, body is a
  # section block, URL becomes a button in the actions block.
  local channel="${SLACK_CHANNEL:-}"
  local username="${SLACK_USERNAME:-sparqr}"
  local icon="${SLACK_ICON_EMOJI:-}"
  local payload
  payload=$(SLACK_WEBHOOK_URL="$SLACK_WEBHOOK_URL" \
            SLACK_CHANNEL="$channel" \
            SLACK_USERNAME="$username" \
            SLACK_ICON_EMOJI="$icon" \
            SLACK_TITLE="$title" \
            SLACK_BODY="$body" \
            SLACK_URL="$url" \
            python3 -c '
import json, os
blocks = [
    {"type": "header", "text": {"type": "plain_text", "text": os.environ.get("SLACK_TITLE", "")[:150]}},
    {"type": "section", "text": {"type": "mrkdwn", "text": os.environ.get("SLACK_BODY", "")[:3000]}},
]
if os.environ.get("SLACK_URL"):
    blocks.append({
        "type": "actions",
        "elements": [{
            "type": "button",
            "text": {"type": "plain_text", "text": "Open in Hermes"},
            "url": os.environ["SLACK_URL"],
        }],
    })
payload = {"blocks": blocks}
if os.environ.get("SLACK_CHANNEL"):
    payload["channel"] = os.environ["SLACK_CHANNEL"]
if os.environ.get("SLACK_USERNAME"):
    payload["username"] = os.environ["SLACK_USERNAME"]
if os.environ.get("SLACK_ICON_EMOJI"):
    payload["icon_emoji"] = os.environ["SLACK_ICON_EMOJI"]
print(json.dumps(payload))
')

  local response
  response=$(curl -fsS -H "Content-Type: application/json" \
    -X POST -d "$payload" \
    "$SLACK_WEBHOOK_URL" 2>&1)
  local rc=$?
  if [[ $rc -ne 0 ]]; then
    echo "slack: webhook POST failed: $response" >&2
    return 1
  fi
}
