#!/usr/bin/env python3
"""CLIP EACH STDIN LINE TO N DISPLAY COLUMNS (default 80), marking a clipped line with a trailing ellipsis.
usage: util_fit_columns.py [WIDTH]

⛔⭐ WHY THIS EXISTS AS A SHARED SCRIPT AND NOT AS THREE `cut -c` CALLS (Lon 2026-09-13, in-chat, routed by
cto to all seats, verbatim: "That banner printed is nu-formatted and un-readble with wrapping text. Do not
show that again. Show as a grid." / "Do not show the test suite banner ever again. It is un-readable.").

  1. `cut -c` COUNTS BYTES. The banner's own rules are U+2550 box-drawing and its bars are U+2588/U+2591 --
     an 80-column rule is 240 bytes, so `cut -c80` would saw it into a third of a line while leaving every
     genuinely over-wide ASCII line untouched. Confidently wrong in both directions at once.
  2. bash `${#var}` counts CHARACTERS, which is closer and still wrong: the verdict line opens with U+2705
     or U+26D4, one character occupying TWO columns. Off-by-one per glyph is exactly the three-column
     overshoot that made the suite grid 83 and unreadable in the first place.

So there is ONE width authority in this tree -- `dw()` in .github/scripts/util_suite_banner.py, which
already handles wide characters, variation selectors and regional-indicator pairs -- and it is IMPORTED
here rather than reimplemented. A second width function beside it is the same defect as a second roster:
both answer, neither agrees, and nothing announces the disagreement.

⛔ IT MUST NEVER BREAK ITS CALLER. s4e_msg.sh runs this on the Stop hook of every single turn, and the
banner's exit status is the seat's computed verdict -- a fitter that could fail would be a formatting tool
holding veto power over the thing it formats. If .github is unreachable it degrades to a conservative
ASCII-only width and SAYS NOTHING, because a banner printed slightly wide beats no banner at all.
"""
import sys, os, io, contextlib, importlib.util
def _load_dw():
    here = os.path.dirname(os.path.abspath(__file__))
    for cand in (os.path.join(here, "..", "..", "SCRIP", "..", ".github", "scripts", "util_suite_banner.py"),
                 os.path.join(here, "..", "..", "SCRIP", ".github", "scripts", "util_suite_banner.py")):
        cand = os.path.abspath(cand)
        if not os.path.exists(cand): continue
        try:
            spec = importlib.util.spec_from_file_location("_sb", cand)
            m = importlib.util.module_from_spec(spec)
            # the banner script has no __main__ guard: importing it PRINTS a banner. Swallow that.
            with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
                try: spec.loader.exec_module(m)
                except SystemExit: pass
            return m.dw
        except Exception: continue
    return len          # degraded, never fatal
dw = _load_dw()
def fit(s, width):
    if dw(s) <= width: return s
    out = ''
    for ch in s:
        if dw(out + ch) > width - 1: break
        out += ch
    return out + '…'
def main():
    width = 80
    if len(sys.argv) > 1:
        try: width = int(sys.argv[1])
        except ValueError: pass
    data = sys.stdin.read()
    trailing_nl = data.endswith("\n")
    lines = data.split("\n")
    if trailing_nl: lines.pop()
    for l in lines: sys.stdout.write(fit(l, width) + "\n")
    return 0
if __name__ == "__main__":
    sys.exit(main())
