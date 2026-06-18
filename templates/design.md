# Design: <feature or system name>

> Stage 2 of SPARC+Design (community extension). Translates the spec into something a human can see and a developer can build.

## User Flows

### Flow 1: <name — e.g. "First-time user signup">
1. <step — e.g. "User lands on the home page">
2. <step — e.g. "Clicks 'Sign up'">
3. <step — e.g. "Form shows email + password fields, with 'Continue with Google' as a secondary option">
4. <step — e.g. "On submit, validate, POST to /api/auth/signup, show inline errors if any">
5. <step — e.g. "On success, redirect to /onboarding">

### Flow 2: <name — e.g. "Returning user login">
1. <step>
2. <step>
3. <step>

### Flow 3: <name — e.g. "Password reset">
1. <step>
2. <step>

### Flow 4: Error recovery — e.g. "API down, user retries"
1. <step>
2. <step>

## Design Tokens

> Use semantic naming. `--color-bg-primary` not `--blue-500`.

### Color
- `--color-bg-primary`: #…
- `--color-bg-secondary`: #…
- `--color-text-primary`: #…
- `--color-text-muted`: #…
- `--color-accent`: #…
- `--color-success`: #…
- `--color-warn`: #…
- `--color-error`: #…
- `--color-border`: #…

### Typography
- `--font-family-sans`: -apple-system, BlinkMacSystemFont, "Inter", "Segoe UI", sans-serif
- `--font-family-mono`: ui-monospace, "SF Mono", "Menlo", monospace
- `--font-size-xs`: 0.75rem (12px)
- `--font-size-sm`: 0.875rem (14px)
- `--font-size-md`: 1rem (16px)
- `--font-size-lg`: 1.125rem (18px)
- `--font-size-xl`: 1.5rem (24px)
- `--font-size-2xl`: 2rem (32px)
- `--font-weight-regular`: 400
- `--font-weight-medium`: 500
- `--font-weight-semibold`: 600
- `--font-weight-bold`: 700
- `--line-height-tight`: 1.2
- `--line-height-normal`: 1.5
- `--line-height-loose`: 1.7

### Spacing
- `--space-0`: 0
- `--space-1`: 4px
- `--space-2`: 8px
- `--space-3`: 12px
- `--space-4`: 16px
- `--space-6`: 24px
- `--space-8`: 32px
- `--space-12`: 48px
- `--space-16`: 64px

### Radius
- `--radius-sm`: 4px
- `--radius-md`: 8px
- `--radius-lg`: 16px
- `--radius-full`: 9999px

### Shadow
- `--shadow-sm`: 0 1px 2px rgba(0,0,0,0.05)
- `--shadow-md`: 0 4px 12px rgba(0,0,0,0.08)
- `--shadow-lg`: 0 12px 24px rgba(0,0,0,0.12)

## Components

### Button
- **States**: default, hover, focus, active, disabled, loading
- **Sizes**: sm (32px tall), md (40px), lg (48px)
- **Variants**: primary, secondary, ghost, danger
- **Tokens used**: `--color-accent`, `--space-3`, `--radius-md`, `--font-weight-semibold`
- **Accessibility**: visible focus ring (3px outline using `--color-accent` at 40% opacity), aria-disabled when loading

### Input
- **States**: default, focus, error, disabled
- **Sizes**: md only (40px tall) — most forms are desktop
- **Tokens used**: `--color-bg-primary`, `--color-border`, `--color-text-primary`
- **Accessibility**: label always present, error text announced via aria-describedby

### Card
- **States**: default, hover (if clickable), selected
- **Tokens used**: `--color-bg-primary`, `--shadow-sm`, `--radius-lg`, `--space-4`

### Navigation
- **Pattern**: left sidebar (collapsible) + top bar (breadcrumb + actions)
- **Tokens used**: `--color-bg-secondary`, `--color-text-primary`

## Accessibility

- **Contrast**: all text ≥ 4.5:1 against its background (WCAG AA)
- **Keyboard nav**: all interactive elements reachable via Tab; visible focus indicator
- **Screen reader**: all form fields labeled; live regions for async feedback; ARIA roles for non-semantic elements
- **Motion**: respect `prefers-reduced-motion`; no essential content conveyed by motion alone

## Responsive Breakpoints

- **mobile**: < 640px — single column, full-width components, bottom nav instead of top bar
- **tablet**: 640-1024px — two columns, sidebar collapses to icon-only
- **desktop**: 1024-1440px — three columns, full sidebar
- **large**: > 1440px — same as desktop, but with wider max content width (1280px)

## Loading + Error States

### Loading
- **Content > 200ms**: skeleton screens
- **Action > 1s**: spinner on the action button
- **Upload / long op**: progress bar with cancel
- **Page transition**: subtle top-of-page progress indicator

### Error
- **Inline form errors**: red text below the field, screen reader announces
- **Transient failures**: toast at top-right, auto-dismiss after 5s
- **Fatal errors**: full-page error with retry + "go home" actions
- **Network down**: persistent banner at top of viewport

## Mockups (optional but recommended)

If you have mockups, link them here:

- `mockups/login.png` — Figma export or HTML screenshot
- `mockups/dashboard.png` — same
- `mockups/mobile.png` — mobile breakpoint

If the design is simple enough, skip this section.
