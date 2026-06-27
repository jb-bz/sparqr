#!/usr/bin/env bash
# post-commit hook for sparqr (v0.4.1 story 4e).
#
# Detects when a release tag was just added or the latest commit
# references a version, and emits a non-blocking reminder to run
# \`sparc retro\`. Optional — installed by \`sparc init\` if
# sparc.hooks_enabled is true in sparc.config.yaml.

set +e

# Get the latest commit message and the latest tag
commit_msg=$(git log -1 --pretty=%B 2>/dev/null | head -n 1)
latest_tag=$(git describe --tags --abbrev=0 2>/dev/null)

# Check if the latest tag was just added (commit msg references it,
# or the tag hash matches HEAD)
matches_release=0
if [[ -n "$latest_tag" ]] && [[ "$(git rev-list -1 "${latest_tag}" 2>/dev/null)" == "$(git rev-parse HEAD 2>/dev/null)" ]]; then
  matches_release=1
fi
if echo "$commit_msg" | grep -qE 'v[0-9]+\.[0-9]+(\.[0-9]+)?'; then
  matches_release=1
fi

if [[ $matches_release -eq 1 ]]; then
  echo ""
  echo "  ┌─ sparqr reminder ────────────────────────────────────────┐"
  echo "  │ release tag detected. run:                              │"
  echo "  │   sparc retro ${latest_tag:-v0.X.0}                      │"
  echo "  │ to scaffold the retrospective file (auto-generated).    │"
  echo "  └──────────────────────────────────────────────────────────┘"
  echo ""
fi