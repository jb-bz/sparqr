---
name: sparc-stage-design
description: SPARC+Design Design stage (community extension). Produce UI/UX flows, visual design, design tokens, and component specs from a specification. Used by the sparc-design profile.
version: 0.1.0
author: Hermes SPARC Package
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [sparc, stage, design, ui-ux, frontend]
    related_skills: [sparc-pipeline-orchestrator, sparc-stage-helpers, sketch, claude-design, popular-web-designs]
    category: software-development
---

# SPARC Stage 2 — Design (community extension)

You are running the **Design** stage of the SPARC+Design pipeline. Your job is to take a `specification.md` and produce a `design.md` that the Pseudocode and Architecture stages can act on.

## When to skip

If the upstream spec is for a backend-only / non-UI feature (e.g. "add a CLI flag", "refactor the auth middleware", "build an internal admin tool with no end-user UI"), you can produce a minimal design document with just:

- A `## User Flows` section with the CLI/admin flow as numbered steps
- A `## Components` section with the modules involved
- No `## Visual Design` section needed

The orchestrator's validator allows this — it requires `User Flows` and one of `Visual Design | Design Tokens | Components`.

## What "good" looks like for UI features

A good design:

1. **User flows** for every major journey (login, primary action, error recovery). At least 2-5 flows.
2. **Visual design tokens** — colors (with hex/rgb), typography (font family, sizes, weights), spacing scale, border radii, shadow scale. Use semantic naming (`--color-bg-primary`, not `--blue-500`).
3. **Component library** scoped — buttons, inputs, cards, nav, modals. For each: states (default/hover/focus/disabled/loading/error), sizes, and which tokens it uses.
4. **Accessibility** — contrast ratios, keyboard nav, screen reader labels, focus order.
5. **Responsive breakpoints** — mobile, tablet, desktop, large.
6. **Loading + error states** designed for every async interaction.

## When to use the design companion skills

This stage is where the design skills shine. Use them to generate alternatives fast:

| Need | Skill | When |
|---|---|---|
| Quick 2-3 variants to compare | `sketch` | First pass, before committing to one |
| Landing page / polished HTML | `claude-design` | When you need production-ready markup |
| Dark-themed architecture diagram | `architecture-diagram` | For diagrams embedded in the design |
| Hand-drawn user flow | `excalidraw` | For rough flow sketches |
| Reference design system | `popular-web-designs` | When picking patterns (Stripe, Linear, Vercel, etc.) |

## Anti-patterns

- ❌ "We'll use a clean modern design" — meaningless
- ❌ Visual design without tokens (just screenshots or hex codes with no naming)
- ❌ Components without states
- ❌ No loading state (every async interaction needs one)
- ❌ No error state (every form, every fetch, every external call)
- ❌ Mobile-afterthought (responsive from the start)
- ❌ Color choices that fail WCAG AA contrast (4.5:1 for body text)

## Template

See `templates/design.md` for the full template. Key sections:

```markdown
# Design: <feature or system name>

## User Flows
### Flow 1: <name>
1. <step>
2. <step>
…

### Flow 2: …

## Design Tokens
### Color
- --color-bg-primary: #…
…

### Typography
- --font-family-sans: …
…

### Spacing
- --space-1: 4px, --space-2: 8px, …

## Components
### Button
- States: default, hover, focus, disabled, loading
- Sizes: sm, md, lg
- Tokens used: --color-bg-primary, --space-2, …

### Input
…

## Accessibility
- Contrast ratios: all text ≥ 4.5:1
- Keyboard nav: tab order documented
- Screen reader: ARIA labels per component
- Focus indicators: visible at all times

## Responsive Breakpoints
- mobile: < 640px
- tablet: 640-1024px
- desktop: 1024-1440px
- large: > 1440px

## Loading + Error States
### Loading
- Skeleton screens for content > 200ms
- Spinners for actions > 1s
- Progress bars for uploads / long ops

### Error
- Inline form errors (per field)
- Toast for transient failures
- Full-page for fatal errors
```

## Validation (enforced)

- Must have `## User Flow(s)`
- Must have at least one of `## Visual Design` / `## Design Tokens` / `## Components`

## Reference

- See `templates/design.md` for the full template
- Hermes skill catalog: `hermes skills browse`
- See `docs/ADDING-STAGES.md` for how to add a "design-v2" stage or skip this stage entirely
