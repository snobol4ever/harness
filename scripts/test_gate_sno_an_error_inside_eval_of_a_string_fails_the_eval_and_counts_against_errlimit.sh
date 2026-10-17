#!/usr/bin/env bash
# test_gate_sno_an_error_inside_eval_of_a_string_fails_the_eval_and_counts_against_errlimit.sh
#
# SPITBOL'S RULE FOR AN ERROR WHILE EVAL(string) RUNS (sbl.min's stage stgee, the rule CEO-1322 copied; measured
# here with sbl -bf at run time): EVAL compiles the string and evaluates it under stage stgee, and err04 pops the
# error to the nearer of the innermost program-defined function call and the evaluation. At &ERRLIMIT 0 the EVAL
# FAILS and &ERRLIMIT is untouched; at &ERRLIMIT > 0 it is the ordinary err07 path, so the EVAL fails AND THE ERROR
# IS COUNTED (&ERRLIMIT 5 -> 4). Inside a function the evaluation calls, the erring statement fails and the
# function goes on. Any evalx exit inside the evaluation (an inner *LEN(1) matched) resets the stage, so a later
# error in the same evaluation is an ordinary one: fatal at &ERRLIMIT 0, counted above it. A SETEXIT armed at
# &ERRLIMIT 0 is not entered: the EVAL fails as if none were armed.
#
# WHAT SCRIP DID BEFORE (cfo 2026-10-02, the c2bb eval-chain row's design question): eval_chain_run_guarded ran the
# chain under g_error = -1, a longjmp guard that failed the EVAL on any error and never counted it, so every
# &ERRLIMIT > 0 arm below read ERRLIMIT=5 where sbl reads 4. The guard also kept the stage's resets from reaching an
# error after an inner evalx (reset0 read CLEAN where sbl is FATAL). And with a SETEXIT label armed at &ERRLIMIT 0
# (setexit0) the -1 guard does not longjmp, the handler arm needs &ERRLIMIT nonzero, and the error fell through to
# the fatal exit, killing a run sbl finishes. On the parent tree 18 of these 26 arms read red. The cure runs the
# chain under the stage (G_ERROR_EVAL_STAGE), the mode core_runtime_error already reads as "count it, the operation
# fails". The setjmp stays: it is how a level unwind (core_unwind_next, code 3) crosses this C frame.
# NOT COVERED, AND WHY: an inner EVAL of an unevaluated expression, EVAL(*(X + 0)) inside the string, is not an evalx
# in SCRIP (the stage never resets there), so sbl's FATAL is SCRIP's failed EVAL under both guards; the error's
# fatal LINE is not graded, because sbl numbers an error in execute-time-compiled code past END and the voice of
# that line is the error voice's business, not this rule's.
#
# Expectations are cut from sbl -bf AT RUN TIME. Each arm grades, per mode, FATAL versus CLEAN and the stdout before
# the error. rc=0 clean · rc=1 a divergence · rc=2 REFUSAL.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
refuse() { echo "⛔ REFUSES rc=2: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built -- cannot measure"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="$(sbl_correctness_bin 2>/dev/null || true)"; [ -n "${SBL:-}" ] && [ -x "$SBL" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || refuse "no sbl oracle -- the expectations are cut from it at run time"
"$HERE/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT

mk() {  # $1 name  $2 &ERRLIMIT  $3 the EVAL argument  $4 1 to arm SETEXIT('H') before the EVAL
    cat > "$D/$1.sno" <<SNO
        &ERRLIMIT = $2
        DEFINE('F()')                                     :(FE)
F       OUTPUT = 'in F'
        Z = X / Y
        OUTPUT = 'F continues'
        F = 'fv'                                          :(RETURN)
FE      X = 1
        Y = 0
$( if [ "$4" = 1 ]; then printf '        SETEXIT(%s)' "'H'"; else printf '* no SETEXIT in this arm'; fi )
        R = EVAL($3)                                      :S(S1)F(F1)
S1      OUTPUT = 'S ' R                                   :(N1)
F1      OUTPUT = 'F'
N1      OUTPUT = 'ERRTYPE=' &ERRTYPE ' ERRLIMIT=' &ERRLIMIT
        R2 = EVAL("X + 1")
        OUTPUT = 'after ' R2                              :(END)
H       OUTPUT = 'handler'                                :(SCONTINUE)
END
SNO
}
mk direct0   0 '"X / Y"' 0
mk direct5   5 '"X / Y"' 0
mk const5    5 '"1 / 0"' 0
mk func0     0 '"F()"' 0
mk func5     5 '"F()"' 0
mk after5    5 "\"(A = 'set') (X / Y)\"" 0
mk nested5   5 "\"EVAL('X / Y')\"" 0
mk setexit0  0 '"X / Y"' 1
mk reset0    0 "\"('abc' ? *LEN(1)) (X / Y)\"" 0
mk reset5    5 "\"('abc' ? *LEN(1)) (X / Y)\"" 0
mk before0   0 "\"(X / Y) ('abc' ? *LEN(1))\"" 0
mk funcerr0  0 '"F() (X / Y)"' 0
mk funcerr5  5 '"F() (X / Y)"' 0
ARMS="direct0 direct5 const5 func0 func5 after5 nested5 setexit0 reset0 reset5 before0 funcerr0 funcerr5"

run_sbl() {  # -> $1.sbl.out (stdout before the error), $1.sbl.fatal (FATAL/CLEAN)
    (cd "$D" && timeout -k 5 20 "$SBL" -bf "$1.sno" </dev/null > "$1.sbl.raw" 2>/dev/null)
    if grep -q "^$1.sno([0-9]*) : ERROR [0-9]" "$D/$1.sbl.raw"; then
        echo FATAL > "$D/$1.sbl.fatal"
        sed -n "/^$1.sno([0-9]*) : ERROR/q;p" "$D/$1.sbl.raw" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' > "$D/$1.sbl.out"
    else echo CLEAN > "$D/$1.sbl.fatal"; cp "$D/$1.sbl.raw" "$D/$1.sbl.out"; fi
}
run_scrip() {  # $1 name $2 mode -> $1.$2.out/.err/.fatal
    local n="$1" m="$2" rc
    if [ "$m" = m3 ]; then (cd "$D" && timeout -k 5 20 "$B/scrip" "$n.sno" </dev/null > "$n.$m.out" 2> "$n.$m.err"); rc=$?
    else "$B/scrip" --compile -o "$D/$n.s" "$D/$n.sno" </dev/null >/dev/null 2>&1 \
           && as -o "$D/$n.o" "$D/$n.s" 2>/dev/null \
           && gcc -o "$D/$n.bin" "$D/$n.o" "$B/out/libscrip_rt.so" -lm -Wl,-rpath,"$B/out" 2>/dev/null \
           || refuse "could not build the m4 arm of $n -- a toolchain failure, not a verdict"
         (cd "$D" && timeout -k 5 20 "./$n.bin" </dev/null > "$n.$m.out" 2> "$n.$m.err"); rc=$?; fi
    [ "$rc" -ge 124 ] && refuse "$n $m timed out or died of a signal (rc=$rc) -- neither verdict"
    if [ "$rc" -ne 0 ]; then echo FATAL > "$D/$n.$m.fatal"; else echo CLEAN > "$D/$n.$m.fatal"; fi
}

fails=0; arms=0
for n in $ARMS; do
    run_sbl "$n"
    for m in m3 m4; do
        run_scrip "$n" "$m"; arms=$((arms+1))
        why=""
        cmp -s "$D/$n.sbl.fatal" "$D/$n.$m.fatal" || why="$why sbl=$(cat "$D/$n.sbl.fatal") scrip=$(cat "$D/$n.$m.fatal")"
        cmp -s "$D/$n.sbl.out" "$D/$n.$m.out"     || why="$why stdout-differs"
        if [ -z "$why" ]; then printf '  ok    %-9s %s: %s, %s\n' "$n" "$m" "$(cat "$D/$n.sbl.fatal")" "$(grep -m1 '^ERRTYPE=' "$D/$n.sbl.out" || echo 'no ERRTYPE line')"
        else printf '  FAIL  %-9s %s:%s\n' "$n" "$m" "$why"; diff "$D/$n.sbl.out" "$D/$n.$m.out" | head -6 | sed 's/^/          /'; head -2 "$D/$n.$m.err" | sed 's/^/          stderr: /'; fails=$((fails+1)); fi
    done
done
grep -qx "ERRTYPE=14 ERRLIMIT=4" "$D/direct5.sbl.out" || refuse "the oracle no longer counts an error inside EVAL against &ERRLIMIT 5 -- re-read sbl before trusting this gate"
grep -qx "ERRTYPE=14 ERRLIMIT=0" "$D/direct0.sbl.out" || refuse "the oracle's &ERRLIMIT 0 control did not print its line -- the witness is not measuring"
[ "$(cat "$D/reset0.sbl.fatal")" = FATAL ] || refuse "the oracle no longer resets the stage on an inner evalx exit inside EVAL -- re-read sbl before trusting this gate"
[ "$fails" -eq 0 ] || { echo "⛔ GATE FAILED: $fails of $arms arm(s) red."
    echo "   An &ERRLIMIT 5 arm reading ERRLIMIT=5 is the EVAL chain running under a guard that does not count (the old -1);"
    echo "   reset0 reading CLEAN is an inner evalx exit that no longer clears the stage."; exit 1; }
echo "✅ GATE OK: $arms arm(s) -- an error inside EVAL of a string fails the EVAL, counts against &ERRLIMIT, and every stage reset sbl makes inside it SCRIP makes, both modes"
exit 0
