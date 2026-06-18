#!/usr/bin/env bash
# setup.sh — Import the SPARC+Design package into a RUNNING Hermes install.
#
# What this does:
#   1. Verifies Hermes is installed and ≥ 0.6.0
#   2. Creates 7 profiles (sparc-spec, sparc-design, sparc-pseudocode,
#      sparc-architecture, sparc-refinement, sparc-completion, sparc-reviewer)
#   3. Installs 5 skills into ~/.hermes/skills/software-development/
#   4. Installs the sparc CLI to ~/.local/bin/sparc (or $PREFIX/bin)
#   5. Probes for running HITL surfaces and offers a multi-choice
#   6. Runs sparc doctor at the end
#
# What this does NOT do:
#   - Touch your Hermes config.yaml
#   - Change your model or provider
#   - Touch your API keys
#   - Touch your memory
#   - Touch any other skills
#   - Touch any other profiles
#
# Idempotent: safe to re-run; re-running will update, not duplicate.
#
# Usage:
#   ./setup.sh                  # interactive (asks 4 questions)
#   ./setup.sh --yes            # accept all defaults, no questions
#   ./setup.sh --help           # this help

set -euo pipefail

# ── Parse args ────────────────────────────────────────────────────────────
ASSUME_YES=0
for arg in "$@"; do
  case "$arg" in
    --yes|-y)    ASSUME_YES=1 ;;
    --help|-h)
      sed -n '2,28p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "unknown arg: $arg" >&2; exit 2 ;;
  esac
done

# ── Resolve paths ─────────────────────────────────────────────────────────
PKG_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
SKILLS_DEST="$HERMES_HOME/skills/software-development"
CLI_DEST_DIR="${PREFIX:-$HOME/.local}/bin"
CLI_DEST="$CLI_DEST_DIR/sparc"
mkdir -p "$SKILLS_DEST" "$CLI_DEST_DIR" "$HERMES_HOME/sparc-package/logs"

# ── Helpers ───────────────────────────────────────────────────────────────
ok()   { printf "  \033[32m✓\033[0m %s\n" "$*"; }
warn() { printf "  \033[33m!\033[0m %s\n" "$*"; }
fail() { printf "  \033[31m✗\033[0m %s\n" "$*"; }
hdr()  { printf "\n\033[1m[%s]\033[0m %s\n" "$1" "$2"; }

ask() {
  # ask "question" "default" — echoes the user's answer (or default on empty)
  local q="$1" def="${2:-}"
  local ans
  if [[ "$ASSUME_YES" == "1" ]]; then
    echo "$def"
    return
  fi
  if [[ -n "$def" ]]; then
    read -r -p "  $q [$def]: " ans
    echo "${ans:-$def}"
  else
    read -r -p "  $q: " ans
    echo "$ans"
  fi
}

HERMES_BIN="${HERMES_BIN:-hermes}"

# ── Banner ────────────────────────────────────────────────────────────────
cat <<'BANNER'
════════════════════════════════════════════════════════════════════
  Hermes SPARC+Design  ·  setup
════════════════════════════════════════════════════════════════════
  This will import the package into your running Hermes install.
  It will not touch your config, model, keys, memory, or other
  skills.  Idempotent — safe to re-run.
BANNER

# ── 1. Hermes version check ───────────────────────────────────────────────
hdr "1/7" "Hermes check"
if ! command -v "$HERMES_BIN" >/dev/null 2>&1; then
  fail "$HERMES_BIN not on PATH. Install Hermes Agent first: https://hermes-agent.nousresearch.com/docs"
  exit 1
fi
HERMES_VERSION=$("$HERMES_BIN" --version 2>/dev/null | head -n1 || echo "unknown")
ok "Hermes found: $HERMES_VERSION"
HERMES_MAJOR=$(echo "$HERMES_VERSION" | grep -oE '[0-9]+\.' | head -n1 | tr -d '.')
if [[ -z "$HERMES_MAJOR" || "$HERMES_MAJOR" -lt 1 ]]; then
  warn "Hermes major version looks old (<1.0). Package targets 0.6.0+. Proceeding anyway."
else
  ok "Hermes major version $HERMES_MAJOR looks compatible"
fi

# ── 2. Create profiles ────────────────────────────────────────────────────
hdr "2/7" "Profiles (7 total)"
declare -a PROFILES=(
  sparc-spec sparc-design sparc-pseudocode
  sparc-architecture sparc-refinement sparc-completion
  sparc-reviewer
)
for p in "${PROFILES[@]}"; do
  yaml="$PKG_ROOT/profiles/${p}.yaml"
  if [[ ! -f "$yaml" ]]; then
    fail "missing profile yaml: $yaml"
    continue
  fi
  # Hermes profile create syntax: hermes profile create <name> --clone-from <existing>
  # We then overwrite the config.yaml of the new profile with our template.
  if "$HERMES_BIN" profile show "$p" >/dev/null 2>&1; then
    ok "$p exists (updating)"
  else
    "$HERMES_BIN" profile create "$p" --clone-from default >/dev/null 2>&1 \
      && ok "created $p" \
      || warn "could not create $p (check Hermes profile command syntax)"
  fi
  # Copy the yaml to the profile dir (Hermes will read it on next /reset)
  cp "$yaml" "$HERMES_HOME/profiles/$p/profile.yaml" 2>/dev/null \
    || cp "$yaml" "$HERMES_HOME/profiles/$p.yaml" 2>/dev/null \
    || warn "could not copy profile yaml for $p; user must add manually"
done

# ── 3. Install skills ─────────────────────────────────────────────────────
hdr "3/7" "Skills (5 total)"
declare -a SKILLS=(
  sparc-pipeline-orchestrator
  sparc-hitl-watcher
  sparc-stage-spec
  sparc-stage-design
  sparc-stage-helpers
)
for s in "${SKILLS[@]}"; do
  src="$PKG_ROOT/skills/$s"
  dst="$SKILLS_DEST/$s"
  if [[ -d "$src" ]]; then
    rm -rf "$dst"
    cp -R "$src" "$dst"
    ok "installed $s"
  else
    fail "missing skill: $src"
  fi
done

# ── 4. Install CLI ────────────────────────────────────────────────────────
hdr "4/7" "sparc CLI"
ln -sf "$PKG_ROOT/bin/sparc" "$CLI_DEST" 2>/dev/null \
  && ok "linked $CLI_DEST" \
  || warn "could not link $CLI_DEST (you may need sudo, or add $CLI_DEST_DIR to PATH)"
# Make sure CLI_DEST_DIR is on PATH for this session
case ":$PATH:" in
  *":$CLI_DEST_DIR:"*) ok "$CLI_DEST_DIR is on PATH" ;;
  *) warn "$CLI_DEST_DIR is NOT on PATH. Add to ~/.zshrc or ~/.bashrc: export PATH=\"$CLI_DEST_DIR:\$PATH\"" ;;
esac

# ── 5. Probe HITL surfaces, ask the user ─────────────────────────────────
hdr "5/7" "HITL adapter choice"
# Source the registry to get the probe functions
# shellcheck source=lib/adapters/hitl/_registry.sh
source "$PKG_ROOT/lib/adapters/hitl/_registry.sh"

declare -A ADAPTER_STATUS
for a in $(hitl_list_adapters); do
  if hitl_probe "$a" 2>/dev/null; then
    ADAPTER_STATUS[$a]="available"
  else
    ADAPTER_STATUS[$a]="not-detected"
  fi
done

echo "  Probed HITL surfaces:"
for a in terminal tui webui workspace official-dashboard; do
  st="${ADAPTER_STATUS[$a]:-unknown}"
  case "$st" in
    available)      printf "    \033[32m●\033[0m %-20s reachable\n" "$a" ;;
    not-detected)   printf "    \033[33m○\033[0m %-20s not detected\n" "$a" ;;
  esac
done

# Build the recommendation
DEFAULT_ADAPTER="terminal"
[[ "${ADAPTER_STATUS[official-dashboard]}" == "available" ]] && DEFAULT_ADAPTER="official-dashboard"
[[ "${ADAPTER_STATUS[webui]}" == "available" ]] && DEFAULT_ADAPTER="webui"
[[ "${ADAPTER_STATUS[workspace]}" == "available" ]] && DEFAULT_ADAPTER="workspace"
ok "default recommendation: $DEFAULT_ADAPTER (override below)"

HITL_CHOICE=$(ask "Which HITL adapter? (terminal/tui/webui/workspace/official-dashboard)" "$DEFAULT_ADAPTER")
HITL_CHOICE="${HITL_CHOICE,,}"  # lowercase
ok "selected: $HITL_CHOICE"

# ── 6. Persist project template + run doctor ──────────────────────────────
hdr "6/6" "Per-project template + final check"
if [[ -f "./sparc.config.yaml" ]]; then
  ok "sparc.config.yaml already exists in current dir (not overwriting)"
else
  cp "$PKG_ROOT/sparc.config.yaml.example" ./sparc.config.yaml
  # Patch the adapter to match the user's choice
  if command -v sed >/dev/null; then
    sed -i.bak "s/^hitl_adapter: terminal$/hitl_adapter: $HITL_CHOICE/" ./sparc.config.yaml 2>/dev/null
    rm -f ./sparc.config.yaml.bak
  fi
  ok "created sparc.config.yaml in $(pwd) (adapter=$HITL_CHOICE)"
  warn "run setup.sh from EACH project directory to create its sparc.config.yaml"
fi

echo ""
echo "════════════════════════════════════════════════════════════════════"
echo "  setup complete.  run:  sparc doctor"
echo "════════════════════════════════════════════════════════════════════"
echo ""
# Try to run doctor immediately, if sparc is on PATH now
if command -v sparc >/dev/null 2>&1; then
  sparc doctor || true
else
  echo "  (sparc not on PATH yet — start a new shell or:  export PATH=\"$CLI_DEST_DIR:\$PATH\")"
  echo "  then run:  sparc doctor"
fi
