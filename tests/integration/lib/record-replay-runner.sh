#!/usr/bin/env bash
# record-replay-runner.sh — Executable that wraps the record-replay
# harness so the mock hermes can `exec` it.
#
# The mock hermes (set up by setup_test_env) is a single-file script
# that does `exec record-replay-runner.sh "$@"`. This script sources
# the record-replay library and calls sparc_rr_record_one with the
# arguments.
#
# This file is a thin executable wrapper; all the logic is in
# lib/record-replay.sh.

# Locate the record-replay library relative to this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./record-replay.sh
source "$SCRIPT_DIR/record-replay.sh"

# Pass through to the harness
sparc_rr_record_one "$@"