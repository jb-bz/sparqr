# lib/adapters/notify/_registry.sh — Notify channel registry and dispatch.
#
# The orchestrator and HITL watcher call `notify_send` after stage
# transitions, which looks up all enabled channels and dispatches
# the same notification to each. This is the only indirection the
# rest of the package needs to know about.
#
# Each adapter file in this directory must define:
#   notify_<name>_probe     — returns 0 if the channel is available, 1 if not
#   notify_<name>_send      — sends a notification (title, body, optional url)
#
# Detection: the probe function reads the appropriate env var or
# BWS-cached secret. If the credential is present, the channel is
# enabled. Probes never make network calls — they're a quick
# "are the credentials set?" check.
#
# Adding a new channel: drop a `<name>.sh` file in this directory
# following the same pattern as the others; add the name to
# SPARC_NOTIFY_CHANNELS below; setup.sh will auto-discover it.

# Source dependencies. No double-source guard: see lib/kanban.sh for
# the full reasoning. Same pattern applies here.

# All known notify channels. Order matters for `sparc adapters list`.
# `log` and `kanban` are always enabled (no credentials needed).
# `discord`, `telegram`, `slack`, `signal` are auto-enabled by their probes.
SPARC_NOTIFY_CHANNELS=(log kanban discord telegram slack signal)

# The lib dir for this adapter family (so adapters can be sourced by name)
SPARC_NOTIFY_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source all built-in adapters up front. New adapters added in user
# ~/.hermes/sparc-package/lib/adapters/notify/ are sourced at setup time
# and registered into SPARC_NOTIFY_CHANNELS by setup.sh.
for _chan in "${SPARC_NOTIFY_CHANNELS[@]}"; do
  _chan_file="$SPARC_NOTIFY_LIB_DIR/${_chan}.sh"
  if [[ -f "$_chan_file" ]]; then
    # shellcheck source=/dev/null
    source "$_chan_file"
  fi
done
unset _chan _chan_file

# notify_probe <channel>
# Returns 0 if the channel's credentials/availability check passes.
notify_probe() {
  local chan="$1"
  if declare -F "notify_${chan}_probe" >/dev/null; then
    "notify_${chan}_probe"
  else
    echo "notify: unknown channel '$chan'" >&2
    return 2
  fi
}

# notify_send <channel> <title> <body> [<url>]
# Sends a notification through the configured channel.
# url is optional (most channels ignore it or include it in the body).
notify_send() {
  local chan="$1" title="$2" body="$3" url="${4:-}"
  if declare -F "notify_${chan}_send" >/dev/null; then
    "notify_${chan}_send" "$title" "$body" "$url"
  else
    echo "notify: channel '$chan' has no send function" >&2
    return 1
  fi
}

# notify_list_channels
# Echoes the names of all registered channels, one per line.
notify_list_channels() {
  printf '%s\n' "${SPARC_NOTIFY_CHANNELS[@]}"
}

# notify_list_available
# Echoes the names of channels whose probe returns 0, one per line.
notify_list_available() {
  for c in "${SPARC_NOTIFY_CHANNELS[@]}"; do
    if notify_probe "$c" 2>/dev/null; then
      echo "$c"
    fi
  done
}

# notify_broadcast <title> <body> [<url>]
# Send to all available channels. Errors from individual channels are
# logged but don't stop the others. Returns 0 if at least one channel
# succeeded, 1 if all failed.
notify_broadcast() {
  local title="$1" body="$2" url="${3:-}"
  local any_ok=0
  local any_failed=0
  for c in $(notify_list_available); do
    if notify_send "$c" "$title" "$body" "$url"; then
      any_ok=1
    else
      any_failed=1
    fi
  done
  if [[ $any_ok -eq 1 ]]; then
    return 0
  else
    return 1
  fi
}
