#!/usr/bin/env bash
export S4E_MINT_NO_CRITERION="gate fixture: the row under test exercises the bus, not work (CEO-1386)"
# test_gate_sno_byname_goto_call_args_after_failure.sh -- A BY-NAME GOTO CALL KEEPS ITS WANT-NAME ACROSS THE SLIM FAST PATH.
#
# WHAT THIS IS: a SNOBOL4 goto whose target is a FUNCTION CALL is invoked BY NAME -- the callee returns a NAME
# via `:(NRETURN)` and the goto transfers to it. This gate pins the case where that call CARRIES ARGUMENTS and
# is taken from a statement whose subject FAILED. Before the cure every b-arm below died
# `ERROR 021 -- function called by name returned a value`, which is a true sentence about the SYMPTOM and names
# the CALLEE. The callee was innocent: its own emitted prologue (bb_define.cpp:93) saves rt_g_want_name into its
# frame and restores it on exit, correctly. The CALLER destroyed the flag first -- rt_proc_call_open_slim
# (src/runtime/rt/rt.c) read it into a local `wn`, cleared the global, and never used `wn` again. NINE sites in
# that file open with that identical line; the other EIGHT hand `wn` to rt_proc_call_prologue(...) /
# rt_proc_call_prologue_lex(..., wn), which stores it. The ninth dropped it, so the callee dutifully saved 0.
#
# ⛔ THE DISCRIMINATOR IS TWO-FACTOR AND NEITHER FACTOR ALONE DOES IT, WHICH IS WHY THE c-ARMS ARE NOT DECORATION:
# c1 (same failed statement, ZERO arguments) and c2 (same one-argument call, statement SUCCEEDS) were GREEN
# BEFORE the cure and must stay green after it. A gate carrying only the b-arms would pass just as happily if a
# future change made every by-name goto call take the non-slim path -- the c-arms are what force the two paths
# to stay distinguishable. Five other axes were ablated and exonerated during the diagnosis and are deliberately
# NOT pinned here: conditional vs unconditional goto arm, one-armed vs two-armed, multiple call sites (the gimpel
# POKEV witness has EIGHT and pruning to one kept it red), callee locals, and depth-3 nesting.
#
# ⭐ EVERY TARGET HERE IS A PLAIN LABEL. That is deliberate. The special-transfer targets (RETURN/FRETURN/NRETURN)
# are the sibling gate test_gate_sno_goto_special_transfer_target.sh.
#
# ✅ THE b-ARMS GRADE BOTH MODES (widened 2026-09-06 by hq_S, 8 graded arms -> 12). They graded m3 alone until
# then, and the reason was honest at the time: in m4 all four b-arms SEGV'd, identically with the want-name cure
# ON and OFF, so that crash was a SECOND defect one layer down and grading it here would have held this gate
# permanently red for something it does not test. That second defect is CURED ON MAIN by 6f3852fd1 ("AIS: the
# signature arm could never fire -- bcps_sig_disp parsed a spelling FRQB never emits"): rcx reached the callee
# holding a code label where the CALL SIGNATURE BLOCK belongs, so the DEFINE box's parameter swap read
# instruction bytes as a frame offset (+0x18) and walked off the map.
#
# ⛔ THE m4 ARMS ARE NON-VACUOUS, AND THAT IS MEASURED RATHER THAN ASSERTED -- a widened arm that was green all
# along would pin nothing while looking like coverage. `git bisect` over the 108 commits 1d4dd575a..e68e35fd4,
# with the b1 m4 arm as the predicate, names 6f3852fd1 as the flip: every ancestor RED (rc=139), every
# descendant GREEN. The abandoned branch hq_S/staged-call-signature-rcx (retired as tag
# retired/hq_S-staged-call-signature-rcx-2026-09-06) is RED on that same predicate.
#
# ⛔ TWO EARLIER READINGS OF THE m4 HALF WERE WRONG AND ARE RECORDED HERE BECAUSE THIS HEADER IS WHERE THE NEXT
# READER LOOKS. (1) An unseated NRETURN floater pair, inferred from a gdb frame #1 of 0x0 -- REFUTED by
# killswitch A/B off ONE build: SCRIP_SLIM_PAIR=1 and =0 are BOTH rc=139, with the arms provably differing at 90
# vs 87 pushes, so the pair is not reachable as the cause. (2) A MISSING signature block at the staged emitter
# arm, cured by emitting one -- that branch turned the SEGV into `ERROR 021` and was never a cure. The arm does
# emit a signature; bcps_sig_disp simply could not parse the '$' spelling of the frame marker, which is the
# defect 6f3852fd1 actually fixed. Two plausible mechanisms, both consistent with the crash, both wrong.
#
# ⛔ THE SCRIP_SLIM_WANTNAME NON-VACUITY RECIPE THIS HEADER USED TO CARRY IS DEAD, AND SAYING SO IS THE POINT.
# It read: "SCRIP_SLIM_WANTNAME=0 restores the pre-cure clear, and every b-arm is RED under it." Re-measured
# 2026-09-06 on main: every arm is GREEN under it, in both modes. The killswitch still exists
# (src/runtime/rt/rt.c, inside rt_proc_call_open_slim) -- these witnesses no longer REACH it. b1's emitted asm
# carries ZERO `rt_proc_call_open_slim` sites and NINE `lea rcx, <sig>`, because 6f3852fd1 made the signature
# arm fire where the slim arm used to. So the b-arms today pin the SIGNATURE arm, not the slim want-name clear.
# ⭐ A killswitch recipe that has gone quietly unreachable is worse than no recipe: it prints exactly like proof
# of non-vacuity while proving nothing. Whoever next needs a want-name control must mint a witness that still
# reaches the slim arm, and check `grep -c rt_proc_call_open_slim` on its emitted asm BEFORE trusting the A/B.
#
# ⭐ ONE INFERENCE CORRECTED, AND IT IS THE PART WORTH THE PARAGRAPH: the zero-arg c1 arm being GREEN was NOT
# evidence that rcx was intact. c1 entered with the same garbage in rcx and never looked at it, because only a
# callee WITH FORMALS runs the swap loop that dereferences it. c1 remains a correct control for this gate's
# want-name class; it was never a control for register state, and reading it as one is how the mechanism got
# mis-minted the first time.
#
# EXIT: 0 all arms match SPITBOL. 1 an arm regressed. 2 UNPROVEN (no built scrip / no oracle).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; cd "$ROOT"
. "$HERE/lib_gate.sh" 2>/dev/null || { echo "REFUSING: cannot load lib_gate.sh -- the ONE gate-honesty authority." >&2; exit 3; }
gate_parse_args "$@"
SCRIP="${SCRIP:-$ROOT/scrip}"; RT="${RT_DIR:-$ROOT/out}"
gate_require_exec "$SCRIP" "scrip binary"
gate_require "$RT/libscrip_rt.so" "runtime library"
gate_require_fresh "$ROOT" src "$SCRIP" "$RT/libscrip_rt.so"
T="$(mktemp -d)" || exit 2; trap 'rm -rf "$T"' EXIT
emit() { printf "        DEFINE('G(L)')\n        DEFINE('G2(L,M)')\n        DEFINE('H()')                   :(MAIN)\nG       G   =  .TGT                     :(NRETURN)\nG2      G2  =  .TGT                     :(NRETURN)\nH       H   =  .TGT                     :(NRETURN)\nMAIN    OUTPUT  =  'before'\n        X  =  'q'\n        %s                              %s\n        OUTPUT  =  'not here'\nTGT     OUTPUT  =  'at TGT'\nEND\n" "$2" "$3" > "$T/$1.sno"; }
emit b1 "'a' 'b'"            ':F(G(1))'
emit b2 "'a' 'b'"            ':F(G(X))'
emit b3 "'a' 'b'"            ':F(G2(1,2))'
emit b4 "IDENT('a','b')"     ':F(G(1))'
emit c1 "'a' 'b'"            ':F(H())'
emit c2 "'a' 'a'"            ':S(G(1))'
ORACLE=/home/resources/x64/bin/sbl
[ -x "$ORACLE" ] || { echo "UNPROVEN(2): correctness oracle absent at $ORACLE -- this gate grades against SPITBOL, never against SCRIP's own output"; exit 2; }
bad=0
for a in b1 b2 b3 b4 c1 c2; do
    want="$("$ORACLE" -bf "$T/$a.sno" < /dev/null 2>&1 | sed -n '/^before$/,$p' | tr '\n' '/')"
    [ -n "$want" ] || { echo "  UNPROVEN $a -- oracle produced no graded output; refusing to grade SCRIP against nothing"; exit 2; }
    modes="m3 m4"
    for m in $modes; do
        if [ "$m" = m3 ]; then
            got="$(timeout -k 5 20s "$SCRIP" "$T/$a.sno" < /dev/null 2>&1 | tr '\n' '/')"
        else
            "$SCRIP" --compile -o "$T/$a.s" "$T/$a.sno" < /dev/null >/dev/null 2>&1
            gcc -no-pie "$T/$a.s" -o "$T/$a.x" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm -lpthread >/dev/null 2>&1 || { echo "  RED  $a $m -- link failed"; bad=1; continue; }
            got="$(timeout -k 5 20s "$T/$a.x" < /dev/null 2>&1 | tr '\n' '/')"
        fi
        if [ "$got" = "$want" ]; then echo "  ok   $a $m -- matches SPITBOL [$want]"
        else echo "  RED  $a $m -- got [$got] want [$want]"; bad=1; fi
    done
done
if [ "$bad" -ne 0 ]; then echo "GATE RED(1) [sno-byname-goto-call-args-after-failure]: a by-name goto call with arguments taken from a failed statement lost its want-name"; exit 1; fi
echo "GATE GREEN(0) [sno-byname-goto-call-args-after-failure]: by-name goto calls with literal/variable/two-arg payloads survive a by-name goto after a failed subject in BOTH modes (12 graded arms; the m4 half was the AIS signature-arm defect, cured by 6f3852fd1 and bisect-proven to flip there), and both zero-arg and success-arm controls hold in BOTH modes"
