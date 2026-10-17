#!/usr/bin/env bash
# test_gate_pl_an_xsb_import_loads_the_module_beside_the_file_and_its_header_as_swipl.sh -- XSB's module interaction in a file loaded at run time
# (load_files/2 with dialect(xsb)), as SWI's xsb/ai_tests drive it (hq_prolog 2026-10-17, xsb_test_ai 0 -> 11 of 11 in both modes), answered as swipl 9.0.4, m3 and m4.
# (1) :- import Ps from Mod, where Mod.P lies beside the importing file, loads Mod.P into module Mod (once) and a call to an imported predicate reaches
#     Mod's definition (qsort.P imports set_unify/2 from set_unify; the loader ignored import/1 and every call was existence_error).
# (2) Mod.H, XSB's header beside Mod.P, is read before Mod.P (can_mono.P calls flatten_sets/2, imported in can_mono.H only).
# (3) An import from a system library resolves: member/2 from basics, ord_setproduct/3 from ordsets (swipl's xsb ordsets addition, vendored as the
#     LOCAL library xsb_ordsets), variant/2 from subsumes (library terms) -- all linked for a program that references load_files.
# (4) A predicate Mod does not export and the importer does not import stays out of the importer (h/1).
# THE REFS ARE CUT FROM THE ORACLE, NEVER FROM SCRIP: the expectation below was cut 2026-10-17 from /usr/bin/swipl by absolute path and every run
# re-cuts it from the live swipl and REFUSES rc=2 when oracle and table disagree or swipl is absent. g/1 sorts its answers: a tabled predicate's
# answer order is the engine's (swipl returns [2,1]).
# FAIL-ONCE: on the parent (4e1ac56b4) m3 printed only "directive raised: existence_error(procedure, f/1)" and nothing on stdout.
# Usage: bash ../harness/scripts/test_gate_pl_an_xsb_import_loads_the_module_beside_the_file_and_its_header_as_swipl.sh
set -uo pipefail
GATE_NAME=test_gate_pl_an_xsb_import_loads_the_module_beside_the_file_and_its_header_as_swipl
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"
OUT="${RT_DIR:-$HERE/../../SCRIP/out}"
SWIPL=/usr/bin/swipl
[ -x "$SCRIP" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no scrip binary at $SCRIP -- run make first"; exit 2; }
[ -x "$SWIPL" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no oracle at $SWIPL"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$OUT/libscrip_rt.so" || exit 2
d=$(mktemp -d) || exit 2
trap 'rm -rf "$d"' EXIT
printf '%s\n' ':- export f/1.' ':- table f/1.' 'f(1).' 'f(2).' 'h(9).' > "$d/b.P"
printf '%s\n' ':- export q/1.' ':- import f/1 from b.' > "$d/c.H"
printf '%s\n' 'q(X) :- f(X).' > "$d/c.P"
cat > "$d/a.P" <<'PL'
:- import f/1 from b.
:- import q/1 from c.
:- import member/2 from basics.
:- import ord_setproduct/3 from ordsets.
:- import variant/2 from subsumes.
g(X) :- f(X).
k(L) :- findall(X, (member(X, [1,2,3]), f(X)), L).
r(L) :- findall(X, q(X), L0), msort(L0, L).
p(P) :- ord_setproduct([a,b], [c,d], P).
v(R) :- ( variant(t(_, A, A), t(_, B, B)) -> R = yes ; R = no ).
PL
cat > "$d/w.pl" <<'PL'
:- use_module(library(lists)).
:- initialization(main).
in(M, G) :- M:G.
main :- load_files(m1:'a.P', [dialect(xsb)]),
        findall(X, in(m1, g(X)), L0), msort(L0, L1), write(L1), nl,
        in(m1, k(L2)), write(L2), nl,
        in(m1, r(L3)), write(L3), nl,
        in(m1, p(P)), write(P), nl,
        in(m1, v(V)), write(V), nl,
        ( catch(in(m1, h(_)), error(existence_error(_, _), _), fail) -> write(h_visible) ; write(h_hidden) ), nl,
        halt.
PL
cat > "$d/want" <<'WANT'
[1,2]
[1,2]
[1,2]
[a-c,a-d,b-c,b-d]
yes
h_hidden
WANT
(cd "$d" && timeout -k 5 30 "$SWIPL" -q -g main -t halt w.pl </dev/null > "$d/oracle" 2>/dev/null)
cmp -s "$d/want" "$d/oracle" || { echo "⛔ REFUSED(2) [$GATE_NAME]: the expectation table is not what $SWIPL prints now"; diff "$d/want" "$d/oracle" | head -5; exit 2; }
fails=0; graded=0
(cd "$d" && timeout -k 5 30 "$SCRIP" w.pl </dev/null 2>/dev/null > "$d/m3"); rc=$?; graded=$((graded + 1))
if [ $rc -ne 0 ] || ! cmp -s "$d/want" "$d/m3"; then fails=$((fails + 1)); echo "  m3 rc=$rc differs:"; diff "$d/want" "$d/m3" | head -10; fi
graded=$((graded + 1))
if (cd "$d" && timeout -k 5 60 "$SCRIP" --compile -o w.s w.pl </dev/null >/dev/null 2>&1 && as --64 -o w.o w.s 2>/dev/null \
    && gcc -no-pie -o w.bin w.o "$OUT/libscrip_rt.so" -lm -lstdc++ -Wl,-rpath,"$OUT" 2>/dev/null); then
    (cd "$d" && timeout -k 5 30 ./w.bin </dev/null 2>/dev/null > "$d/m4"); rc=$?
    if [ $rc -ne 0 ] || ! cmp -s "$d/want" "$d/m4"; then fails=$((fails + 1)); echo "  m4 rc=$rc differs:"; diff "$d/want" "$d/m4" | head -10; fi
else fails=$((fails + 1)); echo "  m4 did not compile or link"; fi
echo "PLXSBIMPORT_BOARD programs=1 modes=2 graded=$graded PASS=$((graded - fails)) FAIL=$fails"
[ $fails -eq 0 ] || exit 1
exit 0
