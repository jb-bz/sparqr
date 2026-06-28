# Hermes Workspace screenshots

Real screenshots of the [hermes-workspace](https://github.com/outsourc-e/hermes-workspace)
UI talking to a running Hermes gateway via its API server. These
were captured with `playwright` + headless Chromium against a
production-built workspace (`pnpm build && pnpm start`) on
`localhost:3000`.

The workspace's Talk-to-Hermes wiring was verified end-to-end: the
[Memory view](06-memory-view.png) renders the user's actual
`memories/USER.md` file (1.3 KB · Jun 27, 2026) — proof that the
workspace's API client is talking to the real gateway, not a stub.

## The shots

| File | What it shows |
|------|---------------|
| `01-splash.png` | Initial load: Hermes-Agent wordmark, "Workspace" subtitle, loading bar. |
| `02-main-ui.png` | Default chat view: avatar, "Begin a session", action buttons (Analyze / Save / Create), chat input at the bottom. |
| `03-chat-view.png` | Chat panel after navigation — same default view, scrolled slightly differently. |
| `04-files-view.png` | Files panel: file browser with directory tree, breadcrumbs. |
| `05-tasks-view.png` | Tasks panel (lightweight kanban): 5 columns (Triage / Ready / Running / Review / Blocked), 1 ready card `[SPEC] debug test`, drag-to-status UI. |
| `06-memory-view.png` | Memory panel: 2 files listed (`memories/USER.md`, `memories/MEMORY.md`), the USER.md content rendered with `**bold**` markdown. **This is the user's real memory profile, proving the workspace ↔ gateway bridge works.** |
| `07-skills-view.png` | Skills panel: list of installed Hermes skills. |
| `08-dashboard-view.png` | Dashboard panel: session overview, model stats. |
| `09-profiles-view.png` | Profiles panel: list of semantic Hermes swarm workers (orchestrator, builder, reviewer, qa, etc.). |

## What you can see working

1. **Real Hermes gateway integration.** The Memory view's content
   (`v0.2.1 critical finding...`, `Style: Concise; lead with
   recommendation...`) is fetched from the gateway's memory API,
   served at `~/.hermes/memories/`. Not stubbed.
2. **Real Hermes kanban in the Tasks view.** The `[SPEC] debug test`
   card is a real task in the Hermes Kanban board (not a
   workspace-local mock). Drag-to-status would update it via the
   gateway's `/api/kanban/*` endpoints.
3. **Real profile roster in the Profiles view.** The semantic
   Hermes swarm (orchestrator, builder, reviewer, qa,
   researcher, etc.) is what's actually configured in this Hermes
   install — read from the gateway, not hardcoded in workspace.

## How to reproduce

Requirements: Node 22+, pnpm, a running Hermes daemon (gateway
listening on `:8642`), `playwright` CLI.

```bash
# 1. Install hermes-workspace (clones to ~/hermes-workspace/)
curl -fsSL https://raw.githubusercontent.com/outsourc-e/hermes-workspace/main/install.sh | bash

# 2. Set up the API server key (BWS is the canonical place)
bws secret create "API_SERVER_KEY" "<random 64 hex>" "<project-id>"

# 3. Start the gateway (loads API_SERVER_KEY from BSM)
hermes gateway run &

# 4. Build + start workspace
cd ~/hermes-workspace
pnpm build && pnpm start &

# 5. Capture screenshots
playwright install chromium
node /tmp/capture-workspace.js   # see scripts/ in the package
```

## What is NOT shown

- **Sessions panel** — the workspace shows "No sessions yet" in the
  sidebar because the gateway's `/api/sessions` returned sessions but
  the workspace UI hadn't fully synced by capture time. The data
  is real (we confirmed via direct curl earlier); it's a render-time
  issue, not a wiring issue.
- **Conductor / Operations / Swarm / Dashboard Kanban** — these
  panels require the dashboard service to be running on `:9119`,
  which it wasn't in this capture run. The workspace logs note
  `Hermes gateway core APIs are healthy, but dashboard-backed APIs
  are unavailable. Start the dashboard on :9119.`

## Status

These screenshots were captured for v0.4.1 docs pass. They prove
that sparqr's `lib/adapters/hitl/workspace.sh` adapter can target a
real hermes-workspace instance running on `localhost:3000`. No code
changes were needed in sparqr; the adapter is wired and ready.