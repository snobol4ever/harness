#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# CN-13 CONST-GRAPH GATE -- the MARGINAL EMITTED-ASM COST OF ONE MORE USE SITE of a declared constant pattern.
#
# ⛔ WHY THIS GATE EXISTS BEFORE THE CODE DOES.  CN-13's whole claim is a COUNT IN THE EMITTED ASM ("one graph +
# N thin sites instead of N copies"), and this project has twice paid for a rung whose success metric was an asm
# count graded by behaviour gates only: s146/s147's "KW-2/KW-3" were quietly redefined to index-plus-call and
# marked DONE while 0/5 keywords were actually direct, and five sessions of behaviour-green scaffolding went by
# before s165 counted the instructions and found it.  The transferable lesson (s165, GOAL-SNOBOL4-100): a
# directive whose success metric is a count in the emitted asm needs a gate that COUNTS THE EMITTED ASM.
#
# WHAT IT MEASURES.  A declared constant pattern used at N sites, mode-4 .s line count, N=1 vs N=25.  Scaling is
# exactly linear (measured s166: 136 lines/site across N=1,2,12,24), so (lines25-lines1)/24 IS the cost of one
# whole extra COPY of the graph -- the duplication CN-13 deletes.  It is a RATCHET: it fails if the marginal cost
# grows past the watermark, so the number can only go down.  When CN-13 lands, drop CG_WATERMARK to the new
# measurement; the CN-13 TARGET line below is the number that says the rung actually happened.
#
# Behaviour is graded too, in BOTH modes and BOTH killswitch arms -- an asm count alone can be made green by a
# compiler that emits less and answers wrong.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: sibling-root convention, no env needed
set -u
SCRIP="${SCRIP:-$S4E/SCRIP/scrip}"; RT="${RT:-$S4E/SCRIP/out}"
CG_WATERMARK="${CG_WATERMARK:-136}"   # s166 measurement at SCRIP e06cee8b (CN-12 substitution road).  CN-13 TARGET: < 20.
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
chk() { if [ "$1" = 0 ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "  FAIL: $2"; fi; }
gen() { n="$1"; out="$2"; { printf '\t&USER_DECLARED_CONSTANTS = 1\n\t&Num = SPAN("0123456789")\n'; i=1; while [ "$i" -le "$n" ]; do printf '\tT%d = "x123y" ; T%d ?  &Num  :F(NO)\n' "$i" "$i"; i=$((i+1)); done; printf '\tOUTPUT = "matched"\nNO\tOUTPUT = "done"\nEND\n'; } > "$out"; }
gen 1  "$T/n1.sno"; gen 25 "$T/n25.sno"
for w in n1 n25; do "$SCRIP" --compile "$T/$w.sno" -o "$T/$w.s" < /dev/null > /dev/null 2>&1; chk $? "mode-4 compile $w"; done
l1=$(wc -l < "$T/n1.s"); l25=$(wc -l < "$T/n25.s"); marg=$(( (l25 - l1) / 24 ))
echo "CONST-GRAPH: 1 site=${l1} lines  25 sites=${l25} lines  MARGINAL=${marg} lines/site  (watermark ${CG_WATERMARK}, CN-13 target < 20)"
[ "$marg" -le "$CG_WATERMARK" ]; chk $? "marginal cost ${marg} exceeds watermark ${CG_WATERMARK} -- a use site got MORE expensive"
if [ "$marg" -lt 20 ]; then echo "  ⭐ CN-13 TARGET MET: the constant is LINKED, not copied."; fi
for w in n1 n25; do
  gcc -no-pie "$T/$w.s" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm -lpthread -o "$T/$w.bin" 2>/dev/null; chk $? "link $w"
  for arm in 1 0; do
    SCRIP_CONST_STATIC=$arm timeout -k 5 20 "$SCRIP" --run "$T/$w.sno" < /dev/null > "$T/$w.m3.$arm" 2>&1; chk $? "m3 run $w CONST_STATIC=$arm"
    grep -q "^matched$" "$T/$w.m3.$arm"; chk $? "m3 $w CONST_STATIC=$arm matched"
  done
  timeout -k 5 20 "$T/$w.bin" < /dev/null > "$T/$w.m4" 2>&1; grep -q "^matched$" "$T/$w.m4"; chk $? "m4 $w matched"
  diff -q "$T/$w.m3.1" "$T/$w.m4" > /dev/null 2>&1; chk $? "$w m3 == m4 (MODE34-IDENTICAL)"
  diff -q "$T/$w.m3.1" "$T/$w.m3.0" > /dev/null 2>&1; chk $? "$w killswitch arms agree on OUTPUT"
done
echo "CONST-GRAPH GATE: PASS=$pass FAIL=$fail"
[ "$fail" = 0 ] && echo "GATE GREEN" || echo "GATE RED"
# ⭐ V2-5 GATE HONESTY: this line used to be a bare "exit 0" -- the gate printed GATE RED and passed anyway.
. "$(dirname "$0")/lib_gate.sh"
gate_floor "$((pass + fail))" 1 "const-graph checks"
gate_verdict "$fail" "const-graph check(s) failed"
