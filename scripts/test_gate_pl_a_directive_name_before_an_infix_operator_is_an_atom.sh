#!/usr/bin/env bash
# test_gate_pl_a_directive_name_before_an_infix_operator_is_an_atom.sh -- the twelve directive names the Prolog parser reads as
# prefix declarations (dynamic discontiguous multifile module_transparent meta_predicate use_module ensure_loaded table
# thread_local public record mode) are ATOMS when an infix operator follows them, and declarations everywhere else, both modes
# (row prolog-a-directive-name-before-an-infix-operator-is-an-atom-so-use-module-slash-1-parses, minted by the ceo 2026-10-02 from
# the Logtalk 3.103.0-b01 run: nine lines of Logtalk's core.pl died on X = f(use_module/1) with "expected ) to close argument list").
#
# THE CURE (src/parsers/prolog/prolog_parse.c, the TK_ATOM case's directive-name block): the block's own token-kind list is replaced
# by prefix_arg_starts(), the rule every other prefix operator obeys, which reads an infix-only operator after the name as "no
# argument starts here".
# WITNESS A, cut 2026-10-03 from gplc 1.4.5: every name before / in a list, use_module/1 inside f(...), ensure_loaded/1 as an
#   argument, dynamic as the left operand of =, the bare names in a list, and the functional declaration forms in use.
# WITNESS B, cut 2026-10-03 from swipl 9.0.4 (gplc holds none of the names as operators and refuses these forms): the PREFIX
#   declaration forms -- :- dynamic foo/1.  :- dynamic bar/1, baz/2.  :- multifile m1/1. -- still declare (assertz, retract and
#   a call of the multifile predicate with no clauses fail as declared predicates do). These are the over-cure controls: a cure that
#   stopped reading the names as prefix operators passes witness A and fails here.
# NOT GRADED: calling a discontiguous(d1/1) predicate with no clauses -- the oracles disagree (gplc raises existence_error, swipl
# fails, SCRIP fails as swipl does), so no witness here grades it.
# FAIL-ONCE: on the parent the whole of witness A is a parse error (main never runs).
# Usage: bash ../harness/scripts/test_gate_pl_a_directive_name_before_an_infix_operator_is_an_atom.sh
set -uo pipefail
GATE_NAME=test_gate_pl_a_directive_name_before_an_infix_operator_is_an_atom
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"
OUT="${RT_DIR:-$HERE/../../SCRIP/out}"
[ -x "$SCRIP" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no scrip binary at $SCRIP -- run make first"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$OUT/libscrip_rt.so" || exit 2
d=$(mktemp -d) || exit 2
trap 'rm -rf "$d"' EXIT
cat > "$d/a.pl" <<'PL'
:- dynamic(foo/1).
:- dynamic(bar/1). :- dynamic(baz/2).
:- dynamic((qux/1, quux/1)).
:- multifile(m1/1).
foo(1).
bar(2).
baz(3, 4).
qux(5).
quux(6).
:- initialization(main).
main :-
    forall(member(T, [dynamic/1, discontiguous/1, multifile/1, module_transparent/1, meta_predicate/1, use_module/1,
                      ensure_loaded/1, table/1, thread_local/1, public/1, record/1, mode/1]),
           (T = N/A, write(N), write(' '), write(A), nl)),
    X = f(use_module/1), X = f(N1/A1), write(N1-A1), nl,
    Y = g(a, ensure_loaded/1), arg(2, Y, Z), functor(Z, F, Ar), write(F/Ar), nl,
    E = (dynamic = 1), E = (L = R), write(L), write(' '), write(R), nl,
    P = [table, record, mode], length(P, Len), write(Len), nl,
    foo(A2), bar(B2), baz(C2, D2), qux(E2), quux(F2), write([A2, B2, C2, D2, E2, F2]), nl,
    ( catch(m1(_), Err2, (write(caught(Err2)), nl)) -> true ; write(m1_fails), nl ).
PL
cat > "$d/a.want" <<'WANT'
dynamic 1
discontiguous 1
multifile 1
module_transparent 1
meta_predicate 1
use_module 1
ensure_loaded 1
table 1
thread_local 1
public 1
record 1
mode 1
use_module-1
(/)/2
dynamic 1
3
[1,2,3,4,5,6]
m1_fails
WANT
cat > "$d/b.pl" <<'PL'
:- dynamic foo/1.
:- dynamic bar/1, baz/2.
:- dynamic((qux/1, quux/1)).
:- multifile m1/1.
foo(1).
bar(2).
baz(3, 4).
qux(5).
quux(6).
:- initialization(main).
main :- foo(A), bar(B), baz(C, D), qux(E), quux(F), write([A, B, C, D, E, F]), nl,
    assertz(bar(7)), findall(X, bar(X), L), write(L), nl,
    ( m1(_) -> write(m1_true) ; write(m1_fails) ), nl,
    retract(foo(1)), ( foo(_) -> write(foo_left) ; write(foo_gone) ), nl.
PL
cat > "$d/b.want" <<'WANT'
[1,2,3,4,5,6]
[2,7]
m1_fails
foo_gone
WANT
fails=0; graded=0
for w in a b; do
    (cd "$d" && timeout -k 5 20 "$SCRIP" $w.pl </dev/null 2>/dev/null) > "$d/$w.m3"; rc=$?; graded=$((graded + 1))
    if [ $rc -ne 0 ] || ! cmp -s "$d/$w.want" "$d/$w.m3"; then fails=$((fails + 1)); echo "  witness $w m3 rc=$rc differs:"; diff "$d/$w.want" "$d/$w.m3" | head -12; fi
    if (cd "$d" && timeout -k 5 60 "$SCRIP" --compile --out=$w.s $w.pl </dev/null >/dev/null 2>&1 && gcc -m64 -no-pie $w.s -L"$OUT" -lscrip_rt -lm -lpthread -Wl,-rpath,"$OUT" -o $w.bin 2>/dev/null); then
        (cd "$d" && timeout -k 5 20 ./$w.bin </dev/null 2>/dev/null) > "$d/$w.m4"; rc=$?; graded=$((graded + 1))
        if [ $rc -ne 0 ] || ! cmp -s "$d/$w.want" "$d/$w.m4"; then fails=$((fails + 1)); echo "  witness $w m4 rc=$rc differs:"; diff "$d/$w.want" "$d/$w.m4" | head -12; fi
    else graded=$((graded + 1)); fails=$((fails + 1)); echo "  witness $w m4 did not compile or link"; fi
done
[ "$(grep -c '' "$d/a.want")" -eq 18 ] && [ "$(grep -c '' "$d/b.want")" -eq 4 ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: an expectation table is not the oracle cut it names"; exit 2; }
echo "PLDIRNAME_BOARD witnesses=2 modes=2 graded=$graded PASS=$((graded - fails)) FAIL=$fails"
[ $fails -eq 0 ] || exit 1
exit 0
