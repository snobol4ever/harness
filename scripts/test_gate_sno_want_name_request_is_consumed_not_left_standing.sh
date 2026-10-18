#!/usr/bin/env bash
# test_gate_sno_want_name_request_is_consumed_not_left_standing.sh -- A BY-NAME REQUEST IS CONSUMED BY THE
# RETURN IT WAS RAISED FOR, AND DOES NOT STAND AFTERWARDS.
#
# WHAT THIS IS: the end state of row want-name-must-live-in-the-activation-not-in-a-global-that-stays-live-
# across-the-callee-body (hq_V's FINDING-2026-09-08, cured by hq_U 2026-09-13). `.F()` raises the caller's
# "I want a NAME" request through SNO$WANTNM; the callee's activation parks it (AB_OFF_WN) and the return
# fix decides deref-or-not from the parked value. The request is PER CALL. Before the cure rt_nret_fix
# ENDED by writing the request back into the global instead of clearing it, so one `.F()` anywhere left
# rt_g_want_name standing at 1 for the rest of the program and EVERY later plain `F()` wrongly kept its
# name. bb_define.cpp's own NRETURN comment already said the epilogue "reads+clears it" -- the C did not.
#
# ⭐ THE WITNESS IS TWO STATEMENTS AND THE SECOND IS THE ONE THAT WAS WRONG. A gate that grades only the
# by-name call passes on the broken tree: the defect is invisible until a SECOND, ordinary call follows.
# So every arm here runs at least one plain call AFTER a by-name one, and all three arms are graded
# against `sbl -bf` -- the ref is cut from the oracle, never from our output.
#
# ARMS: sticky (the two-statement minimum, plus three later plain calls that must all stay STRING)
#       nested (an outer request pending while an inner one is raised and taken inside the callee body)
#       deep   (three NRETURN levels, dotted then plain, so a mis-cleared inner request shows as a deref)
#
# EXIT: 0 all arms match the oracle in both modes. 1 an arm regressed. 2 UNPROVEN (no scrip, RT or oracle).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; cd "$ROOT"
. "$HERE/lib_gate.sh" 2>/dev/null || { echo "REFUSING: cannot load lib_gate.sh -- the ONE gate-honesty authority." >&2; exit 3; }
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "REFUSE(2): cannot load lib_oracle_flags.sh -- the ONE oracle-path authority." >&2; exit 2; }
gate_parse_args "$@"
SCRIP="${SCRIP:-$ROOT/scrip}"; RT="${RT_DIR:-$ROOT/out}"
gate_require_exec "$SCRIP" "scrip binary"
gate_require "$RT/libscrip_rt.so" "runtime library"
gate_require_fresh "$ROOT" src "$SCRIP" "$RT/libscrip_rt.so"
SBL="$(sbl_correctness_bin)" || { echo "REFUSE(2): no SNOBOL4 correctness oracle -- a missing oracle prints a full, plausible, entirely false table"; exit 2; }
T="$(mktemp -d)" || exit 2; trap 'rm -rf "$T"' EXIT
printf "        DEFINE('NV()')                  :(E)\nNV      V = 'BYNAME'\n        NV = .V                         :(NRETURN)\nE\n        OUTPUT = DATATYPE(NV())\n        OUTPUT = DATATYPE(.NV())\n        OUTPUT = DATATYPE(NV())\n        OUTPUT = DATATYPE(NV())\n        X = .V\n        OUTPUT = DATATYPE(NV())\nEND\n" > "$T/sticky.sno"
printf "        DEFINE('NV()')\n        DEFINE('ID(X)')\n        DEFINE('WRAP()')                :(E)\nNV      V = 'BYNAME'\n        NV = .V                         :(NRETURN)\nID      ID = X                          :(RETURN)\nWRAP    WRAP = .NV()                    :(NRETURN)\nE\n        OUTPUT = DATATYPE(.WRAP())\n        OUTPUT = ID(NV())\n        OUTPUT = DATATYPE(.NV()) ' ' ID('after')\n        OUTPUT = ID(DATATYPE(.NV()))\nEND\n" > "$T/nested.sno"
printf "        DEFINE('A()')\n        DEFINE('B()')\n        DEFINE('C()')                   :(E)\nA       V = 'AVAL'\n        A = .V                          :(NRETURN)\nB       B = .A()                        :(NRETURN)\nC       C = .B()                        :(NRETURN)\nE\n        OUTPUT = DATATYPE(.A())\n        OUTPUT = DATATYPE(.B())\n        OUTPUT = DATATYPE(.C())\n        OUTPUT = DATATYPE(A())\n        OUTPUT = DATATYPE(B())\n        OUTPUT = DATATYPE(C())\nEND\n" > "$T/deep.sno"
bad=0; graded=0
for arm in sticky nested deep; do
    want="$(cd "$T" && timeout -k 5 20s "$SBL" $(sbl_lang_flags) "$arm.sno" < /dev/null 2>&1)"
    [ -n "$want" ] || { echo "  REFUSE $arm -- the oracle printed nothing; a blank expectation grades everything green"; exit 2; }
    for m in m3 m4; do
        if [ "$m" = m3 ]; then got="$(cd "$T" && timeout -k 5 20s "$SCRIP" "$arm.sno" < /dev/null 2>&1)"
        else
            "$SCRIP" --compile -o "$T/$arm.s" "$T/$arm.sno" < /dev/null >/dev/null 2>&1 || { echo "  RED  $arm $m -- compile failed"; bad=1; continue; }
            gcc -no-pie "$T/$arm.s" -o "$T/$arm.x" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm -lpthread >/dev/null 2>&1 || { echo "  RED  $arm $m -- link failed"; bad=1; continue; }
            got="$(cd "$T" && timeout -k 5 20s "./$arm.x" < /dev/null 2>&1)"
        fi
        graded=$((graded + 1))
        if [ "$got" = "$want" ]; then echo "  ok   $arm $m -- [$(printf '%s' "$got" | tr '\n' '/')]"
        else echo "  RED  $arm $m -- want [$(printf '%s' "$want" | tr '\n' '/')] got [$(printf '%s' "$got" | tr '\n' '/')]"; bad=1; fi
    done
done
[ "$graded" -eq 6 ] || { echo "REFUSE(2): graded $graded of 6 arm-modes -- a runner that could not measure must never print the success shape"; exit 2; }
if [ "$bad" -ne 0 ]; then echo "GATE RED(1) [sno-want-name-request-is-consumed-not-left-standing]: graded=$graded -- a by-name request outlived the return it was raised for"; exit 1; fi
echo "GATE GREEN(0) [sno-want-name-request-is-consumed-not-left-standing]: graded=$graded/6, the request is consumed by its own return in both modes"
