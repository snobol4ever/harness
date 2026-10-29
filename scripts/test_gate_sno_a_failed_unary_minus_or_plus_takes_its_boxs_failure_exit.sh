#!/usr/bin/env bash
# test_gate_sno_a_failed_unary_minus_or_plus_takes_its_boxs_failure_exit.sh
#
# SPITBOL'S RULE: an error in an operand fails the statement that raised it. Under SETEXIT the handler is entered;
# under &ERRLIMIT > 0 or inside EVAL (stage stgee) the error is counted and the operation fails. So -ARB raises 10
# (negation operand is not numeric) and +ARB raises 4, and 'abc' ? -ARB ABORT is ERROR 10, never a crash.
# WHAT SCRIP DID (ceo CEO-1434's assigned row snobol4-an-error-raised-in-a-pattern-concatenated-with-abort-crashes-
# scrip-inside-eval, found by the infinite_snobol4 SCRIPtix run at expression 2,358): bb_unop's TT_MNS/TT_PLS box
# called rt_num_neg_sno / rt_num_pos, stored the result and went on to gamma WITHOUT TESTING IT. When the error returned
# (counted, the operation fails) the FAIL descriptor flowed on as a value into the concatenation and the match, which
# jumped into a literal's data word: SIGSEGV in mode 3 (a mapped, non-executable page), SIGILL in mode 4. With no
# SETEXIT armed it crashed since before SETEXIT shape B; with one armed, the old nested handler entry jumped away before
# the failed value was used, and shape B (fc306f22a), which returns from the error and fails the statement, reached it.
# THE CURE: for SNOBOL4 (op_strict == 2) the box tests the stored result after its GC poll and takes omega on FAIL, in
# both of its forms (the zd result slot and the frame slot).
# NOT COVERED, AND WHY: the same statements written with constant operands (X = 'abc' ? -ARB ABORT) are a compile-time
# error in sbl, which folds -ARB while compiling; that is the parser-strictness row. sbl itself segfaults on this EVAL
# inside a program-defined function, so every arm runs at the top level.
#
# Expectations are cut from sbl -bf AT RUN TIME, both modes; every arm grades its whole stdout. rc=0 clean · rc=1 a
# divergence · rc=2 REFUSAL.
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

cat > "$D/ev.sno" <<'SNO'
        &TRIM = 1
loop    line = INPUT                                            :F(END)
        &ERRLIMIT = 1000
        SETEXIT('errh')
        r = EVAL(line)                                          :S(ok)
        OUTPUT = 'FAIL'                                         :(loop)
ok      OUTPUT = DATATYPE(r) ' ' r                              :(loop)
errh    OUTPUT = 'ERROR ' &ERRTYPE                              :(loop)
END
SNO
printf "'abc' ? -ARB ABORT\n'abc' ? +ARB ABORT\n-ARB\n+ARB\n'abc' ? (-ARB) LEN(1)\n'abc' ? FENCE(-ARB)\n-'abc'\n+'abc'\n'abc' ? -&ARB\n'abc' ? ARB ABORT\n-'12'\n" > "$D/ev.in"
cat > "$D/top.sno" <<'SNO'
        &ERRLIMIT = 5
        P = ARB
        X = EVAL("'abc' ? -ARB ABORT")                   :S(A)
        OUTPUT = 'eval F ' &ERRTYPE ' ' &ERRLIMIT
A       X = 'abc' ? -P ABORT                             :S(B)
        OUTPUT = 'static F ' &ERRTYPE ' ' &ERRLIMIT
B       X = 'abc' ? +P ABORT                             :S(C)
        OUTPUT = 'static plus F ' &ERRTYPE ' ' &ERRLIMIT
C       OUTPUT = 'end'
END
SNO
ARMS="ev top"
inp() { [ -f "$D/$1.in" ] && echo "$D/$1.in" || echo /dev/null; }
run_scrip() {  # $1 name $2 mode -> stdout
    if [ "$2" = m3 ]; then (cd "$D" && timeout -k 5 30 "$B/scrip" "$1.sno" < "$(inp "$1")" 2>/dev/null)
    else "$B/scrip" --compile --out="$D/$1.s" "$D/$1.sno" </dev/null >/dev/null 2>&1 \
           && gcc -no-pie -o "$D/$1.bin" "$D/$1.s" -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" 2>/dev/null \
           || refuse "could not build the m4 arm of $1 -- a toolchain failure, not a verdict"
         (cd "$D" && timeout -k 5 30 "./$1.bin" < "$(inp "$1")" 2>/dev/null); fi
}
for a in $ARMS; do (cd "$D" && timeout -k 5 30 "$SBL" -bf "$a.sno" < "$(inp "$a")" > "$a.sbl" 2>/dev/null); done
[ "$(wc -l < "$D/ev.sbl")" = "$(wc -l < "$D/ev.in")" ] || refuse "the oracle answered $(wc -l < "$D/ev.sbl") of $(wc -l < "$D/ev.in") lines -- the witness is not measuring"
grep -qx "ERROR 10" "$D/ev.sbl" && grep -qx "static F 10 3" "$D/top.sbl" || refuse "the oracle no longer raises 10 for -ARB -- re-read sbl"
fails=0; arms=0
for m in m3 m4; do
    for a in $ARMS; do
        arms=$((arms+1)); run_scrip "$a" "$m" > "$D/$a.$m"; rc=$?
        if [ "$rc" -ge 124 ]; then printf '  FAIL  %s %-4s died rc=%s (a signal: the crash this gate exists for)\n' "$m" "$a" "$rc"; fails=$((fails+1)); continue; fi
        if cmp -s "$D/$a.sbl" "$D/$a.$m"; then printf '  ok    %s %-4s %s lines, as sbl\n' "$m" "$a" "$(wc -l < "$D/$a.sbl")"
        else printf '  FAIL  %s %-4s\n' "$m" "$a"; diff "$D/$a.sbl" "$D/$a.$m" | head -6 | sed 's/^/          /'; fails=$((fails+1)); fi
    done
done
[ "$fails" -eq 0 ] || { echo "⛔ GATE FAILED: $fails of $arms arm(s) red."
    echo "   A crash or a missing line is bb_unop's TT_MNS/TT_PLS box going on to gamma with the FAIL its call returned (bb_unop.cpp, op_strict == 2)."; exit 1; }
echo "✅ GATE OK: $arms arm(s) -- a unary minus or plus whose operand errs fails its statement (SETEXIT, &ERRLIMIT and EVAL), never a crash, both modes"
exit 0
