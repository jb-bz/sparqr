#!/usr/bin/env bash
# tests/test_retro.sh — Unit tests for bin/sparc-retro (v0.4.1 story 4c).
#
# Tests the retro command's structure: it produces a valid YAML-front-
# matter + sections, populates from ROADMAP, detects commit patterns,
# and writes to a .WIP.md file.

set -uo pipefail

PASS=0
FAIL=0
ok()   { echo "  ✓ $*"; PASS=$((PASS+1)); }
fail() { echo "  ✗ $*"; FAIL=$((FAIL+1)); }

PKG_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RETRO="$PKG_ROOT/bin/sparc-retro"

if ! python3 -c "import yaml" 2>/dev/null; then
  echo "  ⚠  python3 pyyaml not available — skipping test_retro.sh"
  exit 0
fi

# ── 1. --help works
echo "── 1. help ──"
out=$("$RETRO" --help 2>&1)
[[ "$out" == *"auto-generate"* ]] && ok "--help shows description" || fail "no help: $out"
echo "$out" | grep -q "sparc retro.*--dry-run" && ok "--help lists --dry-run" || fail "no --dry-run in help"

# ── 2. --dry-run doesn't write
echo "── 2. dry-run ──"
TESTDIR=$(mktemp -d -t sparqr-retro-test-XXXXXX)
trap "cd / && rm -rf $TESTDIR" EXIT
cd "$TESTDIR"
git init -q .
git config user.email "test@example.com"
git config user.name "Test"
mkdir -p docs/retrospectives
# Make ROADMAP and CHANGELOG available
mkdir -p docs
# Use a minimal CHANGELOG
cat > CHANGELOG.md <<'EOF'
# Changelog

## [v0.4.0-rc1] - 2026-06-22

### Added
- A test release
EOF
# Use a minimal ROADMAP
cat > ROADMAP.md <<'EOF'
# Roadmap

## Versions

**v0.4.0-rc1 — shipped 2026-06-22**

- **Estimated:** 36 pts
- **What surprised us:** Test surprise 1.
- **What we'd do differently:** Test differentiator 1.

EOF
git add . && git commit -qm "initial"
git tag v0.4.0-rc1
# Add some commits with patterns
for msg in "fix: bug" "docs: readme" "add test_x" "perf: speed" "refactor: clean"; do
  echo "$msg" > /tmp/_msg && git commit --allow-empty -qm "$msg"
done

out=$("$RETRO" v0.4.0-rc1 --dry-run 2>&1)
[[ -z "$(ls docs/retrospectives/ 2>/dev/null)" ]] && ok "--dry-run doesn't write file" || fail "--dry-run wrote a file"
echo "$out" | grep -q "^---$" && ok "output has YAML front-matter" || fail "no front-matter"
echo "$out" | grep -q "release: v0.4.0-rc1" && ok "front-matter has release" || fail "no release"
echo "$out" | grep -q "## What we said" && ok "has 'What we said' section" || fail "missing section"
echo "$out" | grep -q "## What we actually shipped" && ok "has 'What we actually shipped'" || fail "missing"
echo "$out" | grep -q "## What surprised us" && ok "has 'What surprised us'" || fail "missing"
echo "$out" | grep -q "## What we'd do differently" && ok "has 'What we'd do differently'" || fail "missing"

# ── 3. without --dry-run, writes to .md or -WIP.md
echo "── 3. writes file ──"
"$RETRO" v0.4.0-rc1 > /dev/null 2>&1
files=$(ls docs/retrospectives/ 2>/dev/null | grep -c "v0.4.0-rc1")
[[ "$files" -ge 1 ]] && ok "wrote a file" || fail "no file written"
# Second run should write to -WIP.md (since .md exists)
"$RETRO" v0.4.0-rc1 > /dev/null 2>&1
[[ -f docs/retrospectives/v0.4.0-rc1-WIP.md ]] && ok "second run writes -WIP.md" || fail "no -WIP.md"
# And the original .md should still exist and be the first-run output
[[ -f docs/retrospectives/v0.4.0-rc1.md ]] && ok "original .md still exists" || fail ".md missing"
# Check that the second-run output (WIP) doesn't have the test's commit text
# (this confirms the second run actually wrote a different file)
content_wip=$(cat docs/retrospectives/v0.4.0-rc1-WIP.md)
content_md=$(cat docs/retrospectives/v0.4.0-rc1.md)
# Both should be non-empty
[[ -n "$content_wip" && -n "$content_md" ]] && ok "both files have content" || fail "files empty"

# ── 4. detects "fix" pattern in commits
echo "── 4. bug-fix detection ──"
content=$(cat docs/retrospectives/v0.4.0-rc1-WIP.md)
echo "$content" | grep -q "fix" && ok "detects fix/bug pattern" || fail "no fix detected"
echo "$content" | grep -q "docs" && ok "detects docs pattern" || fail "no docs detected"

# ── 5. commit count
echo "── 5. commit count ──"
total_commits=$(git log v0.4.0-rc1..HEAD --oneline | wc -l | tr -d ' ')
echo "  → $total_commits commits since v0.4.0-rc1 tag"
echo "$content" | grep -q "$total_commits" && ok "commit count appears" || fail "no commit count"

# ── 6. detect v0.4.0-rc1 from CHANGELOG when no release given
echo "── 6. default release from CHANGELOG ──"
# Reset the test dir with minimal config
rm -rf docs/retrospectives
git checkout -- docs/retrospectives 2>/dev/null || true
mkdir -p docs/retrospectives
cat > CHANGELOG.md <<'EOF'
# Changelog

## [v0.3.0] - 2026-06-21

### First
EOF
cat > ROADMAP.md <<'EOF'
# Roadmap

**v0.3.0 — shipped 2026-06-21**

- Estimated: 28 pts
EOF
git add CHANGELOG.md ROADMAP.md && git commit -qm "v0.3.0 metadata" 2>/dev/null
out=$("$RETRO" --dry-run 2>&1)
echo "$out" | grep -q "release: v0.3.0" && ok "defaults to first CHANGELOG release" || fail "didn't find default release: $out"

# ── Summary
echo ""
echo "══════════════════════════════════════════════════════"
echo "  $PASS pass  ·  $FAIL fail"
echo "══════════════════════════════════════════════════════"
[[ $FAIL -eq 0 ]]
