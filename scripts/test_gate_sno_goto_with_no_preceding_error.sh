#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_sno_goto_with_no_preceding_error.sh -- row
# snobol4-an-unresolved-return-label-dumps-core-and-three-dead-pins-were-hiding-it (hq_S 2026-09-11).
#
# A goto to ABORT, CONTINUE or SCONTINUE reached with NO preceding error is three DISTINCT diagnostics in
# the one oracle, measured live against /home/resources/x64/bin/sbl -bf on 2026-09-11 (hq_S):
#     :(ABORT)     -> ERROR 036 -- goto abort with no preceding error
#     :(CONTINUE)  -> ERROR 037 -- goto continue with no preceding error
#     :(SCONTINUE) -> ERROR 321 -- goto scontinue with no preceding error
# SCRIP answered ALL THREE with "ERROR 035 -- Not in a SETEXIT handler", which is CSNOBOL4's error 35
# text reached through core_err_msgs[] -- dialect residue, since core_errnum_csnobol4() has been hard 0
# since the compat switch was retired (CEO-388/390) and every other number SCRIP publishes is SPITBOL's.
#
# ⭐ The three codes are the whole point of the gate: one collapsed answer looks like a working diagnostic
# and passes any arm that only asks "did it error", so the arms below assert the NUMBER and the TEXT.
# ⛔ This grades the NO-PRECEDING-ERROR path only. SCONTINUE reached INSIDE a live SETEXIT handler is a
# separate and unsettled question -- sbl raises 331 there and loops the handler to &ERRLIMIT while CSNOBOL4
# resumes the interrupted statement; SCRIP follows CSNOBOL4. Named in the csnobol4 setexit4 measurement,
# deliberately NOT graded here.
# ⛔ The live-handler control arm ends :(CONTINUE) ON PURPOSE. Ending it :(RETURN) SIGSEGVs in BOTH modes --
# rt_chain_enter jumps into the handler without leaving a return address, so the level-zero `ret` that
# rt_outer_call's pushed rt_kw_return_level_zero sentinel would have caught lands on a saved register value
# instead (rip in a non-executable page, caller 0x0). Measured hq_S 2026-09-11 and reproduced at 01eb996ca, so
# it predates this gate; it is row snobol4-a-return-inside-a-setexit-handler-at-level-zero-jumps-to-a-non-code
# -site and is NOT this gate's subject -- an arm that reds on another row's bug teaches runners to stop calling it.
# ⛔ The live-handler witness divides by a VARIABLE holding 0 ON PURPOSE: sbl -bf folds 1 / 0 when the statement compiles and
# refuses the program with ERROR 014 before SETEXIT ever runs (measured by the cfo 2026-10-03, rc=231, no 'caught'), and SCRIP does
# the same since its compile-time pre-evaluation (ddf5c1a60) -- a literal divisor never reaches a handler in either. With Z = 0 the
# division is a run-time error: 'caught 14' then 'tail' in sbl and in both modes.
# Exit: 0 = every arm as specified; 1 = a divergence; 2 = cannot measure.
set -uo pipefail
SCRIP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../SCRIP" && pwd)"
SCRIP_BIN="${SCRIP_BIN:-$SCRIP_DIR/scrip}"
[ -x "$SCRIP_BIN" ] || { echo "⛔ GATE REFUSES: no built ./scrip at $SCRIP_BIN -- this gate cannot measure"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
printf "\tOUTPUT = 'a'\t:(ABORT)\nEND\n"     > "$W/g_abort.sno"
printf "\tOUTPUT = 'a'\t:(CONTINUE)\nEND\n"  > "$W/g_continue.sno"
printf "\tOUTPUT = 'a'\t:(SCONTINUE)\nEND\n" > "$W/g_scontinue.sno"
printf "\tSETEXIT(.f)\n\t&ERRLIMIT = 4\n\tZ = 0\n\tX = 1 / Z\n\tOUTPUT = 'tail'\t:(END)\nf\tOUTPUT = 'caught ' &ERRTYPE\t:(CONTINUE)\nEND\n" > "$W/g_handler.sno"
run_mode() {   # $1 = program, $2 = 3|4 -- prints the program's own stdout+stderr
    if [ "$2" = "3" ]; then timeout -k 5 15 "$SCRIP_BIN" "$1" < /dev/null 2>&1; return 0; fi
    timeout -k 5 15 "$SCRIP_BIN" --compile -o "$W/m4.s" "$1" < /dev/null > /dev/null 2>&1 || { echo "<compile-failed>"; return 0; }
    gcc -m64 -no-pie "$W/m4.s" -Wl,-rpath,"$SCRIP_DIR/out" -L"$SCRIP_DIR/out" -lscrip_rt -lm -o "$W/m4.bin" 2>/dev/null || { echo "<link-failed>"; return 0; }
    timeout -k 5 15 "$W/m4.bin" < /dev/null 2>&1
}
FAIL=0; TOTAL=0
check() {   # $1 = program stem, $2 = extended regex the output MUST match, $3 = english
    local stem="$1" want="$2" what="$3" m out
    for m in 3 4; do
        TOTAL=$((TOTAL + 1)); out="$(run_mode "$W/$stem.sno" "$m")"
        if printf '%s' "$out" | grep -qE "$want"; then printf '  ok   m%s %-13s %s\n' "$m" "$stem" "$what"
        else FAIL=$((FAIL + 1)); printf '  FAIL m%s %-13s %s -- got: %s\n' "$m" "$stem" "$what" "$(printf '%s' "$out" | head -2 | tr '\n' '|')"; fi
    done
}
reject() {  # $1 = program stem, $2 = extended regex that must NOT appear, $3 = english
    local stem="$1" bad="$2" what="$3" m out
    for m in 3 4; do
        TOTAL=$((TOTAL + 1)); out="$(run_mode "$W/$stem.sno" "$m")"
        if printf '%s' "$out" | grep -qE "$bad"; then FAIL=$((FAIL + 1)); printf '  FAIL m%s %-13s %s -- got: %s\n' "$m" "$stem" "$what" "$(printf '%s' "$out" | head -2 | tr '\n' '|')"
        else printf '  ok   m%s %-13s %s\n' "$m" "$stem" "$what"; fi
    done
}
echo "[gate] SNOBOL4 goto ABORT/CONTINUE/SCONTINUE with no preceding error (oracle: sbl -bf)"
check  g_abort     'error 36: goto abort with no preceding error'      'ABORT raises 036 with SPITBOL text'
check  g_continue  'error 37: goto continue with no preceding error'   'CONTINUE raises 037 with SPITBOL text'
check  g_scontinue 'error 321: goto scontinue with no preceding error'  'SCONTINUE raises 321 with SPITBOL text'
reject g_abort     'Not in a SETEXIT handler'                             'the CSNOBOL4 error-35 text is gone'
reject g_continue  'Not in a SETEXIT handler'                             'the CSNOBOL4 error-35 text is gone'
reject g_scontinue 'Not in a SETEXIT handler'                             'the CSNOBOL4 error-35 text is gone'
check  g_handler   'caught'                                              'a live SETEXIT handler still intercepts'
reject g_handler   'error 3[67]:|error 321:'                               'a live handler raises none of the three'
if [ "$FAIL" -eq 0 ]; then echo "GATE GREEN [sno_goto_with_no_preceding_error]: $TOTAL/$TOTAL arms"; exit 0; fi
echo "⛔ GATE RED [sno_goto_with_no_preceding_error]: $FAIL of $TOTAL arms diverge"; exit 1
