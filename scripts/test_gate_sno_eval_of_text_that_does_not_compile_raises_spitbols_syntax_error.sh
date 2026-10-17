#!/usr/bin/env bash
# test_gate_sno_eval_of_text_that_does_not_compile_raises_spitbols_syntax_error.sh
#
# SPITBOL'S RULE (sbl.min scane scn07-scn51 and expan exp02-exp24, read by the cfo 2026-10-02 for ceo CEO-1419's ticket
# snobol4-eval-of-text-that-does-not-compile-raises-spitbols-syntax-error-where-scrip-fails-the-eval): EVAL of text that
# does not compile RAISES the scanner's or the expression parser's syntax error, numbered 220-233, with its own &ERRTEXT.
# Under SETEXIT it is trapped; at &ERRLIMIT > 0 it is counted; at &ERRLIMIT 0 the EVAL simply fails and the run goes on.
# That is the stage rule (CEO-1322): the compile of EVAL's text runs under stage stgee. SCRIP used to FAIL the EVAL
# silently with &ERRTEXT 'parse error: syntax error'. Found by Lon's infinite_snobol4 demo: 11,285 of 20,000 random
# expressions read this way.
# THE CURE (runtime_eval.c rt_eval_syntax_raise): when SCRIP's own parser has REJECTED the text, eval_sb_syntax runs
# SPITBOL's element rules and three-state expression machine over it and names the first error SPITBOL would raise.
# Text SCRIP accepts is never classified, so no EVAL that works today changes. A position the port does not model (a
# ';' or ':' outside an open paren) is declined, and the EVAL fails as before. A BINARY '=' IS MODELED since the cfo's row
# snobol4-a-syntax-error-inside-an-eval-assignment-reads-fail-where-spitbol-raises-233 (CEO-1448): it needs a left operand
# (221) and its right side is classified like any expression, except that it may be EMPTY -- (X =) is the null string in sbl.
# Its sixteen arms run as a second evaluator pass (lines2.txt), so each pass stays under the 32-trap ceiling below.
# FAIL-ONCE, MEASURED with this gate on the parent (runtime_eval.c stashed, SCRIP c07aa9bd2): the eleven raising lines read FAIL
# in both modes, 22 arms RED; the five valid ones agreed already. On the cure 92/92.
# NOT COVERED, AND WHY: text SCRIP's parser ACCEPTS where SPITBOL rejects it (1/TAB(2), &BAL** '0', 1.5- 10,
# 99999999999999999999) is a different class: the parser's leniency, not this raise. A name operator or assignment
# whose target is not a name (1 . 2, 1 = 2, sbl 212) is a lowering FATAL in SCRIP, another class.
#
# Each arm grades the evaluator's line for one text, both modes, against sbl -bf cut AT RUN TIME. The run stays under
# 32 trapped errors, because a trap still nests (ticket snobol4-setexit-trapped-errors-leak-stack-to-error-246-and-stop-
# raising-after-32). rc=0 clean · rc=1 a divergence · rc=2 REFUSAL.
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
errh    OUTPUT = 'ERROR ' &ERRTYPE ' ' &ERRTEXT                 :(loop)
END
SNO
cat > "$D/lines.txt" <<'TXT'
* 2
- 0
1 +
 - 0
-
2+ 1
'x' ? - 1
0?2
x+ 1
2**3
1'a'
'a'1
[1]
(1
1)
(1]
x[1
x[1)
f(1,2))
f(1
(1;2)
x[1;2
'abc
\1
{
1x
1..2
1 'a'
1e5
.5
-.5
(.5)
.'a'
TXT
cat > "$D/lines2.txt" <<'TXT'
(b = ANY('ab')^ POS(2))
(u = ')'?&OUTPUT FENCE(LEN(1)))
(x = * FENCE(LEN(1)))
(x = + 5)
'a' ? (x = '[' - + TAB(2))
(X = (1 +))
(X = 'abc)
(X = 1 2 ))
X = (1
( = 1)
(X = = 1)
(X =)
(X = Y =)
(X = ())
(X = 1)
X = 1
TXT
cat > "$D/lim.sno" <<'SNO'
        X = EVAL('1 +')                                         :S(A)
        OUTPUT = 'zero: the EVAL failed and the run goes on, ERRLIMIT=' &ERRLIMIT
A       &ERRLIMIT = 5
        X = EVAL('(1')                                          :S(B)
        OUTPUT = 'five: failed, counted, ERRLIMIT=' &ERRLIMIT ' ERRTYPE=' &ERRTYPE ' [' &ERRTEXT ']'
B       OUTPUT = 'end'
END
SNO
run_scrip() {  # $1 program $2 mode $3 stdin -> stdout
    if [ "$2" = m3 ]; then (cd "$D" && timeout -k 5 30 "$B/scrip" --stlimit "$1.sno" < "$3" 2>/dev/null)
    else "$B/scrip" --stlimit --compile -o "$D/$1.s" "$D/$1.sno" </dev/null >/dev/null 2>&1 \
           && gcc -no-pie -o "$D/$1.bin" "$D/$1.s" -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" 2>/dev/null \
           || refuse "could not build the m4 arm of $1 -- a toolchain failure, not a verdict"
         (cd "$D" && timeout -k 5 30 "./$1.bin" < "$3" 2>/dev/null); fi
}
(cd "$D" && timeout -k 5 30 "$SBL" -bf ev.sno < lines.txt > ev.sbl 2>/dev/null)
(cd "$D" && timeout -k 5 30 "$SBL" -bf ev.sno < lines2.txt > ev2.sbl 2>/dev/null)
[ "$(wc -l < "$D/ev2.sbl")" = "$(wc -l < "$D/lines2.txt")" ] || refuse "the oracle answered $(wc -l < "$D/ev2.sbl") of the assignment lines -- the witness is not measuring"
(cd "$D" && timeout -k 5 30 "$SBL" -bf lim.sno < /dev/null > lim.sbl 2>/dev/null)
nl=$(wc -l < "$D/lines.txt")
[ "$(wc -l < "$D/ev.sbl")" = "$nl" ] || refuse "the oracle answered $(wc -l < "$D/ev.sbl") of $nl lines -- the witness is not measuring"
grep -qx "ERROR 221 syntax error: missing operand" "$D/ev.sbl" || refuse "the oracle no longer raises 221 for EVAL('1 +') -- re-read sbl before trusting this gate"
grep -q "^zero: the EVAL failed and the run goes on, ERRLIMIT=0$" "$D/lim.sbl" || refuse "the oracle's &ERRLIMIT 0 control did not print -- re-read sbl"
fails=0; arms=0
for m in m3 m4; do
    for pass in "lines.txt ev.sbl ev" "lines2.txt ev2.sbl ev2"; do set -- $pass
    run_scrip ev "$m" "$D/$1" > "$D/$3.$m"
    i=0
    while IFS= read -r txt; do
        i=$((i+1)); arms=$((arms+1)); want=$(sed -n "${i}p" "$D/$2"); got=$(sed -n "${i}p" "$D/$3.$m")
        if [ "$want" = "$got" ]; then printf '  ok    %s %-12s %s\n' "$m" "[$txt]" "$want"
        else printf '  FAIL  %s %-12s sbl: %s   scrip: %s\n' "$m" "[$txt]" "$want" "${got:-<no line>}"; fails=$((fails+1)); fi
    done < "$D/$1"
    done
    run_scrip lim "$m" /dev/null > "$D/lim.$m"; arms=$((arms+1))
    if cmp -s "$D/lim.sbl" "$D/lim.$m"; then echo "  ok    $m &ERRLIMIT 0 fails the EVAL quietly; &ERRLIMIT 5 counts it: $(tr '\n' '|' < "$D/lim.sbl")"
    else echo "  FAIL  $m &ERRLIMIT arm: sbl [$(tr '\n' '|' < "$D/lim.sbl")] scrip [$(tr '\n' '|' < "$D/lim.$m")]"; fails=$((fails+1)); fi
done
[ "$fails" -eq 0 ] || { echo "⛔ GATE FAILED: $fails of $arms arm(s) red."
    echo "   An arm reading FAIL where sbl reads ERROR n is EVAL's parse failure no longer raised (runtime_eval.c rt_eval_syntax_raise);"
    echo "   an arm reading a different ERROR number is eval_sb_syntax's port of scane/expan disagreeing with sbl.min."; exit 1; }
echo "✅ GATE OK: $arms arm(s) -- EVAL of text that does not compile raises SPITBOL's syntax error, numbered and worded as sbl's, fails quietly at &ERRLIMIT 0 and is counted above it, both modes"
exit 0
