#!/usr/bin/env bash
# tests/test_setup.sh — Verify the package structure, files, and basic
# script-parse cleanliness. This test does NOT need a running Hermes.
#
# Run: bash tests/test_setup.sh

set -uo pipefail

# Resolve package root
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_ROOT="$(cd "$TEST_DIR/.." && pwd)"

PASS=0
FAIL=0
ok()   { printf "  \033[32m✓\033[0m %s\n" "$*"; PASS=$((PASS+1)); }
fail() { printf "  \033[31m✗\033[0m %s\n" "$*"; FAIL=$((FAIL+1)); }
hdr()  { printf "\n\033[1m[%s]\033[0m\n" "$*"; }

# ── Required files exist ────────────────────────────────────────────────
hdr "required files"
for f in README.md LICENSE CHANGELOG.md CONTRIBUTING.md .gitignore setup.sh \
         sparc.config.yaml.example \
         bin/sparc bin/sparc-init bin/sparc-pipeline bin/sparc-stage \
         bin/sparc-hitl-watcher bin/sparc-doctor \
         lib/stages.sh lib/kanban.sh lib/artifacts.sh lib/validators.sh \
         lib/adapters/hitl/_registry.sh lib/adapters/hitl/terminal.sh \
         lib/adapters/hitl/tui.sh lib/adapters/hitl/webui.sh \
         lib/adapters/hitl/workspace.sh lib/adapters/hitl/official-dashboard.sh; do
  if [[ -f "$PKG_ROOT/$f" ]]; then
    ok "$f"
  else
    fail "$f missing"
  fi
done

# ── 7 profiles exist ────────────────────────────────────────────────────
hdr "7 profiles"
for p in sparc-spec sparc-design sparc-pseudocode sparc-architecture \
         sparc-refinement sparc-completion sparc-reviewer; do
  if [[ -f "$PKG_ROOT/profiles/$p.yaml" ]]; then
    ok "profiles/$p.yaml"
  else
    fail "profiles/$p.yaml missing"
  fi
done

# ── 5 skills exist ─────────────────────────────────────────────────────
hdr "5 skills"
for s in sparc-pipeline-orchestrator sparc-hitl-watcher sparc-stage-spec \
         sparc-stage-design sparc-stage-helpers; do
  if [[ -f "$PKG_ROOT/skills/$s/SKILL.md" ]]; then
    ok "skills/$s/SKILL.md"
  else
    fail "skills/$s/SKILL.md missing"
  fi
done

# ── 6 templates exist ──────────────────────────────────────────────────
hdr "6 templates"
for t in specification design pseudocode architecture refinement completion; do
  if [[ -f "$PKG_ROOT/templates/$t.md" ]]; then
    ok "templates/$t.md"
  else
    fail "templates/$t.md missing"
  fi
done

# ── 6 docs exist ───────────────────────────────────────────────────────
hdr "6 docs"
for d in INSTALL.md ARCHITECTURE.md HITL.md ADDING-STAGES.md TROUBLESHOOTING.md FAQ.md; do
  if [[ -f "$PKG_ROOT/docs/$d" ]]; then
    ok "docs/$d"
  else
    fail "docs/$d missing"
  fi
done

# ── All scripts parse cleanly ──────────────────────────────────────────
hdr "all scripts parse cleanly"
find "$PKG_ROOT" -type f -name "*.sh" -print0 | while IFS= read -r -d '' f; do
  if bash -n "$f" 2>/dev/null; then
    ok "$(realpath --relative-to="$PKG_ROOT" "$f")"
  else
    fail "$(realpath --relative-to="$PKG_ROOT" "$f")"
  fi
done

# ── bin/ scripts are executable ────────────────────────────────────────
hdr "bin/ scripts are executable"
for f in "$PKG_ROOT"/bin/*; do
  if [[ -x "$f" ]]; then
    ok "$(basename "$f")"
  else
    fail "$(basename "$f") is not executable"
  fi
done

# ── setup.sh is executable ─────────────────────────────────────────────
hdr "setup.sh executable"
[[ -x "$PKG_ROOT/setup.sh" ]] && ok "setup.sh" || fail "setup.sh is not executable"

# ── Summary ────────────────────────────────────────────────────────────
printf "\n══════════════════════════════════════════════════════\n"
printf "  %d pass  ·  %d fail\n" "$PASS" "$FAIL"
printf "══════════════════════════════════════════════════════\n"

[[ "$FAIL" -eq 0 ]] || exit 1
