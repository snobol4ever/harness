#!/usr/bin/env bash
# test_gate_sno_code_of_text_that_does_not_compile_raises_spitbols_compile_error.sh
#
# THE ROW (ceo CEO-1442, the cfo's report): snobol4-code-of-text-that-does-not-compile-fails-silently-where-spitbol-raises-the-
# compile-error. CODE(' X = (1') under SETEXIT is trapped as error 226 in sbl -bf; SCRIP's CODE failed with &ERRTYPE 0 and raised
# nothing, both modes. The CODE analogue of the EVAL cure e9213711a (test_gate_sno_eval_of_text_that_does_not_compile_raises_...).
#
# SPITBOL'S RULE (sbl.min cmpil cmp13-cmp31, scngf, scane, expan; measured on sbl -bf by the cfo 2026-10-02): CODE compiles its
# text statement by statement (';' ends one, column 1 is the label) and RAISES the first compile error with its number: the
# expression errors 220-233 in a field, and the statement's own -- 214 a bad first character, 218 a duplicated goto field, 219 a ':'
# with no field, 227/228 a goto's right paren or bracket missing, 234 a goto element that opens with neither ( nor <, 212 an empty
# goto -- and the compile-time pre-evaluation errors (X = -POS(0) is 10). Under SETEXIT it is trapped, and after CONTINUE the CODE
# still fails with &ERRTYPE kept; at &ERRLIMIT > 0 it is counted; at &ERRLIMIT 0 the CODE simply fails and the run goes on -- the
# same stage rule as EVAL's.
# THE CURE (runtime_eval.c): when SCRIP's own parser has rejected the text, code_sb_syntax splits it into statements and fields
# and names the error SPITBOL raises first (each field through eval_sb_syntax, the goto field by cmp13's loop), and code_at raises
# it in the EVAL stage at each of its three failure exits; a pre-evaluation error raises its own number. Text SCRIP's parser accepts
# is never classified, and text the classifier finds no error in fails silently as before, so no CODE call that works today changes.
# NOT COVERED, AND WHY: where SCRIP's parser and sbl's disagree about whether the text compiles -- '*comment' and ' X = 1 :S (L1)'
# compile in sbl and fail in SCRIP, ' X = 1 :' (219 in sbl) compiles in SCRIP -- the parser's acceptance is a class of its own. So
# is the order of a pre-evaluation error in an earlier statement against a syntax error in a later one (the syntax error is raised).
#
# Each arm grades the evaluator's lines for one text, both modes, against sbl -bf cut AT RUN TIME; the run stays under 32 trapped
# errors (a trap still nests). FAIL-ONCE, MEASURED: this gate on the parent (SCRIP ddf5c1a60, the cure stashed) reads all four arms
# RED, both modes -- no text trapped, 'failed 0' (the two pre-evaluation texts 'failed 10' and 'failed 2', still untrapped), and
# the &ERRLIMIT arms 'failed 0 limit 10'; on the cure 4/4. rc=0 clean · rc=1 a divergence · rc=2 REFUSAL.
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
cat > "$D/cd.sno" <<'SNO'
        &TRIM = 1
loop    line = INPUT                                            :F(END)
        &ERRLIMIT = 1000
        SETEXIT('errh')
        c = CODE(line)                                          :S(ok)
        OUTPUT = 'failed ' &ERRTYPE                             :(loop)
ok      OUTPUT = 'succeeded'                                    :(loop)
errh    OUTPUT = 'trapped ' &ERRTYPE ' ' &ERRTEXT               :(CONTINUE)
END
SNO
cat > "$D/lines.txt" <<'TXT'
 X = (1
 X = 1 +
 X = 'abc
 X = 1 2 )
 X = -POS(0)
 X = 1 + 'a'
 X = 1; Y = (2
 X = 1 :S(L1
 X = 1 :S(L1)S(L2)
 X = 1 :(
 X = 1 , 2
 X = 99999999999999999999
 X = 'a''b'
 X = 1 :F(L1) junk
 X= 1
.X = 1
 X = 1 :<C
 X = 1 :S()
 X = 1 :S(L1))
 X = 1
L X = 1
 X = 1 :S(L1) F(L2)
 X = 1 :S<L1>
 :(L1)
 X = 1 ;
X=1
 X =1
TXT
cat > "$D/lim.sno" <<'SNO'
        &ERRLIMIT = 10
        c = CODE(' X = (1')                                     :S(A)
        OUTPUT = 'counted: failed ' &ERRTYPE ' limit ' &ERRLIMIT
A       &ERRLIMIT = 0
        c = CODE(' X = 1 +')                                    :S(B)
        OUTPUT = 'zero: failed ' &ERRTYPE ' and the run goes on'
B       OUTPUT = 'end'
END
SNO
RT="$B/out"
run() {
    if [ "$1" = m3 ]; then (cd "$D" && timeout -k 5 20 "$B/scrip" "$2.sno" < "${3:-/dev/null}" 2>/dev/null)
    else "$B/scrip" --compile --out="$D/$2.s" "$D/$2.sno" < /dev/null > /dev/null 2>&1 && gcc -no-pie -o "$D/$2.bin" "$D/$2.s" -L "$RT" -lscrip_rt -lm -Wl,-rpath,"$RT" 2> /dev/null \
           || { echo "M4-BUILD-FAILED"; return; }
         (cd "$D" && timeout -k 5 20 "./$2.bin" < "${3:-/dev/null}" 2>/dev/null); fi
}
(cd "$D" && timeout -k 5 20 "$SBL" -bf cd.sno < lines.txt > want.cd 2>/dev/null) || true
(cd "$D" && timeout -k 5 20 "$SBL" -bf lim.sno < /dev/null > want.lim 2>/dev/null) || true
[ "$(grep -c '^trapped ' "$D/want.cd")" = 19 ] || refuse "sbl does not trap the 19 raising texts as measured ($(grep -c '^trapped ' "$D/want.cd") trapped)"
[ "$(grep -c '^succeeded$' "$D/want.cd")" = 8 ] || refuse "sbl does not compile the 8 control texts as measured"
grep -qx 'counted: failed 226 limit 9' "$D/want.lim" && grep -qx 'zero: failed 221 and the run goes on' "$D/want.lim" || refuse "sbl's &ERRLIMIT arms read otherwise: $(tr '\n' '|' < "$D/want.lim")"
RC=0
for m in m3 m4; do
    run $m cd "$D/lines.txt" > "$D/got.cd.$m"
    if cmp -s "$D/want.cd" "$D/got.cd.$m"; then echo "  ok    $m: 19 raising texts trapped by sbl's numbers and failed after CONTINUE, 8 controls compiled"
    else RC=1; echo "  RED   $m: the CODE lines differ from sbl's"; diff "$D/want.cd" "$D/got.cd.$m" | head -12 | sed 's/^/        /'; fi
    run $m lim > "$D/got.lim.$m"
    if cmp -s "$D/want.lim" "$D/got.lim.$m"; then echo "  ok    $m: &ERRLIMIT 10 counts the error, &ERRLIMIT 0 fails the CODE and the run goes on"
    else RC=1; echo "  RED   $m: &ERRLIMIT arms: sbl [$(tr '\n' '|' < "$D/want.lim")] scrip [$(tr '\n' '|' < "$D/got.lim.$m")]"; fi
done
[ $RC = 0 ] && echo "GATE PASS(0) [code_of_text_that_does_not_compile_raises_spitbols_compile_error]: CODE raises sbl's compile error, both modes"
[ $RC = 0 ] || echo "GATE FAIL(1) [code_of_text_that_does_not_compile_raises_spitbols_compile_error]: a CODE compile error is silent or misnumbered"
exit $RC
