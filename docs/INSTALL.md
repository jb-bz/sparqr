# Installing sparqr

This guide walks through importing the package into a running Hermes install. If anything is unclear, [file an issue](https://github.com/jb-bz/sparqr/issues).

**Navigation:** [Prerequisites](#prerequisites) · [Quick install](#quick-install) · [What setup.sh does](#what-setupsh-does-in-order) · [What setup.sh does NOT do](#what-setupsh-does-not-do) · [Per-project setup](#per-project-setup) · [Verifying](#verifying-the-install) · [Uninstalling](#uninstalling) · [Troubleshooting](#troubleshooting)

---

## Quick links

- **What is sparqr?** See the [README](../README.md) for the elevator pitch.
- **How does it work?** See [ARCHITECTURE.md](ARCHITECTURE.md).
- **I just want to use it** → see [Per-project setup](#per-project-setup).
- **Something broke** → [TROUBLESHOOTING.md](TROUBLESHOOTING.md).
- **I want to extend it** → [HITL.md](HITL.md) or [ADDING-STAGES.md](ADDING-STAGES.md).

---

## Prerequisites

- **Hermes Agent** ≥ 0.6.0. Check with `hermes --version`. Install from https://hermes-agent.nousresearch.com if you don't have it.
- **bash** ≥ 4.0 (`bash --version` — most modern systems have this)
- **sqlite3** CLI (preinstalled on macOS; `apt install sqlite3` on Debian/Ubuntu)
- **curl** (preinstalled everywhere)
- **jq** — `brew install jq` (macOS) or `apt install jq` (Linux). Required for HITL adapter JSON.
- Optional: **yq** — `brew install yq` / `apt install yq` — used to parse `sparc.config.yaml` natively. Without it, setup.sh falls back to a python3 parser.

---

## Quick install

```bash
# 1. Clone
git clone https://github.com/jb-bz/sparqr.git
cd sparqr

# 2. Run the importer (asks 1 question, ~2 minutes)
./setup.sh

# 3. Verify
sparc doctor

# 4. Try the example end-to-end
cd examples/hello-sparc
sparc init "Build a CLI that reverses input lines"
sparc pipeline start
```

That's it. `setup.sh` is idempotent — re-running it is safe and will update, not duplicate.

---

## What setup.sh does (in order)

1. **Hermes check** — verifies `hermes --version` works and is recent enough
2. **Profiles** — creates 7 profiles: `sparc-spec`, `sparc-design`, `sparc-pseudocode`, `sparc-architecture`, `sparc-refinement`, `sparc-completion`, `sparc-reviewer`
3. **Skills** — installs 5 skills into `~/.hermes/skills/software-development/`
4. **CLI** — symlinks `sparc` to `~/.local/bin/sparc` (or `$PREFIX/bin/sparc` if `PREFIX` is set)
5. **HITL probe** — checks which HITL surfaces are reachable and asks you to pick one
6. **Project config** — creates `./sparc.config.yaml` in the current directory with your choices patched in
7. **Doctor** — runs `sparc doctor` so you can see the green lights

---

## What setup.sh does NOT do

- ❌ Touch `~/.hermes/config.yaml` (your model, providers, API keys — all untouched)
- ❌ Touch `~/.hermes/.env` (your secrets — only READ for the BSM bootstrap)
- ❌ Touch `~/.hermes/memory/` (your agent memory — untouched)
- ❌ Touch any other profiles or skills
- ❌ Touch any files outside the package root, `~/.hermes/`, and your `PATH` (`~/.local/bin/`)
- ❌ Install or update Hermes itself (you do that)
- ❌ Install Python packages (you do that)

---

## Per-project setup

You only need to run `setup.sh` once per **machine**. After that, each **project** that wants to use SPARC needs its own `sparc.config.yaml`. Two options:

### Option A — one-off per project (manual)

```bash
cd ~/projects/my-cool-app
cp /path/to/sparqr/sparc.config.yaml.example ./sparc.config.yaml
# edit it
sparc init "Build the cool app"
sparc pipeline start
```

### Option B — wrapper script

Drop this in your shell rc:

```bash
sparc-new() {
  cp /path/to/sparqr/sparc.config.yaml.example ./sparc.config.yaml
  sparc init "$1"
}
```

Then: `sparc-new "Build the cool app"`.

---

## Verifying the install

```bash
sparc doctor
```

You should see all checks passing or warning. Common warnings and how to fix them:

- `sparc not on PATH` → add `export PATH="$HOME/.local/bin:$PATH"` to your shell rc
- `webui/workspace not detected` → expected, unless you have those UIs running
- `sparc.config.yaml not in current dir` → expected if you're not in a project; only a warning

---

## Uninstalling

The package is intentionally easy to undo:

```bash
# Remove profiles
for p in sparc-spec sparc-design sparc-pseudocode sparc-architecture \
         sparc-refinement sparc-completion sparc-reviewer; do
  hermes profile delete "$p"
done

# Remove skills
rm -rf ~/.hermes/skills/software-development/sparc-*

# Remove CLI
rm -f ~/.local/bin/sparc

# Remove package data (NOT your project artifacts)
rm -rf ~/.hermes/sparc-package/logs ~/.hermes/sparc-package/hitl

# Per-project: remove the sparc.config.yaml and any kanban board
# (use `hermes kanban boards list` to find them, then `hermes kanban boards delete <slug>`)
```

Your `~/.hermes/config.yaml`, `.env`, and memory are untouched. Your other skills and profiles are untouched.

---

## Troubleshooting

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for the full list. Common ones:

- `hermes: command not found` → install Hermes first
- `bash: bad substitution` → your bash is < 4.0; install a newer one
- `sparc doctor: 5 fail, 0 warn` → re-run `./setup.sh` to fix
