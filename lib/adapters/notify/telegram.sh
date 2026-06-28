# lib/adapters/notify/telegram.sh — Notify channel: Telegram via Bot API.
#
# Posts notifications to a Telegram chat via the official Bot API.
# Requires creating a bot via @BotFather and sending /start so the
# bot can message you.
#
# Env vars (required):
#   TELEGRAM_BOT_TOKEN  — the token @BotFather gives you
#   TELEGRAM_CHAT_ID    — your chat ID (or a group/channel ID with
#                         the bot added as admin)
#
# Optional:
#   TELEGRAM_PARSE_MODE — "Markdown", "MarkdownV2", or "HTML"
#                          (default: "Markdown")

# notify_telegram_probe
# Returns 0 if both TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID are set.
notify_telegram_probe() {
  if [[ -z "${TELEGRAM_BOT_TOKEN:-}" ]]; then
    return 1
  fi
  if [[ -z "${TELEGRAM_CHAT_ID:-}" ]]; then
    return 1
  fi
  return 0
}

# notify_telegram_send <title> <body> [<url>]
# Sends a message via the Telegram sendMessage API.
notify_telegram_send() {
  local title="$1" body="$2" url="${3:-}"
  if ! notify_telegram_probe; then
    echo "telegram: TELEGRAM_BOT_TOKEN and/or TELEGRAM_CHAT_ID not set" >&2
    return 1
  fi

  # Build message. Title is bold, body is plain. URL appended.
  local message
  if [[ -n "$url" ]]; then
    message="$(printf '*%s*\n\n%s\n\n%s' "$title" "$body" "$url")"
  else
    message="$(printf '*%s*\n\n%s' "$title" "$body")"
  fi

  local parse_mode="${TELEGRAM_PARSE_MODE:-Markdown}"
  local response
  response=$(curl -fsS -X POST \
    "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}" \
    -d "parse_mode=${parse_mode}" \
    --data-urlencode "text=${message}" 2>&1)
  local rc=$?
  if [[ $rc -ne 0 ]]; then
    echo "telegram: sendMessage failed: $response" >&2
    return 1
  fi
}
