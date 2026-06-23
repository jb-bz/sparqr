#!/usr/bin/env python3
"""Render a kanban status output as a PNG image.

Usage: python3 render-kanban.py "title" "status_output" output.png

The image is a 1100x600 dark-themed card showing the kanban board
status, suitable for embedding in documentation. No browser required.
"""

import subprocess
import sys
import tempfile
import os
from pathlib import Path


def render_png(title: str, body: str, output: str, width: int = 1100):
    """Render title + monospace body as a PNG using the macOS textutil/qlmanage approach.

    Falls back to Chromium headless HTML→PNG if needed.
    """
    # Try a simpler approach: use Python's PIL/Pillow if available
    try:
        from PIL import Image, ImageDraw, ImageFont
    except ImportError:
        # Fall back to a different approach
        render_via_chromium(title, body, output, width)
        return

    # Use a monospace font (Menlo is on macOS)
    font_path = "/System/Library/Fonts/Menlo.ttc"
    if not os.path.exists(font_path):
        font_path = "/System/Library/Fonts/Menlo.ttc"

    # Header line
    header_height = 80
    line_height = 26
    body_lines = body.splitlines()
    # Trim trailing empty lines
    while body_lines and not body_lines[-1].strip():
        body_lines.pop()
    body_height = line_height * (len(body_lines) + 1)
    height = header_height + body_height + 60

    img = Image.new("RGB", (width, height), color=(24, 24, 32))
    draw = ImageDraw.Draw(img)

    # Title bar (sparqr accent color)
    draw.rectangle([(0, 0), (width, 60)], fill=(40, 60, 100))
    title_font = ImageFont.truetype(font_path, 22)
    draw.text((30, 18), title, fill=(220, 230, 255), font=title_font)

    # Subtitle: $ command
    sub_font = ImageFont.truetype(font_path, 14)
    draw.text((30, 40), "$ sparqr status --board tutorial-cli-todo", fill=(160, 180, 220), font=sub_font)

    # Body: kanban status, monospace, with checkmarks in green
    body_font = ImageFont.truetype(font_path, 16)
    green = (120, 200, 120)
    white = (220, 220, 230)
    y = header_height + 20
    for line in body_lines:
        # Color ✓ marks green
        if line.strip().startswith("✓"):
            x = 30
            for ch in line:
                color = green if ch == "✓" else white
                draw.text((x, y), ch, fill=color, font=body_font)
                # rough char width
                x += 10
        elif line.strip().startswith("━"):
            draw.text((30, y), line[:110], fill=(100, 100, 130), font=body_font)
        else:
            draw.text((30, y), line, fill=white, font=body_font)
        y += line_height

    img.save(output, "PNG")
    print(f"saved {output} ({width}x{height})")


def render_via_chromium(title: str, body: str, output: str, width: int = 1100):
    """Fallback: render via headless Chromium."""
    chrome = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
    if not os.path.exists(chrome):
        print("no Chrome and no PIL; cannot render", file=sys.stderr)
        sys.exit(1)

    # Build an HTML page
    html_path = output + ".html"
    # Escape body for HTML
    body_html = body.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
    # Color ✓ marks
    body_html = body_html.replace("✓", '<span style="color:#78c878">✓</span>')
    body_html = body_html.replace("━", '<span style="color:#646478">━</span>')
    html = f"""<!doctype html>
<html><head><style>
body {{ background: #181820; color: #dcdce6; font-family: Menlo, monospace; padding: 20px; }}
h1 {{ background: #283c64; color: #dce6ff; padding: 14px 20px; margin: 0; font-size: 18px; border-radius: 4px; }}
.sub {{ color: #a0b4dc; font-size: 12px; padding: 8px 20px; }}
pre {{ padding: 0 20px; font-size: 14px; line-height: 1.5; white-space: pre; }}
</style></head>
<body>
<h1>{title}</h1>
<div class="sub">$ sparqr status --board tutorial-cli-todo</div>
<pre>{body_html}</pre>
</body></html>"""
    Path(html_path).write_text(html)

    subprocess.run([
        chrome, "--headless", "--no-sandbox", "--disable-gpu",
        f"--window-size={width},800",
        f"--screenshot={output}",
        f"file://{html_path}",
    ], check=True)
    os.unlink(html_path)
    print(f"saved {output} (chromium)")


if __name__ == "__main__":
    if len(sys.argv) < 4:
        print(f"usage: {sys.argv[0]} TITLE BODY.txt OUTPUT.png")
        sys.exit(1)
    title = sys.argv[1]
    body = Path(sys.argv[2]).read_text()
    render_png(title, body, sys.argv[3])
