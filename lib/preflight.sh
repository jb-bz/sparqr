# lib/preflight.sh — Prerequisites check for setup and install-time validation.
#
# A single function `sparc_preflight_check` that:
#   1. Verifies all required tools are present and at minimum versions
#   2. Verifies the ~/.hermes/ directory is writable
#   3. Returns 0 if all required prereqs are present, 1 otherwise
#   4. Prints a clean one-line status per check (✓/✗ + fix hint)
#
# Used by:
#   - setup.sh: runs once at the start; aborts if required prereqs are missing
#   - sparc doctor --pre-install: same checks, never aborts
#
# This file is sourced; no executable code at top level.

# Guard against double-sourcing. Use a function-existence check rather than
# a sentinel var, because the sentinel var can be inherited from the
# environment (e.g. a test that pre-sets it) and cause the lib to
# short-circuit silently.
if declare -F sparc_preflight_check >/dev/null 2>&1; then
  return 0
fi

# Minimum bash version we support (3.2 on stock macOS is too old for associative
# arrays, namerefs, etc.). The package's bin/ scripts use those, so 4.0+ is
# effectively required.
SPARC_MIN_BASH_MAJOR=4
SPARC_MIN_BASH_MINOR=0

# Internal helper: print a check line.
# Args: $1 = status ("ok" | "warn" | "fail"), $2 = name, $3 = detail
_sparc_preflight_line() {
  local status="$1" name="$2" detail="$3"
  case "$status" in
    ok)   printf "  \033[32m✓\033[0m %-22s %s\n" "$name" "$detail" ;;
    warn) printf "  \033[33m!\033[0m %-22s %s\n" "$name" "$detail" ;;
    fail) printf "  \033[31m✗\033[0m %-22s %s\n" "$name" "$detail" ;;
  esac
}

# Internal helper: compare versions. Returns 0 if $1 >= $2, 1 otherwise.
# Version format: MAJOR.MINOR (e.g. "4.0" vs "4.2"). Sufficient for our checks.
# Robust to empty/missing input (returns 1 = "not >= required", which is safe).
_sparc_version_gte() {
  local have="$1" need="$2"
  # Default empty/missing to "0.0" so the comparison treats them as the lowest
  [[ -z "$have" ]] && have="0.0"
  [[ -z "$need" ]] && need="0.0"
  local have_major="${have%%.*}"
  local have_minor="${have#*.}"; [[ "$have_minor" == "$have" ]] && have_minor="0"
  local need_major="${need%%.*}"
  local need_minor="${need#*.}"; [[ "$need_minor" == "$need" ]] && need_minor="0"
  # Strip non-numeric suffixes (e.g. "4.0-rc1" → "4", "0")
  have_major="${have_major//[!0-9]/}"; [[ -z "$have_major" ]] && have_major="0"
  have_minor="${have_minor//[!0-9]/}"; [[ -z "$have_minor" ]] && have_minor="0"
  need_major="${need_major//[!0-9]/}"; [[ -z "$need_major" ]] && need_major="0"
  need_minor="${need_minor//[!0-9]/}"; [[ -z "$need_minor" ]] && need_minor="0"
  if [[ "$have_major" -gt "$need_major" ]]; then return 0; fi
  if [[ "$have_major" -lt "$need_major" ]]; then return 1; fi
  [[ "$have_minor" -ge "$need_minor" ]]
}

# sparc_preflight_check [--quiet]
# Runs all prerequisite checks. Prints status lines. Exits 0 if all
# required prereqs are met, 1 otherwise.
# Optional --quiet suppresses the per-check status output (just returns exit code).
#
# Required: hermes, bash ≥4.0, sqlite3, curl, jq
# Recommended: git, yq (Python fallback works without yq)
# Hermes-managed: ~/.hermes/bin/bws (auto-installed by setup.sh, not checked here)

sparc_preflight_check() {
  local quiet=0
  [[ "${1:-}" == "--quiet" ]] && quiet=1

  local fail_count=0
  local warn_count=0
  local line_fn=""; [[ $quiet -eq 0 ]] && line_fn=_sparc_preflight_line

  # ── Required tools ─────────────────────────────────────────────────────

  # bash
  local bash_ver="${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}"
  if _sparc_version_gte "$bash_ver" "${SPARC_MIN_BASH_MAJOR}.${SPARC_MIN_BASH_MINOR}"; then
    [[ $quiet -eq 0 ]] && $line_fn ok "bash" "version $bash_ver (≥ ${SPARC_MIN_BASH_MAJOR}.${SPARC_MIN_BASH_MINOR})"
  else
    [[ $quiet -eq 0 ]] && $line_fn fail "bash" "version $bash_ver is too old; need ≥ ${SPARC_MIN_BASH_MAJOR}.${SPARC_MIN_BASH_MINOR}. brew install bash on macOS, or apt install bash on Linux."
    fail_count=$((fail_count + 1))
  fi

  # hermes
  if command -v "${HERMES_BIN:-hermes}" >/dev/null 2>&1; then
    local hermes_ver
    hermes_ver=$("${HERMES_BIN:-hermes}" --version 2>/dev/null | head -n1)
    [[ $quiet -eq 0 ]] && $line_fn ok "hermes" "found: $hermes_ver"
  else
    [[ $quiet -eq 0 ]] && $line_fn fail "hermes" "not found. Install from https://hermes-agent.nousresearch.com first."
    fail_count=$((fail_count + 1))
  fi

  # sqlite3
  if command -v sqlite3 >/dev/null 2>&1; then
    local sqlite_ver
    sqlite_ver=$(sqlite3 -version 2>/dev/null | head -n1)
    [[ $quiet -eq 0 ]] && $line_fn ok "sqlite3" "$sqlite_ver"
  else
    [[ $quiet -eq 0 ]] && $line_fn fail "sqlite3" "not found. apt install sqlite3 on Linux; preinstalled on macOS."
    fail_count=$((fail_count + 1))
  fi

  # curl
  if command -v curl >/dev/null 2>&1; then
    [[ $quiet -eq 0 ]] && $line_fn ok "curl" "$(curl --version | head -n1)"
  else
    [[ $quiet -eq 0 ]] && $line_fn fail "curl" "not found. apt install curl on Linux; preinstalled on macOS."
    fail_count=$((fail_count + 1))
  fi

  # jq
  if command -v jq >/dev/null 2>&1; then
    [[ $quiet -eq 0 ]] && $line_fn ok "jq" "$(jq --version)"
  else
    [[ $quiet -eq 0 ]] && $line_fn fail "jq" "not found. brew install jq on macOS, apt install jq on Linux."
    fail_count=$((fail_count + 1))
  fi

  # ── Recommended tools ─────────────────────────────────────────────────

  # git
  if command -v git >/dev/null 2>&1; then
    [[ $quiet -eq 0 ]] && $line_fn ok "git" "$(git --version)"
  else
    [[ $quiet -eq 0 ]] && $line_fn warn "git" "not found. Optional; only needed for git push from sparc doctor or for repo-based workflows."
    warn_count=$((warn_count + 1))
  fi

  # yq (optional — Python fallback exists for YAML parsing)
  if command -v yq >/dev/null 2>&1; then
    [[ $quiet -eq 0 ]] && $line_fn ok "yq" "$(yq --version 2>&1 | head -n1)"
  else
    if command -v python3 >/dev/null 2>&1; then
      [[ $quiet -eq 0 ]] && $line_fn warn "yq" "not found. Optional; setup.sh falls back to a python3 parser for sparc.config.yaml. Install yq for faster startup: brew install yq / apt install yq."
      warn_count=$((warn_count + 1))
    else
      [[ $quiet -eq 0 ]] && $line_fn warn "yq" "not found, and python3 is also missing. sparc.config.yaml parsing will fail. Install at least one of: yq, python3."
      warn_count=$((warn_count + 1))
    fi
  fi

  # ── Filesystem ────────────────────────────────────────────────────────

  # ~/.hermes/ is writable
  local hermes_home="${HERMES_HOME:-$HOME/.hermes}"
  if [[ -d "$hermes_home" ]]; then
    if [[ -w "$hermes_home" ]]; then
      [[ $quiet -eq 0 ]] && $line_fn ok "~/.hermes/" "exists and is writable"
    else
      [[ $quiet -eq 0 ]] && $line_fn fail "~/.hermes/" "exists but is NOT writable by $(whoami). Check permissions: ls -ld $hermes_home"
      fail_count=$((fail_count + 1))
    fi
  elif [[ -w "$(dirname "$hermes_home")" ]]; then
    [[ $quiet -eq 0 ]] && $line_fn ok "~/.hermes/" "will be created (parent dir is writable)"
  else
    [[ $quiet -eq 0 ]] && $line_fn fail "~/.hermes/" "parent dir $(dirname "$hermes_home") is NOT writable by $(whoami). Check permissions."
    fail_count=$((fail_count + 1))
  fi

  # ── Summary ──────────────────────────────────────────────────────────

  if [[ $quiet -eq 0 ]]; then
    echo ""
    if [[ $fail_count -eq 0 ]]; then
      if [[ $warn_count -eq 0 ]]; then
        echo "  All prerequisites met. You can run setup.sh."
      else
        echo "  Prerequisites met with $warn_count warning(s). setup.sh will work; warnings are optional."
      fi
    else
      echo "  $fail_count required prerequisite(s) missing. Install the items marked ✗ above, then re-run."
    fi
  fi

  [[ $fail_count -eq 0 ]]
}
