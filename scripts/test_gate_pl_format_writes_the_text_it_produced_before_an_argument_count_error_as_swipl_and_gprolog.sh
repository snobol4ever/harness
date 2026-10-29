#!/usr/bin/env bash
# test_gate_pl_format_writes_the_text_it_produced_before_an_argument_count_error_as_swipl_and_gprolog.sh -- format/2 writes the text it produced
# before an argument-count error, as swipl 10 and gprolog 1.6 do, in both modes (row prolog-rosetta-eight-programs-crash-or-fail-with-one-output-shape-knights-tour-2-and-kin-ceo-1887,
# hq_prolog 2026-10-22: Rosetta knights-tour-2 calls format('%3.0d',[N]) -- a C directive, so the whole text is literal and the argument is left over -- and swipl and gprolog print
# %3.0d before the error while SCRIP raised first and printed nothing outside the GNU dialect).
# WHAT IS GRADED: five calls, each in a catch that prints a marker: too many arguments (abc with [1]), not enough ((a~wb~wc) with [x] and (x~w~n~w) with [a]), a leftover argument after ~w,
# and the C-style directive; the stdout of both modes equals swipl's (error terms are not printed -- their shapes differ by system and are not the point).
# THE REF IS CUT FROM THE ORACLE, NEVER FROM SCRIP: the expectation below was cut 2026-10-22 from /usr/bin/swipl by absolute path (gprolog 1.6.0 prints the same bytes, checked the same day),
# and every run re-cuts it from the live swipl and REFUSES rc=2 when the oracle and the table disagree or swipl is absent.
# FAIL-ONCE: on origin 37138a1dd (the baseline binary, same engine) both modes printed only the caught markers (0 of 2); the cure reads 2 of 2.
# Usage: bash ../harness/scripts/test_gate_pl_format_writes_the_text_it_produced_before_an_argument_count_error_as_swipl_and_gprolog.sh
set -uo pipefail
GATE_NAME=test_gate_pl_format_writes_the_text_it_produced_before_an_argument_count_error_as_swipl_and_gprolog
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"
OUT="${RT_DIR:-$HERE/../../SCRIP/out}"
SWIPL=/usr/bin/swipl
[ -x "$SCRIP" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no scrip binary at $SCRIP -- run make first"; exit 2; }
[ -x "$SWIPL" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no oracle at $SWIPL"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$OUT/libscrip_rt.so" || exit 2
d=$(mktemp -d) || exit 2
trap 'rm -rf "$d"' EXIT
cat > "$d/scc.pl" <<'PL'
t(G) :- catch(G, E, (nl, write(caught), nl)), nl, write('--'), nl.
:- initialization(main).
main :- t(format("abc", [1])), t(format("a~wb~wc", [x])), t(format("~w", [a, b])), t(format("x~w~n~w", [a])), t(format("%3.0d", [5])), halt.
PL
cat > "$d/scc.want" <<'WANT'
abc
caught

--
axb
caught

--
a
caught

--
xa

caught

--
%3.0d
caught

--
WANT
fails=0; graded=0
"$SWIPL" -q -g main -t halt "$d/scc.pl" </dev/null > "$d/scc.oracle" 2>/dev/null
cmp -s "$d/scc.want" "$d/scc.oracle" || { echo "⛔ REFUSED(2) [$GATE_NAME]: the expectation table is not what $SWIPL prints now"; diff "$d/scc.want" "$d/scc.oracle" | head -5; exit 2; }
timeout -k 5 20 "$SCRIP" "$d/scc.pl" </dev/null 2>/dev/null > "$d/scc.m3"; rc=$?; graded=$((graded + 1))
if [ $rc -ne 0 ] || ! cmp -s "$d/scc.want" "$d/scc.m3"; then fails=$((fails + 1)); echo "  m3 rc=$rc differs:"; diff "$d/scc.want" "$d/scc.m3" | head -10; fi
graded=$((graded + 1))
if timeout -k 5 60 "$SCRIP" --compile --out="$d/scc.s" "$d/scc.pl" </dev/null >/dev/null 2>&1; then
    if as --64 -o "$d/scc.o" "$d/scc.s" 2> "$d/scc.aserr" && gcc -no-pie -o "$d/scc.bin" "$d/scc.o" "$OUT/libscrip_rt.so" -lm -lstdc++ -Wl,-rpath,"$OUT" 2>/dev/null; then
        timeout -k 5 20 "$d/scc.bin" </dev/null 2>/dev/null > "$d/scc.m4"; rc=$?
        if [ $rc -ne 0 ] || ! cmp -s "$d/scc.want" "$d/scc.m4"; then fails=$((fails + 1)); echo "  m4 rc=$rc differs:"; diff "$d/scc.want" "$d/scc.m4" | head -10; fi
    else fails=$((fails + 1)); echo "  m4 did not assemble or link:"; head -3 "$d/scc.aserr" | cut -c1-200; fi
else fails=$((fails + 1)); echo "  m4 did not compile"; fi
echo "PLFMTERR_BOARD programs=1 modes=2 graded=$graded PASS=$((graded - fails)) FAIL=$fails"
[ $fails -eq 0 ] || exit 1
exit 0
