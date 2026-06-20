#!/usr/bin/env bash
# tests/test_skills.sh — Structural and behavioral tests for skills.
#
# Verifies:
#   1. Every skill in skills/ has a SKILL.md with valid frontmatter
#   2. The sparc-reviewer profile references the reviewer-checklist skill
#   3. The reviewer-checklist recipe (extract acceptance criteria from a
#      spec, build review markdown) works against a sample spec + artifact
#
# Run: bash tests/test_skills.sh

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_ROOT="$(cd "$TEST_DIR/.." && pwd)"

PASS=0
FAIL=0
ok()   { printf "  \033[32m✓\033[0m %s\n" "$*"; PASS=$((PASS+1)); }
fail() { printf "  \033[31m✗\033[0m %s\n" "$*"; FAIL=$((FAIL+1)); }
hdr()  { printf "\n\033[1m[%s]\033[0m\n" "$*"; }

# ── 1. Structural tests: every skill has valid frontmatter ────────────

hdr "1. Every skill has SKILL.md with valid frontmatter"

# Find every SKILL.md under skills/. Use a simple loop; avoids dep on find.
skill_files=$(find "$PKG_ROOT/skills" -name "SKILL.md" -type f 2>/dev/null | sort)
if [[ -z "$skill_files" ]]; then
  fail "no SKILL.md files found under skills/"
else
  ok "found $(echo "$skill_files" | wc -l | tr -d ' ') SKILL.md files"
fi

for skill_file in $skill_files; do
  skill_name=$(basename "$(dirname "$skill_file")")

  # Check the frontmatter exists (starts with ---, ends with ---)
  if head -n 1 "$skill_file" | grep -q '^---$'; then
    ok "$skill_name: frontmatter opens with ---"
  else
    fail "$skill_name: frontmatter does not start with ---"
    continue
  fi

  # Find the closing --- (the SECOND --- line, after the first one)
  # awk prints the line numbers of all --- matches; we want the 2nd.
  closing_line=$(awk '/^---$/{print NR}' "$skill_file" | sed -n '2p')
  if [[ -n "$closing_line" && "$closing_line" -gt 1 ]]; then
    ok "$skill_name: frontmatter closes with ---"
  else
    fail "$skill_name: frontmatter does not close with --- (closing_line='$closing_line')"
    continue
  fi

  # Extract frontmatter (lines 2..closing_line-1) and check required fields
  frontmatter=$(sed -n "2,$((closing_line - 1))p" "$skill_file")

  if echo "$frontmatter" | grep -q '^name: '; then
    ok "$skill_name: has name field"
  else
    fail "$skill_name: missing name field"
  fi

  if echo "$frontmatter" | grep -q '^description: '; then
    ok "$skill_name: has description field"
  else
    fail "$skill_name: missing description field"
  fi

  if echo "$frontmatter" | grep -q '^version: '; then
    ok "$skill_name: has version field"
  else
    fail "$skill_name: missing version field"
  fi

  # Check that the name matches the directory name
  expected_name="$skill_name"
  actual_name=$(echo "$frontmatter" | sed -n 's/^name: *//p' | head -n 1 | tr -d '\r')
  if [[ "$actual_name" == "$expected_name" ]]; then
    ok "$skill_name: name field matches directory name"
  else
    fail "$skill_name: name field is '$actual_name', expected '$expected_name'"
  fi

  # Check the file isn't trivial (>500 bytes; a real skill has content)
  size=$(wc -c < "$skill_file" | tr -d ' ')
  if [[ "$size" -gt 500 ]]; then
    ok "$skill_name: file size is $size bytes (>500, real content)"
  else
    fail "$skill_name: file size is only $size bytes (too small to be a real skill)"
  fi
done

# ── 2. Profile check ────────────────────────────────────────────────────

hdr "2. sparc-reviewer profile references sparc-reviewer-checklist"
reviewer_yaml="$PKG_ROOT/profiles/sparc-reviewer.yaml"
if [[ ! -f "$reviewer_yaml" ]]; then
  fail "profiles/sparc-reviewer.yaml does not exist"
else
  if grep -q 'sparc-reviewer-checklist' "$reviewer_yaml"; then
    ok "profile references sparc-reviewer-checklist skill"
  else
    fail "profile does not reference sparc-reviewer-checklist skill"
  fi
  # Verify it's in the skills: section
  if awk '/^skills:/{flag=1; next} /^[a-z]/{flag=0} flag && /sparc-reviewer-checklist/' "$reviewer_yaml" | grep -q .; then
    ok "sparc-reviewer-checklist is in the skills: list (not just mentioned in a comment)"
  else
    fail "sparc-reviewer-checklist is in a comment but not in the skills: list"
  fi
fi

# ── 3. Reviewer recipe: extract acceptance criteria from a sample spec ─

hdr "3. Reviewer recipe: extract acceptance criteria from a sample spec"

# Helper: extract the body of the '## Acceptance Criteria' section.
# Stops at the next ## heading. Empty lines and bullet markers are stripped.
# Args: <spec_file>
# Echoes one line per criterion.
extract_acceptance_criteria() {
  local spec="$1"
  awk '
    /^## Acceptance Criteria/ { in_section = 1; next }
    in_section && /^## / { in_section = 0 }
    in_section && /^[[:space:]]*$/ { next }  # skip blank lines
    in_section {
      # Strip leading whitespace, bullet markers, and numbering
      gsub(/^[[:space:]]*[-*][[:space:]]*/, "", $0)
      gsub(/^[[:space:]]*[0-9]+\.[[:space:]]*/, "", $0)
      print
    }
  ' "$spec"
}

# Helper: build a review markdown from criteria + a check function
# Args: <stage> <criteria_count> <passing_count> <verdict> <notes>
build_review() {
  local stage="$1" total="$2" passing="$3" verdict="$4" notes="$5"
  local failing=$((total - passing))
  cat <<EOF
# Review of ${stage}

**Spec acceptance criteria:** ${total} total
**Passing:** ${passing}
**Failing:** ${failing}

## Verdict

VERDICT: ${verdict}

## Notes for the human

${notes}
EOF
}

# Test 3a: a sample spec with 3 criteria
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT
sample_spec="$TMPDIR/spec.md"
cat > "$sample_spec" <<'SPEC_EOF'
# Specification

## User Stories

- As a developer, I want a CLI to run the SPARC pipeline.

## Acceptance Criteria

- All public functions have docstrings
- Test coverage is at least 80 percent
- No new lint warnings

## Success Metrics

- Pipeline runs end-to-end without manual intervention
SPEC_EOF

criteria=$(extract_acceptance_criteria "$sample_spec")
n=$(echo "$criteria" | wc -l | tr -d ' ')
if [[ "$n" -eq 3 ]]; then
  ok "extracted 3 acceptance criteria from sample spec"
else
  fail "expected 3 criteria, got $n"
fi

# Verify each criterion text
if echo "$criteria" | grep -q "All public functions have docstrings"; then
  ok "criterion 1 extracted verbatim"
else
  fail "criterion 1 not found in extracted text"
fi
if echo "$criteria" | grep -q "Test coverage is at least 80 percent"; then
  ok "criterion 2 extracted verbatim"
else
  fail "criterion 2 not found in extracted text"
fi
if echo "$criteria" | grep -q "No new lint warnings"; then
  ok "criterion 3 extracted verbatim"
else
  fail "criterion 3 not found in extracted text"
fi

# Test 3b: extraction stops at the next ## heading
if echo "$criteria" | grep -q "Pipeline runs end-to-end"; then
  fail "extraction leaked into Success Metrics section"
else
  ok "extraction stopped at the next ## heading"
fi

# Test 3c: build a review and verify its structure
review=$(build_review "refinement" 3 3 "APPROVE" "All criteria pass")
if echo "$review" | grep -q "^# Review of refinement$"; then
  ok "review has the correct title"
else
  fail "review title missing or wrong"
fi
if echo "$review" | grep -q "^\\*\\*Spec acceptance criteria:\\*\\* 3 total$"; then
  ok "review shows total criteria count"
else
  fail "review missing or wrong total count"
fi
if echo "$review" | grep -q "^\\*\\*Passing:\\*\\* 3$"; then
  ok "review shows passing count"
else
  fail "review missing or wrong passing count"
fi
if echo "$review" | grep -q "^\\*\\*Failing:\\*\\* 0$"; then
  ok "review shows failing count"
else
  fail "review missing or wrong failing count"
fi
if echo "$review" | grep -q "^VERDICT: APPROVE"; then
  ok "review shows verdict"
else
  fail "review missing or wrong verdict"
fi

# Test 3d: a failing review (REDIRECT with notes)
review_fail=$(build_review "completion" 5 4 "REDIRECT" "README is missing two env vars")
if echo "$review_fail" | grep -q "^VERDICT: REDIRECT"; then
  ok "REDIRECT verdict is correctly formatted"
else
  fail "REDIRECT verdict missing"
fi
if echo "$review_fail" | grep -q "^\\*\\*Failing:\\*\\* 1$"; then
  ok "5 total, 4 passing, 1 failing math is correct"
else
  fail "passing/failing math is wrong"
fi

# Test 3e: numbered criteria format (1. 2. 3.)
sample_spec2="$TMPDIR/spec2.md"
cat > "$sample_spec2" <<'SPEC_EOF'
# Spec

## Acceptance Criteria

1. First criterion
2. Second criterion

## Next Section
SPEC_EOF
criteria2=$(extract_acceptance_criteria "$sample_spec2")
n2=$(echo "$criteria2" | wc -l | tr -d ' ')
if [[ "$n2" -eq 2 ]]; then
  ok "numbered criteria extracted (1. 2.)"
else
  fail "expected 2 numbered criteria, got $n2"
fi

# Test 3f: empty acceptance criteria section
sample_spec3="$TMPDIR/spec3.md"
cat > "$sample_spec3" <<'SPEC_EOF'
# Spec

## Acceptance Criteria

## Other Section
SPEC_EOF
criteria3=$(extract_acceptance_criteria "$sample_spec3")
# wc -l counts a trailing newline even on empty input. Strip whitespace
# before counting so we get a true count.
n3=$(echo -n "$criteria3" | wc -l | tr -d ' ')
if [[ "$n3" -eq 0 ]]; then
  ok "empty acceptance criteria section returns 0 lines"
else
  fail "expected 0 lines, got $n3: '$criteria3'"
fi

# ── Summary ────────────────────────────────────────────────────────────
printf "\n══════════════════════════════════════════════════════\n"
printf "  %d pass  ·  %d fail\n" "$PASS" "$FAIL"
printf "══════════════════════════════════════════════════════\n"

[[ "$FAIL" -eq 0 ]] || exit 1