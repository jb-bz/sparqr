# Reverse CLI — built by the SPARC+Design pipeline.

Built via `sparc init "Build a CLI that reverses input lines"`. The full spec, design, pseudocode, architecture, refinement, and completion artifacts are in `../docs/sparc/`.

## Install

```bash
pip install .
```

## Usage

```bash
echo -e "hello\nworld" | reverse
# → olleh
# → dlrow

reverse --help
```
