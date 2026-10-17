#!/usr/bin/env bash
# test_gate_sno_rewind_on_an_unopened_unit_raises_174.sh -- REWIND(N) on a unit with no OPENed file raises
# ERROR 174 in BOTH modes, and the output produced before the raise survives it.
#
# ⛔⭐ THIS GATE EXISTS BECAUSE THE CURE FOR THIS DEFECT LANDED WITH NO INSTRUMENT AND THE BOARD DID NOT
# MOVE. hq_R found it (_REWIND_ fell back to stdin for unit 5 instead of raising), probed it four ways
# against sbl, cured it -- and csnobol4_suite/rewind1 went FAIL to REJECT and stayed red, because its .ref
# is a transcript of SPITBOL's OWN fatal termination (memory used/left, REGENERATIONS, stmts executed,
# execution time) which no implementation produces by being correct. A correct cure on a dead-pinned
# program cannot flip it; test_gate_no_ref_pins_oracle_internal_state.sh names the class and rewind1 was
# the last member of it still inside a graded denominator (ceo CEO-724). THE SEMANTIC MOVES HERE SO THAT
# LEAVING THE DENOMINATOR COSTS NO COVERAGE -- an exclusion that drops a behaviour nobody re-checks is the
# expensive mistake this file is written to prevent.
#
# ⭐ THE EXPECTATION IS CUT FROM sbl -bf AT RUN TIME AND COMPARED THROUGH THE ONE ERROR VOICE (RULES.md
# § ONE ERROR VOICE, ceo CEO-623/625): the runtime prints its own SCRIP-shaped error for every language and
# never an oracle's shape, so the captured stream is rendered by util_render_error_voice.py spitbol and the
# oracle's own ERROR line is what it is diffed against. Measured: the rendered line is BYTE-IDENTICAL to
# the oracle's. What is NOT graded here, deliberately, is SPITBOL's termination accounting -- that is the
# very thing the ref pinned and the very thing we must never print.
#
# THE ARMS:
#   1  the oracle raises 174 on this witness            (cut at run time -- refuses if it does not)
#   2  m3 raises 174, rendered line identical to arm 1
#   3  m4 raises 174, rendered line identical to arm 1
#   4  m3 keeps the two lines it printed BEFORE the raise
#   5  m4 keeps the two lines it printed BEFORE the raise
#   6  DETECTOR -- the same witness with the REWIND removed raises NOTHING in either mode, so arms 2 and 3
#      are discriminating and not a grep that matches anything
# EXIT: 0 all arms pass · 1 an arm failed · 2 REFUSED (no binary, no oracle, oracle shape moved).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="$ROOT/scrip"
RT_DIR="$ROOT/out"
NAME=sno_rewind_on_an_unopened_unit_raises_174
VOICE="$HERE/util_render_error_voice.py"
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
[ -f "$RT_DIR/libscrip_rt.so" ] || refuse "no $RT_DIR/libscrip_rt.so -- cannot measure mode 4"
[ -f "$VOICE" ] || refuse "no util_render_error_voice.py -- the equivalence list is the only sanctioned way to compare an oracle-shaped ref"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="$(sbl_correctness_bin 2>/dev/null || true)"; [ -n "${SBL:-}" ] && [ -x "$SBL" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || refuse "no sbl oracle -- cannot measure (a missing oracle prints a full false table)"
T="$(mktemp -d)" || refuse "no tmpdir"
trap 'rm -rf "$T"' EXIT
printf 'COPY\tOUTPUT = INPUT\t\t:s(COPY)\n\tREWIND(5)\ncopy2\tOUTPUT = INPUT\t\t:s(copy2)\nEND\n' > "$T/w.sno"
printf 'COPY\tOUTPUT = INPUT\t\t:s(COPY)\nEND\n' > "$T/d.sno"
printf 'hello\nworld\n' > "$T/w.in"
graded=0; fail=0
arm() { graded=$((graded+1)); if [ "$2" = "$3" ]; then echo "  PASS $1  [$2]"; else echo "  FAIL $1  want[$2] got[$3]"; fail=$((fail+1)); fi; }
( cd "$T" && timeout -k 5 30 "$SBL" -bf w.sno < w.in > ora.out 2>/dev/null )
ORA="$(grep -m1 -E '^w\.sno\([0-9]+\) : ERROR [0-9]+ -- ' "$T/ora.out" || true)"
[ -n "$ORA" ] || refuse "the oracle raised no ERROR line on the witness -- the oracle or the witness moved, re-measure rather than score"
case "$ORA" in *"ERROR 174"*) ;; *) refuse "the oracle raised something other than 174: $ORA" ;; esac
echo "  ARM 1 oracle expectation cut at run time: $ORA"
graded=$((graded+1))
( cd "$T" && timeout -k 5 30 "$SCRIP" --run w.sno < w.in > m3.raw 2>&1 )
( cd "$T" && timeout -k 5 30 "$SCRIP" --compile w.sno -o w.s > cc.log 2>&1 ) || refuse "mode-4 compile of the witness failed -- cannot measure"
( cd "$T" && gcc -c w.s -o w.o >> cc.log 2>&1 && gcc w.o -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" -o w.bin >> cc.log 2>&1 ) || refuse "mode-4 link of the witness failed -- cannot measure"
( cd "$T" && timeout -k 5 30 ./w.bin < w.in > m4.raw 2>&1 )
python3 "$VOICE" spitbol < "$T/m3.raw" > "$T/m3.out" || refuse "the error-voice renderer refused on the mode-3 capture"
python3 "$VOICE" spitbol < "$T/m4.raw" > "$T/m4.out" || refuse "the error-voice renderer refused on the mode-4 capture"
arm "m3-raises-174" "$ORA" "$(grep -m1 -E '^w\.sno\([0-9]+\) : ERROR [0-9]+ -- ' "$T/m3.out" || true)"
arm "m4-raises-174" "$ORA" "$(grep -m1 -E '^w\.sno\([0-9]+\) : ERROR [0-9]+ -- ' "$T/m4.out" || true)"
arm "m3-keeps-output-before-the-raise" "hello world" "$(head -2 "$T/m3.out" | tr '\n' ' ' | sed 's/ $//')"
arm "m4-keeps-output-before-the-raise" "hello world" "$(head -2 "$T/m4.out" | tr '\n' ' ' | sed 's/ $//')"
( cd "$T" && timeout -k 5 30 "$SCRIP" --run d.sno < w.in > d3.raw 2>&1 )
( cd "$T" && timeout -k 5 30 "$SCRIP" --compile d.sno -o d.s > dcc.log 2>&1 && gcc -c d.s -o d.o >> dcc.log 2>&1 && gcc d.o -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" -o d.bin >> dcc.log 2>&1 && timeout -k 5 30 ./d.bin < w.in > d4.raw 2>&1 ) || refuse "the detector witness would not build -- cannot prove the arms discriminate"
arm "detector-no-rewind-raises-nothing" "m3=0 m4=0" "m3=$(grep -c 'ERROR ' "$T/d3.raw" || true) m4=$(grep -c 'ERROR ' "$T/d4.raw" || true)"
echo "graded=$graded FAIL=$fail  (expectation cut from $SBL -bf at run time; SCRIP's own voice rendered through util_render_error_voice.py spitbol, never taught the oracle's shape. SPITBOL's termination accounting -- memory used/left, REGENERATIONS, stmts executed, execution time -- is deliberately NOT graded: it is what dead-pinned csnobol4_suite/rewind1 and it is state no correct implementation reproduces.)"
[ "$graded" = 6 ] || refuse "expected 6 arms, graded $graded"
if [ "$fail" -ne 0 ]; then echo "GATE FAIL(1) [$NAME]: $fail/$graded"; exit 1; fi
echo "GATE PASS(0) [$NAME]: $graded/$graded"
exit 0
