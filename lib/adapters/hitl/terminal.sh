# lib/adapters/hitl/terminal.sh — Terminal-based HITL adapter (fallback).
#
# This is the adapter that always works, no UI required. It prints the review
# request to stderr and reads a reply from /dev/tty (or stdin if no tty).
#
# Reply vocabulary (parsed case-insensitively):
#   APPROVE  | a | yes  → orchestrator unblocks the next stage
#   REDIRECT | r       → orchestrator re-runs the current stage with the reply
#                         as additional context
#   REJECT   | x | no  → orchestrator marks the pipeline failed and stops
#   anything else       → treated as REDIRECT with the free text as guidance

SPARC_HITL_ADAPTER_NAME="terminal"

hitl_terminal_probe() {
  # Always available
  return 0
}

hitl_terminal_notify() {
  local board="$1" task="$2" stage="$3" artifact="$4"
  {
    echo ""
    echo "════════════════════════════════════════════════════════════════════"
    echo "  SPARC+Design  ·  HITL REVIEW REQUEST"
    echo "════════════════════════════════════════════════════════════════════"
    echo "  Board : $board"
    echo "  Task  : $task"
    echo "  Stage : $stage"
    echo "  Art.  : $artifact"
    echo "────────────────────────────────────────────────────────────────────"
    echo "  Review the artifact, then reply with one of:"
    echo "    APPROVE  (or 'a' / 'yes')  — pass the gate"
    echo "    REDIRECT (or 'r')          — re-run the stage with your notes"
    echo "    REJECT   (or 'x' / 'no')   — fail the pipeline"
    echo "  Anything else is treated as REDIRECT with your text as guidance."
    echo "════════════════════════════════════════════════════════════════════"
  } >&2
}

hitl_terminal_await_reply() {
  local board="$1" task="$2"
  local reply
  # Prefer /dev/tty so this works in pipes and CI too
  if [[ -r /dev/tty ]]; then
    read -r -p "  review> " reply < /dev/tty
  else
    read -r -p "  review> " reply
  fi
  # Normalize
  local lower="${reply,,}"
  case "$lower" in
    approve|a|yes|y) echo "APPROVE" ;;
    reject|x|no|n)   echo "REJECT" ;;
    redirect|r|"")   echo "REDIRECT" ;;
    *)               echo "REDIRECT: $reply" ;;
  esac
}
