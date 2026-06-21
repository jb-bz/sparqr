# lib/artifacts.sh — Artifact storage helper.
#
# Each SPARC stage produces exactly one artifact (a markdown file). This module
# makes the artifact storage policy explicit and consistent:
#
#   1. The artifact is written to disk at the configured path
#      (default: ./docs/sparc/<board>/<stage>/<task-id>.md)
#   2. The artifact is ALSO appended to the kanban comment thread
#      (so re-spawned workers can read the parent's artifact as context)
#   3. The artifact path is recorded in a manifest at
#      ./docs/sparc/<board>/manifest.json so downstream tools can find it
#
# The two-store policy ("belt and suspenders") survives Hermes auto-compaction,
# kanban DB corruption, and any one source of truth failing.

# Source dependencies. No double-source guard: see lib/kanban.sh for
# the full reasoning. Same pattern applies here — bin/sparc `exec`s
# subcommands, and exec doesn't carry function definitions across
# processes. The sentinel-var pattern caused `command not found`
# errors in the dispatched subcommands.

# Source kanban.sh (no guard needed; re-sourcing is idempotent)
source "$(dirname "${BASH_SOURCE[0]}")/kanban.sh"

# sparc_artifact_path <board> <stage> <task_id>
# Echoes the canonical disk path for an artifact.
sparc_artifact_path() {
  local board="$1" stage="$2" task_id="$3"
  local base="${SPARC_ARTIFACT_DISK_DIR:-./docs/sparc}"
  # Expand ~ if present
  base="${base/#\~/$HOME}"
  echo "$base/$board/$stage/$task_id.md"
}

# sparc_artifact_write <board> <stage> <task_id> <content>
# Writes the artifact to disk. Creates parent dirs.
sparc_artifact_write() {
  local board="$1" stage="$2" task_id="$3" content="$4"
  local path
  path=$(sparc_artifact_path "$board" "$stage" "$task_id")
  mkdir -p "$(dirname "$path")"
  printf '%s\n' "$content" > "$path"
  echo "$path"
}

# sparc_artifact_publish <board> <stage> <task_id> <content>
# Writes to disk AND appends to kanban comment thread.
# Returns the disk path on stdout. Returns 0 unless disk write fails.
sparc_artifact_publish() {
  local board="$1" stage="$2" task_id="$3" content="$4"
  local path
  path=$(sparc_artifact_write "$board" "$stage" "$task_id" "$content") || return $?

  # Always also push to kanban (this is the durable, agent-readable store)
  if [[ "${SPARC_ARTIFACT_ALSO_KANBAN:-true}" != "false" ]]; then
    local comment
    comment="[ARTIFACT:$stage] (saved at $path)

$content"
    sparc_kanban_comment "$board" "$task_id" "$comment" || \
      echo "  ! warning: failed to mirror artifact to kanban (rc=$?)" >&2
  fi

  echo "$path"
}

# sparc_artifact_read <board> <stage> <task_id>
# Reads the artifact from disk. Returns empty string + non-zero if missing.
sparc_artifact_read() {
  local board="$1" stage="$2" task_id="$3"
  local path
  path=$(sparc_artifact_path "$board" "$stage" "$task_id")
  [[ -f "$path" ]] || return 1
  cat "$path"
}

# sparc_artifact_latest <board> <stage>
# Echoes the path of the most recent artifact for a stage on a board.
# Useful for the orchestrator when a new task is created and needs context
# from the previous stage's artifact.
sparc_artifact_latest() {
  local board="$1" stage="$2"
  local base="${SPARC_ARTIFACT_DISK_DIR:-./docs/sparc}"
  base="${base/#\~/$HOME}"
  local dir="$base/$board/$stage"
  [[ -d "$dir" ]] || return 1
  ls -1t "$dir"/*.md 2>/dev/null | head -n1
}
