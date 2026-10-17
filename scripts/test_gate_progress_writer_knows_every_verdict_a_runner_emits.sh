#!/usr/bin/env bash
# test_gate_progress_writer_knows_every_verdict_a_runner_emits.sh -- the progress DB's writer must accept every
# verdict the boards actually produce, or a whole suite's per-program evidence is dropped while the suite's
# SCORE row is published anyway.
#
# ⛔ THE DEFECT (ceo 2026-09-14, found running the x64 board; the class the coo filed on 2026-09-13 and
# CEO-750 ruled on that morning). util_progress_append.py's OUTCOMES tuple knew twelve verdicts. The LAW had
# since grown three more -- DEFERRED (hq_T's declared m4 asm budget), OUTSIDE (CEO-542's outside-baseline) and
# UNGRADABLE (THE PACKAGE LOCKDOWN's third bucket) -- and the writer learned none of them. Measured: the x64
# suite emits DEFERRED for four programs, the writer REFUSES rc=2 on the first one, and ALL 72 rows (36
# programs x 2 modes) are dropped. The board still printed, and the SCORE row was still written.
#
# ⭐ WHY THIS IS A GATE AND NOT A ONE-LINE FIX: the three missing verdicts were not a typo, they are what
# happens every time a ruling invents a bucket -- the runner learns it the same day, the recorder does not,
# and nothing compares the two lists. So this gate DERIVES the runners' vocabulary from the runners
# themselves and fails when the writer's tuple does not cover it. The next verdict some ruling invents is
# caught by construction rather than by a reader noticing a suite went quiet.
#
# ⛔ AND THE FAILURE IS SILENT IN THE DIRECTION THAT MATTERS: a dropped row does not red anything. It makes the
# suite VANISH from the flip histogram, which is the instrument the fleet reads to answer "are we making
# progress" -- so the defect reports as "no movement", the least alarming thing it could possibly say.
#
# NO BUILD NEEDED (source census, <1s). rc=0 clean · rc=1 the writer does not know a verdict a runner emits
# · rc=2 REFUSAL (cannot read one of the two sides, which is not a pass).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
W="$HERE/util_progress_append.py"
[ -f "$W" ] || { echo "⛔ REFUSES rc=2: cannot read the writer at $W"; exit 2; }

python3 - "$W" "$HERE" <<'PY'
import os, re, sys

writer, scripts_dir = sys.argv[1], sys.argv[2]
src = open(writer, encoding="utf-8").read()
m = re.search(r'^OUTCOMES\s*=\s*\((.*?)\)', src, re.S | re.M)
if not m:
    print("⛔ REFUSES rc=2: no OUTCOMES tuple in the writer -- its shape moved and this gate is blind, which is not a pass.")
    sys.exit(2)
known = set(re.findall(r'"([A-Z]+)"', m.group(1)))
if len(known) < 8:
    print("⛔ REFUSES rc=2: only %d verdict(s) parsed out of the writer; the parse is wrong, not the writer." % len(known))
    sys.exit(2)

# What a runner can put in an outcome column. Derived from the runners, never from a second hand-kept list:
# every all-caps word a *_suite.sh / board_* / scorecard_* writes into a progress row or prints as a verdict.
emitted = {}
pat = re.compile(r'\b(DEFERRED|OUTSIDE|UNGRADABLE|UNGRADED|UNPROVEN|REJECT|MISSING|REFUSE|CRASH|HANG|SKIP|XFAIL|XPASS|FAIL|PASS)\b')
for fn in sorted(os.listdir(scripts_dir)):
    if not fn.endswith(".sh"):
        continue
    if not (fn.startswith("test_") and "suite" in fn or fn.startswith("board_") or fn.startswith("scorecard_")):
        continue
    try:
        text = open(os.path.join(scripts_dir, fn), encoding="utf-8", errors="replace").read()
    except OSError:
        continue
    for w in pat.findall(text):
        emitted.setdefault(w, set()).add(fn)

if not emitted:
    print("⛔ REFUSES rc=2: no runner vocabulary found -- the census matched nothing, which is not a pass.")
    sys.exit(2)

missing = sorted(w for w in emitted if w not in known)
print("progress writer vocabulary vs the verdicts the runners emit")
print("  writer knows : %s" % " ".join(sorted(known)))
print("  runners emit : %s" % " ".join(sorted(emitted)))
if missing:
    print()
    print("⛔ GATE FAILED: the writer does not know %d verdict(s) the runners emit." % len(missing))
    for w in missing:
        who = sorted(emitted[w])
        print("   %-12s emitted by %d runner(s), e.g. %s" % (w, len(who), ", ".join(who[:3])))
    print("   ⛔ A ROW REFUSED IS A ROW DROPPED, AND THE WHOLE FILE GOES WITH IT: rows-tsv refuses on the FIRST")
    print("      bad outcome, so one unknown verdict in one program silences every program in that run.")
    print("   ⭐ Add the verdict to OUTCOMES in util_progress_append.py. Do NOT 'fix' this by making the runner")
    print("      print a verdict it does not mean -- the bucket exists because a ruling created it.")
    sys.exit(1)
print()
print("✅ GATE OK: every verdict the %d runner(s) emit is one the progress writer accepts" % len({f for s in emitted.values() for f in s}))
PY
exit $?
