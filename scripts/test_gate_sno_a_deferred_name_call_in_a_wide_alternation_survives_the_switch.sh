#!/usr/bin/env bash
export S4E_ONE_RUNNER_FIXTURE="gate arm ${0##*/}: a runner invoked as an instrument fixture, not a board (CEO-523)"
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_sno_a_deferred_name_call_in_a_wide_alternation_survives_the_switch.sh -- THE PORTER CRASH UNDER --stlimit (ceo, 2026-09-24,
# CEO-1248; found by the SnoRungs pass after the by-name landing f8c25ae0e: demo_porter and benchmark_porter CRASH signal 11 in both modes).
# THE WITNESS is porter's step-4 pattern with nine arms (fixtures/sno_switch/porter_step4_nine_arms.sno, the program reduced by
# ablation: the eight arms tried and failed before the winning '-ement' arm, then that arm's deferred guard *g_m_gt_1() and its
# conditional assignment through the deferred call *s_empty()), on the ONE input word "abatement". Facts measured on f8c25ae0e:
#   - it runs correctly WITHOUT the switch (rc 0, "abat" = SPITBOL) and SIGSEGVs WITH it (--stlimit or SCRIP_SNO_STMTKW=1), m3 and m4;
#   - the shape is arm-count dependent: the same arm alone passes, and the nine arms pass when the eight keep their '$ stem';
#   - it is not the collector (0 collections at a 512 MB arena, still SIGSEGV) and not the arena;
#   - the fault is a jump to 0x300000002 with r11 = the RPOS(0) box, i.e. inside the match-end path that performs the recorded
#     conditional assignment and evaluates its deferred-call target from C (rt_dcap_pump -> rt_dcap_call_prepare);
#   - it began at 2a81a02db (the switch), where the graders started arming the statement hooks for every program.
# EXIT 0 both modes print the oracle's line; 1 a mode crashes or differs (the red of 2026-09-24); 2 REFUSED (fixture or binary missing).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
F="$HERE/fixtures/sno_switch/porter_step4_nine_arms"
[ -f "$F.sno" ] && [ -f "$F.in" ] && [ -f "$F.ref" ] || { echo "REFUSED(2): fixture $F.{sno,in,ref} missing"; exit 2; }
[ -x "$ROOT/scrip" ] || { echo "REFUSED(2): $ROOT/scrip not built"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
red=0
( cd "$W" && SCRIP_SNO_STMTKW=1 timeout -k 5 30 "$ROOT/scrip" --stlimit "$F.sno" < "$F.in" > m3.out 2> m3.err ); rc=$?
if [ "$rc" -ne 0 ] || ! cmp -s "$W/m3.out" "$F.ref"; then echo "RED m3: rc=$rc out=$(head -c 40 "$W/m3.out" | tr '\n' '|') err=$(tail -c 120 "$W/m3.err" | tr '\n' ' ')"; red=1; else echo "ok  m3: rc=0 output = ref"; fi
if ( cd "$W" && SCRIP_SNO_STMTKW=1 "$ROOT/scrip" --compile --stlimit -o "$W/w.s" "$F.sno" < /dev/null > /dev/null 2>&1 && gcc "$W/w.s" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$W/w.bin" 2>/dev/null ); then
    ( cd "$W" && SCRIP_SNO_STMTKW=1 timeout -k 5 30 ./w.bin < "$F.in" > m4.out 2> m4.err ); rc=$?
    if [ "$rc" -ne 0 ] || ! cmp -s "$W/m4.out" "$F.ref"; then echo "RED m4: rc=$rc out=$(head -c 40 "$W/m4.out" | tr '\n' '|') err=$(tail -c 120 "$W/m4.err" | tr '\n' ' ')"; red=1; else echo "ok  m4: rc=0 output = ref"; fi
else echo "RED m4: the witness did not compile or link"; red=1; fi
[ "$red" -eq 0 ] && { echo "GATE OK: the deferred-name call in a nine-arm alternation runs to the oracle's answer under the switch in both modes"; exit 0; }
echo "GATE FAILED: porter's step-4 shape crashes or diverges under --stlimit (CEO-1248 row snobol4-the-statement-switch-crashes-a-deferred-name-call-in-a-wide-alternation)"; exit 1
