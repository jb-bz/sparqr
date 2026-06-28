# lib/adapters/notify/discord.sh — Notify channel: Discord via webhook.
#
# Posts notifications to a Discord channel using a webhook URL.
# Webhooks are simpler than bots: no Discord developer account,
# no OAuth flow, no rate-limit perms to manage. Just create a
# webhook in the target channel and drop the URL into the env.
#
# Env vars (required):
#   DISCORD_WEBHOOK_URL  — the webhook URL. Looks like:
#                           https://discord.com/api/webhooks/<id>/<token>
#
# Optional:
#   DISCORD_USERNAME  — override the username shown for the webhook
#                       (default: "sparqr")
#   DISCORD_AVATAR_URL — override the avatar (default: no avatar)

# notify_discord_probe
# Returns 0 if DISCORD_WEBHOOK_URL is set and looks valid.
notify_discord_probe() {
  local url="${DISCORD_WEBHOOK_URL:-}"
  if [[ -z "$url" ]]; then
    return 1
  fi
  if [[ "$url" =~ ^https://discord(app)?\.com/api/webhooks/ ]]; then
    return 0
  fi
  return 1
}

# notify_discord_send <title> <body> [<url>]
# Posts an embed to the configured Discord webhook.
notify_discord_send() {
  local title="$1" body="$2" url="${3:-}"
  if ! notify_discord_probe; then
    echo "discord: DISCORD_WEBHOOK_URL not set or invalid" >&2
    return 1
  fi

  # Build the JSON payload. Use python3 because bash JSON encoding
  # of arbitrary text is fragile.
  local username="${DISCORD_USERNAME:-sparqr}"
  local avatar="${DISCORD_AVATAR_URL:-}"
  local payload
  payload=$(DISCORD_WEBHOOK_URL="$DISCORD_WEBHOOK_URL" \
            DISCORD_USERNAME="$username" \
            DISCORD_AVATAR_URL="$avatar" \
            DISCORD_TITLE="$title" \
            DISCORD_BODY="$body" \
            DISCORD_URL="$url" \
            python3 -c '
import json, os
payload = {
    "username": os.environ.get("DISCORD_USERNAME", "sparqr"),
    "content": "",
    "embeds": [{
        "title": os.environ.get("DISCORD_TITLE", ""),
        "description": os.environ.get("DISCORD_BODY", ""),
        "color": 9335199,  # sparqr indigo
    }],
}
if os.environ.get("DISCORD_AVATAR_URL"):
    payload["avatar_url"] = os.environ["DISCORD_AVATAR_URL"]
if os.environ.get("DISCORD_URL"):
    payload["embeds"][0]["url"] = os.environ["DISCORD_URL"]
print(json.dumps(payload))
')

  local response
  response=$(curl -fsS -H "Content-Type: application/json" \
    -X POST -d "$payload" \
    "$DISCORD_WEBHOOK_URL" 2>&1)
  local rc=$?
  if [[ $rc -ne 0 ]]; then
    echo "discord: webhook POST failed: $response" >&2
    return 1
  fi
}
