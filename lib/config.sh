# lib/config.sh — sparc.config.yaml parsing helpers.
#
# The config file is per-project (./sparc.config.yaml) and uses a
# simple YAML subset: top-level sections, 2-deep keys, scalar values.
# We parse it with pure awk — no yq, no python3 dependency — because
# the YAML we actually use is tiny and the parser is 6 lines.
#
# If the user has yq installed, it's faster; this file's parser is
# the portable fallback. Both produce the same results for our
# supported YAML subset.
#
# Scope: this file grows as we add config-driven features. Each
# section gets a `<section>_get <key>` helper. The first such helper
# is `sparc_config_models_get <stage>` for the per-stage model
# routing added in v0.2.0 story 5.

# Source dependencies. No double-source guard: see lib/kanban.sh for
# the full reasoning. Same pattern applies here.

# sparc_config_get <config_file> <section> [<key>]
#
#   Echoes the value of `<section>.<key>` from a sparc.config.yaml
#   file. If <key> is omitted, echoes the section's scalar value
#   (for top-level scalars like `board: foo`) OR lists all sub-keys
#   (for sections with indented children like `models:`). If the
#   section or key is missing, echoes nothing and returns 1.
#
#   The parser handles the YAML subset we actually use. There are
#   two valid section shapes:
#
#     section: value                 # scalar on the same line
#
#     section:                       # nothing on this line; sub-map below
#       key: value
#       another: value
#
#   Both shapes are accepted. Lines that are blank, comments, or
#   nested maps/lists are skipped. Quoted values have their
#   surrounding quotes stripped.
#
#   Returns: 0 on a hit, 1 on a miss. Always echoes to stdout.
sparc_config_get() {
  local config="$1" section="$2"
  local key="${3:-}"
  [[ -f "$config" ]] || return 1

  awk -v section="$section" -v key="$key" '
    # Skip blank lines and comments (anywhere)
    /^[[:space:]]*$/ { next }
    /^[[:space:]]*#/ { next }
    # Top-level section header (no leading whitespace, ends with ":")
    /^[^[:space:]]/ {
      if (in_section) exit  # we already left the section
      in_section = ($1 == section ":")
      if (!in_section) next
      # We are in the section. Check for an inline scalar value.
      line = $0
      sub(/^[^:]+:[[:space:]]*/, "", line)
      gsub(/^["\047]|["\047]$/, "", line)
      if (line != "") {
        # Has an inline value. This is a top-level scalar section.
        if (key == "") {
          print line
          found = 1
          exit
        } else {
          # Asked for a key in a scalar section — not present
          exit 1
        }
      }
      next
    }
    # In the section, capture "  key: value" lines (sub-map)
    in_section && /^[[:space:]]+[a-zA-Z_]/ {
      if (key == "") {
        # Echo the whole line as "key: value"
        key_part = $0
        sub(/^[[:space:]]+/, "", key_part)
        sub(/:[[:space:]].*$/, "", key_part)
        val_part = $0
        sub(/^[[:space:]]+[^:]+:[[:space:]]*/, "", val_part)
        gsub(/^["\047]|["\047]$/, "", val_part)
        printf "%s: %s\n", key_part, val_part
        found = 1
      } else if ($1 == key ":") {
        val = $0
        sub(/^[^:]+:[[:space:]]*/, "", val)
        gsub(/^["\047]|["\047]$/, "", val)
        print val
        found = 1
        exit
      }
    }
    END {
      exit (found ? 0 : (key == "" ? 0 : 1))
    }
  ' "$config"
}

# sparc_config_models_get <config_file> <stage>
#
#   Convenience wrapper for the most common config lookup: the model
#   ID for a given stage. Returns the model string (e.g. "anthropic/
#   claude-haiku-4"), or empty if the stage isn't configured.
#
#   This is the function the orchestrator calls in its spawn pass.
#   The lookup is O(1) in practice (the YAML is small) and the
#   result is cached at the call site if needed.
sparc_config_models_get() {
  local config="$1" stage="$2"
  sparc_config_get "$config" "models" "$stage"
}

# sparc_config_gates_get <config_file> <stage> [<param>]
#
#   Echoes the value of a gate parameter for the given stage.
#   Default param is "type" (so `gates_get cfg spec` returns
#   "approval" / "confidence" / "sampling" / "exception").
#
#   Schema (v0.3.0 story 1):
#
#     gates:
#       spec:
#         type: approval           # or confidence | sampling | exception
#       design:
#         type: confidence
#         threshold: 0.9           # auto-approve if reviewer >= this
#       refinement:
#         type: sampling
#         percent: 10              # review N% of the time
#       completion:
#         type: exception          # review only on reviewer flag
#
#   Returns 1 if config doesn't exist OR if the stage/param is
#   missing. Echoes empty in those cases.
#
#   The parser walks 3 levels deep (gates -> stage -> param). The
#   pure-awk parser below is intentional: no yq/python dependency,
#   and the gates section is small enough that a recursive descent
#   parser isn't worth the complexity.
sparc_config_gates_get() {
  local config="$1" stage="$2" param="${3:-type}"
  [[ -f "$config" ]] || return 1

  awk -v stage="$stage" -v param="$param" '
    # Top-level "gates:" header
    /^gates:[[:space:]]*$/ {
      in_gates = 1
      current_stage = ""
      next
    }
    # Any non-blank, non-comment line at column 0 exits the section
    in_gates && /^[^[:space:]#]/ && !/^gates:/ {
      in_gates = 0
      current_stage = ""
      next
    }
    # Stage header line: "  spec:" (key ending with ":", no value)
    in_gates && /^[[:space:]]+[a-zA-Z_][a-zA-Z0-9_-]*:[[:space:]]*$/ {
      line = $0
      sub(/^[[:space:]]+/, "", line)
      sub(/:.*$/, "", line)
      current_stage = line
      next
    }
    # Parameter line: "  type: approval" (key, colon, value)
    in_gates && current_stage == stage \
        && /^[[:space:]]+[a-zA-Z_][a-zA-Z0-9_-]*:[[:space:]]+/ {
      this_param = $1
      sub(/:$/, "", this_param)
      if (this_param == param) {
        val = $0
        sub(/^[^:]+:[[:space:]]*/, "", val)
        gsub(/^["\047]|["\047]$/, "", val)
        print val
        exit 0
      }
    }
    END { exit 1 }
  ' "$config"
}

# sparc_config_gate_default <stage>
#
#   Returns the default gate type for a stage if the user hasn't
#   configured one. Approval is the safe default — explicit human
#   review — because that matches v0.2.0 behavior and avoids
#   silently changing gate semantics.
sparc_config_gate_default() {
  echo "approval"
}