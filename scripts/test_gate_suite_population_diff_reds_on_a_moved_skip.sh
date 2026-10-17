#!/usr/bin/env bash
# test_gate_suite_population_diff_reds_on_a_moved_skip.sh -- A SKIP THAT MOVES IS A RED, IN EITHER DIRECTION
# (coo 2026-09-17, CEO-824; row instruments-a-skip-count-change-between-batches-is-a-red-not-a-silent-population-change,
# minted on the cfo's escalation).
#
# THE DEFECT, MEASURED, AND WHY A GATE RATHER THAN A HABIT.  The SNOBOL4 rungs read m4_pass=1970 m4_skip=0 at SCRIP
# ad0f85fae and m4_pass=1967 m4_skip=3 at b12714737, and that landing's own commit said "equal to base program for
# program" while its board wrote SCORE's SnoRungs row on that tree; the three were cured at 0567ad829 and read skip=0 at
# a861648ab.  BOTH the appearance and the disappearance passed unremarked, because every reader compared PASS and a
# SKIP fires no verdict in the ladder -- it is the DENOMINATOR moving, which lowers the pass count exactly like a
# regression and raises it exactly like a cure.
#
# WHAT THIS GRADES: the instrument, not a suite.  It is hermetic and needs no build -- it plants readings and asserts
# the verdicts, so it cannot go quiet when a runner is unavailable.
#   (a) util_suite_population_diff.py --selftest passes, and its arms are COUNTED (>= 13)
#   (b) THE RECORDED PAIR, re-derived here rather than trusted: 0 -> 3 is rc=1, 3 -> 0 is rc=1, identical is rc=0
#   (c) a pass/fail move with the population FIXED is rc=0 -- an instrument that reds on everything measures nothing
#   (d) two families and a shard-vs-full reading each REFUSE rc=2, never a number
# FAIL_ONCE=1 blanks the selftest's proof line before arm (a) asserts, to prove the arm trips.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; cd "$HERE/../../SCRIP" || exit 2
D="$HERE/util_suite_population_diff.py"
refuse(){ echo "⛔ REFUSED-TO-GRADE (rc=2): $*"; exit 2; }
[ -f "$D" ] || refuse "no instrument at $D"
fails=0; checks=0
ck(){ checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }
echo "=== gate: a SKIP or graded-denominator move between two readings of one suite is a red, in either direction ==="

st="$(timeout -k 5 60s python3 "$D" --selftest 2>&1)"; strc=$?
[ "$strc" = 124 ] && refuse "the instrument's selftest timed out"
[ -n "${FAIL_ONCE:-}" ] && st="$(printf '%s\n' "$st" | grep -v '^SELFTEST PASS')"
arms="$(printf '%s\n' "$st" | sed -n 's/^population: \([0-9]*\) selftest arm(s).*/\1/p')"
if printf '%s\n' "$st" | grep -q '^SELFTEST PASS' && [ "$strc" = 0 ] && [ "${arms:-0}" -ge 13 ]; then
  ck ok "(a) the instrument trips on every planted arm -- $arms arms, 0 FAIL"
else
  ck no "(a) the selftest did not pass (rc=$strc, arms=${arms:-none}): $(printf '%s\n' "$st" | grep -m2 '  FAIL  ' | tr '\n' ';')"
fi

W="$(mktemp -d)" || refuse "no temp dir"; trap 'rm -rf "$W"' EXIT
B="SUITE_BOARD family=ALL total=1982 shipped=1982 outside=8 m3_n=1974 m3_pass=1970 m3_fail=3 m3_skip=0 m4_n=1974"
printf '%s m4_pass=1970 m4_fail=3 m4_skip=0 all_pass=1970 all_n=1982\n' "$B" > "$W/base"
printf '%s m4_pass=1967 m4_fail=3 m4_skip=3 all_pass=1967 all_n=1982\n' "$B" > "$W/skipped"
printf '%s m4_pass=1967 m4_fail=6 m4_skip=0 all_pass=1967 all_n=1982\n' "$B" > "$W/regressed"
sed 's/family=ALL/family=OTHER/' "$W/base" > "$W/other"
sed 's/$/ shard=1\/4/' "$W/base" > "$W/shard"
r(){ python3 "$D" "$1" "$2" >"$W/out" 2>&1; echo $?; }
[ "$(r "$W/base" "$W/skipped")" = 1 ] && ck ok "(b1) the recorded ad0f85fae -> b12714737 pair (m4_skip 0 -> 3, pass 1970 -> 1967) reds" \
  || ck no "(b1) the recorded 0 -> 3 pair did not red: $(head -2 "$W/out" | tr '\n' ';')"
[ "$(r "$W/skipped" "$W/base")" = 1 ] && ck ok "(b2) the DISAPPEARANCE (3 -> 0, the 0567ad829 cure) reds too -- a skip that vanishes is as much a population change as one that appears" \
  || ck no "(b2) the 3 -> 0 direction did not red: $(head -2 "$W/out" | tr '\n' ';')"
[ "$(r "$W/base" "$W/base")" = 0 ] && ck ok "(b3) two identical readings are green" \
  || ck no "(b3) two identical readings did not read green: $(head -2 "$W/out" | tr '\n' ';')"
[ "$(r "$W/base" "$W/regressed")" = 0 ] && ck ok "(c) three PASSes becoming three FAILs with the population FIXED is green here and printed as information -- that red is the board's, not this instrument's" \
  || ck no "(c) a pure pass/fail move was convicted as a population change: $(head -2 "$W/out" | tr '\n' ';')"
[ "$(r "$W/base" "$W/other")" = 2 ] && ck ok "(d1) two different families REFUSE rc=2 -- comparing two populations is not a comparison" \
  || ck no "(d1) two families did not refuse: $(head -2 "$W/out" | tr '\n' ';')"
[ "$(r "$W/base" "$W/shard")" = 2 ] && ck ok "(d2) a shard reading against a full board REFUSES rc=2" \
  || ck no "(d2) shard-vs-full did not refuse: $(head -2 "$W/out" | tr '\n' ';')"

# (e) THE REAL PAIR, out of the archive the ceo ruled into existence (CEO-827).  Every arm above plants its readings;
# this one reads what a runner actually printed, because a reconstruction is faithful at best and this row exists
# precisely because nobody could diff the real pair on the morning it was ruled.
# ⛔ THE ARCHIVE IS DATA THE FLEET PRODUCES, NOT A PREREQUISITE OF THIS INSTRUMENT, and the difference was measured
# rather than reasoned: the first cut REFUSED rc=2 when .github/board-lines was absent, and within the hour the cto
# reported this gate redding THEIR preflight -- their .github checkout simply predated the ceo's archive commit.
# A gate that reds a seat for the state of a sibling repo they have not merged is grading the wrong thing. So an
# absent archive is NOT MEASURED, said out loud and named in the population line; the planted arms above still
# prove the instrument, and arm (e) grades a real reading whenever one is on disk.
BL="$HERE/../../.github/board-lines"
if [ ! -d "$BL" ]; then
  ck ok "(e) NOT MEASURED against real readings: no $BL on this root (merge .github, or nobody has archived a board line yet) -- the planted arms above proved the instrument, and this run graded no runner's own output"
  BL=""
fi
pair_found=0
for f in ${BL:+"$BL"/*.tsv}; do
  [ -f "$f" ] || continue
  # any suite archived at two different trees is a real pair; take the first and grade the instrument on it
  read -r suite t1 t2 <<<"$(awk -F'\t' '!/^#/ && NF>=4 { if (seen[$2] != "" && seen[$2] != $1) { print $2, seen[$2], $1; exit } seen[$2]=$1 }' "$f")"
  [ -n "${suite:-}" ] || continue
  out="$(python3 "$D" --archive "$f" --suite "$suite" --from "$t1" --to "$t2" 2>&1)"; rc=$?
  moved="$(printf '%s\n' "$out" | grep -cE '^⛔ (SKIP|DENOMINATOR) MOVED')"
  if { [ "$rc" = 1 ] && [ "$moved" -ge 1 ]; } || { [ "$rc" = 0 ] && [ "$moved" = 0 ]; }; then
    ck ok "(e) the archived pair $suite $t1 -> $t2 in $(basename "$f") grades as a READING (rc=$rc, $moved population field(s) moved)"
  else
    ck no "(e) the archived pair $suite $t1 -> $t2 read rc=$rc with $moved moved field(s) -- the two disagree: $(printf '%s\n' "$out" | head -2 | tr '\n' ';')"
  fi
  pair_found=1
  break
done
[ "$pair_found" = 1 ] || [ -z "$BL" ] || ck ok "(e) the archive exists but holds no suite at two trees yet -- NOT MEASURED against real readings this run, and said so rather than counted as coverage"

# (f) THE CALLER (CEO-827 (3)): the base-vs-head control arm of a shared-node landing is the only place two readings
# of one suite exist at once, and the diff's verdict is part of that arm's verdict. The wrapper ENFORCES the entry
# lines rather than asking for them, because a 40-line sample is where three skips hide in a 1982-entry board.
C="$HERE/control_arm_population.sh"
if [ ! -x "$C" ]; then
  ck no "(f) no caller at $C -- the instrument would be run by nobody but this gate"
else
  E='  SKIP m4 eval_2: scrip --compile failed [fp=0 rc=1]'
  printf '%s\n  FAIL m4 x: bytes differ [fp=a rc=0]\n' "$(cat "$W/base")" > "$W/c_base"
  printf '%s\n%s\n' "$(cat "$W/skipped")" "$E" > "$W/c_head"
  cp "$W/base" "$W/c_bare"; cp "$W/skipped" "$W/c_bare2"
  bash "$C" "$W/c_base" "$W/c_head" > "$W/c1" 2>&1; c1=$?
  bash "$C" "$W/c_base" "$W/c_base" > "$W/c2" 2>&1; c2=$?
  bash "$C" "$W/c_bare" "$W/c_bare2" > "$W/c3" 2>&1; c3=$?
  bash "$C" "$W/c_base" > "$W/c4" 2>&1; c4=$?
  { [ "$c1" = 1 ] && grep -q 'm4 SKIP APPEARED (1): eval_2' "$W/c1" && grep -q 'CONTROL-ARM POPULATION RED' "$W/c1"; } \
    && ck ok "(f1) the control arm reds on a moved skip and NAMES the entry (eval_2), and says the verdict is part of the arm's verdict" \
    || ck no "(f1) the control arm did not red-and-name on a moved skip (rc=$c1): $(head -2 "$W/c1" | tr '\n' ';')"
  { [ "$c2" = 0 ] && grep -q 'CONTROL-ARM POPULATION PASS' "$W/c2"; } \
    && ck ok "(f2) an identical pair passes and says the pass counts are comparable" \
    || ck no "(f2) an identical pair did not pass (rc=$c2): $(head -2 "$W/c2" | tr '\n' ';')"
  { [ "$c3" = 2 ] && grep -q 'SUITE_LIST_ALL=1' "$W/c3"; } \
    && ck ok "(f3) two readings with NO per-entry lines REFUSE rc=2 naming SUITE_LIST_ALL -- a moved skip that can never be named is not a verdict" \
    || ck no "(f3) bare board lines did not refuse for the entry-line reason (rc=$c3): $(head -2 "$W/c3" | tr '\n' ';')"
  [ "$c4" = 2 ] && ck ok "(f4) one argument REFUSES rc=2 -- a control arm has two sides" \
    || ck no "(f4) a one-sided call did not refuse (rc=$c4)"
fi

echo "population: $checks arm(s) graded, $fails FAIL; the instrument's own selftest carried ${arms:-0} more"
if [ "$fails" -eq 0 ]; then
  echo "GATE PASS [suite_population_diff_reds_on_a_moved_skip]: $checks of $checks arms hold"; exit 0
fi
echo "⛔ GATE RED [suite_population_diff_reds_on_a_moved_skip]: $fails of $checks arms FAIL"; exit 1
