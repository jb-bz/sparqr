# lib/gates.sh — Gate type decision logic (v0.3.0 story 1b-d).
#
# Four gate types are supported:
#   approval    — human must approve explicitly. Current v0.2.0 behavior.
#   confidence  — auto-approve if reviewer confidence >= threshold.
#   sampling    — auto-approve (N-1)/N of the time; review N% of the time.
#   exception   — auto-approve unless reviewer explicitly flags a problem.
#
# These functions are pure logic (no side effects, no hermes calls).
# They're called from bin/sparc-pipeline's once_tick to decide whether
# a blocked task should auto-resolve or wait for human review.
#
# Schema reminder (see lib/config.sh:sparc_config_gates_get):
#
#   gates:
#     spec:
#       type: confidence
#       threshold: 0.9
#     refinement:
#       type: sampling
#       percent: 10
#     completion:
#       type: exception

# Source dependencies (no guards; re-sourcing is idempotent)
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"
source "$(dirname "${BASH_SOURCE[0]}")/kanban.sh"

# sparc_gate_should_auto_approve <config> <board> <task_id> <stage>
#
#   Returns 0 if the gate type allows auto-approving this task
#   (no human needed), 1 if the gate requires human review.
#
#   Decision tree:
#     type=approval  → 1 (always requires human)
#     type=confidence → parse last comment for [CONFIDENCE=X],
#                        if X >= threshold: 0, else 1
#     type=sampling   → random number < percent: 0, else 1
#     type=exception  → parse last comment for [REVIEWER_FLAG] or
#                        [BLOCKED]; if found: 1, else 0
#     type=missing    → treat as approval (backward-compat default)
sparc_gate_should_auto_approve() {
  local config="$1" board="$2" task_id="$3" stage="$4"
  local gate_type
  gate_type=$(sparc_config_gates_get "$config" "$stage" type 2>/dev/null || true)
  [[ -z "$gate_type" ]] && gate_type="approval"

  case "$gate_type" in
    approval)    return 1 ;;  # always requires human
    confidence)  sparc_gate_check_confidence "$config" "$board" "$task_id" "$stage" ;;
    sampling)    sparc_gate_check_sampling "$config" "$board" "$task_id" "$stage" ;;
    exception)   sparc_gate_check_exception "$board" "$task_id" ;;
    *)           return 1 ;;  # unknown gate type: require human
  esac
}

# sparc_gate_check_confidence <config> <board> <task_id> <stage>
#
#   Looks for the most recent [CONFIDENCE=X] marker in the task's
#   comment thread. If X >= threshold, auto-approves. Otherwise
#   requires human review.
#
#   Confidence format: [CONFIDENCE=0.95] (also accepts [CONFIDENCE: 0.95])
sparc_gate_check_confidence() {
  local config="$1" board="$2" task_id="$3" stage="$4"
  local threshold
  threshold=$(sparc_config_gates_get "$config" "$stage" threshold 2>/dev/null || true)
  [[ -z "$threshold" ]] && threshold="0.9"

  # Find most recent confidence marker. The orchestrator's HITL pass
  # already fetched comments via sparc_kanban_event_log. We re-fetch
  # here to keep this function stateless and easy to test.
  local comments
  comments=$(sparc_kanban_event_log "$board" "$task_id" 2>/dev/null || true)

  # Extract last [CONFIDENCE=X.X] marker. bash + macOS awk compatible:
  # use grep with extended regex (which DOES support capture groups)
  # instead of awk match() (which doesn't on macOS).
  local last_confidence
  last_confidence=$(echo "$comments" | grep -oE '\[CONFIDENCE[=:][[:space:]]*[0-9.]+\]' | tail -n 1 | grep -oE '[0-9.]+')

  # If no confidence was reported, fall back to requiring human review
  [[ -z "$last_confidence" ]] && return 1

  # Numeric comparison. bash can't compare floats natively, so use
  # awk for the >= check.
  awk -v c="$last_confidence" -v t="$threshold" 'BEGIN { exit !(c+0 >= t+0) }' \
    && return 0 \
    || return 1
}

# sparc_gate_check_sampling <config> <board> <task_id> <stage>
#
#   Returns 0 (need review) N% of the time, 1 (auto-approve) the rest.
#   Uses $RANDOM for the decision; reproducible enough for tests.
sparc_gate_check_sampling() {
  local config="$1" board="$2" task_id="$3" stage="$4"
  local percent
  percent=$(sparc_config_gates_get "$config" "$stage" percent 2>/dev/null || true)
  [[ -z "$percent" ]] && percent="10"

  # Random number 0-99, compare against percent.
  # If r < percent: we're in the review sample → needs human (return 1).
  # If r >= percent: not sampled → auto-approve (return 0).
  # The function returns 0 = auto-approve, 1 = needs-human (matching
  # the convention of all other gate checks).
  local r=$((RANDOM % 100))
  [[ $r -ge $percent ]]
}

# sparc_gate_check_exception <board> <task_id>
#
#   Auto-approves unless the reviewer explicitly flagged an issue.
#   Flag markers: [REVIEWER_FLAG], [BLOCKED], [REJECT].
sparc_gate_check_exception() {
  local board="$1" task_id="$2"
  local comments
  comments=$(sparc_kanban_event_log "$board" "$task_id" 2>/dev/null || true)

  # If any comment matches a flag marker, return 1 (needs review).
  if echo "$comments" | grep -qE '\[(REVIEWER_FLAG|BLOCKED|REJECT)\]'; then
    return 1
  fi
  return 0  # no flag → auto-approve
}

# sparc_gate_resolve_blocked <config> <board> <task_id> <stage>
#
#   High-level: when a task is blocked, decide what to do.
#   Echoes one of:
#     "auto-approve" — orchestrator should mark task done without human
#     "needs-human"  — orchestrator should keep the task blocked and
#                      surface it to the human
#
#   This is the function bin/sparc-pipeline calls in its once_tick
#   pass 1 (blocked handling).
sparc_gate_resolve_blocked() {
  local config="$1" board="$2" task_id="$3" stage="$4"
  if sparc_gate_should_auto_approve "$config" "$board" "$task_id" "$stage"; then
    echo "auto-approve"
  else
    echo "needs-human"
  fi
}

# sparc_gate_prompt_instructions <config> <stage>
#
#   Generates the gate-specific instructions to add to the stage
#   agent's prompt. The agent needs to know:
#   - What gate type is configured for this stage
#   - What action to take when finishing (mark blocked vs complete)
#   - What format to use for confidence / flag markers
#
#   Echoes the instructions as a multi-line string. Returns empty
#   if the gate type is missing (which is treated as approval by
#   the orchestrator; the agent prompt just says "do whatever").
sparc_gate_prompt_instructions() {
  local config="$1" stage="$2"
  local gate_type
  gate_type=$(sparc_config_gates_get "$config" "$stage" type 2>/dev/null || true)
  [[ -z "$gate_type" ]] && gate_type="approval"

  case "$gate_type" in
    approval)
      cat <<'EOF'
Gate type: approval (default).
After publishing the artifact, mark the task BLOCKED with a
one-line summary. The human reviewer will see your work and
decide whether to approve, reject, or redirect.
EOF
      ;;
    confidence)
      local threshold
      threshold=$(sparc_config_gates_get "$config" "$stage" threshold 2>/dev/null || true)
      [[ -z "$threshold" ]] && threshold="0.9"
      cat <<EOF
Gate type: confidence (auto-approve if >= ${threshold}).
After publishing the artifact, post a comment with your confidence:
  hermes kanban --board \$SPARC_BOARD comment \$TASK_ID '[CONFIDENCE=0.95]'
Then mark the task BLOCKED. The orchestrator will auto-approve
if your confidence >= ${threshold}, otherwise surface to the human.
EOF
      ;;
    sampling)
      local percent
      percent=$(sparc_config_gates_get "$config" "$stage" percent 2>/dev/null || true)
      [[ -z "$percent" ]] && percent="10"
      cat <<EOF
Gate type: sampling (review ${percent}% of the time).
After publishing the artifact, mark the task BLOCKED. The
orchestrator will decide (per ${percent}% sampling rate) whether
to surface your work to a human or auto-approve. There's nothing
extra for you to do — just block as usual.
EOF
      ;;
    exception)
      cat <<'EOF'
Gate type: exception (auto-approve unless you flag a problem).
After publishing the artifact:
  - If the work looks correct, mark the task COMPLETE directly.
  - If you found an issue worth flagging, mark BLOCKED with a
    comment starting with [REVIEWER_FLAG]: <description>.
EOF
      ;;
    *)
      echo "Gate type: $gate_type (unknown — falling back to approval)."
      ;;
  esac
}
