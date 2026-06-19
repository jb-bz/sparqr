# Human-in-the-Loop (HITL)

The HITL layer is the difference between an autonomous agent that does things and a tool you can trust to do things. This document explains how the package's HITL layer works, how to configure it, and how to add a new adapter.

**Navigation:** [How HITL works](#how-hitl-works-in-this-package) · [Built-in adapters](#built-in-adapters) · [Choosing between surfaces](#choosing-between-webui-workspace-and-official-dashboard) · [Notify channels](#notify-channels-planned-for-v020) · [Authoring a HITL adapter](#authoring-a-hitl-adapter) · [Reversibility-aware gates](#reversibility-aware-gate-placement) · [Mirroring to external PM](#mirroring-to-an-external-pm-tool) · [Reference](#reference)

---

## Quick links

- **What is sparqr?** See the [README](../README.md).
- **How do stage gates work?** See [ARCHITECTURE.md](ARCHITECTURE.md).
- **I want to add a new stage** → [ADDING-STAGES.md](ADDING-STAGES.md).
- **I want to add a new review surface** → [Authoring a HITL adapter](#authoring-a-hitl-adapter).
- **Something broke** → [TROUBLESHOOTING.md](TROUBLESHOOTING.md).
- **FAQ** → [FAQ.md](FAQ.md).

---

## How HITL works in this package

When a stage agent finishes a stage that's gated for human review, it calls:

```bash
sparc_kanban_block "$SPARC_BOARD" "$TASK_ID" "<one-line summary of what to review>"
```

This sets the task's status to `blocked` and records the summary as a comment. The agent then exits.

The orchestrator daemon, polling every 3 seconds, sees the new `blocked` state. It:

1. Finds the artifact on disk
3. Calls `hitl_notify` on the configured primary adapter — pushes a review request to the surface
4. Calls `hitl_await_reply` — blocks until the human responds
5. Interprets the reply (APPROVE / REDIRECT / REJECT) and calls the right kanban verb

That's the entire HITL flow. The agent itself never talks to the human directly.

## Built-in adapters

| Adapter | Surface | When to use |
|---|---|---|
| `terminal`           | stdin/stdout via `/dev/tty` | Always available, no setup. Good for local dev. |
| `tui`                | File at `~/.hermes/sparc-package/hitl/<task>.request` + matching `.reply` file | When you have a Hermes TUI session open. |
| `webui`              | [`nesquena/hermes-webui`](https://github.com/nesquena/hermes-webui) on `:8787` | When you prefer the webui for coding. |
| `workspace`          | [`outsourc-e/hermes-workspace`](https://github.com/outsourc-e/hermes-workspace) on `:3000` | When you want the dedicated Kanban TaskBoard. |
| `official-dashboard` | Built-in `hermes dashboard` on `:9119` | When neither of the above is installed. |

The setup script probes each at install time and offers a multi-choice. You can change later by editing `sparc.config.yaml`'s `hitl_adapter:` line.

### Choosing between webui, workspace, and official-dashboard

- **`webui`** is best if you do most of your work in the webui chat already. It has a kanban panel and a kanban bridge API (`api/kanban_bridge.py`, 1,297 lines).
- **`workspace`** is best if you want the dedicated multi-agent control plane. It has a Kanban TaskBoard with explicit `backlog / ready / running / review / blocked / done` lanes that match the SPARC stages. Swarm Mode routes a Conductor through the inbox.
- **`official-dashboard`** is the fallback. Ships with `pip install hermes-agent[web,pty]`. Simpler than the others, no swarm mode, but always available if you have Hermes itself.

All three use the same adapter contract, so switching is one line in `sparc.config.yaml`.

## Notify channels (planned for v0.2.0)

v0.1.0 does **not** ship a separate notify channel. The HITL adapter IS the notification — when a review is needed, you see it in whichever UI you configured (webui, workspace, dashboard, TUI, or terminal). If you want a chat-gateway ping (Telegram, Discord, Slack, Signal) on top of the HITL adapter, that's planned for v0.2.0. The HITL adapter interface is designed to be pluggable so you can add a chat-gateway adapter as either a HITL surface or a side-channel notify. See [Adding a chat-gateway notifier](#adding-a-chat-gateway-notifier) below.

## Authoring a HITL adapter

Each HITL adapter is a single file at `lib/adapters/hitl/<name>.sh` that defines three functions:

```bash
# 1. Probe: returns 0 if the surface is reachable, 1 if not.
hitl_<name>_probe() {
  # e.g. curl -fsS --max-time 2 http://example.com/health
}

# 2. Notify: surfaces the review request to the human.
#    Args: $1=board, $2=task, $3=stage, $4=artifact_path
hitl_<name>_notify() {
  # POST/PUT/etc. to your surface's API
}

# 3. Await reply: blocks until the human responds.
#    Args: $1=board, $2=task
#    Echo: the reply (APPROVE | REDIRECT [text] | REJECT [text])
hitl_<name>_await_reply() {
  # poll/long-poll/subscribe, then echo the reply
}
```

To register the adapter, add it to the `SPARC_HITL_ADAPTERS` array in `lib/adapters/hitl/_registry.sh`:

```bash
SPARC_HITL_ADAPTERS=(terminal tui webui workspace official-dashboard my-new-adapter)
```

That's it. `sparc adapters` will now list it. `sparc.config.yaml`'s `hitl_adapter: my-new-adapter` will work.

## Authoring a notify channel (v0.2.0)

When v0.2.0 lands, the notify channel will live under `lib/adapters/notify/` and follow the same pluggable pattern as HITL adapters. Each notify adapter defines:

```bash
# Probe
notify_<channel>_probe() { ... }

# Send
# Args: $1=message
notify_<channel>_send() { ... }
```

To prepare for v0.2.0, you can already author notify adapters today and ship them alongside the package. They'll be auto-discovered at that time.

## Adding a chat-gateway notifier (today)

If you want a Telegram/Discord/Slack ping TODAY (before v0.2.0 ships the formal notify channel), the supported pattern is:

1. **Add a custom HITL adapter** under `~/.hermes/sparc-package/lib/adapters/hitl/chat-telegram.sh` (or wherever you keep the package) that implements the three HITL functions AND sends a Telegram message as part of `hitl_<name>_notify`. This is a hack — it's driving a chat-gateway notifier through the HITL interface — but it works in v0.1.0 and is a valid stepping stone.

2. **Or wait for v0.2.0** which will split notify from HITL. The interface is already designed (see the stub above); only the directory and dispatch code are missing.

To track progress on v0.2.0, see the GitHub issues.

## Reversibility-aware gate placement

The default gates (Spec, Architecture, Completion) match the reversibility heuristic from `agentpatterns.ai/workflows/human-in-the-loop`:

- **Gate before** actions that are irreversible (merge to main, deploy to prod, send money, ship to users)
- **Skip gates for** reversible steps (write a draft, create a branch, edit a config, run a local test)

In SPARC terms:
- **Spec** is the commitment to build something. Wrong spec = wrong product. Gate.
- **Design** is just markdown. Easy to redo. Skip.
- **Pseudocode** is markdown. Easy to redo. Skip.
- **Architecture** is the foundation for everything else. Wrong arch = rewrite. Gate.
- **Refinement** is code in progress. Easy to iterate locally. Skip.
- **Completion** is the ship decision. Irreversible. Gate.

You can change this in `sparc.config.yaml`:

```yaml
hitl_gates:
  spec:         true
  design:       true   # uncomment to gate design
  pseudocode:   false
  architecture: true
  refinement:   false
  completion:   true
```

To gate every stage (heavy, useful when learning the package), set all to `true`.

## Mirroring to an external PM tool

If you use Plane.so / Linear / Jira in parallel, you can mirror SPARC's kanban state to it. The pattern:

1. Create a webhook in your PM tool that fires on state change
2. In your PM tool, set up a project with custom workflow matching `triage | todo | ready | running | blocked | done | archived`
3. Write a small adapter that pushes SPARC kanban events to the PM tool's API on every state change

A reference implementation is in `examples/hello-sparc/extras/plane-mirror/` (not included in v0.1.0; planned for v0.2.0). See issue #5.

## Reference

- `lib/adapters/hitl/_registry.sh` — adapter dispatch
- `lib/adapters/hitl/*.sh` — built-in adapters
- `bin/sparc-hitl-watcher` — manual HITL management from the CLI
- `skills/sparc-hitl-watcher/SKILL.md` — the reviewer profile's protocol
- [ARCHITECTURE.md](ARCHITECTURE.md) — the overall design
- v0.2.0 will add `lib/adapters/notify/` for chat-gateway pingers
