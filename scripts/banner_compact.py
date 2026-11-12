#!/usr/bin/env python3
"""THE DOUBLE-SIDED BANNER (the cto, 2026-11-03 22:3x CST, first as /home/claude_cto/.claude/banner_compact.py; fleet-wide on Lon's word
2026-11-04: "In the display banner add a column for a delta/difference and distribute the new double-sided banner across the fleet.";
CEO-2129). The Stop hook pipes `s4e_msg.sh banner` through this filter: the suite grid's rows are laid out in TWO COLUMNS side by side,
half the suites on the left, half on the right, each cell `Lang Suite Pass/Tot Excl M3 M4 Pct Min Run Δ` (Excl is the suite's excluded count, `-` when blank;
Run is the date and time range of the readings the row was assembled from and Δ is the LAST column, both on Lon's word 2026-11-11 10:2x CST, in the coo's
window, verbatim: "The stop turn banner should display the date/time-range of the run that created the row." / "In the stop turn banner the delta
column should be last."), so the whole fleet score fits one screen without
a wrapped line (Lon's terminal wraps a long line; the full grid is 45 rows). Δ is util_suite_banner.py's delta column: Total minus Pass, how many failures remain
(Lon 2026-11-04: "The delta column represents how many failures remain."); since 2026-11-05 it also carries the state, the S column
merged into it (Lon, in the coo's window: "Fix the test suite display banner to show the minimum time required for each of the 44 suites.
You should merge the delta and S columns together."): ✓ a suite at 100%, V a void reading, ? no reading, else the failures remaining.
Min is the grid's Wall column, the suite's MINIMUM time: the sum over its programs and modes of each one's smallest PASS seconds
(results.tsv.min, CEO-1562; Lon 2026-10-18: "That column is meant to represent the MINIMUM amount of time to run the test."), blank when no
program has passed; the footer adds their total. M3 and M4 are each mode's own pass count from the progress store's
latest readings (Lon 2026-11-04: "The display banner need modifying to show both mode 3 and mode 4 numbers seperately."; CTO-482), beside the
both-modes Pass; an older grid without them renders with the two cells blank. The grid's header names the columns, so this
filter reads them by NAME and renders an older grid without Δ or Wall the same way (the cell blank). Lines before and after the grid pass through, cut to the banner's width. When no grid row is found
the input passes through untouched, so a refused or missing grid is never hidden."""
import re
import sys

CELLW = 81
WIDTH = 2 * CELLW + 3
STATE = {"DONE": "✓", "VOID": "V", "NO READING": "?", "": ""}


def cut(s, w=WIDTH):
    return s if len(s) <= w else s[: w - 1] + "…"


def main():
    raw = sys.stdin.read()
    lines = raw.splitlines()
    head, rows, tail, seen_table, names = [], [], [], False, None
    for ln in lines:
        if ln.startswith("│"):
            cells = [c.strip() for c in ln.strip("│").split("│")]
            seen_table = True
            if cells and cells[0] == "Lang":
                names = cells
            elif names and len(cells) == len(names):
                rows.append(dict(zip(names, cells)))
            continue
        if ln[:1] in "┌├└":
            seen_table = True
            continue
        (tail if seen_table else head).append(ln)
    if not rows:
        sys.stdout.write(raw)
        return

    def secs(w):
        w, n = (w or "").strip(), 0
        for num, unit in re.findall(r"(\d+)([hms])", w):
            n += int(num) * {"h": 3600, "m": 60, "s": 1}[unit]
        return n

    def hms(n):
        return f"{n}s" if n < 60 else (f"{n // 60}m{n % 60:02d}s" if n < 3600 else f"{n // 3600}h{(n % 3600) // 60:02d}m")

    def fmt(r):
        st = r.get("State", "")
        ds = STATE.get(st, st[:1]) if st else r.get("Δ", "")
        ex = (r.get("Excl", "") or "").strip() or "-"
        s = f"{r.get('Lang',''):<8} {r.get('Suite',''):<12} {r.get('Pass',''):>4}/{r.get('Total',''):<4} {ex:>4} {r.get('M3',''):>4} {r.get('M4',''):>4} {r.get('Pct',''):>4} {r.get('Wall',''):>6} {r.get('Run',''):<17} {ds:>4}"
        return s[:CELLW].ljust(CELLW)

    half = (len(rows) + 1) // 2
    left, right = rows[:half], rows[half:]
    out = [cut(h) for h in head if h.strip()]
    hdr = f"{'Lang':<8} {'Suite':<12} {'Pass/Tot':<9} {'Excl':>4} {'M3':>4} {'M4':>4} {'Pct':>4} {'Min':>6} {'Run':<17} {'Δ':>4}".ljust(CELLW)
    out.append(hdr + " │ " + hdr)
    for i in range(half):
        l = fmt(left[i])
        r = fmt(right[i]) if i < len(right) else ""
        out.append((l + " │ " + r).rstrip())
    tot = sum(secs(r.get("Wall", "")) for r in rows)
    tail = [t for t in tail if t.strip()]
    if tot and tail and re.match(r"\d+ suites, \d+ at 100%", tail[-1]):
        tail[-1] = tail[-1] + f"; minimum time of all {len(rows)} together {hms(tot)}"
    out += [cut(t) for t in tail]
    sys.stdout.write("\n".join(out) + "\n")


if __name__ == "__main__":
    main()
