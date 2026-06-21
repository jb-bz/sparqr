# lib/adapters/hitl/_registry.sh — HITL adapter registry and dispatch.
#
# The orchestrator and HITL watcher never call adapters directly; they call
# hitl_notify and hitl_await_reply, which look up the configured adapter by
# name and call the adapter's implementation function. This is the only
# indirection the rest of the package needs to know about.
#
# Each adapter file in this directory must define:
#   hitl_<name>_probe     — returns 0 if the surface is available, 1 if not
#   hitl_<name>_notify    — sends the review request to the human
#   hitl_<name>_await_reply — blocks until the human replies; echoes the reply

# Source dependencies. No double-source guard: see lib/kanban.sh for
# the full reasoning. Same pattern applies here.

# All known adapter names. Used by `sparc adapters list` and the setup wizard.
SPARC_HITL_ADAPTERS=(terminal tui webui workspace official-dashboard)

# The lib dir for this adapter family (so adapters can be sourced by name)
SPARC_HITL_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source all built-in adapters up front. New adapters added in user
# ~/.hermes/sparc-package/lib/adapters/hitl/ are sourced at setup time
# and registered into SPARC_HITL_ADAPTERS by setup.sh.
for _adapter in "${SPARC_HITL_ADAPTERS[@]}"; do
  _adapter_file="$SPARC_HITL_LIB_DIR/${_adapter}.sh"
  if [[ -f "$_adapter_file" ]]; then
    # shellcheck source=/dev/null
    source "$_adapter_file"
  fi
done
unset _adapter _adapter_file

# hitl_probe <adapter>
# Returns 0 if the adapter's surface is reachable, 1 otherwise.
hitl_probe() {
  local adapter="$1"
  if declare -F "hitl_${adapter}_probe" >/dev/null; then
    "hitl_${adapter}_probe"
  else
    echo "hitl: unknown adapter '$adapter'" >&2
    return 2
  fi
}

# hitl_notify <adapter> <board> <task_id> <stage> <artifact_path>
# Sends the review request to the configured surface.
hitl_notify() {
  local adapter="$1" board="$2" task="$3" stage="$4" artifact="$5"
  if declare -F "hitl_${adapter}_notify" >/dev/null; then
    "hitl_${adapter}_notify" "$board" "$task" "$stage" "$artifact"
  else
    echo "hitl: adapter '$adapter' has no notify function" >&2
    return 1
  fi
}

# hitl_await_reply <adapter> <board> <task_id>
# Blocks until the human replies. Echoes the reply (APPROVE | REDIRECT | REJECT | free text).
hitl_await_reply() {
  local adapter="$1" board="$2" task="$3"
  if declare -F "hitl_${adapter}_await_reply" >/dev/null; then
    "hitl_${adapter}_await_reply" "$board" "$task"
  else
    echo "hitl: adapter '$adapter' has no await_reply function" >&2
    return 1
  fi
}

# hitl_list_adapters
# Echoes the names of all registered adapters, one per line.
hitl_list_adapters() {
  printf '%s\n' "${SPARC_HITL_ADAPTERS[@]}"
}

# hitl_list_available
# Echoes the names of adapters whose probe returns 0, one per line.
hitl_list_available() {
  for a in "${SPARC_HITL_ADAPTERS[@]}"; do
    if hitl_probe "$a" 2>/dev/null; then
      echo "$a"
    fi
  done
}
