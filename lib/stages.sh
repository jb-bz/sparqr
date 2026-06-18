# lib/stages.sh — Stage definitions for the SPARC+Design pipeline
#
# Stages are pure data. The orchestrator iterates over the array; the HITL
# gate logic reads `requires_review`; the stage agent runner reads `profile`
# and `template`. To add/remove/reorder stages, edit this file. No other
# file in the package needs to change.
#
# Each stage entry has:
#   key         — short id (matches Kanban task title prefix)
#   name        — human-readable name
#   order       — 1-based position in the pipeline
#   profile     — Hermes profile name to spawn for this stage
#   skill       — Hermes skill to preload when spawning
#   template    — path to artifact template (relative to this package)
#   requires_review — bool, whether the reviewer profile blocks at end of this stage
#   description — one sentence used in the README and `sparc stages` output
#
# This file is sourced; no executable code. Keep it pure data.

# Guard against double-sourcing
if [[ -n "${SPARC_STAGES_LOADED:-}" ]]; then
  return 0
fi
export SPARC_STAGES_LOADED=1

# Default stage set: SPARC's 5 phases + Design inserted between Spec and Pseudo.
# Order matters; the orchestrator respects it.
SPARC_STAGE_KEYS_DEFAULT=(
  spec
  design
  pseudocode
  architecture
  refinement
  completion
)

# Full stage table. `key|profile|skill|template|requires_review|description`
# Uses '|' as a delimiter since descriptions may contain spaces. Do not
# include '|' in descriptions.
SPARC_STAGES_TABLE='
spec|sparc-spec|sparc-stage-spec|templates/specification.md|true|Define what to build, why, for whom. User stories + acceptance criteria.
design|sparc-design|sparc-stage-design|templates/design.md|false|UI/UX, user flows, visual design, design system. (Community extension; remove by commenting the line in sparc.config.yaml.)
pseudocode|sparc-pseudocode|sparc-stage-helpers|templates/pseudocode.md|false|High-level logic without implementation details.
architecture|sparc-architecture|sparc-stage-helpers|templates/architecture.md|true|System design, components, data flow, APIs, technology choices.
refinement|sparc-refinement|sparc-stage-helpers|templates/refinement.md|false|TDD implementation, debugging, security hardening.
completion|sparc-completion|sparc-stage-helpers|templates/completion.md|true|Test suite, acceptance criteria, docs, deployment, verification.
'

# sparc_stage_get <key> <field>
# Returns the value of a stage field. Field can be: profile, skill, template,
# requires_review, description, order, name.
sparc_stage_get() {
  local key="$1" field="$2"
  local line
  line=$(echo "$SPARC_STAGES_TABLE" | grep -E "^${key}\|" || true)
  if [[ -z "$line" ]]; then
    echo "sparc_stage_get: unknown stage key: $key" >&2
    return 1
  fi
  case "$field" in
    profile)          echo "$line" | cut -d'|' -f2 ;;
    skill)            echo "$line" | cut -d'|' -f3 ;;
    template)         echo "$line" | cut -d'|' -f4 ;;
    requires_review)  echo "$line" | cut -d'|' -f5 ;;
    description)      echo "$line" | cut -d'|' -f6 ;;
    order)
      local i=1
      for k in "${SPARC_STAGE_KEYS_DEFAULT[@]}"; do
        if [[ "$k" == "$key" ]]; then echo "$i"; return 0; fi
        i=$((i+1))
      done
      return 1
      ;;
    name)
      case "$key" in
        spec)         echo "Specification" ;;
        design)       echo "Design" ;;
        pseudocode)   echo "Pseudocode" ;;
        architecture) echo "Architecture" ;;
        refinement)   echo "Refinement" ;;
        completion)   echo "Completion" ;;
        *)            echo "$key" ;;
      esac
      ;;
    *) echo "sparc_stage_get: unknown field: $field" >&2; return 1 ;;
  esac
}

# sparc_stage_all_keys
# Echoes the configured stage keys, in order, one per line.
# Honors SPARC_STAGE_KEYS env var override (colon-separated) — this is how
# the per-project config can drop a stage.
sparc_stage_all_keys() {
  if [[ -n "${SPARC_STAGE_KEYS:-}" ]]; then
    echo "$SPARC_STAGE_KEYS" | tr ':' '\n'
  else
    printf '%s\n' "${SPARC_STAGE_KEYS_DEFAULT[@]}"
  fi
}

# sparc_stage_requires_review <key>
# Returns 0 (true) if a human HITL review is required at the end of this stage.
# Honors SPARC_HITL_GATES env var override (semicolon-separated key:true|false
# pairs) — this is how the per-project config can change gate placement.
sparc_stage_requires_review() {
  local key="$1"
  # Check per-project override first
  if [[ -n "${SPARC_HITL_GATES:-}" ]]; then
    local entry
    entry=$(echo "$SPARC_HITL_GATES" | tr ';' '\n' | grep -E "^${key}:" || true)
    if [[ -n "$entry" ]]; then
      local val="${entry#*:}"
      [[ "$val" == "true" ]] && return 0 || return 1
    fi
  fi
  # Fall back to table default
  local req
  req=$(sparc_stage_get "$key" requires_review)
  [[ "$req" == "true" ]]
}

# sparc_stage_next <key>
# Echoes the next stage key, or empty string if this is the last stage.
sparc_stage_next() {
  local key="$1" current_order next_key=""
  current_order=$(sparc_stage_get "$key" order)
  local next_order=$((current_order + 1))
  for k in $(sparc_stage_all_keys); do
    local ord
    ord=$(sparc_stage_get "$k" order 2>/dev/null || echo 0)
    if [[ "$ord" == "$next_order" ]]; then
      next_key="$k"
      break
    fi
  done
  echo "$next_key"
}

# sparc_stage_first
# Echoes the first stage key.
sparc_stage_first() {
  sparc_stage_all_keys | head -n1
}

# sparc_stage_is_last <key>
# Returns 0 if this is the last stage in the configured pipeline.
sparc_stage_is_last() {
  local key="$1" order
  order=$(sparc_stage_get "$key" order)
  local max_order=0
  for k in $(sparc_stage_all_keys); do
    local o
    o=$(sparc_stage_get "$k" order 2>/dev/null || echo 0)
    [[ "$o" -gt "$max_order" ]] && max_order="$o"
  done
  [[ "$order" == "$max_order" ]]
}
