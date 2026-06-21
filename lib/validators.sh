# lib/validators.sh — Acceptance-criteria validators for stage transitions.
#
# The MAST taxonomy (arXiv 2503.13657) shows that 41.77% of multi-agent
# failures are specification issues. The single most effective mitigation is
# enforcing that downstream stages do not start until upstream stages have
# produced a valid artifact. These validators are the gate.
#
# Each validator returns 0 (pass) or 1 (fail), and on failure writes a
# one-line reason to stderr that the reviewer profile or the orchestrator
# can surface to the human.

# Source dependencies. No double-source guard: see lib/kanban.sh for
# the full reasoning. Same pattern applies here.

# Source dependencies (no guards; re-sourcing is idempotent)
source "$(dirname "${BASH_SOURCE[0]}")/artifacts.sh"

# sparc_validate_specification <board> <task_id>
# Pass conditions:
#   1. The artifact file exists
#   2. It contains at least one user story ("As a " or "Given/When/Then")
#   3. It contains at least one acceptance criterion ("Acceptance Criteria" header)
#   4. It contains a Success Metrics section
sparc_validate_specification() {
  local board="$1" task_id="$2"
  local content
  content=$(sparc_artifact_read "$board" "spec" "$task_id" 2>/dev/null) || {
    echo "specification artifact missing at docs/sparc/$board/spec/$task_id.md" >&2
    return 1
  }
  grep -qE 'As an? |Given .* When .* Then' <<<"$content" || {
    echo "specification: no user stories found (need 'As a …' or 'Given/When/Then')" >&2
    return 1
  }
  grep -qiE '^#+ +Acceptance Criteria' <<<"$content" || {
    echo "specification: no '## Acceptance Criteria' section" >&2
    return 1
  }
  grep -qiE '^#+ +Success Metrics' <<<"$content" || {
    echo "specification: no '## Success Metrics' section" >&2
    return 1
  }
  return 0
}

# sparc_validate_design <board> <task_id>
# Pass conditions:
#   1. Artifact exists
#   2. Contains a User Flows section
#   3. Contains a Visual Design section (or "Design Tokens" / "Components")
sparc_validate_design() {
  local board="$1" task_id="$2"
  local content
  content=$(sparc_artifact_read "$board" "design" "$task_id" 2>/dev/null) || {
    echo "design artifact missing" >&2
    return 1
  }
  grep -qiE '^#+ +(User Flows?|Flow)' <<<"$content" || {
    echo "design: no '## User Flow(s)' section" >&2
    return 1
  }
  grep -qiE '^#+ +(Visual Design|Design Tokens?|Components?)' <<<"$content" || {
    echo "design: no '## Visual Design' / '## Design Tokens' / '## Components' section" >&2
    return 1
  }
  return 0
}

# sparc_validate_pseudocode <board> <task_id>
# Pass conditions: artifact exists and has at least 5 numbered algorithmic steps.
sparc_validate_pseudocode() {
  local board="$1" task_id="$2"
  local content
  content=$(sparc_artifact_read "$board" "pseudocode" "$task_id" 2>/dev/null) || {
    echo "pseudocode artifact missing" >&2
    return 1
  }
  local steps
  steps=$(grep -cE '^[0-9]+\.' <<<"$content")
  [[ "$steps" -ge 5 ]] || {
    echo "pseudocode: only $steps numbered steps found (need ≥5)" >&2
    return 1
  }
  return 0
}

# sparc_validate_architecture <board> <task_id>
# Pass conditions: artifact has Components, Data Flow, and API/Interface sections.
sparc_validate_architecture() {
  local board="$1" task_id="$2"
  local content
  content=$(sparc_artifact_read "$board" "architecture" "$task_id" 2>/dev/null) || {
    echo "architecture artifact missing" >&2
    return 1
  }
  grep -qiE '^#+ +(Components|Modules|Services)' <<<"$content" || {
    echo "architecture: no '## Components' section" >&2
    return 1
  }
  grep -qiE '^#+ +Data Flow' <<<"$content" || {
    echo "architecture: no '## Data Flow' section" >&2
    return 1
  }
  grep -qiE '^#+ +(API|Interface|Contract)' <<<"$content" || {
    echo "architecture: no '## API/Interface' section" >&2
    return 1
  }
  return 0
}

# sparc_validate_refinement <board> <task_id>
# Pass conditions: artifact lists test results. The orchestrator actually
# runs the tests; this just checks that the refinement artifact recorded them.
sparc_validate_refinement() {
  local board="$1" task_id="$2"
  local content
  content=$(sparc_artifact_read "$board" "refinement" "$task_id" 2>/dev/null) || {
    echo "refinement artifact missing" >&2
    return 1
  }
  grep -qiE '^#+ +Test Results?' <<<"$content" || {
    echo "refinement: no '## Test Results' section" >&2
    return 1
  }
  return 0
}

# sparc_validate_completion <board> <task_id>
# Pass conditions: artifact has Verification Checklist, all items checked.
sparc_validate_completion() {
  local board="$1" task_id="$2"
  local content
  content=$(sparc_artifact_read "$board" "completion" "$task_id" 2>/dev/null) || {
    echo "completion artifact missing" >&2
    return 1
  }
  grep -qiE '^#+ +Verification Checklist' <<<"$content" || {
    echo "completion: no '## Verification Checklist' section" >&2
    return 1
  }
  # At least 80% of checklist items should be checked
  local total checked
  total=$(grep -cE '^- \[[ x]\]' <<<"$content" || echo 0)
  checked=$(grep -cE '^- \[x\]' <<<"$content" || echo 0)
  [[ "$total" -gt 0 ]] || {
    echo "completion: no checklist items found" >&2
    return 1
  }
  local ratio=$(( checked * 100 / total ))
  [[ "$ratio" -ge 80 ]] || {
    echo "completion: only $checked/$total checklist items complete ($ratio% < 80%)" >&2
    return 1
  }
  return 0
}

# sparc_validate <stage> <board> <task_id>
# Dispatcher. Returns 0 if the stage's artifact passes validation, 1 otherwise.
sparc_validate() {
  local stage="$1" board="$2" task_id="$3"
  case "$stage" in
    spec)         sparc_validate_specification "$board" "$task_id" ;;
    design)       sparc_validate_design "$board" "$task_id" ;;
    pseudocode)   sparc_validate_pseudocode "$board" "$task_id" ;;
    architecture) sparc_validate_architecture "$board" "$task_id" ;;
    refinement)   sparc_validate_refinement "$board" "$task_id" ;;
    completion)   sparc_validate_completion "$board" "$task_id" ;;
    *)            echo "sparc_validate: unknown stage: $stage" >&2; return 2 ;;
  esac
}
