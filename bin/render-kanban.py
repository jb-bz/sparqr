#!/usr/bin/env python3
"""Render a kanban status output as a beautiful PNG image.

Usage: python3 render-kanban.py "title" "body.txt" output.png [--width 1100]

The image is a 1100xN dark-themed card showing the kanban board
status, suitable for embedding in documentation. No browser required
beyond headless Chrome.

Design:
- Top bar: sparqr wordmark + subtitle, with gradient accent
- Body: monospace status output with color-coded status badges
  (✓ done = green, ▶ ready = blue, ◻ todo = gray, ⏵ running = yellow,
  ⏸ blocked = red)
- Footer: optional "totals:" line highlighted
- Card: rounded corners, subtle shadow, 1px border, generous padding

Use the helper scripts `examples/tutorial/_stage-runs/*.txt` or
`docs/screenshots/*.txt` for input.
"""

import re
import subprocess
import sys
import os
from pathlib import Path

# sparqr brand colors (tuned for dark theme)
COLORS = {
    "bg":       "#0F1117",   # card background
    "border":   "#1F2937",   # card border
    "header":   "#5C6AC4",   # sparqr indigo
    "header2":  "#7B89D9",   # gradient stop
    "subtext":   "#94A3B8",   # subtitle gray
    "text":      "#E2E8F0",   # body text
    "muted":     "#64748B",   # dim text (stage labels, prompts)
    "accent":    "#A78BFA",   # purple accent (paths, IDs)
    # Status colors
    "done":      "#10B981",   # green
    "ready":     "#3B82F6",   # blue
    "todo":      "#6B7280",   # gray
    "running":   "#FBBF24",   # yellow
    "blocked":   "#EF4444",   # red
    "ok":        "#10B981",   # green for stderr success paths
    "err":       "#F87171",   # red for stderr error paths
}

STATUS_BADGES = {
    "✓": ("done", "done"),
    "▶": ("ready", "ready"),
    "◻": ("todo", "todo"),
    "⏵": ("running", "running"),
    "⏸": ("blocked", "blocked"),
    "✓ ": ("done", "done"),
}

# Match [ ] and [✓] status markers in tutorial.py list output
LIST_DONE_RE = re.compile(r"\[(\s*✓\s*)\]")
LIST_OPEN_RE = re.compile(r"\[(\s+)\]")
# Match error output (stderr) and section dividers
STDERR_HINT_RE = re.compile(r"^(usage: tutorial|no todo with id|unknown command|text required|store at)", re.IGNORECASE)
DIVIDER_RE = re.compile(r"^─+\s+[^-]+\s+─+$")
# Match --- LABEL --- style dividers
DIVIDER_DASH_RE = re.compile(r"^---\s+\S.*\s+---$")
# Match success messages (tutorial output)
SUCCESS_HINT_RE = re.compile(r"^(added todo|marked todo|deleted todo|created sparc)", re.IGNORECASE)

# Match `done=N  todo=N  ...` totals line
TOTALS_RE = re.compile(r"^(\s*totals?:.*)$", re.IGNORECASE)
# Match the `$ ` prompt prefix
PROMPT_RE = re.compile(r"^(\s*\$\s)(.*)$")
# Match stage prefix like [SPEC] or [UREFINEMENT]
STAGE_RE = re.compile(r"\[([A-Z]+)\]")
# Match task IDs like t_abc1234
TASK_ID_RE = re.compile(r"\b(t_[a-z0-9]{6,})\b")


def colorize_status_chars(line: str) -> str:
    """Colorize the leading status character (✓, ▶, ◻, ⏵, ⏸) on a kanban row."""
    for badge, (symbol_color, _) in STATUS_BADGES.items():
        if line.lstrip().startswith(badge):
            return line.replace(badge, f'<span style="color:{COLORS[symbol_color]};font-weight:600">{badge}</span>', 1)
    return line


def colorize_stage(line: str) -> str:
    """Colorize [STAGE] markers in dim purple."""
    return STAGE_RE.sub(
        lambda m: f'<span style="color:{COLORS["muted"]};font-weight:500">[{m.group(1)}]</span>',
        line,
    )


def colorize_task_id(line: str) -> str:
    """Highlight task IDs in accent color."""
    return TASK_ID_RE.sub(
        lambda m: f'<span style="color:{COLORS["accent"]}">{m.group(1)}</span>',
        line,
    )


def colorize_totals(line: str) -> str:
    """Highlight a `totals: ready=N todo=N ...` line."""
    def repl(m):
        return f'<span style="color:{COLORS["accent"]};font-weight:600">{m.group(1)}</span>'
    return TOTALS_RE.sub(repl, line)


def colorize_prompt(line: str) -> str:
    """Colorize a `$ ` prompt prefix in muted gray + the rest in normal text."""
    m = PROMPT_RE.match(line)
    if m:
        return f'<span style="color:{COLORS["muted"]}">{m.group(1)}</span><span style="color:{COLORS["text"]}">{m.group(2)}</span>'
    return f'<span style="color:{COLORS["text"]}">{line}</span>'


def colorize_list_markers(line: str) -> str:
    """Colorize [✓] (done) and [ ] (open) markers in tutorial list output."""
    line = LIST_DONE_RE.sub(
        lambda m: f'<span style="color:{COLORS["done"]};font-weight:600">[{m.group(1).strip()}]</span>',
        line,
    )
    # Match [ ] in list output (tutorial prints [ ] for open todos, [✓] for done)
    # We need to NOT match [GLOBAL] etc — only when preceded by a digit (todo id)
    line = re.sub(
        r"(\[\d+\]) \[(\s+)\]",
        lambda m: f'{m.group(1)} <span style="color:{COLORS["muted"]}">[{m.group(2)}]</span>',
        line,
    )
    return line


def colorize_stderr(line: str) -> str:
    """Color stderr output red."""
    if STDERR_HINT_RE.match(line.strip()):
        return f'<span style="color:{COLORS["err"]}">{line}</span>'
    return line


def colorize_success(line: str) -> str:
    """Color success messages green."""
    if SUCCESS_HINT_RE.match(line.strip()):
        return f'<span style="color:{COLORS["done"]}">{line}</span>'
    return line


def colorize_divider_label(line: str) -> str:
    """Colorize the '── label ──' or '--- label ---' style divider lines."""
    if DIVIDER_RE.match(line.strip()) or DIVIDER_DASH_RE.match(line.strip()):
        return f'<span style="color:{COLORS["muted"]}">{line}</span>'
    return line


def colorize(line: str) -> str:
    """Apply all colorizers to a line. Order matters.

    Note: colorize_prompt must run LAST because it wraps the entire
    line in a <span>. If it runs first, the wrapped output breaks
    the regex-based colorizers that follow.
    """
    line = colorize_status_chars(line)
    line = colorize_list_markers(line)
    line = colorize_totals(line)
    line = colorize_divider_label(line)
    line = colorize_stderr(line)
    line = colorize_success(line)
    line = colorize_stage(line)
    line = colorize_task_id(line)
    line = colorize_prompt(line)
    return line


def html_escape(text: str) -> str:
    return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def render_html(title: str, subtitle: str, body: str, width: int) -> str:
    """Build the HTML for the screenshot."""
    body_lines = body.splitlines()
    # Trim trailing empty lines
    while body_lines and not body_lines[-1].strip():
        body_lines.pop()

    body_html_parts = []
    in_block = False
    block_buffer = []
    for line in body_lines:
        # Treat horizontal-rule lines (━━━━) as section dividers
        if line.strip().startswith("━"):
            # End any pending block, emit divider
            if block_buffer:
                body_html_parts.append("\n".join(block_buffer))
                block_buffer = []
            body_html_parts.append('<div class="divider"></div>')
            in_block = False
        else:
            in_block = True
            block_buffer.append(f'<div class="line">{colorize(html_escape(line))}</div>')
    if block_buffer:
        body_html_parts.append("\n".join(block_buffer))

    body_html = "\n".join(body_html_parts)
    # Estimate height: 56px header + 18px per body line + 40px footer + padding
    body_lines_count = len(body_lines)
    height = 56 + max(body_lines_count * 22, 100) + 40 + 60

    return f"""<!doctype html>
<html><head><meta charset="utf-8"><style>
* {{ box-sizing: border-box; margin: 0; padding: 0; }}
body {{
  background: transparent;
  font-family: 'JetBrains Mono', 'SF Mono', 'Menlo', 'Monaco', monospace;
  padding: 20px;
  display: inline-block;
}}
.card {{
  background: {COLORS["bg"]};
  border: 1px solid {COLORS["border"]};
  border-radius: 12px;
  width: {width}px;
  overflow: hidden;
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.5), 0 2px 6px rgba(0, 0, 0, 0.3);
}}
.header {{
  background: linear-gradient(135deg, {COLORS["header"]} 0%, {COLORS["header2"]} 100%);
  padding: 16px 24px;
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
}}
.brand {{
  font-size: 18px;
  font-weight: 700;
  color: white;
  letter-spacing: -0.3px;
}}
.brand .bolt {{ color: #FFD700; margin-right: 4px; }}
.subtitle {{
  font-size: 12px;
  color: rgba(255, 255, 255, 0.85);
  font-family: 'JetBrains Mono', 'SF Mono', 'Menlo', monospace;
}}
.body {{
  padding: 20px 24px;
  font-size: 13px;
  line-height: 1.55;
  color: {COLORS["text"]};
  max-height: 720px;
  overflow: hidden;
}}
.line {{
  white-space: pre;
  min-height: 1.5em;
  font-variant-ligatures: none;
}}
.divider {{
  height: 1px;
  background: linear-gradient(90deg, transparent, {COLORS["border"]} 20%, {COLORS["border"]} 80%, transparent);
  margin: 8px 0;
}}
</style></head>
<body>
<div class="card">
  <div class="header">
    <div class="brand"><span class="bolt">⚡</span>sparqr</div>
    <div class="subtitle">{html_escape(subtitle)}</div>
  </div>
  <div class="body">
{body_html}
  </div>
</div>
</body></html>"""


def render_png(title: str, body: str, output: str, width: int = 1100):
    """Render title + body as a PNG via headless Chrome."""
    chrome = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
    if not os.path.exists(chrome):
        print("Chrome not found at", chrome, file=sys.stderr)
        sys.exit(1)

    subtitle = title
    html = render_html(title, subtitle, body, width)

    # Save the html for debugging
    html_path = output + ".html"
    Path(html_path).write_text(html)

    # Calculate height based on body content
    body_line_count = len([ln for ln in body.splitlines() if ln.strip()])
    height = 56 + max(body_line_count * 22, 200) + 60 + 60  # header + body + padding + footer

    subprocess.run([
        chrome, "--headless", "--no-sandbox", "--disable-gpu",
        f"--window-size={width + 40},{height}",
        f"--hide-scrollbars",
        f"--screenshot={output}",
        f"file://{html_path}",
    ], check=True, capture_output=True)
    os.unlink(html_path)
    print(f"saved {output} ({width}x{height})")


if __name__ == "__main__":
    if len(sys.argv) < 4:
        print(f"usage: {sys.argv[0]} TITLE BODY.txt OUTPUT.png [--width 1100]")
        sys.exit(1)
    title = sys.argv[1]
    body = Path(sys.argv[2]).read_text()
    width = 1100
    if "--width" in sys.argv:
        width = int(sys.argv[sys.argv.index("--width") + 1])
    render_png(title, body, sys.argv[3], width=width)
