# tests/integration/ — Integration tests for sparqr.
#
# Unlike tests/test_*.sh (which run fast and use mocked hermes),
# these tests run the package against a real Hermes installation.
# They are SLOW and require Docker.
#
# To run locally:
#   1. cd tests/integration
#   2. docker compose up -d hermes    # bring up real Hermes
#   3. ./run-all.sh                   # run all integration tests
#   4. docker compose down            # cleanup
#
# To skip these tests (default):
#   Just run tests/test_*.sh — this directory is not part of that glob.
#
# The integration tests are organized by what they exercise:
#   - test_setup_against_hermes.sh   : setup.sh runs end-to-end
#   - test_single_stage_run.sh       : one stage completes against real hermes
#   - test_two_stage_pipeline.sh     : full pipeline with HITL gate
#   - test_record_replay.sh          : VCR-style recording harness
#
# Each test starts with `set -uo pipefail` and uses the helpers in
# lib/test-helpers.sh (relative to this directory).
#
# Why integration tests exist separately from the unit tests:
#   - Mocked hermes can't catch real CLI output format changes
#   - Mocked hermes can't catch race conditions in real spawn/wait
#   - Mocked hermes can't catch SQLite schema mismatches with real kanban
#   - Real Hermes is slow to start (~5s), so unit tests are the default

# Subdirectories
subdirs=(
  fixtures/    # Recorded hermes sessions (JSON outputs from real runs)
  lib/         # Shared test helpers
)

# Layout:
# tests/integration/
#   README.md               (this file)
#   docker-compose.yml      # Brings up real Hermes
#   Dockerfile.hermes       # Image definition for hermes (uses real install)
#   run-all.sh              # Entry point: runs every test_*.sh in this dir
#   lib/
#     test-helpers.sh       # Shared setup/teardown, hermes config
#     record-replay.sh      # VCR-style recording harness
#   fixtures/
#     hermes-kanban-list.json
#     hermes-kanban-create.json
#     ...
#   test_setup_against_hermes.sh
#   test_single_stage_run.sh
#   test_two_stage_pipeline.sh
#   test_record_replay.sh

# Design notes
# ------------
# 1. Real hermes, recorded sessions
# ---------------------------------
# The recording harness (record-replay.sh) captures every call to
# `hermes kanban ...` the first time a test runs against real Hermes
# (in CI with Docker). On subsequent runs (locally without Docker),
# the harness replays the recorded JSON. This gives us the
# integration-test benefit (testing against real Hermes outputs)
# without the cost (Docker required every time).
#
# Cost: when Hermes changes its output format, recordings need to
# be re-generated. The run-all.sh script has a `--record` flag that
# re-records all sessions.
#
# 2. Slow tests, marked accordingly
# ---------------------------------
# Every test in this directory:
#   - starts with the line "# SLOW_TEST" in the first 5 lines (for
#     the CI workflow to detect)
#   - has a --record flag for re-recording
#   - cleans up Docker on exit
#
# 3. Why not just use mocks?
# --------------------------
# The unit tests (tests/test_*.sh) use mocks. Mocks are fast and
# cover most behavior. But mocks can't catch:
#   - Real hermes CLI output format changes
#   - SQLite schema evolution
#   - Timing-dependent bugs (race conditions)
#   - Real kanban DB transaction behavior
#
# We need both layers.

# When to add a new integration test
# ----------------------------------
# Add a new test here when:
#   - You're fixing a bug that mocks can't reproduce
#   - Hermes releases a new feature we want to verify
#   - A test failure in CI only reproduces against real hermes
#   - The behavior depends on actual filesystem or DB state
#
# Don't add tests here that can run with mocks — they belong in
# tests/test_*.sh and run on every PR.