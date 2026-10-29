#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_pl_rung11_lco.sh -- RUNG 11 LANDING GATE (LCO / last-call optimisation, ARCH-PROLOG-BYRD-BOX-TRANSLATION.md
# sec B.18; task prolog-rung-11-last-call-optimisation-lco). This is the task's own DONE-WHEN, minted as a script rather
# than a one-line bash -c: the sec B.18 depth criterion needs two witness programs and an RSS comparison, which does not
# fit legibly on one line and this project's OWN convention for a multi-part criterion is a dedicated script (see
# test_gate_pl_quad_regs.sh, test_prolog_ladder.sh), not a fragile nested-quoting one-liner.
# THREE PARTS, ALL REQUIRED:
#   (1) bash ../harness/scripts/test_prolog_ladder.sh --only 11   -- PASS 2/2 (m3 + m4) on the ladder's own rung-11 witness.
#   (2) bash ../harness/scripts/test_gate_pl_port_trace.sh --only 11 -- the port-trace instrument (refs owed at landing, ceo 2026-09-03).
#   (3) THE DEPTH CRITERION, IN BOTH MODES -- count(N) to 10^6 under `ulimit -s 512` (vs the default 8MB, so the ceiling
#       this proves is tighter than the ladder witness's own 100000 by construction), and RSS must be FLAT across N, not
#       merely non-crashing: measured at N=1000 and N=1000000 (a 1000x range), the high-N run's max RSS must stay under
#       2x the low-N run's -- a generous bound (true O(1) LCO measures near-identical) that still catches an O(N)
#       regression (a 1000x N range would blow way past 2x if frames were still accumulating).
#       ⛔ THIS PART GRADED m3 ALONE UNTIL 2026-09-03 AND THAT WAS THE HOLE IN THIS GATE (hq_P, found by hq_C's question
#       about the rung-3 trace, not by any board). It ran `"$SCRIP" "$W/hi.pl"` -- no --compile, so mode-3 by default --
#       while parts 1 and 2 both graded m3+m4. So the ONE property this rung exists to establish, that the frame is
#       RELEASED, was proven in one mode and merely assumed in the other; a mode-4 LCO regression would have kept this
#       gate green. The cure is measured, not assumed: m4 passes the same criterion on the same witnesses (5324KB @1e3
#       vs 5176KB @1e6 under ulimit -s 512, flat), so the arm was added because it PASSES honestly, not to paper a red.
#       ⭐ THE SHAPE IS WORTH MORE THAN THE FIX: a multi-part gate whose parts disagree about their own population is the
#       false-green trap wearing a passing suite -- parts 1 and 2 said "m3 + m4" in this very header, and part 3 said
#       nothing, so the header read as if all three covered both. State each part's population IN the part.
# EXIT: 0 all three parts pass · 1 any part fails · 2 UNPROVEN (cannot measure: no scrip binary, a witness would not write).
# AUTHORSHIP: drafted by seat05 while it held this row, saved outside the root and never pushed when the ceo released
# the row (a fleet seat never touches a rung); adopted here unchanged in substance by hq_P, which owns the row, after
# proving it FAILS ONCE -- part 3's RSS bound was checked to reject an O(N) stack by running the high-N witness with a
# deliberately un-flat control. A DONE-WHEN nobody has seen fail is not an acceptance test.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; cd "$ROOT"
SCRIP="${SCRIP:-$ROOT/scrip}"; RT="${RT_DIR:-$ROOT/out}"
[ -x "$SCRIP" ] || { echo "GATE UNPROVEN(2) [pl_rung11_lco]: no scrip binary at $SCRIP"; exit 2; }

echo "--- part 1: ladder --only 11 ---"
LOUT="$(bash "$HERE/test_prolog_ladder.sh" --only 11 2>&1)"; LRC=$?
printf '%s\n' "$LOUT"
echo "$LOUT" | grep -qE '^rung 11 summary: PASS=[1-9][0-9]* FAIL=0 '
P1=$?
# ⭐ PASS=N, not PASS=2 (hq_prolog 2026-10-01): the pattern was pinned to one witness x two modes when rung 11 had one witness;
# rung 11 now carries four (the ladder's own verdict read PASS=8 FAIL=0 while this grep read it red), so the pin reads the
# ladder's FAIL=0 with any non-zero PASS -- the population is the ladder's to declare, never this gate's to count.
[ "$LRC" -ne 2 ] || { echo "GATE UNPROVEN(2) [pl_rung11_lco]: part 1 (ladder) could not measure"; exit 2; }

echo "--- part 2: port-trace --only 11 ---"
bash "$HERE/test_gate_pl_port_trace.sh" --only 11
P2=$?
[ "$P2" -ne 2 ] || { echo "GATE UNPROVEN(2) [pl_rung11_lco]: part 2 (port-trace) could not measure"; exit 2; }

echo "--- part 3: sec B.18 depth criterion (10^6 under ulimit -s 512, RSS flat) -- BOTH MODES ---"
command -v /usr/bin/time >/dev/null 2>&1 || { echo "GATE UNPROVEN(2) [pl_rung11_lco]: /usr/bin/time not found, cannot measure RSS"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
mk_witness() { printf ':- initialization(main).\ncount(N,N) :- !.\ncount(I,N) :- I < N, J is I+1, count(J,N).\nmain :- count(0,%s), write(done), nl.\n' "$1"; }
mk_witness 1000    > "$W/lo.pl"
mk_witness 1000000 > "$W/hi.pl"
# ⛔ THE m4 ARM MUST BUILD BEFORE IT CAN GRADE, AND A BUILD THAT FAILS IS UNPROVEN(2), NEVER A PASS -- an m4 witness that
# will not link is exactly the "skip-as-success" rung the RULES forbid; it cannot be allowed to read as a flat RSS.
m4build() { [ -s "$1" ] && as --64 -o "$1.o" "$1" 2>/dev/null && gcc -no-pie -o "$2" "$1.o" "$RT/libscrip_rt.so" -lm -lstdc++ -Wl,-rpath,"$RT" 2>/dev/null; }
rss_of() { grep 'Maximum resident' "$1" | grep -oE '[0-9]+'; }
P3=0
for M in m3 m4; do
  if [ "$M" = m3 ]; then LO_CMD=("$SCRIP" "$W/lo.pl"); HI_CMD="\"$SCRIP\" \"$W/hi.pl\""
  else
    for n in lo hi; do timeout -k 5 120 "$SCRIP" --compile --out="$W/$n.s" "$W/$n.pl" </dev/null >/dev/null 2>&1; m4build "$W/$n.s" "$W/$n.bin" || { echo "GATE UNPROVEN(2) [pl_rung11_lco]: part 3 m4 witness $n would not compile+link -- cannot measure, and an unbuilt witness is never a pass"; exit 2; }; done
    LO_CMD=("$W/lo.bin"); HI_CMD="\"$W/hi.bin\""
  fi
  LO_OUT="$(/usr/bin/time -v "${LO_CMD[@]}" </dev/null 2>"$W/$M.lo.time")"; LO_RC=$?
  LO_RSS="$(rss_of "$W/$M.lo.time")"
  HI_OUT="$(bash -c "ulimit -s 512; exec /usr/bin/time -v $HI_CMD </dev/null" 2>"$W/$M.hi.time")"; HI_RC=$?
  HI_RSS="$(rss_of "$W/$M.hi.time")"
  echo "$M N=1000:    rc=$LO_RC out=$LO_OUT rss=${LO_RSS:-?}KB"
  echo "$M N=1000000: rc=$HI_RC out=$HI_OUT rss=${HI_RSS:-?}KB (ulimit -s 512)"
  [ -n "$LO_RSS" ] && [ -n "$HI_RSS" ] || { echo "GATE UNPROVEN(2) [pl_rung11_lco]: $M could not read Maximum resident set size from /usr/bin/time -v output"; exit 2; }
  [ "$LO_RC" -eq 0 ] && [ "$HI_RC" -eq 0 ] && [ "$LO_OUT" = "done" ] && [ "$HI_OUT" = "done" ] && [ "$HI_RSS" -lt "$((LO_RSS * 2))" ] || { echo "$M FAILS the depth criterion"; P3=1; }
done

echo "--- summary ---"
echo "part1(ladder)=$([ $P1 -eq 0 ] && echo PASS || echo FAIL) part2(port-trace)=$([ $P2 -eq 0 ] && echo PASS || echo FAIL) part3(depth,rss lo=${LO_RSS}KB hi=${HI_RSS}KB)=$([ $P3 -eq 0 ] && echo PASS || echo FAIL)"
[ $P1 -eq 0 ] && [ $P2 -eq 0 ] && [ $P3 -eq 0 ] && { echo "GATE PASS(0) [pl_rung11_lco]: rung 11 (LCO) DONE-WHEN satisfied"; exit 0; }
echo "GATE FAIL(1) [pl_rung11_lco]: rung 11 (LCO) DONE-WHEN not satisfied"
exit 1
