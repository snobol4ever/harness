#!/usr/bin/env bash
# test_gate_progress_configuration_declarations_do_not_regress.sh -- THE CONFIGURATION RATCHET: A LANE THAT HAS
# DECLARED WHAT IT EXERCISED MAY NEVER SILENTLY STOP, AND NO WRITER MAY STILL BE EMITTING THE OLD COLUMN WIDTH
# (coo 2026-09-21; ceo rank 1 at CEO-1058, "the ratchet is still rank 1 as ruled").
#
# ⛔⭐ THE HOLE THIS CLOSES IS IN A GUARD I LANDED MYSELF THIS MORNING, AND IT IS A HOLE OF SHAPE, NOT OF CARE.
# util_progress_append.py refuses an undeclared row in exactly ONE case: when a GC axis is set IN THE WRITER'S
# OWN PROCESS ENVIRONMENT. That is correct and it is bounded, and the writer's own comment says why -- "the
# runner may set the axis per-child, so an empty environment here is an ABSENCE OF EVIDENCE about the child".
# A runner that forks its children with SCRIP_GC_STRESS set and appends from a clean parent therefore meets NO
# REFUSAL AT ALL. The undeclared population can grow forever and the guard can never fire on it. A ratchet is
# the only thing that closes a hole of that shape: not "declare or refuse" at the moment of writing, which the
# writer cannot always know, but "having declared once, you may not stop", which the TABLE always knows.
#
# ⛔⭐ AND IT IS JUDGED AGAINST THE LIVE TABLE ON PURPOSE. This is the clause the ceo asked be applied (CEO-1058):
# A HERMETIC GATE THAT CONSTRUCTS ITS SUBJECT FRESH CANNOT SEE A DEFECT THAT EXISTS ONLY IN THE LONG-LIVED
# ARTEFACT. test_gate_progress_append_writes_a_row.sh was green for FIFTEEN DAYS while `fingerprint` was
# unreadable in 3.58M rows, for exactly the reason we built it that way: its mktemp table always gets a complete
# header on first touch, so the subject it graded could not exhibit the defect. Arm 1 below therefore reads the
# REAL table. Arms 2-6 are fixtures, and every one of them plants a table that ALREADY EXISTS and ALREADY
# CARRIES HISTORY IN THE OLD SHORT SHAPE before the arm writes a single row.
#
#   1  LIVE: the real table passes the ratchet at the pinned baseline (rc 1 = a lane regressed; rc 2 = UNPROVEN)
#   2  ARM A FIRES: a short row appended AFTER the baseline is named -- and the identical short rows BEFORE it
#      are NOT, which is what proves the baseline actually bounds the judgement instead of decorating it
#   3  ARM B FIRES: a lane that declared and then went undeclared is named, with its first declaration quoted
#   4  SEAM/CONTROL: a lane that has NEVER declared appending `undeclared` is ACCEPTED -- the ratchet forbids
#      REGRESSION, not ABSENCE (see the standing note below; this arm is why the gate is landable at all)
#   5  FLOOR: an empty window REFUSES rc=2 and does not report success over a population of nothing
#   6  THE BASELINE IS PINNED TO ITS COMMIT: the constant matches f839e933b's own commit time, so nobody can
#      slide the window forward until the table is green
#
# ⛔ WHAT THIS GATE DELIBERATELY DOES NOT DO, AND THE NUMBER THAT DECIDED IT: it does not red a lane that has
# NEVER declared. Measured on the live table the day it was written, exactly ONE measurer had written a declared
# configuration SINCE THE COLUMN EXISTED -- hq_snocone, 12096 rows -- and the other nine had not; hq_pascal's
# `pat` suite alone carries 854 full-width undeclared rows since the baseline.
# ⛔ BOUNDED IN PLACE 2026-09-21 BY THE ceo (CEO-1060) AND THE BOUND IS RIGHT: the `config` column did not EXIST before
# 17:53:17Z, so "has ever declared" spans THIRTY MINUTES, and a population that could not have contained the thing
# cannot be evidence that nobody does it -- A NULL RESULT BOUNDS THE PROBE, NOT THE THING PROBED. What the number
# actually establishes is that ONE SEAT HAS RUN A BOARD THROUGH THE NEW WRITER AND IT DECLARED CORRECTLY: a working
# mechanism with a sample of one, NOT fleet-wide non-compliance. The design conclusion is UNCHANGED and is if anything
# stronger -- with nine lanes not yet observed at all, a ratchet on ABSENCE would red seats whose behaviour has never
# been measured. A ratchet on ABSENCE would have been a
# fleet-wide red on arrival, and a gate nobody can be green under is turned off rather than obeyed. The floor
# rises one lane at a time, by that lane's own first declaration, and from then on it cannot fall.
#
# Cost: ~14 s, and it is a FULL SCAN of a 3.6M-row / 525 MB table that grows about 16k rows a day -- so this
# cost grows with the table, by roughly 4% a day at today's rate. A tail-seek would make it O(window), and it is
# deliberately NOT done here: a seek that lands slightly wrong silently SHRINKS the population and the ratchet
# goes green over the rows it failed to read, which is the "instrument reports success while doing nothing"
# failure this gate exists to prevent. Correctness over speed for an instrument whose whole job is not to lie.
# Revisit when the cost is felt, as an economy decision for the ceo (CEO-1046), not a unilateral one here.
# BLOCKING in `make test` with the cost line above (CEO-1045); NOT in `make preflight` (CEO-1046: it reads a
# live external artefact, so it is not hermetic and does not belong in the cheap hermetic set).
#
# PROVEN RED BEFORE THE CURE (CEO-1049), live table, 2026-09-21: the SAME ratchet with --baseline pulled back to
# 00:00Z the same day reads ⛔ RED, ARM A, 16298 SHORT ROWS of 31082 across FOUR measurers -- hq_snocone 8736,
# cto 4032, hq_pascal 3444, ceo 86 -- and at the pinned baseline reads ✅ GREEN, 0 short of 15638. Same code,
# same table, one parameter: a before/after pair on one tree plus the one change (RULES.md INSTRUMENT LAWS).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
. "$HERE/lib_gate.sh"
gate_parse_args "$@"
Q="$S4E/.github/scripts/util_progress_flips.py"
[ -f "$Q" ] || { echo "GATE UNPROVEN(2) [progress_configuration_ratchet]: query tool missing at $Q (pull .github)"; exit 2; }
LIVE_DB="${S4E_PROGRESS_DB_LIVE:-/home/resources/progress/results.tsv}"
W="$(mktemp -d "${TMPDIR:-/tmp}/gate_progress_ratchet.XXXXXX")" || { echo "GATE UNPROVEN(2): mktemp failed"; exit 2; }
trap 'rm -rf "$W"' EXIT
fails=0; checks=0
ck() { checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }

BASE="$(python3 -c 'import sys; sys.path.insert(0,"'"$S4E"'/.github/scripts"); import util_progress_flips as u; print(u.CONFIG_BASELINE)')" || {
  echo "GATE UNPROVEN(2) [progress_configuration_ratchet]: cannot read CONFIG_BASELINE from $Q"; exit 2; }
TREE="$(python3 -c 'import sys; sys.path.insert(0,"'"$S4E"'/.github/scripts"); import util_progress_flips as u; print(u.CONFIG_BASELINE_TREE)')"

# ⛔ THE PRE-EXISTING TABLE, IN THE LIVE SHAPE: the FULL 14-column header, plus history already written in the
# SHORT 13-column shape that every pre-migration writer emitted. No arm below ever starts from an empty file --
# that is the whole point of this gate (CEO-1058). `hist` rows are dated BEFORE the baseline on purpose: the
# ratchet must leave them alone, and arm 2 checks that it does.
HDR='ts_utc	scrip	corpus	measurer	class	suite	lang	program	mode	outcome	secs	note	fingerprint	config'
seed() {   # seed <db>  -- a table that already exists, already has history, already in the old short shape
  printf '%s\n' "$HDR" > "$1"
  printf '2026-09-06T00:00:00\tdeadbeef1\tcafebabe2\told_lane\trungs\tsnobol4-rungs\tsnobol4\thist_a\tm3\tPASS\t0\t\tfeedface0000\n' >> "$1"
  printf '2026-09-19T00:00:00\tdeadbeef1\tcafebabe2\told_lane\trungs\tsnobol4-rungs\tsnobol4\thist_b\tm3\tPASS\t0\t\tfeedface0000\n' >> "$1"
}
row13() { printf '%s\t%s\tcafebabe2\t%s\trungs\t%s\tsnobol4\t%s\tm3\tPASS\t0\t\tfeedface0000\n' "$1" deadbeef1 "$2" "$3" "$4" >> "$5"; }
row14() { printf '%s\t%s\tcafebabe2\t%s\trungs\t%s\tsnobol4\t%s\tm3\tPASS\t0\t\tfeedface0000\t%s\n' "$1" deadbeef1 "$2" "$3" "$4" "$6" >> "$5"; }
ratchet() { python3 "$Q" --db "$1" --ratchet ${2:+--baseline "$2"} 2>&1; }

echo "=== gate: the configuration ratchet -- a lane that has declared may never silently stop ==="
echo "    baseline $BASE (SCRIP $TREE) · live table $LIVE_DB"

echo "--- ARM 1: THE LIVE TABLE (the long-lived artefact, not a fixture) ---"
if [ ! -f "$LIVE_DB" ]; then
  echo "GATE UNPROVEN(2) [progress_configuration_ratchet]: the live table $LIVE_DB does not exist, so the arm that"
  echo "  matters cannot run. A fixture-only pass here would be the exact blindness this gate was minted to refuse."
  exit 2
fi
out="$(python3 "$Q" --db "$LIVE_DB" --ratchet 2>&1)"; rc=$?
printf '%s\n' "$out" | sed 's/^/    | /'
case "$rc" in
  0) ck ok "live table: ratchet GREEN -- no short rows since the baseline and no lane has stopped declaring";;
  1) ck no "live table: ratchet RED -- a lane stopped declaring or a writer is emitting the old width (named above)";;
  *) echo "GATE UNPROVEN(2) [progress_configuration_ratchet]: the ratchet could not measure the live table (rc=$rc)"; exit 2;;
esac

echo "--- ARM 2: ARM A FIRES on a short row AFTER the baseline, and NOT on identical rows before it ---"
D="$W/a.tsv"; seed "$D"
# ⛔ THE WINDOW MUST BE NON-EMPTY BEFORE THIS ARM MEANS ANYTHING, and arm 5's floor is what taught me so:
# the first cut of this arm held only pre-baseline rows, so it read rc=2 NOTHING TO MEASURE and I had written
# it down as "the baseline is decoration". The floor was right and the arm was wrong. One clean post-baseline
# row goes in FIRST, so a green here is a green over a real population and not over an empty one.
row14 "2026-09-21T17:59:00" lane_ok snobol4-rungs anchor "$D" "shipped"
row13 "2026-09-20T10:00:00" lane_a snobol4-rungs before_base "$D"     # short, BEFORE the baseline -- history
out="$(ratchet "$D")"; rc=$?
[ "$rc" = 0 ] && printf '%s' "$out" | grep -q 'ARM A: 0 short rows' \
  && ck ok "a short row dated BEFORE the baseline is history and is NOT judged, over a non-empty window (rc=0)" \
  || ck no "a pre-baseline short row was judged (rc=$rc) -- the baseline is decoration, not a bound"
row13 "2026-09-21T18:00:00" lane_a snobol4-rungs after_base "$D"      # short, AFTER the baseline -- the defect
out="$(ratchet "$D")"; rc=$?
[ "$rc" = 1 ] && printf '%s' "$out" | grep -q 'ARM A -- 1 SHORT ROW' \
  && ck ok "ONE short row after the baseline is named and reds the ratchet (rc=1)" \
  || ck no "a post-baseline short row did not fire arm A (rc=$rc): $(printf '%s' "$out" | grep -c 'ARM A')"
printf '%s' "$out" | grep -q 'lane_a' \
  && ck ok "arm A names the offending lane by measurer, not just a count" \
  || ck no "arm A fired without naming lane_a -- a count nobody can act on"

echo "--- ARM 3: ARM B FIRES when a lane declares and then stops ---"
D="$W/b.tsv"; seed "$D"
row14 "2026-09-21T18:00:00" lane_b snobol4-rungs p1 "$D" "SCRIP_GC_STRESS=3"
out="$(ratchet "$D")"; rc=$?
[ "$rc" = 0 ] && ck ok "a lane that declares is green" || ck no "a declaring lane was red (rc=$rc)"
row14 "2026-09-21T18:05:00" lane_b snobol4-rungs p2 "$D" ""           # full width, blank -- the regression
out="$(ratchet "$D")"; rc=$?
[ "$rc" = 1 ] && printf '%s' "$out" | grep -q 'ARM B -- 1 LANE' \
  && ck ok "declaring then going blank is named as a REGRESSION and reds the ratchet (rc=1)" \
  || ck no "a lane stopped declaring and the ratchet stayed green (rc=$rc)"
printf '%s' "$out" | grep -q "declared first at 2026-09-21T18:00:00" \
  && ck ok "arm B quotes the first declaration, so the lane can see what it is being held to" \
  || ck no "arm B named a regression without quoting the declaration it regressed from"

echo "--- ARM 4: SEAM/CONTROL -- absence is NOT regression (the arm that makes this landable) ---"
D="$W/c.tsv"; seed "$D"
row14 "2026-09-21T18:00:00" never_declared snobol4-rungs p1 "$D" ""
row14 "2026-09-21T18:05:00" never_declared snobol4-rungs p2 "$D" ""
out="$(ratchet "$D")"; rc=$?
[ "$rc" = 0 ] \
  && ck ok "a lane that has NEVER declared appending blank config is ACCEPTED -- the ratchet holds no lane to a bar it has not itself set" \
  || ck no "a never-declaring lane was red (rc=$rc) -- this would red nine of ten seats on arrival and the gate would be turned off, not obeyed"

echo "--- ARM 5: FLOOR -- an empty window REFUSES rather than reporting success over nothing ---"
D="$W/d.tsv"; seed "$D"
row14 "2026-09-21T18:00:00" lane_e snobol4-rungs p1 "$D" "shipped"
out="$(ratchet "$D" "2099-01-01T00:00:00")"; rc=$?
[ "$rc" = 2 ] && printf '%s' "$out" | grep -q 'REFUSE(2)' \
  && ck ok "a baseline with no rows after it is rc=2 NOTHING TO MEASURE, never a green" \
  || ck no "an empty window returned rc=$rc -- an instrument reporting success while doing nothing"
printf '%s' "$out" | grep -q 'OVERRIDDEN by --baseline' \
  && ck ok "an overridden baseline says so and does not wear the column commit's provenance" \
  || ck no "an overridden window was printed as though it were the column's own commit"

echo "--- ARM 6: THE BASELINE IS PINNED TO ITS COMMIT and cannot be slid forward ---"
cmt="$(git -C "$ROOT" log -1 --date=format-local:%Y-%m-%dT%H:%M:%S --format=%cd "$TREE" 2>/dev/null)"
if [ -z "$cmt" ]; then
  ck no "commit $TREE is not in this tree, so the baseline names a provenance nothing can check"
else
  cmtu="$(TZ=UTC git -C "$ROOT" log -1 --date=format-local:%Y-%m-%dT%H:%M:%S --format=%cd "$TREE" 2>/dev/null)"
  [ "$cmtu" = "$BASE" ] \
    && ck ok "CONFIG_BASELINE $BASE is $TREE's own commit time in UTC -- the window is pinned to the change it names" \
    || ck no "CONFIG_BASELINE is $BASE but $TREE landed at $cmtu -- a baseline that has drifted from its commit can be slid until the table is green"
fi

echo
if [ "$fails" = 0 ]; then
  echo "GATE PASS [progress_configuration_ratchet]: $checks checks, 0 red -- the live table carries no short rows since the baseline, no lane that has declared what it exercised has stopped, and the ratchet is proven to fire on both halves without redding a lane that never started"
  exit 0
fi
echo "GATE FAIL [progress_configuration_ratchet]: $fails of $checks checks red -- the configuration record can regress without anything noticing"
exit 1
