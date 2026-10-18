#!/usr/bin/env bash
# test_gate_icn_suspend_record_stack_alignment.sh -- an Icon procedure that SUSPENDS a record must behave
# exactly as the icont oracle does, in both modes.
#
# THE CLASS (hq_I 2026-09-06, row icon-ipl-parse-icn-coexpression-sigsegv-both-modes): the Icon generator
# call path pushes an ODD 8-byte word and never pads it, so the callee body is entered at rsp 0-mod-16 and
# every runtime helper it calls is entered 8 bytes off the SysV ABI's required alignment.
# bb_call_proc_staged.cpp emits, at every call_proc_staged site: a PL-CALL-ALIGN pad + the L(7) push (16
# bytes, parity-neutral, added by an earlier cure of THIS SAME CLASS for Prolog -- witness
# prolog-call-n-user-predicate-segfault), then under icn_gen_regime() ONLY a lone "N-2 STEP 3 REGION
# HAND-OFF" push (8 bytes, parity-FLIPPING), then the wire pair (16 bytes, parity-neutral), then jmp.
#
# ⛔ THE DEFECT IS LATENT, WHICH IS WHY IT READS AS A RECORD BUG AND IS NOT ONE. A misaligned rsp costs
# nothing until some callee executes an ALIGNED SSE store. Suspending a list or a string reaches no such
# callee and passes; suspending a RECORD reaches dat_construct -> rt_fire_buildplan_tweak, whose
# snprintf(proc, 256, "%s__TWEAK", ...) compiles to movaps and faults. MEASURED, not inferred: the faulting
# instruction is `movaps %xmm0,-0xc0(%rbp)` with si_code=SI_KERNEL(128) and si_addr=0x0, the signature of a
# misaligned SSE store rather than a bad pointer; entry rsp at rt_call_arr_bl is 0-mod-16 on the suspend
# path and the ABI-correct 8-mod-16 on the return path.
#
# ⛔ THE CONTROLS ARE THE POINT OF THIS GATE. icn_suspend_list_control and icn_coexpr_int_control are GREEN
# PRE-CURE and were verified green before being called controls (hq_B's standing condition, and hq_I's own
# correction from 2026-09-05: an arm that is red before the cure is a witness with a misleading name). They
# are equally misaligned -- they just never reach an SSE spill. So a "cure" that only makes records avoid
# rt_fire_buildplan_tweak would turn this gate green while leaving every other Icon generator call one
# unlucky callee away from the same crash. icn_return_record_control exonerates record construction itself.
#
# ⛔ A CURE DIRECTION ALREADY MEASURED WRONG, recorded so nobody re-walks it: padding the region-handoff push
# in place (sub rsp,8 between the lea and the push, keeping [entry rsp+16]) DOES fix every record witness and
# DOES restore 8-mod-16 -- and it breaks the co-expression path, which SIGSEGVs in scrip_coswitch ->
# rt_scan_state_capture -> malloc. Something in the region/wire contract depends on that exact distance.
# The omega-landing counterpart (16 -> 24) was measured to change nothing either way. Reverted whole; the
# tree this gate lands on is byte-identical to the pre-experiment tree.
#
# THE FIX BELONGS TO A SHARED NODE. bb_call_proc_staged.cpp is lowered to by Prolog, Icon and SNOBOL4, so a
# cure is authored by the lane whose language exposed it and CO-SIGNED by hq_U (RULES.md § shared node).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
S4E="$(cd "$ROOT/.." && pwd)"
GATE_NAME=icn_suspend_record_stack_alignment
. "$HERE/lib_oracle_flags.sh" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: lib_oracle_flags.sh unavailable"; exit 2; }
. "$HERE/lib_gate.sh" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: lib_gate.sh unavailable"; exit 2; }
gate_parse_args "$@"
ICONT="$(icont_bin)" || exit 2
gate_require_exec "$ROOT/scrip" "the scrip binary"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"

W="$S4E/corpus/tests/icon"
T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT

PROGS="icn_suspend_record_witness icn_suspend_record_field_witness icn_suspend_record_local_witness icn_suspend_record_multi_witness icn_suspend_record_coexpr_witness icn_suspend_list_control icn_return_record_control icn_coexpr_int_control"
CONTROLS=" icn_suspend_list_control icn_return_record_control icn_coexpr_int_control "

red=0; examined=0
for p in $PROGS; do
    # ⛔ THE FIXTURE LIVES IN THE ICON RUNGS, NOT BESIDE IT (coo 2026-09-25, on the ceo's triage of hq_icon's report): corpus
    # a80ca7617 (09-10) absorbed these witnesses into tests/icon/ALL.icn after measuring each three ways, and deleted the loose
    # pairs; the rungs renamed each entry by feature (list_alt_elem1_control is procedure_every_elemgen_replace_11), and
    # ALL.csv keeps the old name in its origin column. So the gate refused "missing committed fixture" on every run since. It
    # now extracts each entry BY ORIGIN through the harness (the durable provenance key), byte-identical to the loose pair.
    mkdir -p "$T/fx"; src="$T/fx/$p.icn"; ref="$T/fx/$p.ref"
    python3 "$HERE/corpus_suite_harness.py" extract "$W/ALL.icn" "$W/ALL.ref" "" "$src" --origin "$p" --out-ref "$ref" >"$T/fx/$p.extract.out" 2>&1
    if [ ! -s "$src" ] || [ ! -f "$ref" ]; then
        echo "GATE UNPROVEN(2) [$GATE_NAME]: $p is not extractable by origin from $W/ALL.icn ($(tail -1 "$T/fx/$p.extract.out" | cut -c1-120))"; gate_stamp; exit 2
    fi
    if ( cd "$T" && timeout -k 5 30s "$ICONT" -s -o "$p.oracle" "$src" >/dev/null 2>&1 ) && [ -x "$T/$p.oracle" ]; then
        ( cd "$T" && timeout -k 5 10s "./$p.oracle" </dev/null >"$T/$p.oref" 2>&1 )
        if ! cmp -s "$T/$p.oref" "$ref"; then
            echo "RED  $p: committed ref disagrees with the live icont oracle -- re-cut it (oracle/ref drift, not this class)"
            red=$((red+1)); examined=$((examined+1)); continue
        fi
    else
        echo "GATE UNPROVEN(2) [$GATE_NAME]: icont could not build $p, so its ref cannot be re-anchored"; gate_stamp; exit 2
    fi
    is_control=0
    case "$CONTROLS" in *" $p "*) is_control=1;; esac
    ( cd "$T" && timeout -k 5 10s "$ROOT/scrip" "$src" </dev/null >"$T/$p.m3" 2>&1 )
    ok3=0; cmp -s "$T/$p.m3" "$ref" && ok3=1
    ok4=0
    if ( cd "$T" && timeout -k 5 30s "$ROOT/scrip" --compile -o "$p.s" "$src" </dev/null >/dev/null 2>&1 ) \
       && ( cd "$T" && gcc -no-pie "$p.s" -o "$p.bin" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" >/dev/null 2>&1 ); then
        ( cd "$T" && timeout -k 5 10s "./$p.bin" </dev/null >"$T/$p.m4" 2>&1 )
        cmp -s "$T/$p.m4" "$ref" && ok4=1
    fi
    examined=$((examined+1))
    tag="witness"; [ "$is_control" = 1 ] && tag="control"
    if [ "$ok3" = 1 ] && [ "$ok4" = 1 ]; then
        echo "PASS $p [$tag]: m3 and m4 both byte-match the icont-cut ref"
    else
        echo "RED  $p [$tag]: m3=$ok3/1 m4=$ok4/1 byte-match the icont-cut ref"
        [ "$ok3" = 0 ] && { echo "     m3 got: $(tr '\n' ' ' < "$T/$p.m3" 2>/dev/null)"; echo "     want:   $(tr '\n' ' ' < "$ref")"; }
        red=$((red+1))
    fi
done
gate_floor "$examined" 8 "witness/control programs"
gate_verdict "$red" "program(s) diverging from the icont oracle in either mode"
