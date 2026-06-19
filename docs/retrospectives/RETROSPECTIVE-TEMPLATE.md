# Retrospective template

Use this template when filling in `docs/retrospectives/v0.X.0.md` for each release. Keep the prose tight; the goal is *calibration data*, not a journal entry.

---

## Frontmatter

```yaml
---
release: v0.X.0
shipped: YYYY-MM-DD      # the date the release tag/commit was created
estimated_pts: N        # the sum from the ROADMAP at release time
actual_pts: M           # the actual sum (with one-line reasoning for any re-estimates)
velocity_ratio: M/N     # 1.0 means estimate was exact; >1 means under-estimated; <1 means over-estimated
stories_planned: N
stories_shipped: M
stories_deferred: list of story numbers and one-line reasons
---
```

## Sections to fill in

### What we said we'd do
- 1-2 sentences. The list of stories in the ROADMAP at the time of release.

### What we actually shipped
- 1-2 sentences. The actual list. Bullets are fine for unexpected additions.

### Stories in retrospect
- A table with columns: `Story | Estimated pts | Actual pts | Notes`
- For "actual pts" give a one-sentence justification (this story took longer because X, etc.)
- The total at the bottom is the release's actual point sum

### What surprised us
- 3-5 bullets. Each bullet is one specific thing that turned out differently from expectation, with the *kind* of surprise (e.g. "we underestimated integration testing", not "this was hard")
- Resist the urge to be philosophical. Concrete observations only.

### What we'd do differently
- 3-5 bullets. Each bullet is a *concrete change* for the next release (e.g. "type the orchestrator flow more carefully", not "be more careful"). If you can't write the change in one sentence, the bullet is too vague.

### Velocity data
- The unit of measurement is "points per release." Compare release-to-release ratios.
- Optional: list the cluster of commits that constituted the release (use `git log <prev-tag>..<this-tag> --oneline`)

### What this means for the next release
- A 2-3 sentence forward-looking note: "if our velocity is X, then v0.X+1.0 is roughly Y pts, and we should..."
- This is where the calibration data actually pays off. If v0.2.0 was 50 pts actual and v0.3.0 is planned at 28 pts, v0.3.0 is now obviously under-scoped and needs an honest re-estimate.

---

## How to fill this in

**Completely automated** (per current workflow):
1. After the release is tagged, the agent (me) generates a draft retrospective from:
   - Git log of the release (`git log <prev-tag>..<this-tag> --oneline`)
   - The estimated story list from the ROADMAP at release time
   - The actual PRs / commits that landed
2. I commit the draft as `docs/retrospectives/v0.X.0.md`
3. You review and edit for the "what surprised us" and "what we'd do differently" sections, which need your perspective not mine

**What I can NOT infer**: the qualitative observations in "what surprised us" and "what we'd do differently." I have access to the git log and the conversation history, but the *honest* version of these sections is the user's, not mine. I'll write a draft and you tell me where I'm wrong.

---

## Example

`docs/retrospectives/v0.1.0.md` is the first retrospective and follows this template (with one deviation: it explicitly notes the points scale didn't exist when v0.1.0 was built, so the points in that file are retroactive).
