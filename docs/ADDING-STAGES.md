# Adding / Removing / Reordering Stages

Stages are pure data in `lib/stages.sh`. The orchestrator, validator, and stage-agent-runner all read from this single source. To customize the pipeline, edit the data.

**Navigation:** [The 6 default stages](#the-6-default-stages) · [Per-project override](#per-project-override-no-code-change) · [Adding a new stage (for everyone)](#adding-a-new-stage-to-the-package-for-everyone) · [Removing a stage (per-project)](#removing-a-stage-per-project) · [Removing a stage (for everyone)](#removing-a-stage-for-everyone) · [What to NOT customize](#what-to-not-customize) · [Reference](#reference)

---

## Quick links

- **What is sparqr?** See the [README](../README.md).
- **What are the default stages?** See the [README § The 6 stages](../README.md#-the-6-stages).
- **I want a new HITL review surface** → [HITL.md](HITL.md).
- **Something broke** → [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

---

## The 6 default stages

```
spec → design → pseudocode → architecture → refinement → completion
```

You can:
- **Reorder** — change the order in `SPARC_STAGE_KEYS_DEFAULT`
- **Remove** — delete a key from the array
- **Add** — add a new key + a new line in `SPARC_STAGES_TABLE` + a new profile + a new skill + a new template + a new validator
- **Rename** — change a key (and all references)

## Per-project override (no code change)

For per-project changes, edit `sparc.config.yaml` and use the `stages:` and `hitl_gates:` keys:

```yaml
# Skip the Design stage for this project
stages:
  - spec
  - pseudocode
  - architecture
  - refinement
  - completion

# Gate at every stage (heavy)
hitl_gates:
  spec:         true
  design:       true
  pseudocode:   true
  architecture: true
  refinement:   true
  completion:   true
```

`SPARC_STAGE_KEYS` and `SPARC_HITL_GATES` env vars are set by the CLI when it loads your config. No code change needed for per-project customization.

## Adding a new stage to the package (for everyone)

To add a "Design Review" stage between Design and Pseudocode, so designers can gate on the design before pseudocode starts:

### 1. Add a row to `lib/stages.sh`

```bash
SPARC_STAGE_KEYS_DEFAULT=(
  spec
  design
  design-review   # <-- new
  pseudocode
  architecture
  refinement
  completion
)

SPARC_STAGES_TABLE='
spec|sparc-spec|sparc-stage-spec|templates/specification.md|true|…
design|sparc-design|sparc-stage-design|templates/design.md|false|…
design-review|sparc-design-review|sparc-stage-helpers|templates/design-review.md|true|…
pseudocode|…
…
'

# Also add the name mapping in sparc_stage_get():
#     design-review) echo "Design Review" ;;
```

### 2. Create a profile: `profiles/sparc-design-review.yaml`

```yaml
name: sparc-design-review
description: Design review stage — collects feedback on the design from stakeholders.

config:
  agent:
    max_turns: 30
  terminal:
    timeout: 300
  delegation:
    max_iterations: 5

skills:
  - sparc-stage-helpers

tags:
  - sparc
  - stage-agent
  - design-review
```

### 3. Create a template: `templates/design-review.md`

```markdown
# Design Review: <feature>

## Reviewers
- <persona> (e.g. "PM", "eng lead", "designer")

## Feedback per Reviewer
### <reviewer 1>
- [ ] <feedback item 1>
- [ ] <feedback item 2>

### <reviewer 2>
- …

## Action Items
- [ ] <what to change in the design>
- [ ] <what to add>

## Approved?
- [ ] yes, ship to pseudocode
- [ ] no, redirect back to design with the items above
```

### 4. Add a validator: `lib/validators.sh`

```bash
sparc_validate_design-review() {
  local board="$1" task_id="$2"
  local content
  content=$(sparc_artifact_read "$board" "design-review" "$task_id" 2>/dev/null) || {
    echo "design-review artifact missing" >&2
    return 1
  }
  grep -qiE '^#+ +Reviewers' <<<"$content" || {
    echo "design-review: no '## Reviewers' section" >&2
    return 1
  fi
  grep -qiE '^#+ +Feedback' <<<"$content" || {
    echo "design-review: no '## Feedback' section" >&2
    return 1
  fi
  return 0
}
```

### 5. Add to setup.sh's profile list

```bash
declare -a PROFILES=(
  sparc-spec sparc-design sparc-design-review   # <-- new
  sparc-pseudocode sparc-architecture
  sparc-refinement sparc-completion
  sparc-reviewer
)
```

### 6. Test

```bash
sparc doctor
sparc stages    # should show your new stage in the right position
```

That's it. The orchestrator, CLI, and adapters all pick up the new stage automatically because they read from `lib/stages.sh`.

## Removing a stage (per-project)

Easiest: edit `sparc.config.yaml`'s `stages:` list to omit the stage you want to skip.

```yaml
# Pure SPARC (5 stages, no Design)
stages:
  - spec
  - pseudocode
  - architecture
  - refinement
  - completion
```

## Removing a stage (for everyone)

Edit `lib/stages.sh`'s `SPARC_STAGE_KEYS_DEFAULT` array and remove the corresponding line from `SPARC_STAGES_TABLE`. Also remove the profile and skill if they're no longer referenced.

## What to NOT customize

- The kanban statuses (`triage | todo | ready | running | blocked | done | archived`) are fixed by Hermes Kanban. You can't add custom statuses.
- The state transitions (only `ready → running → done` is allowed for stage agents; only `done → blocked → done` is allowed for HITL) are also fixed by Kanban.
- The `task_links` parent→child DAG is the only graph topology Kanban supports. No arbitrary edges.

If you need a richer workflow than this, you're past what Hermes Kanban offers. At that point, evaluate the `outsourc-e/hermes-workspace` Swarm Mode (designed for this) or a dedicated PM tool.

## Reference

- `lib/stages.sh` — stage table (the source of truth)
- `lib/validators.sh` — validators (one per stage)
- `sparc.config.yaml.example` — per-project override keys
- `templates/<stage>.md` — one template per stage
- `profiles/<stage>.yaml` — one profile per stage
