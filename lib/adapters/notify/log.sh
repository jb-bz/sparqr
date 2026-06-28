# lib/adapters/notify/log.sh — Notify channel: write to a log file.
#
# Always-on (no credentials needed). Useful for debugging the
# notification pipeline itself and for users who want a permanent
# record of every state transition.
#
# Env vars:
#   SPARC_NOTIFY_LOG  — path to the log file. Default:
#                       ~/.hermes/sparc-package/logs/notify.log

# notify_log_probe
# Always returns 0 (no credentials needed).
notify_log_probe() {
  return 0
}

# notify_log_send <title> <body> [<url>]
# Appends the notification as a timestamped line to the log file.
notify_log_send() {
  local title="$1" body="$2" url="${3:-}"
  local log_file="${SPARC_NOTIFY_LOG:-$HOME/.hermes/sparc-package/logs/notify.log}"
  mkdir -p "$(dirname "$log_file")"
  local ts
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  {
    echo "===== $ts ====="
    echo "[$title]"
    if [[ -n "$url" ]]; then
      echo "$url"
    fi
    echo "$body"
    echo
  } >> "$log_file"
}
