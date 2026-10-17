#!/usr/bin/env bash
# test_gate_rungs_boards_publish_xpass.sh -- ROW-LEVEL GATE (hq_T, on coo's ruling 2026-09-08).
# ⛔⭐ THE DEFECT THIS ASSERTS AGAINST IS A BOARD DEFECT, NOT AN INSTRUMENT ONE.  A rung suite headline that holds its
# fraction constant while xfail and xpass TRADE underneath it is STRUCTURALLY BLIND TO MOVEMENT INSIDE ITS OWN
# KNOWN-RED SET: a seat can cure a real bug and the row cannot show it, and a marker can go stale and the row
# cannot show that either.  Both are invisible for the same reason and in OPPOSITE directions, so no amount of
# reading the fraction tells them apart -- which is why the cure is to publish the xpass count beside it.
# ⭐ WHAT IT BUYS, and the reason it is worth a gate: it converts the question "are this rung suite's declared xfails
# still red?" from a RUN into a READ.  A nonzero xpass IS the stale-marker case, printed.  Before this, settling it
# cost a full board, and two boards taken an hour apart genuinely disagreed (snobol4 read xfail 26 xpass 1, then
# xfail 25 xpass 2), so the run everyone would have had to spend was not even reproducible.
# ⛔ IT ASSERTS THE PROPERTY, NEVER THE NUMBERS.  Any xpass count greens it, zero included -- a zero is a MEASURED
# "no stale markers", which is exactly the reading the row could not previously carry.  What reds it is a cell that
# publishes a fraction and says nothing about the set behind it.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCORE="${S4E_SCORE_MD:-$HERE/../../.github/SCORE.md}"
[ -r "$SCORE" ] || { echo "⛔ GATE REFUSES (rc=2): cannot read SCORE.md at $SCORE -- a gate that cannot measure never prints the success shape."; exit 2; }
python3 - "$SCORE" <<'PY'
import re, sys
# ⛔ THE TWO RUNG_SUITES THE 2026-09-08 RULING COVERS, and the ONLY two whose runners publish the count today.  When a
# third rungs' runner starts publishing it (util_score_row.py --column board, from its own SUITE_BOARD fields),
# ADD IT HERE -- the list is the gate's scope, and a scope that silently never grows is how a standard decays into
# a pair of exceptions.  raku's cell already carries xfail/xpass by hand; it is not runner-published, so not graded.
RULED = ("snobol4", "icon")
lines = open(sys.argv[1], encoding="utf-8").read().splitlines()
def cells(l): return [c.strip() for c in l.strip().strip('|').split('|')]
# find the display table's header by its own column NAME, never by a line number -- the table moves down the file
# every time a paragraph is added above it, and a gate pinned to a line number grades whatever slid into that slot.
hdr = col = None
for n, l in enumerate(lines):
    if not l.startswith('|'): continue
    cs = cells(l)
    for i, c in enumerate(cs):
        if c.lower().startswith("rungs board"):
            hdr, col = n, i; break
    if hdr is not None: break
if hdr is None:
    print("⛔ GATE REFUSES (rc=2): no 'Rungs board' column found in SCORE.md -- the display table's shape changed and this gate is grading nothing.  Re-derive the column rather than deleting the arm."); sys.exit(2)
found, bad, graded = {}, [], 0
for l in lines[hdr+1:]:
    if not l.startswith('|'): continue
    cs = cells(l)
    if len(cs) <= col: continue
    lang = cs[0].strip('* ').lower()
    if lang in RULED and lang not in found:
        found[lang] = cs[col]
for lang in RULED:
    cell = found.get(lang)
    if cell is None:
        print("⛔ GATE REFUSES (rc=2): no '%s' row under the Rungs board column -- the row this gate was written for is not there to grade." % lang); sys.exit(2)
    graded += 1
    if not re.search(r'xpass\s*=\s*\d+', cell):
        # name what the cell DOES carry, so the reader can tell "the runner has not re-run yet" from "the runner
        # stopped publishing it" -- two very different repairs behind one identical red.
        frac = re.search(r'\d+/\d+', cell)
        bad.append("  %-8s Rungs board cell publishes NO xpass count%s.  It is therefore blind to movement inside its own known-red set: a cured bug and a stale marker both leave this number unchanged.  Cure: re-run the rungs (its runner publishes the count from its own SUITE_BOARD m3_xpass/m4_xpass fields)."
                   % (lang, (" (its headline reads %s)" % frac.group(0)) if frac else " and names no fraction either"))
if graded == 0:
    print("⛔ GATE REFUSES (rc=2): graded zero rows."); sys.exit(2)
if bad:
    print("⛔ GATE FAIL: %d of %d ruled rungs row(s) publish a fraction with no xpass beside it (coo 2026-09-08):" % (len(bad), graded))
    print("\n".join(bad)); sys.exit(1)
print("✅ GATE OK: all %d ruled rungs row(s) publish an xpass count beside their fraction -- movement inside the known-red set is READABLE, not a run away (%s)."
      % (graded, ", ".join("%s: %s" % (k, re.search(r'xpass\s*=\s*\d+', v).group(0)) for k, v in sorted(found.items()))))
PY
