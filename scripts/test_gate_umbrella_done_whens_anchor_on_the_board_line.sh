#!/usr/bin/env bash
# test_gate_umbrella_done_whens_anchor_on_the_board_line.sh -- every umbrella DONE-WHEN reads its score from the runner's OWN
# labelled board line, never from a whole-stdout token grep. hq_T 2026-09-04, row
# umbrella-done-whens-anchor-on-the-runners-own-board-line-never-on-any-line-with-pass (ceo mint on hq_B + seat02's flag, 20:39).
#
# ⛔⭐ THE DEFECT: the ceo's umbrella template grepped the runner's WHOLE stdout for PASS=[1-9] to prove it measured, then for
# (FAIL|REJECT|CRASH|HANG|...)=[1-9] to red it. That assumes EVERY score-shaped token in the stream belongs to the score. False since
# CEO-251 REQUIRED informational arms beside it: snoflake prints an sbl-vs-@expect line and csnobol4 a triangulation line, both
# carrying FAIL= BY DESIGN, so those rows read unfinished against a PERFECT SCRIP. And false in the other direction where a runner
# spells its count lowercase -- dotnet's clean suite read "printed no PASS count" and refused.
# ⭐ BOTH FAILURES ARE THE SAME BUG WEARING OPPOSITE MASKS: a false red and a false refusal out of one wrong assumption, which is why
# curing only the arm that bit you leaves the class alive. EXTRACTION ANCHORS ON IDENTITY, NEVER ON POSITION -- name the line
# (^GIMPEL_BOARD, ^SUITE_BOARD, ^mode-3), pull the tokens out of THAT line, and spell them the way the runner prints them.
#
# WHAT IS GRADED RED: a DONE-WHEN that pipes the variable holding the runner's WHOLE captured output into a grep for a score token.
# WHAT IS ACCEPTED: the same grep applied to a variable that was itself extracted with a labelled/anchored pattern.
# ⛔ SCOPED EXACTLY TO THE RULING AND NO WIDER. A whole-stdout grep for something that is NOT a score token (inria greps its own
# stdout for 445/445) is the same FAMILY of defect and is reported as a NAMED OBSERVATION, never counted in the red -- the ruling
# covers score-token greps, and a gate broader than its rule gets switched off by the first person it blocks for a good reason.
# ⛔ IT DOES NOT RUN ANY SUITE. It reads baton text only: hermetic, sub-second, no build, no oracle.
# Population: tasks/*-to-100-percent*.task.md and *-censused-by-class*.task.md. Denominator printed; REFUSES rc=2 on an empty one.
# UMBRELLA_TASKS_DIR overrides the live postoffice, which is how the fail-once arms run on scratch batons and never on real ones.
# Usage: bash ../harness/scripts/test_gate_umbrella_done_whens_anchor_on_the_board_line.sh    Exit: 0 all anchored · 1 some unanchored · 2 cannot measure.
set -uo pipefail
GATE_NAME=umbrella-done-whens-anchor-on-the-board-line
TASKS="${UMBRELLA_TASKS_DIR:-/home/resources/postoffice/tasks}"
refuse() { echo "⛔ GATE UNPROVEN(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -d "$TASKS" ] || refuse "no tasks dir at $TASKS"
command -v python3 >/dev/null 2>&1 || refuse "python3 not on PATH"
UMBRELLA_TASKS_DIR="$TASKS" GATE_NAME="$GATE_NAME" python3 - <<'PY'
import os, re, sys, glob
tasks = os.environ['UMBRELLA_TASKS_DIR']; gate = os.environ['GATE_NAME']
files = sorted(set(glob.glob(os.path.join(tasks, '*-to-100-percent*.task.md'))) |
               set(glob.glob(os.path.join(tasks, '*-censused-by-class*.task.md'))))
if not files:
    print(f"⛔ GATE UNPROVEN(2) [{gate}]: censused {tasks} and found zero umbrella batons -- a census that cannot see its population must never print 0", file=sys.stderr); sys.exit(2)
SCORE = r'(?:PASS|FAIL|REJECT|CRASH|HANG|UNEXPECTED|NOBUILD)=|SKIP\\?\(cc\\?\)='
# A variable is a WHOLE-OUTPUT variable when it is assigned from a command substitution that runs a runner script.
RUNNER_ASSIGN = re.compile(r'(\w+)=\$\((?:\s*timeout\s+\S+\s*)?(?:bash|sh)\s+../harness/scripts/\S+')
# A variable is a BOARD-LINE variable when it is assigned from a grep carrying an anchored or labelled pattern.
LINE_ASSIGN = re.compile(r'(\w+)=\$\(\s*(?:echo|printf)[^)]*?\|\s*grep[^)]*?(?:\^|_BOARD|BOARD )')
# A score-token grep and the variable feeding it.
FED_GREP = re.compile(r'(?:echo|printf)\s+[^|;]*?"\$(?:\{)?(\w+)\}?"[^|;]*\|\s*grep[^|;]*')
red = 0; notes = []; graded = 0
for path in files:
    name = os.path.basename(path)[:-len('.task.md')]
    dws = [l for l in open(path, encoding='utf-8', errors='replace').read().splitlines() if l.startswith('DONE-WHEN:')]
    if not dws: notes.append((name, "carries NO DONE-WHEN line at all")); continue
    graded += 1
    full = set(RUNNER_ASSIGN.findall(' '.join(dws)))
    lines = set(LINE_ASSIGN.findall(' '.join(dws)))
    full -= lines
    hits, family = [], []
    for dw in dws:
        for m in FED_GREP.finditer(dw):
            var, seg = m.group(1), m.group(0)
            if var not in full: continue
            # ⛔ THE ANCHOR MAY LIVE IN THE PATTERN RATHER THAN IN A PRIOR EXTRACTION, and that is just as anchored: a single
            # grep for "^CSNOBOL4_SUITE_BOARD total=... m3_FAIL=0 ..." names the line it means and cannot match an
            # informational arm, which is the whole property the ruling asks for. Judging by the INPUT alone flags it, and
            # flagging a correctly-pinned baton is how a gate teaches its lane to stop reading it.
            if re.search(r'grep[^|;]*"[^"]*(?:\^[A-Za-z][A-Za-z0-9_]*_BOARD|_BOARD\s|\^mode-[34])', seg): continue
            if re.search(SCORE, seg): hits.append(seg.strip()[:150])
            elif re.search(r'grep\s+-\w*q?\w*E?\s*"[^"]*[0-9]+/[0-9]+', seg): family.append(seg.strip()[:110])
    if hits:
        red += 1
        print(f"RED  {name}")
        print(f"       reads its score by grepping the runner's WHOLE stdout, not a labelled board line:")
        for h in hits[:3]: print(f"         {h}")
        print(f"       cure: capture the runner's own board line first (grep -m1 \"^<SUITE>_BOARD \" or ^mode-3), then read the")
        print(f"       tokens out of THAT line, spelled as the runner prints them; REFUSE(2) if the line is absent.")
    elif family:
        notes.append((name, "whole-stdout grep for a FRACTION, not a score token -- same family, outside this ruling: " + family[0]))
print(f"-- graded {graded} umbrella baton DONE-WHEN(s) of {len(files)} baton(s) censused in {tasks}")
if notes:
    print("-- NAMED OBSERVATIONS (not counted in the verdict, outside the ruling's scope):")
    for n, why in notes: print(f"     {n}: {why}")
if graded == 0:
    print(f"⛔ GATE UNPROVEN(2) [{gate}]: no baton carried a DONE-WHEN -- graded nothing", file=sys.stderr); sys.exit(2)
if red:
    print(f"GATE RED(1) [{gate}]: {red} of {graded} umbrella DONE-WHEN(s) still scan whole stdout -- an informational arm carrying FAIL= reds a perfect suite, and a lowercase count reads as 'no PASS count'")
    sys.exit(1)
print(f"GATE GREEN(0) [{gate}]: all {graded} umbrella DONE-WHEN(s) anchor on their runner's own board line")
PY
