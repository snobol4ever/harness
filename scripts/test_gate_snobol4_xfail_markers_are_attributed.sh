#!/usr/bin/env bash
# test_gate_snobol4_xfail_markers_are_attributed.sh — every surviving XFAIL marker in the SNOBOL4
# rungs must NAME A LIVE ROW, so that "expected to fail" always carries a route to a cure.
#
# ⛔ WHY THIS GATE EXISTS (hq_P 2026-09-06, row snobol4-every-xfail-fixed-as-a-faulty-test-or-cured-
# as-a-defect; CEO-328 (4) asked the question in prose and nobody could run it). Measured at the time
# of writing: of 32 markers, 6 named a live row, 3 named a row that was never minted, and 23 named NO
# ROW AT ALL -- they cite a FINDING and the words "Known, still open". ⭐ A FINDING IS A RECORD, NOT A
# ROUTE: under Lon's THERE IS NO XFAIL ruling, a marker whose text names no row leaves its reader with
# no way to reach the work, and it is invisible to every board because it is, by construction, expected.
# ⛔ THAT IS A STATEMENT ABOUT THE MARKER'S TEXT, NOT ABOUT WHETHER ANYONE OWNS THE DEFECT -- see the
# double-banner note below before you act on a single number from this gate.
#
# ⛔⭐ THE POPULATION IS ALL.csv's xfail COLUMN, AND v1 OF THIS GATE GOT THAT WRONG. It read ALL.xfail
# as the population, which makes the WORST case structurally invisible: an entry marked xfail with NO
# reason recorded at all is simply not in the file, so the gate counts a smaller, cleaner census and
# passes over exactly the entries nobody can act on. Caught within the hour of landing v1, on corpus
# f1e0cb251: csv=34 against reasons=32, the two extras (bal_arb_keyword_branch_1,
# user_function_keyword_branch_3) arriving from a ladder rung with no reason text at all. ⭐ AN
# INSTRUMENT THAT TAKES ITS DENOMINATOR FROM THE SAME FILE IT IS GRADING CANNOT SEE WHAT IS MISSING
# FROM THAT FILE -- the denominator must come from the other side. Its sibling
# test_gate_xfail_marker_and_index_agree.sh MEASURES this as REASONS_MISSING=2 and still exits 0.
#
# ⛔ REPORTED, NOT BLOCKING, ON PURPOSE: it is RED today (28 of 34 carry no usable route; the other 6 name a live row, but only in prose). It is wired into `make test`
# with a leading `-` exactly like test_gate_no_xfail_survives.sh, and the ramp to blocking is a
# ceo/Lon date decision, not a script author's.
#
# ⭐ SIX ARMS NEGATIVE-TESTED AT LANDING, because a gate that cannot fail is the trap this row is
# about: rc=1 real tree · rc=2 missing QUEUE.tsv · rc=2 QUEUE parsing to zero rows · rc=2 missing
# ALL.csv · rc=2 ALL.csv with no xfail column · rc=0 on a synthetic tree where all 32 reasons name a
# live row. Re-run them with `bash ../harness/scripts/util_xfail_attribution_gate_arms.sh` -- they are cheap, and
# they are the only thing standing between this gate and the skip-as-success class it exists to expose.
#
# ⛔⛔ READ THE OUTPUT AS "UNRESOLVABLE BY NAME", NEVER AS "UNOWNED" -- THE AUTHOR OF THIS GATE MADE
# EXACTLY THAT MISREADING AND WAS ONE COMMAND FROM MINTING THREE DUPLICATE ROWS INTO ANOTHER HQ'S LANE.
# The 23 ARE owned: six snobol4-xfail-class-* rows cover this population, and each re-derives its own
# membership with its own bespoke grep over the marker prose (hq_T's fuzz row closes on
# `grep -ciE "fz_|fuzz"`). No marker names its row and no row lists its entries, so the join is prose
# and is invisible from both ends -- that is the defect, not an absence of rows. ⭐ A gate that answers
# "does this string appear in QUEUE.tsv" cannot answer "is this defect owned", and it has no way to
# say so. See FINDING-2026-09-06-hq_P-23-of-32-snobol4-xfail-markers-name-no-live-row-... (the filename
# is the claim that turned out to be wrong; it is kept because the correction is the finding).
#
# ⛔ WHAT THIS GATE DOES NOT CLAIM: that an attributed marker is CORRECT, or that its row is the right
# row. It grades ROUTING ONLY. A marker pointing at a live row it has nothing to do with passes here
# and is still wrong -- that is a different question and needs a different instrument.
set -u
here="$(cd "$(dirname "$0")" && pwd)"; root="$(cd "$here/../.." && pwd)"
RUNGS_XFAIL="$root/corpus/tests/snobol4/ALL.xfail"
RUNGS_CSV="$root/corpus/tests/snobol4/ALL.csv"
QUEUE="${S4E_QUEUE:-/home/resources/postoffice/QUEUE.tsv}"
# ⛔ REFUSE rc=2 rather than skip-as-success: an instrument that cannot measure must say so. A missing
# ALL.xfail is NOT "zero unattributed markers" -- it is a gate that graded nothing and must not print
# the same string as one that passed.
# ⭐ AMENDED 2026-10-02 (ceo CEO-1408): the POPULATION is ALL.csv's xfail column (below), so an ABSENT ALL.xfail is MEASURABLE -- it is
# zero reason blocks. util_build_rungs_suite.py --resort deletes an empty ALL.xfail, which is exactly the state of a rungs with no
# markers left (SnoRungs on 2026-10-02). Read as empty: zero marked entries grade CLEAN, and any marked entry grades NO REASON AT
# ALL (RED) -- never a skip. The refusal stays for a missing QUEUE.tsv or ALL.csv, which ARE the population and the routes.
if [ ! -f "$RUNGS_XFAIL" ]; then
    _xf_empty="$(mktemp)" || { echo "⛔ GATE REFUSES: mktemp failed"; exit 2; }; trap 'rm -f "$_xf_empty"' EXIT
    echo "  ALL.xfail absent -- read as ZERO reason blocks (the population is ALL.csv's xfail column)"; RUNGS_XFAIL="$_xf_empty"
fi
[ -f "$QUEUE" ]        || { echo "⛔ GATE REFUSES: no QUEUE.tsv at $QUEUE -- cannot tell a live row from a dead one"; exit 2; }
[ -f "$RUNGS_CSV" ]   || { echo "⛔ GATE REFUSES: no $RUNGS_CSV -- ALL.csv is the POPULATION; without it this gate can only see xfails that already have a reason, which is the blind spot it exists to close"; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "⛔ GATE REFUSES: no python3"; exit 2; }
python3 - "$RUNGS_XFAIL" "$QUEUE" "$RUNGS_CSV" <<'PY'
import re, sys, csv, collections
BANNER = re.compile(r"^\*-+ (?P<seq>\d+) (?P<name>\S+)(?P<xfail> XFAIL)?$")
xf, q, cs = sys.argv[1], sys.argv[2], sys.argv[3]
rows = {}
for ln in open(q, encoding="utf-8", errors="replace"):
    if ln.startswith("#"):
        continue
    f = ln.rstrip("\n").split("\t")
    if len(f) >= 4:
        rows[f[1]] = f[3]
if not rows:
    print("⛔ GATE REFUSES: QUEUE.tsv parsed as zero rows -- the format moved under this gate")
    sys.exit(2)
marks, cur = collections.OrderedDict(), None
for ln in open(xf, encoding="utf-8", errors="replace"):
    m = BANNER.match(ln.rstrip("\n"))
    if m:
        cur = m.group("name"); marks[cur] = ""
    elif cur and ln.strip():
        marks[cur] += ln
if not marks and open(xf, encoding="utf-8", errors="replace").read().strip():
    print("⛔ GATE REFUSES: %s parsed as zero markers -- banner format moved, or the file is a stub" % xf)
    sys.exit(2)
# ⛔⭐ THE POPULATION IS ALL.csv's xfail COLUMN, NEVER ALL.xfail. Reading the reason file as the
# population makes the WORST case invisible: an entry marked xfail with NO reason recorded at all
# simply is not there to be counted, so the gate reports a smaller, cleaner census and passes over
# exactly the entries nobody can act on. Measured the hour this gate landed -- corpus f1e0cb251
# carried csv=34 against reasons=32, the two extras (bal_arb_keyword_branch_1,
# user_function_keyword_branch_3) arriving from a ladder rung with no reason text. Its sibling
# test_gate_xfail_marker_and_index_agree.sh MEASURES that as REASONS_MISSING=2 and still exits 0.
try:
    csv_rows = list(csv.DictReader(open(cs, encoding="utf-8", errors="replace")))
except Exception as e:
    print("⛔ GATE REFUSES: cannot read %s (%s)" % (cs, e)); sys.exit(2)
if not csv_rows or "xfail" not in csv_rows[0] or "entry" not in csv_rows[0]:
    print("⛔ GATE REFUSES: %s has no xfail/entry column -- the schema moved under this gate" % cs)
    sys.exit(2)
population = [r["entry"] for r in csv_rows if r.get("xfail") == "1"]
assert isinstance(rows, dict) and rows, "REFUSE: the QUEUE row map was clobbered"
if not population:
    print("✅ ALL.csv marks zero xfail entries -- nothing to attribute")
    sys.exit(0)
noreason = [e for e in population if e not in marks]
live, closed, unminted, none = [], [], [], []
for e in population:
    txt = marks.get(e)
    if txt is None:
        continue
    cands = set(re.findall(r"`([a-z0-9][a-z0-9-]{6,})`", txt))
    cands |= set(re.findall(r"(?:class )?row `?([a-z0-9][a-z0-9-]{6,})`?", txt))
    known = {c for c in cands if c in rows}
    if known:
        (live if any(not rows[c].startswith(("DONE", "SUPERSEDED")) for c in known) else closed).append((e, sorted(known)))
    elif cands:
        unminted.append((e, sorted(cands)))
    else:
        none.append((e, []))
print("XFAIL MARKER ATTRIBUTION (snobol4): population=%d (ALL.csv xfail=1)  reasons_on_file=%d  live_row=%d  row_closed=%d  named_but_never_minted=%d  NO_ROW=%d  NO_REASON_AT_ALL=%d"
      % (len(population), len(marks), len(live), len(closed), len(unminted), len(none), len(noreason)))
for e in noreason:
    print("  %-24s %-46s %s" % ("NO REASON AT ALL", e, "(marked xfail in ALL.csv, absent from ALL.xfail)"))
bad = closed + unminted + none + [(e, []) for e in noreason]
for label, group in (("ROW CLOSED", closed), ("NAMED BUT NEVER MINTED", unminted), ("NAMES NO ROW", none)):
    for e, c in group:
        print("  %-24s %-46s %s" % (label, e, ",".join(c) if c else "-"))
if bad:
    print("⛔ %d of %d xfail entries carry no usable route -- unresolvable by name." % (len(bad), len(population)))
    print("   ⛔ This is NOT a count of unowned defects: six snobol4-xfail-class-* rows cover this")
    print("      population and each re-derives membership with its own grep over this prose. The join")
    print("      is prose and invisible from both ends -- that is the defect this gate reports.")
    sys.exit(1)
print("✅ every surviving XFAIL marker names a live row")
PY
