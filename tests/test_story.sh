#!/usr/bin/env bash
# tests/test_story.sh — Unit tests for bin/sparc-story (v0.4.1 story 4a).
#
# Tests in a tempdir to avoid polluting the real package's .sparc/.
# bash 3.2 compatible (no declare -A).

set -uo pipefail

PASS=0
FAIL=0
ok()   { echo "  ✓ $*"; PASS=$((PASS+1)); }
fail() { echo "  ✗ $*"; FAIL=$((FAIL+1)); }

PKG_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STORY="$PKG_ROOT/bin/sparc-story"

# Skip if pyyaml not available
if ! python3 -c "import yaml" 2>/dev/null; then
  echo "  ⚠  python3 pyyaml not available — skipping test_story.sh"
  echo "  Install with: pip3 install --user pyyaml"
  exit 0
fi

TESTDIR=$(mktemp -d -t sparqr-story-test-XXXXXX)
cd "$TESTDIR"
trap "cd / && rm -rf $TESTDIR" EXIT

# ── 1. stories file is auto-created on first add
echo "── 1. auto-create stories file ──"
"$STORY" add "First story" --points 3 > /dev/null 2>&1
[[ -f .sparc/stories.yaml ]] && ok "creates .sparc/stories.yaml on first add" || fail ".sparc/stories.yaml not created"
grep -q "schema_version: 1" .sparc/stories.yaml && ok "file has schema_version 1" || fail "no schema_version in file"

# ── 2. add a 3-pt story
echo "── 2. add 3-pt story ──"
out=$("$STORY" add "Second story" --points 3 2>&1)
echo "$out" | grep -q "second-story" && ok "id generated from name" || fail "no id in output: $out"
echo "$out" | grep -q "3 pts" && ok "shows points in output" || fail "no points in output"
echo "$out" | grep -q "planned" && ok "default status is planned" || fail "no status in output"
count=$(python3 -c "import yaml; d=yaml.safe_load(open('.sparc/stories.yaml')); print(len(d.get('stories', [])))")
[[ "$count" == "2" ]] && ok "file has 2 stories" || fail "expected 2 stories, got $count"

# ── 3. invalid points rejected
echo "── 3. invalid points rejected ──"
out=$("$STORY" add "Bad story" --points 7 2>&1)
[[ "$?" -ne 0 ]] && ok "rejects points=7" || fail "accepted invalid points"
echo "$out" | grep -q "must be one of 1, 2, 3, 5, 8, 13" && ok "explains the valid set" || fail "no error message"

# ── 4. duplicate name rejected
echo "── 4. duplicate name in same release ──"
out=$("$STORY" add "Second story" --points 5 2>&1)
[[ "$?" -ne 0 ]] && ok "rejects duplicate name" || fail "accepted duplicate name"

# ── 5. 13-pt triggers warning but still adds
echo "── 5. 13-pt warning ──"
out=$("$STORY" add "Big one" --points 13 2>&1)
echo "$out" | grep -q "WARNING" && ok "13-pt story emits warning" || fail "no warning for 13-pt"
echo "$out" | grep -q "must be split" && ok "warning explains the rule" || fail "no rule explained"
count=$(python3 -c "import yaml; d=yaml.safe_load(open('.sparc/stories.yaml')); print(len(d.get('stories', [])))")
[[ "$count" == "3" ]] && ok "13-pt story IS added (warning is not a blocker)" || fail "13-pt story not added"

# ── 6. list shows all stories
echo "── 6. list ──"
out=$("$STORY" list 2>&1)
echo "$out" | grep -q "First story" && ok "list shows First story" || fail "First story not in list"
echo "$out" | grep -q "Second story" && ok "list shows Second story" || fail "Second story not in list"
echo "$out" | grep -q "Big one" && ok "list shows Big one" || fail "Big one not in list"
echo "$out" | grep -q "v0.4.0" && ok "list shows release header" || fail "no release header"

# ── 7. show one story
echo "── 7. show ──"
out=$("$STORY" show second-story-$(python3 -c "import yaml,re; d=yaml.safe_load(open('.sparc/stories.yaml')); [print(re.search(r'id: (\\S+)', open('.sparc/stories.yaml').read().split('name: Second story')[0]).group(1) if 'Second story' in str(d.get('stories', [])) else '']" 2>/dev/null) 2>&1)
# Simpler: extract id directly
SECOND_ID=$(python3 -c "import yaml; d=yaml.safe_load(open('.sparc/stories.yaml')); print([s['id'] for s in d['stories'] if s['name']=='Second story'][0])")
out=$("$STORY" show "$SECOND_ID" 2>&1)
echo "$out" | grep -q "id:.*$SECOND_ID" && ok "show displays id" || fail "no id in show"
echo "$out" | grep -q "points:    3" && ok "show displays points" || fail "no points in show"
echo "$out" | grep -q "Second story" && ok "show displays name" || fail "no name in show"

# ── 8. update status
echo "── 8. update ──"
"$STORY" update "$SECOND_ID" --status in-progress > /dev/null 2>&1
status=$(python3 -c "import yaml; d=yaml.safe_load(open('.sparc/stories.yaml')); print([s['status'] for s in d['stories'] if s['id']=='$SECOND_ID'][0])")
[[ "$status" == "in-progress" ]] && ok "status updated to in-progress" || fail "status not updated, got: $status"

# ── 9. split a 13-pt story
echo "── 9. split 13-pt story ──"
BIG_ID=$(python3 -c "import yaml; d=yaml.safe_load(open('.sparc/stories.yaml')); print([s['id'] for s in d['stories'] if s['name']=='Big one'][0])")
out=$("$STORY" split "$BIG_ID" --into "Sub A" --points 5 --into "Sub B" --points 8 2>&1)
echo "$out" | grep -q "split into 2" && ok "split emits confirmation" || fail "no split confirmation: $out"
count=$(python3 -c "import yaml; d=yaml.safe_load(open('.sparc/stories.yaml')); print(len(d.get('stories', [])))")
[[ "$count" == "5" ]] && ok "5 stories after split (3 + 2 subs)" || fail "expected 5 stories, got $count"
status=$(python3 -c "import yaml; d=yaml.safe_load(open('.sparc/stories.yaml')); print([s['status'] for s in d['stories'] if s['id']=='$BIG_ID'][0])")
[[ "$status" == "deferred" ]] && ok "parent story marked deferred after split" || fail "parent not deferred"

# ── 10. rm
echo "── 10. rm ──"
"$STORY" rm "$SECOND_ID" > /dev/null 2>&1
count=$(python3 -c "import yaml; d=yaml.safe_load(open('.sparc/stories.yaml')); print(len(d.get('stories', [])))")
[[ "$count" == "4" ]] && ok "rm reduces count" || fail "rm didn't remove story"

# ── Summary
echo ""
echo "══════════════════════════════════════════════════════"
echo "  $PASS pass  ·  $FAIL fail"
echo "══════════════════════════════════════════════════════"
[[ $FAIL -eq 0 ]]
