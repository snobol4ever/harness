#!/usr/bin/env bash
# test_gate_sno_one_parser_one_dialect_refuses_what_sbl_refuses.sh
#
# THE RULING (ceo CEO-1428, on the cfo's question): ONE PARSER, ONE DIALECT -- whatever sbl -bf refuses at compile time
# SCRIP refuses, in the main compile and in EVAL and CODE alike, never a looser EVAL. Three texts SCRIP accepted (row
# snobol4-scrips-parser-accepts-a-doubled-quote-a-comma-list-and-an-overflowing-integer-that-spitbols-compiler-rejects):
#   'a''b' and "a""b"     sbl 220 (missing operator): SPITBOL has no doubled-quote escape, the second quote opens a new
#                         literal with no blank before it. SCRIP's lexer read '' inside a literal as one quote (CSNOBOL4).
#                         The corpus holds one such site (programs/TZ/TZ-aloiddlp.inc, a C-style '\'').
#   1 , 2                 sbl 223 (invalid use of comma) at the top level; (1 , 2) is SPITBOL's selection and stays legal.
#                         The main compile already refused it; EVAL wraps its text in parentheses before parsing, which
#                         made the comma list a selection.
#   99999999999999999999  sbl 231 (invalid numeric item), and 9223372036854775808 and -9223372036854775808 too (the
#                         digits overflow before the minus applies). SCRIP's lexer took the token with atol and EVAL's
#                         numeric fast path with strtoll, both saturating at 9223372036854775807.
# THE CURE: snobol4.l drops the two doubled-quote rules and converts T_INT with an overflow check that raises "invalid
# numeric item" as T_REAL already did; eval_build_chain refuses a comma at depth 0 before wrapping; EVAL_fn's fast path
# raises on ERANGE or INT64_MIN. EVAL's refusal is then classified by eval_sb_syntax (e9213711a), so each reads sbl's
# number. 1/TAB(2), &BAL** '0' and 1.5- 10, cured earlier, stay in as guards.
# CODE of a text that does not compile used to FAIL SILENTLY where sbl raises the compile error (CODE(' X = (1') is 226); it
# raises since the CODE row's cure and test_gate_sno_code_of_text_that_does_not_compile_raises_spitbols_compile_error grades
# the numbers, so the CODE arm here still grades only that both refuse. The static arm grades refusal (exit status), not the
# error voice.
#
# Expectations are cut from sbl -bf AT RUN TIME, both modes. rc=0 clean · rc=1 a divergence · rc=2 REFUSAL.
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
printf "1/TAB(2)\n&BAL** '0'\n1.5- 10\n'a''b'\n1 , 2\n99999999999999999999\n\"a\"\"b\"\n'a' 'b'\n(1 , 2)\nf(1 , 2)\n9223372036854775807\n9223372036854775808\n-9223372036854775808\n-9223372036854775807\n-5\n+7\n" > "$D/ev.in"
cat > "$D/code.sno" <<'SNO'
        &ERRLIMIT = 10
        C = CODE(" X = 99999999999999999999")             :S(A1)
        OUTPUT = 'int refused'                              :(A2)
A1      OUTPUT = 'int compiled'
A2      C = CODE(" Y = 'a''b'")                             :S(A3)
        OUTPUT = 'quote refused'                            :(A4)
A3      OUTPUT = 'quote compiled'
A4      C = CODE(" Z = 'a' 'b'")                            :S(A5)
        OUTPUT = 'legal refused'                            :(END)
A5      OUTPUT = 'legal compiled'
END
SNO
i=0
for body in "X = 'a''b'" 'X = "a""b"' "X = 1 , 2" "X = 99999999999999999999" "X = -9223372036854775808"; do
    i=$((i+1)); printf "        OUTPUT = 'ran'\n        %s\nEND\n" "$body" > "$D/bad$i.sno"
done
printf "        X = 'a' 'b'\n        Y = (1 , 2)\n        Z = 9223372036854775807\n        OUTPUT = X ' ' Y ' ' Z\nEND\n" > "$D/good.sno"
run_scrip() {  # $1 name $2 mode $3 stdin -> stdout; rc 3 = refused to compile
    if [ "$2" = m3 ]; then (cd "$D" && timeout -k 5 30 "$B/scrip" "$1.sno" < "$3" 2>/dev/null)
    else "$B/scrip" --compile -o "$D/$1.s" "$D/$1.sno" </dev/null >/dev/null 2>&1 || return 3
         gcc -no-pie -o "$D/$1.bin" "$D/$1.s" -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" 2>/dev/null || refuse "could not link the m4 arm of $1"
         (cd "$D" && timeout -k 5 30 "./$1.bin" < "$3" 2>/dev/null); fi
}
(cd "$D" && timeout -k 5 30 "$SBL" -bf ev.sno < ev.in > ev.sbl 2>/dev/null)
(cd "$D" && timeout -k 5 30 "$SBL" -bf code.sno < /dev/null > code.sbl 2>/dev/null)
(cd "$D" && timeout -k 5 30 "$SBL" -bf good.sno < /dev/null > good.sbl 2>/dev/null)
[ "$(wc -l < "$D/ev.sbl")" = "$(wc -l < "$D/ev.in")" ] || refuse "the oracle answered $(wc -l < "$D/ev.sbl") of $(wc -l < "$D/ev.in") EVAL lines"
grep -qx "ERROR 220" "$D/ev.sbl" && grep -qx "ERROR 223" "$D/ev.sbl" || refuse "the oracle no longer refuses 'a''b' (220) or 1 , 2 (223) -- re-read sbl"
grep -qx "int refused" "$D/code.sbl" && grep -qx "legal compiled" "$D/code.sbl" || refuse "the oracle's CODE arm changed -- re-read sbl"
for k in 1 2 3 4 5; do (cd "$D" && timeout -k 5 30 "$SBL" -bf "bad$k.sno" < /dev/null > "bad$k.sbl" 2>&1); r=$?; [ "$r" -ne 0 ] && ! grep -qx "ran" "$D/bad$k.sbl" || refuse "sbl compiled bad$k.sno ($(sed -n 2p "$D/bad$k.sno")) -- the oracle no longer refuses it"; done
fails=0; arms=0
for m in m3 m4; do
    for a in ev code good; do
        arms=$((arms+1)); in=/dev/null; [ "$a" = ev ] && in="$D/ev.in"
        run_scrip "$a" "$m" "$in" > "$D/$a.$m"
        if cmp -s "$D/$a.sbl" "$D/$a.$m"; then printf '  ok    %s %-5s %s lines, as sbl\n' "$m" "$a" "$(wc -l < "$D/$a.sbl")"
        else printf '  FAIL  %s %-5s\n' "$m" "$a"; diff "$D/$a.sbl" "$D/$a.$m" | head -6 | sed 's/^/          /'; fails=$((fails+1)); fi
    done
    for k in 1 2 3 4 5; do
        arms=$((arms+1)); run_scrip "bad$k" "$m" /dev/null > "$D/bad$k.$m"; r=$?
        if [ "$m" = m4 ] && [ "$r" = 3 ]; then printf '  ok    %s bad%s  refused to compile, as sbl: %s\n' "$m" "$k" "$(sed -n 2p "$D/bad$k.sno" | sed 's/^ *//')"
        elif [ "$m" = m3 ] && [ "$r" -ne 0 ] && ! grep -qx "ran" "$D/bad$k.$m"; then printf '  ok    %s bad%s  refused to compile, as sbl: %s\n' "$m" "$k" "$(sed -n 2p "$D/bad$k.sno" | sed 's/^ *//')"
        else printf '  FAIL  %s bad%s  COMPILED what sbl refuses: %s\n' "$m" "$k" "$(sed -n 2p "$D/bad$k.sno" | sed 's/^ *//')"; fails=$((fails+1)); fi
    done
done
[ "$fails" -eq 0 ] || { echo "⛔ GATE FAILED: $fails of $arms arm(s) red."
    echo "   A doubled quote read as one quote is snobol4.l's string states; an overflowing integer accepted is T_INT's conversion or EVAL_fn's"
    echo "   numeric fast path; 1 , 2 accepted in EVAL is eval_build_chain's depth-0 comma refusal."; exit 1; }
echo "✅ GATE OK: $arms arm(s) -- SCRIP refuses the doubled quote, the top-level comma and the overflowing integer where sbl does, in the main compile, EVAL and CODE, both modes"
exit 0
