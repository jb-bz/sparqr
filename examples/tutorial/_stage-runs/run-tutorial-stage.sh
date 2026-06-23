#!/usr/bin/env bash
# run-tutorial-stage.sh — Run a single SPARC+Design stage with real LLM
# for the tutorial. Mimics what bin/sparc-pipeline would do, but
# synchronous (waits for completion) and writes outputs to the
# right place in examples/tutorial/.

set -euo pipefail

# Args
STAGE="${1:?usage: run-tutorial-stage.sh <stage> <task_id> <board> <profile> <skill>}"
TASK_ID="${2:?missing task_id}"
BOARD="${3:?missing board}"
PROFILE="${4:?missing profile}"
SKILL="${5:?missing skill}"
TUTORIAL_ROOT="/Users/jolonbankey/Documents/AAA-Agents/hermes/sparc-orchestration-2026-06/package/examples/tutorial"
PKG_ROOT="/Users/jolonbankey/Documents/AAA-Agents/hermes/sparc-orchestration-2026-06/package"

# Upstream artifact: the previous stage's output.
# We use a case statement instead of an associative array because
# bash 3.2 (macOS default) doesn't support `declare -A`.
case "$STAGE" in
  spec)         UPSTREAM="" ;;
  design)       UPSTREAM="spec" ;;
  pseudocode)   UPSTREAM="design" ;;
  architecture) UPSTREAM="pseudocode" ;;
  refinement)   UPSTREAM="architecture" ;;
  completion)   UPSTREAM="refinement" ;;
  *)
    echo "run-tutorial-stage.sh: unknown stage: $STAGE" >&2
    echo "  expected one of: spec design pseudocode architecture refinement completion" >&2
    exit 1
    ;;
esac

# Build the prompt (matches what bin/sparc-pipeline builds for stage agents).
mkdir -p "$TUTORIAL_ROOT/$STAGE"

PROMPT="You are the SPARC+Design stage agent for stage: ${STAGE}
Task ID: ${TASK_ID}
Board:   ${BOARD}
Profile: ${PROFILE}

Steps:
  1. Read the parent task comment thread to see upstream context:
     hermes kanban --board ${BOARD} show ${TASK_ID}
"

if [[ -n "$UPSTREAM" ]]; then
  PROMPT+="
  2. Read the most recent upstream artifact (the previous stage's output):
     cat ${TUTORIAL_ROOT}/${UPSTREAM}/*.md
     (or run: find ${TUTORIAL_ROOT}/${UPSTREAM} -name '*.md' -exec cat {} +)
"
else
  PROMPT+="
  2. No upstream stage — this is the first stage.
"
fi

PROMPT+="
  3. Do the work for this stage. Use the ${SKILL} skill.
  4. Write your artifact to a file in the directory: ${TUTORIAL_ROOT}/${STAGE}/
     (the file name is up to you; use ${STAGE}.md or similar).
     Use the template at: ${PKG_ROOT}/templates/${STAGE}.md
  5. After writing the file, print its path and a 1-line summary.
  6. Use sparc_artifact_publish to also post it to the kanban thread:
     source ${PKG_ROOT}/lib/artifacts.sh
     sparc_artifact_publish ${BOARD} ${STAGE} ${TASK_ID} \"\$(cat ${TUTORIAL_ROOT}/${STAGE}/${STAGE}.md)\"

When done, output a JSON block like:
{
  \"status\": \"complete\",
  \"artifact_path\": \"/path/to/${STAGE}.md\",
  \"summary\": \"<one-line summary>\"
}"

# Run the LLM via hermes chat -q (one-shot, non-interactive).
echo "→ Running stage '$STAGE' for task $TASK_ID"
echo "  profile=$PROFILE  skill=$SKILL  upstream=${UPSTREAM:-none}"
echo "  prompt length: ${#PROMPT} chars"
echo ""

# Capture output to a stage log.
LOG_FILE="$TUTORIAL_ROOT/_stage-runs/${STAGE}.log"
mkdir -p "$TUTORIAL_ROOT/_stage-runs"
echo "--- prompt ---" > "$LOG_FILE"
echo "$PROMPT" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"
echo "--- output ---" >> "$LOG_FILE"

/Users/jolonbankey/.local/bin/hermes \
  -p "$PROFILE" \
  -m minimax-m3 \
  chat -q "$PROMPT" \
  2>&1 | tee -a "$LOG_FILE"

# After the run, check the artifact was created.
ARTIFACT_DIR="$TUTORIAL_ROOT/$STAGE"
echo ""
echo "→ Stage '$STAGE' complete"
echo "  artifacts:"
ls -la "$ARTIFACT_DIR" 2>/dev/null
