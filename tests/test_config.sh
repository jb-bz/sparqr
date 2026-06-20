#!/usr/bin/env bash
# tests/test_config.sh — Unit tests for lib/config.sh (v0.2.0 story 5).
#
# Tests the sparc.config.yaml parser in isolation. We write small
# YAML files to a tempdir, call the parser, and verify the output.
# No mocking of hermes needed — this is pure bash + awk.
#
# Run: bash tests/test_config.sh

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_ROOT="$(cd "$TEST_DIR/.." && pwd)"

PASS=0
FAIL=0
ok()   { printf "  \033[32m✓\033[0m %s\n" "$*"; PASS=$((PASS+1)); }
fail() { printf "  \033[31m✗\033[0m %s\n" "$*"; FAIL=$((FAIL+1)); }
hdr()  { printf "\n\033[1m[%s]\033[0m\n" "$*"; }

TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

# Source the lib fresh for each test
fresh_source() {
  unset SPARC_CONFIG_LOADED
  # shellcheck source=../lib/config.sh
  source "$PKG_ROOT/lib/config.sh"
}

# Write a YAML config file from a heredoc
write_config() {
  local name="$1"
  local path="$TMPDIR/$name"
  cat > "$path"
  echo "$path"
}

# ───────────────────────────────────────────────────────────────────────
# TEST 1: sparc_config_get returns a value for a simple key
# ───────────────────────────────────────────────────────────────────────
hdr "1. sparc_config_get: simple key lookup"
fresh_source
cfg=$(write_config "simple.yaml" <<'EOF'
models:
  spec: anthropic/claude-haiku-4
  design: anthropic/claude-haiku-4
EOF
)

val=$(sparc_config_get "$cfg" "models" "spec")
if [[ "$val" == "anthropic/claude-haiku-4" ]]; then
  ok "got spec value"
else
  fail "got '$val'"
fi

val=$(sparc_config_get "$cfg" "models" "design")
if [[ "$val" == "anthropic/claude-haiku-4" ]]; then
  ok "got design value"
else
  fail "got '$val'"
fi

# ───────────────────────────────────────────────────────────────────────
# TEST 2: missing key returns empty + exit 1
# ───────────────────────────────────────────────────────────────────────
hdr "2. sparc_config_get: missing key returns empty"
fresh_source
cfg=$(write_config "miss.yaml" <<'EOF'
models:
  spec: foo
EOF
)
val=$(sparc_config_get "$cfg" "models" "nonexistent")
rc=$?
if [[ -z "$val" ]]; then ok "empty value for missing key"; else fail "got '$val'"; fi
if [[ $rc -ne 0 ]]; then ok "exit code is non-zero for miss"; else fail "expected non-zero, got $rc"; fi

# ───────────────────────────────────────────────────────────────────────
# TEST 3: missing section returns empty
# ───────────────────────────────────────────────────────────────────────
hdr "3. sparc_config_get: missing section returns empty"
fresh_source
cfg=$(write_config "no_section.yaml" <<'EOF'
other_section:
  foo: bar
EOF
)
val=$(sparc_config_get "$cfg" "models" "spec")
rc=$?
if [[ -z "$val" ]]; then ok "empty value for missing section"; else fail "got '$val'"; fi
if [[ $rc -ne 0 ]]; then ok "exit code is non-zero"; else fail "expected non-zero, got $rc"; fi

# ───────────────────────────────────────────────────────────────────────
# TEST 4: quoted values have quotes stripped
# ───────────────────────────────────────────────────────────────────────
hdr "4. sparc_config_get: quoted values have quotes stripped"
fresh_source
cfg=$(write_config "quoted.yaml" <<'EOF'
models:
  spec: "anthropic/claude-haiku-4"
  design: 'anthropic/claude-sonnet-4'
EOF
)
val=$(sparc_config_get "$cfg" "models" "spec")
if [[ "$val" == "anthropic/claude-haiku-4" ]]; then
  ok "double-quoted value stripped"
else
  fail "double-quoted: got '$val'"
fi
val=$(sparc_config_get "$cfg" "models" "design")
if [[ "$val" == "anthropic/claude-sonnet-4" ]]; then
  ok "single-quoted value stripped"
else
  fail "single-quoted: got '$val'"
fi

# ───────────────────────────────────────────────────────────────────────
# TEST 5: multiple sections — only the right one is matched
# ───────────────────────────────────────────────────────────────────────
hdr "5. sparc_config_get: multiple sections are correctly partitioned"
fresh_source
cfg=$(write_config "multi.yaml" <<'EOF'
board: sparc-my-app
hitl_adapter: terminal

models:
  spec: anthropic/claude-haiku-4
  design: anthropic/claude-haiku-4
  architecture: anthropic/claude-sonnet-4

profiles:
  spec: sparc-spec
  design: sparc-design
EOF
)

# Different sections shouldn't bleed into each other
val=$(sparc_config_get "$cfg" "models" "spec")
if [[ "$val" == "anthropic/claude-haiku-4" ]]; then ok "models.spec is correct"; else fail "got '$val'"; fi
val=$(sparc_config_get "$cfg" "profiles" "spec")
if [[ "$val" == "sparc-spec" ]]; then ok "profiles.spec is correct"; else fail "got '$val'"; fi
val=$(sparc_config_get "$cfg" "profiles" "design")
if [[ "$val" == "sparc-design" ]]; then ok "profiles.design is correct"; else fail "got '$val'"; fi

# Make sure models doesn't return profiles' spec
val=$(sparc_config_get "$cfg" "models" "sparc-spec")
if [[ -z "$val" ]]; then ok "models doesn't return 'sparc-spec'"; else fail "got '$val'"; fi

# ───────────────────────────────────────────────────────────────────────
# TEST 6: comments are ignored
# ───────────────────────────────────────────────────────────────────────
hdr "6. sparc_config_get: comments are ignored"
fresh_source
cfg=$(write_config "comments.yaml" <<'EOF'
# Top-level comment
models:
  # Inside-section comment
  spec: foo
  # Another comment
  design: bar
EOF
)
val=$(sparc_config_get "$cfg" "models" "spec")
if [[ "$val" == "foo" ]]; then ok "spec value ignores comment above"; else fail "got '$val'"; fi
val=$(sparc_config_get "$cfg" "models" "design")
if [[ "$val" == "bar" ]]; then ok "design value ignores comment above"; else fail "got '$val'"; fi

# ───────────────────────────────────────────────────────────────────────
# TEST 7: list all keys in a section (no key arg)
# ───────────────────────────────────────────────────────────────────────
hdr "7. sparc_config_get: list all keys (no key arg)"
fresh_source
cfg=$(write_config "list.yaml" <<'EOF'
models:
  spec: foo
  design: bar
  architecture: baz
EOF
)
all=$(sparc_config_get "$cfg" "models")
# Use grep -c to count lines (handles missing trailing newline correctly)
n=$(echo "$all" | grep -c .)
if [[ "$n" -eq 3 ]]; then ok "got 3 lines"; else fail "expected 3 lines, got $n: $all"; fi
if echo "$all" | grep -q "^spec: foo$"; then ok "spec: foo present"; else fail "missing spec: foo"; fi
if echo "$all" | grep -q "^design: bar$"; then ok "design: bar present"; else fail "missing design: bar"; fi
if echo "$all" | grep -q "^architecture: baz$"; then ok "architecture: baz present"; else fail "missing architecture: baz"; fi

# ───────────────────────────────────────────────────────────────────────
# TEST 8: sparc_config_models_get is the right wrapper
# ───────────────────────────────────────────────────────────────────────
hdr "8. sparc_config_models_get: thin wrapper around models section"
fresh_source
cfg=$(write_config "models_wrap.yaml" <<'EOF'
models:
  spec: anthropic/claude-haiku-4
  refinement: anthropic/claude-sonnet-4
EOF
)
val=$(sparc_config_models_get "$cfg" "spec")
if [[ "$val" == "anthropic/claude-haiku-4" ]]; then ok "models_get spec"; else fail "got '$val'"; fi
val=$(sparc_config_models_get "$cfg" "refinement")
if [[ "$val" == "anthropic/claude-sonnet-4" ]]; then ok "models_get refinement"; else fail "got '$val'"; fi

# ───────────────────────────────────────────────────────────────────────
# TEST 9: empty file returns empty
# ───────────────────────────────────────────────────────────────────────
hdr "9. sparc_config_get: empty file returns empty"
fresh_source
cfg=$(write_config "empty.yaml" <<'EOF'
EOF
)
val=$(sparc_config_get "$cfg" "models" "spec")
if [[ -z "$val" ]]; then ok "empty file → empty value"; else fail "got '$val'"; fi

# ───────────────────────────────────────────────────────────────────────
# TEST 10: nonexistent file returns empty
# ───────────────────────────────────────────────────────────────────────
hdr "10. sparc_config_get: nonexistent file returns empty"
fresh_source
val=$(sparc_config_get "$TMPDIR/does_not_exist.yaml" "models" "spec")
if [[ -z "$val" ]]; then ok "nonexistent file → empty value"; else fail "got '$val'"; fi

# ───────────────────────────────────────────────────────────────────────
# TEST 11: real sparc.config.yaml.example parses cleanly
# ───────────────────────────────────────────────────────────────────────
hdr "11. Real sparc.config.yaml.example parses without errors"
fresh_source
example="$PKG_ROOT/sparc.config.yaml.example"
if [[ ! -f "$example" ]]; then
  fail "example file does not exist at $example"
else
  # Should not error on the existing example (no models: section yet,
  # but other sections should still parse)
  val=$(sparc_config_get "$example" "board")
  if [[ -n "$val" ]]; then ok "example's board: $val"; else fail "couldn't parse board"; fi
  val=$(sparc_config_get "$example" "hitl_adapter")
  if [[ -n "$val" ]]; then ok "example's hitl_adapter: $val"; else fail "couldn't parse hitl_adapter"; fi
fi

# ───────────────────────────────────────────────────────────────────────
# TEST 12: model IDs with slashes (e.g. anthropic/claude-haiku-4) parse cleanly
# ───────────────────────────────────────────────────────────────────────
hdr "12. Model IDs with slashes parse correctly"
fresh_source
cfg=$(write_config "slashes.yaml" <<'EOF'
models:
  spec: anthropic/claude-haiku-4
  design: anthropic/claude-haiku-4-20250101
  architecture: openai/gpt-5
EOF
)
val=$(sparc_config_get "$cfg" "models" "spec")
if [[ "$val" == "anthropic/claude-haiku-4" ]]; then ok "vendor/model-id"; else fail "got '$val'"; fi
val=$(sparc_config_get "$cfg" "models" "architecture")
if [[ "$val" == "openai/gpt-5" ]]; then ok "openai model"; else fail "got '$val'"; fi

# ───────────────────────────────────────────────────────────────────────
# Summary
# ───────────────────────────────────────────────────────────────────────
printf "\n══════════════════════════════════════════════════════\n"
printf "  %d pass  ·  %d fail\n" "$PASS" "$FAIL"
printf "══════════════════════════════════════════════════════\n"

[[ "$FAIL" -eq 0 ]] || exit 1