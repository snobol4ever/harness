#!/usr/bin/env bash
# test_gate_pl_a_prelude_dcg_rule_reaches_the_program_that_calls_it.sh -- a nonterminal the prelude defines as a DCG rule
# (utf8_codes//1 of library(utf8), sequence//2 of library(dcg/high_order)) reaches a program that calls it, and a program
# that defines a nonterminal of the same name keeps its own (cto 2026-10-01, on hq_prolog's report: swi_tests test_utf8
# fell from 45 to 0 of 94).
#
# THE REGRESSION THIS PINS, AND IT WAS MINE. b1cde82b2 (the parser_prolog.sc tree landing) moved the C parser's DCG
# translation into the lowerer's pre-pass, so a DCG rule reaches prolog_inject_prelude untranslated as
# (TT_CLAUSE (TT_FNC --> Head Body)). pl_clause_key keyed it -->/2 and the dependency walk read no body, so no prelude DCG
# rule was ever wanted: phrase(utf8_codes(L), Codes) raised existence_error(procedure, utf8_codes/3). pl_clause_key now
# keys a DCG rule by its nonterminal (the head left of a pushback) with arity + 2, and pl_clause_body hands the walk the
# rule's body. A user DCG rule is keyed the same way, which is what keeps the prelude's row out when the user defines it.
# rc 0 green · 1 red · 2 could not measure.
set -uo pipefail
GATE_NAME=test_gate_pl_a_prelude_dcg_rule_reaches_the_program_that_calls_it
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"; cd "$ROOT"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"
[ -x "$SCRIP" ] || { echo "⛔ REFUSE(2) [$GATE_NAME]: no scrip at $SCRIP"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "${RT_DIR:-$ROOT/out}/libscrip_rt.so" || exit 2
D=$(mktemp -d) || { echo "⛔ REFUSE(2) [$GATE_NAME]: no tmpdir"; exit 2; }
trap 'rm -rf "$D"' EXIT
cat > "$D/pre.pl" <<'PLEOF'
:- initialization(main).
main :- ( catch(phrase(utf8_codes(L), [104,195,169]), E, (writeq(E), nl, fail)) -> writeq(L) ; writeq(no) ), nl,
        ( catch(phrase(sequence(digit, Ds), [49,50]), E2, (writeq(E2), nl, fail)) -> writeq(Ds) ; writeq(no) ), nl, halt.
digit(D) --> [D].
PLEOF
cat > "$D/own.pl" <<'PLEOF'
:- initialization(main).
utf8_codes([own|T]) --> [_], !, utf8_codes(T).
utf8_codes([]) --> [].
main :- phrase(utf8_codes(L), [1,2]), writeq(L), nl, halt.
PLEOF
want_pre='[104,233]
[49,50]'
want_own='[own,own]'
PASS=0; FAIL=0; N=0
for w in pre own; do
    [ "$w" = pre ] && want="$want_pre" || want="$want_own"
    for mode in m3 m4; do
        N=$((N+1))
        if [ "$mode" = m3 ]; then got=$(cd "$D" && timeout -k 5 20 "$SCRIP" "$D/$w.pl" </dev/null 2>&1)
        else
            if (cd "$D" && timeout -k 5 60 "$SCRIP" --compile -o "$D/$w.s" "$D/$w.pl" </dev/null >/dev/null 2>&1) \
               && gcc -m64 "$D/$w.s" -o "$D/$w.bin" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm >/dev/null 2>&1; then
                got=$(cd "$D" && timeout -k 5 20 "$D/$w.bin" </dev/null 2>&1)
            else echo "  RED  $w $mode: the witness failed to compile or link"; FAIL=$((FAIL+1)); continue; fi
        fi
        if [ "$got" = "$want" ]; then PASS=$((PASS+1))
        else printf '  RED  %s %s: got\n%s\n       want\n%s\n' "$w" "$mode" "$got" "$want"; FAIL=$((FAIL+1)); fi
    done
done
[ "$N" -gt 0 ] || { echo "⛔ REFUSE(2) [$GATE_NAME]: graded ZERO witnesses"; exit 2; }
echo "PL PRELUDE DCG RULES: PASS=$PASS FAIL=$FAIL / $N arms graded (2 witnesses x m3+m4)"
[ "$FAIL" -eq 0 ] && { echo "verdict=GREEN -- utf8_codes//1 and sequence//2 reach the program, and a program's own utf8_codes//1 wins"; exit 0; }
echo "verdict=RED"; exit 1
