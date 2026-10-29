#!/usr/bin/env bash
# test_gate_pl_swi_dialect_format_s_does_not_pad_and_listing_prints_a_dynamic_predicate_as_swipl.sh -- in a program SCRIP reads as SWI-Prolog (it carries a use_module directive), format's ~Ns prints at most N
# characters and never pads, and listing/1 prints a dynamic predicate as swipl 9.0.4 does: ":- dynamic p/1.", a blank line, the clauses, a blank line; m3 and m4 (hq_packages 2026-10-22, the XSB package's
# prolog_tests_format_test: "6 Hello new  worl!" where swipl prints "6 Hello new worl!", and prolog_tests_listing_test: listing/1 raised existence_error outside the GNU dialect).
# THE DIALECTS DISAGREE AND BOTH ARE RIGHT: GNU Prolog 1.6.0 pads ("[new ]", measured through oracle_gprolog.sh), swipl does not ("[new]"); the padding stays for the default dialect and the GNU one, and only the SWI
# dialect (rt_pl_dialect_swi in rt_pl_format_run) leaves it off. listing/1 under the GNU dialect keeps its own "% file:" form. The listing is implemented for dynamic predicates, and a rule's body prints in SCRIP's GNU layout (tab indent, spaced operators) where swipl indents four spaces and prints A>1: the SWI clause layout of portray_clause is a row of its own, not asserted here.
# THE REFS ARE CUT FROM THE ORACLE, NEVER FROM SCRIP: every run re-cuts them from the live /usr/bin/swipl and REFUSES rc=2 when the table and the oracle disagree.
# Usage: bash ../harness/scripts/test_gate_pl_swi_dialect_format_s_does_not_pad_and_listing_prints_a_dynamic_predicate_as_swipl.sh
set -uo pipefail
GATE_NAME=test_gate_pl_swi_dialect_format_s_does_not_pad_and_listing_prints_a_dynamic_predicate_as_swipl
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"
OUT="${RT_DIR:-$HERE/../../SCRIP/out}"
SWIPL=/usr/bin/swipl
[ -x "$SCRIP" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no scrip binary at $SCRIP -- run make first"; exit 2; }
[ -x "$SWIPL" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no oracle at $SWIPL"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$OUT/libscrip_rt.so" || exit 2
d=$(mktemp -d) || exit 2
trap 'rm -rf "$d"' EXIT
cat > "$d/w.pl" <<'PL'
:- use_module(library(lists)).
t1 :- format("[~4s]~n", ["new"]), format("[~4s]~n", ["world"]), format("[~s]~n", ["abc"]), format("[~a~t~8|]~n", [ab]).
t2 :- assertz(p(1)), assertz(p(2)), listing(p/1).
t3 :- assertz(q(0)), assertz(q(a)), assertz(q("s")), listing(q/1).
:- initialization((t1, t2, t3, halt)).
PL
(cd "$d" && timeout -k 5 60 "$SWIPL" -q w.pl </dev/null > "$d/want" 2>/dev/null)
head -3 "$d/want" | tr '\n' '|' | grep -q '^\[new\]|\[worl\]|\[abc\]|$' || { echo "⛔ REFUSED(2) [$GATE_NAME]: the oracle's format lines are not the expected ones: $(head -3 "$d/want" | tr '\n' '|')"; exit 2; }
fails=0; graded=0
(cd "$d" && timeout -k 5 60 "$SCRIP" w.pl </dev/null 2>/dev/null > "$d/m3"); rc=$?; graded=$((graded + 1))
if [ $rc -ne 0 ] || ! cmp -s "$d/want" "$d/m3"; then fails=$((fails + 1)); echo "  m3 rc=$rc differs:"; diff "$d/want" "$d/m3" | head -10; fi
graded=$((graded + 1))
if (cd "$d" && timeout -k 5 120 "$SCRIP" --compile --out=w.s w.pl </dev/null >/dev/null 2>&1 && gcc -no-pie -o w.bin w.s "$OUT/libscrip_rt.so" -lm -Wl,-rpath,"$OUT" 2>/dev/null); then
    (cd "$d" && timeout -k 5 60 ./w.bin </dev/null 2>/dev/null > "$d/m4"); rc=$?
    if [ $rc -ne 0 ] || ! cmp -s "$d/want" "$d/m4"; then fails=$((fails + 1)); echo "  m4 rc=$rc differs:"; diff "$d/want" "$d/m4" | head -10; fi
else fails=$((fails + 1)); echo "  m4 did not compile or link"; fi
echo "PLSWIFMTLST_BOARD arms=2 modes=2 graded=$graded PASS=$((graded - fails)) FAIL=$fails"
[ $fails -eq 0 ] || exit 1
exit 0
