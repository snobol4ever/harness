#!/usr/bin/env bash
# test_gate_pl_xfail_marker_consistent.sh -- AN XFAIL MARKER LIVES IN THREE PLACES AND MUST AGREE IN ALL THREE.
# Row prolog-master-seven-stale-xfail-markers-xpass-on-the-rung-3-tree (hq_C mint, ceo assign).
#
# The INTERIM PROMOTION PROTOCOL (lib_rungs_extract.sh) requires a promotion to move together:
#   (1) the ` XFAIL` suffix on the ALL.pl banner,
#   (2) the same suffix on the ALL.ref banner,
#   (3) the `xfail` column in ALL.csv.
# ⛔ A HALF-APPLIED PROMOTION MAKES read_suite RAISE AND TEARS THE SUITE FOR EVERY SEAT ON THE BOX (hq_C), which
# is why this is an invariant gate over ALL entries and not a checklist for the seven that happened to be promoted.
#
# WHAT IT PROVES:
#   (a) for every entry, ALL.pl banner XFAIL == ALL.ref banner XFAIL == (ALL.csv xfail == 1);
#   (b) the two banner lists name the same entries in the same order (a rename in one file only is the other
#       way this tears, and it is invisible to a per-entry check that keys on name);
#   (c) read_suite actually reads the result, IN THIS TREE -- the harness's own `list` must enumerate every entry.
#       Without (c) the gate would certify a file the grader cannot load, which is the exact failure it exists to stop.
#   (d) banner width is uniform, so a promotion that drops ` XFAIL` re-pads instead of leaving a ragged column.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"; P="${PL_SUITE_DIR:-$S4E/corpus/tests/prolog}"
refuse(){ echo "⛔ REFUSED-TO-GRADE: $*"; exit 2; }
for f in ALL.pl ALL.ref ALL.csv; do [ -f "$P/$f" ] || refuse "missing $P/$f"; done
python3 - "$P" <<'PY'
import csv,io,re,sys,subprocess,os
P=sys.argv[1]; sep=re.compile(r'^(%-+) +(\d+) +(\S+?)( XFAIL)?\s*$')
def banners(p):
    out=[]
    for l in io.open(os.path.join(P,p),encoding='utf-8'):
        m=sep.match(l.rstrip('\n'))
        if m: out.append((m.group(3), bool(m.group(4)), len(l.rstrip('\n'))))
    return out
bp, br = banners('ALL.pl'), banners('ALL.ref')
rows=list(csv.reader(io.open(os.path.join(P,'ALL.csv'),newline='')));h=rows[0]
cs={r[h.index('entry')]: r[h.index('xfail')]=='1' for r in rows[1:]}
fails=[]
if [e for e,_,_ in bp]!=[e for e,_,_ in br]:
    fails.append('(b) ALL.pl and ALL.ref banner lists differ (order or membership)')
for (e,x,_),(e2,x2,_) in zip(bp,br):
    if x!=x2: fails.append('(a) %s: ALL.pl XFAIL=%s but ALL.ref XFAIL=%s'%(e,x,x2))
    if e in cs and cs[e]!=x: fails.append('(a) %s: banner XFAIL=%s but ALL.csv xfail=%s'%(e,x,cs[e]))
    if e not in cs: fails.append('(a) %s: in the banners but absent from ALL.csv'%e)
w=set(n for _,_,n in bp)|set(n for _,_,n in br)
if len(w)!=1: fails.append('(d) banner widths are ragged: %s'%sorted(w))
print('  entries: ALL.pl=%d ALL.ref=%d ALL.csv=%d   XFAIL marked: %d'%(len(bp),len(br),len(cs),sum(1 for _,x,_ in bp if x)))
for f in fails[:20]: print('  FAIL  '+f)
if fails: print('⛔ GATE FAIL: %d inconsistency(ies)'%len(fails)); sys.exit(1)
print('  ok    (a) all three places agree for every entry')
print('  ok    (b) banner lists identical across ALL.pl and ALL.ref')
print('  ok    (d) banner width uniform at %d'%w.pop())
PY
rc=$?; [ "$rc" -eq 0 ] || exit "$rc"
n="$(python3 "$HERE/corpus_suite_harness.py" list "$P/ALL.pl" "$P/ALL.ref" --lang prolog 2>/dev/null | grep -c .)" || refuse "read_suite could not list the rungs -- the grader cannot load this tree"
[ "${n:-0}" -gt 0 ] || refuse "read_suite listed 0 entries -- the grader cannot load this tree"
echo "  ok    (c) read_suite lists $n entries in this tree"
echo "✅ GATE PASS"; exit 0
