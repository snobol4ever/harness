#!/usr/bin/env bash
# test_gate_sno_a_runtime_error_sbl_raises_is_raised_by_number_in_both_modes.sh -- row snobol4-runtime-errors-sbl-raises-are-
# silent-statement-failures-in-scrip-binary-arithmetic-array-and-replace-and-negation-carries-the-wrong-error-number-ceo-1304
# (found by the ceo's audit, CEO-1304; routed to the cfo, CEO-1306; cured by the cfo 2026-09-27).
#
# THE DEFECT: under &ERRLIMIT 0 (the default of both) sbl -bf raises a FATAL runtime error and terminates on x + 1, x - 1,
# x * 2, x / 2 and x ** 2 with x = 'abc', on ARRAY(0 - 1) and on REPLACE with unequally long 2nd and 3rd arguments; SCRIP
# failed the statement silently, took :F, ran on and exited 0, in both modes. -x was raised but numbered 1 where sbl says 010.
# NO SUITE SAW IT: corpus/tests/snobol4/ALL.ref carries no ERROR line, so these programs sit outside every rung suite's
# denominator -- which is why a cure proven on them owes this gate (the ceo's rule of 2026-09-27: a cure proven on a program
# that leaves the denominator owes a gate that keeps it under test).
# THE CURE: the SNOBOL4 lowerer marks its arithmetic nodes strict=2 and bb_binop_arith calls a SNOBOL4-voiced entry family
# (rt_add_sno and its siblings: the same asm fast paths, a slow path that raises SPITBOL's number for the operand that is not
# numeric); Icon's strict=1 and every other frontend's strict=0 are unchanged. ARRAY raises 067 in both dispatch copies and in
# the prototype parser, REPLACE raises 171, negation 010, affirmation 004, and integer division by zero 014 (it said 2).
#
# EACH ARM is a one-statement program run by sbl -bf (the EXPECTED number is read live from the oracle, never typed) and by
# scrip in mode 3 and mode 4: the arm passes when scrip prints 'before' exactly when sbl does, never reaches 'success' or
# 'failure', and names the same error number. A witness sbl does not raise on is a wrong witness and REFUSES rc=2.
# ⛔ A CONSTANT ARM NEVER RUNS (cfo 2026-10-02): sbl -bf evaluates an operation on constant operands WHEN IT COMPILES the
# statement (1 / 0, 9223372036854775807 + 1, 4611686018427387904 * 4, 0.0 ** 0.0, 2.0 ** 2000 are compile-time errors: no
# 'before', the program never runs), and SCRIP does the same since its compile-time pre-evaluation; so 'before' is read from
# sbl's own output, and mode 4 reads the number from the refused compile (M4-COMPILE-REFUSED) where no binary is built.
# CONTROL ARMS: a numeric string operand ('12' + 1) raises nothing and prints 13 in both; ATAN('abc') raises 301 in both.
# ERRLIMIT ARM: with &ERRLIMIT = 5 the same x + 1 is counted, the statement FAILS, and &ERRTYPE reads 1, as sbl gives it.
# FAIL-ONCE, MEASURED: SCRIP_BIN at a scrip built on origin bc96cf1b2 (before the cure) reads 0 of 38 raising arms and the
# &ERRLIMIT arm RED in both modes (&ERRTYPE 0 where sbl gives 1), the two controls green -- the gate measures the cure.
# LANDING 2 (the class, same row): integer overflow 003/034/028 (it WRAPPED silently: the asm fast paths of rt_add/rt_sub/rt_mul
# computed into rdx, the right operand's tag word, before their jo, so the slow path read a corrupted right operand -- a wrong
# answer on every frontend reaching that path), 0 ** 0 018, 2 ** 63 017, (-8) ** 0.5 311, 2.0 ** 2000 266, 1.0E300 squared 263,
# REMDR 165/166/167/312, and INT64_MIN / -1 (a SIGFPE core dump; sbl dumps too). Measured: a build at origin 7ad35d97a (landing
# 1 only) reads 38 of 70 raising arms and both INT64_MIN arms RED in both modes.
# LANDING 3 (the class, same row): negating INT64_MIN raises 011 (it WRAPPED to itself). rt_num_neg gained the voiced entries
# rt_num_neg_sno (011) and rt_num_neg_strict (Icon: the large integer), chosen by bb_unop from the node's strict; strict 0
# still wraps, which is fpc's answer for Pascal. Measured: a build of landing 2 reads that arm RED in both modes.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"
RT_DIR="$(cd "$(dirname "$SCRIP")" && pwd)/out"
NAME=sno_a_runtime_error_sbl_raises_is_raised_by_number_in_both_modes
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
[ -f "$RT_DIR/libscrip_rt.so" ] || refuse "no $RT_DIR/libscrip_rt.so -- cannot measure mode 4"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="$(sbl_correctness_bin 2>/dev/null || true)"; [ -n "${SBL:-}" ] && [ -x "$SBL" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || refuse "no sbl oracle -- cannot measure"
T="$(mktemp -d)" || refuse "no tmpdir"
trap 'rm -rf "$T"' EXIT
prog() {
    printf "        OUTPUT = 'before'\n        x = 'abc'\n        n = '12'\n        a = 'ab'\n        b = 'X'\n        i = 9223372036854775807\n        m = 4611686018427387904\n        z = 0\n        t = 2\n        r = 1.0E300\n%s        OUTPUT = %s   :S(ok)F(bad)\nok      OUTPUT = 'success' :(END)\nbad     OUTPUT = 'failure'\nEND\n" "${2:-}" "$1" > "$T/w.sno"
}
runm() {
    if [ "$1" = m3 ]; then timeout -k 5 20 "$SCRIP" "$T/w.sno" < /dev/null 2>&1
    else rm -f "$T/w" "$T/w.s"
        "$SCRIP" --compile -o "$T/w.s" "$T/w.sno" < /dev/null > "$T/c.out" 2>&1 || { cat "$T/c.out"; echo "M4-COMPILE-REFUSED"; return; }
        gcc -o "$T/w" "$T/w.s" -L "$RT_DIR" -lscrip_rt -Wl,-rpath,"$RT_DIR" -lm 2> /dev/null || { echo "M4-BUILD-FAILED"; return; }
        (cd "$T" && timeout -k 5 20 ./w < /dev/null 2>&1); fi
}
errno_of() { grep -io 'error [0-9]*' | head -1 | awk '{print $2+0}'; }
RC=0; n=0; ok=0
for ex in "x + 1" "1 + x" "x - 1" "2 - x" "x * 2" "2 * x" "x / 2" "2 / x" "x ** 2" "2 ** x" "-x" "+x" "1 / 0" \
          "ARRAY(0 - 1)" "ARRAY(0)" "ARRAY('')" "ARRAY('3:1')" "REPLACE('abcabc', a, b)" "REPLACE('abcabc', '', '')" \
          "i + 1" "(0 - i) - 2" "m * 4" "m * t" "9223372036854775807 + 1" "4611686018427387904 * 4" "z ** z" "0.0 ** 0.0" "t ** 63" \
          "(z - 8) ** 0.5" "2.0 ** 2000" "r * r" "REMDR(5, z)" "REMDR(5.0, 0.0)" "REMDR(x, 2)" "REMDR(5, x)" "-(0 - i - 1)"; do
    prog "$ex"
    sout=$("$SBL" -bf "$T/w.sno" < /dev/null 2>/dev/null); want=$(printf '%s\n' "$sout" | errno_of); wb=$(printf '%s\n' "$sout" | grep -cx 'before')
    [ -n "$want" ] || refuse "sbl -bf raised no error for [$ex] -- the witness is wrong"
    for m in m3 m4; do n=$((n+1))
        out=$(runm $m); got=$(printf '%s\n' "$out" | errno_of)
        if [ "$(printf '%s\n' "$out" | grep -cx 'before')" = "$wb" ] && ! printf '%s\n' "$out" | grep -qx 'failure\|success' && [ "$got" = "$want" ]; then ok=$((ok+1))
        else RC=1; echo "  RED $m [$ex]: sbl -bf raises ERROR $want and terminates; scrip: $(printf '%s' "$out" | tr '\n' ' ' | cut -c1-120)"; fi
    done
done
echo "  raising arms: $ok of $n raise the number sbl -bf raises and terminate, both modes"
# INT64_MIN / -1 and REMDR(INT64_MIN, -1): sbl -bf ITSELF dies of SIGFPE (rc 136) on both, so no number can be read from it; scrip
# raises SPITBOL's own number for integer division overflow (014) and gives REMDR's exact answer 0 -- and must never dump core.
for m in m3 m4; do
    prog "(0 - i - 1) / (0 - 1)"; out=$(runm $m); got=$(printf '%s\n' "$out" | errno_of)
    [ "$got" = 14 ] && ! printf '%s\n' "$out" | grep -qx 'failure\|success' || { RC=1; echo "  RED $m [INT64_MIN / -1]: expected error 14, got: $(printf '%s' "$out" | tr '\n' ' ' | cut -c1-120)"; }
    prog "REMDR(0 - i - 1, 0 - 1)"; out=$(runm $m)
    printf '%s\n' "$out" | grep -qx '0' && printf '%s\n' "$out" | grep -qx 'success' || { RC=1; echo "  RED $m [REMDR(INT64_MIN, -1)]: expected 0 and success, got: $(printf '%s' "$out" | tr '\n' ' ' | cut -c1-120)"; }
done
for m in m3 m4; do
    prog "n + 1"; out=$(runm $m)
    if printf '%s\n' "$out" | grep -qx '13' && printf '%s\n' "$out" | grep -qx 'success' && ! printf '%s\n' "$out" | grep -qi 'error'; then :; else RC=1; echo "  RED $m control ['12' + 1]: expected 13 and success, got: $(printf '%s' "$out" | tr '\n' ' ' | cut -c1-120)"; fi
    prog "ATAN(x)"; want=$("$SBL" -bf "$T/w.sno" < /dev/null 2>/dev/null | errno_of); out=$(runm $m); got=$(printf '%s\n' "$out" | errno_of)
    [ -n "$want" ] && [ "$got" = "$want" ] || { RC=1; echo "  RED $m control [ATAN(x)]: sbl raises ${want:-nothing}, scrip ${got:-nothing}"; }
    prog "x + 1" $'        &ERRLIMIT = 5\n'
    sed -i "s/^bad     OUTPUT = 'failure'$/bad     OUTPUT = 'failure ' \&ERRTYPE/" "$T/w.sno"
    wantl=$("$SBL" -bf "$T/w.sno" < /dev/null 2>/dev/null | grep -x 'failure [0-9]*'); out=$(runm $m)
    if [ -n "$wantl" ] && printf '%s\n' "$out" | grep -qx "$wantl"; then :; else RC=1; echo "  RED $m &ERRLIMIT arm: sbl prints [${wantl:-nothing}], scrip: $(printf '%s' "$out" | tr '\n' ' ' | cut -c1-120)"; fi
done
[ $RC = 0 ] && echo "GATE PASS(0) [$NAME]: every runtime error of the witness set is raised by the number sbl -bf raises and terminates, in both modes ($ok of $n); the numeric control succeeds, ATAN's 301 holds, and &ERRLIMIT counts and fails the statement with sbl's &ERRTYPE" \
             || echo "GATE FAIL(1) [$NAME]: a runtime error sbl -bf raises is silent or misnumbered in scrip"
exit $RC
