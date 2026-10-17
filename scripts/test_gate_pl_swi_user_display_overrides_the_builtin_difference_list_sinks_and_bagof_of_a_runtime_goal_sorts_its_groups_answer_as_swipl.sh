#!/usr/bin/env bash
# test_gate_pl_swi_user_display_overrides_the_builtin_difference_list_sinks_and_bagof_of_a_runtime_goal_sorts_its_groups_answer_as_swipl.sh -- THREE SWI BEHAVIOURS THE ProRosetta CRAWL FOUND (hq_prolog 2026-10-15, row prolog-every-suite-to-100-under-tenet-ceo-1562; wireworld and
# stem-and-leaf-plot): (1) a file that DEFINES display/1 (swipl: library(edinburgh), not a system predicate) calls its own definition, not the built-in that prints
# a term with canonical lists -- the det-leaf table in lower_prolog.c now yields to a file definition of the names swipl keeps outside the system module
# (pl_swi_library_leaf: display/1,2, concat_atom/2,3, numbervars/1, string_to_atom/2, read_term_from_chars/3 ...); (2) format/3 and with_output_to/2 accept the
# difference-list sinks codes(Cs, Tail) and chars(Cs, Tail) (library(dcg/basics) integer//1 writes through format(codes(H, T), ...)); (3) bagof/setof over a goal that is
# a runtime value (library(solution_sequences) group_by/4 builds ExistsTerm^Goal at run time) sorts its groups by witness as swipl does ('$bagof_var' now keysorts).
# THE ARM: one witness cut against swipl -q in this run and diffed in mode 3 and mode 4.  RED BEFORE (the parent 596e8b1b6): display prints the term, codes/2 raises
# domain_error(stream_or_alias, ...), the groups come out in first-solution order.
# rc=0 both modes agree with swipl - rc=1 a divergence - rc=2 REFUSAL (no swipl, no build).  ~3 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
GATE=test_gate_pl_swi_user_display_overrides_the_builtin_difference_list_sinks_and_bagof_of_a_runtime_goal_sorts_its_groups_answer_as_swipl
refuse() { echo "REFUSED(2) [$GATE]: $*"; exit 2; }
command -v swipl >/dev/null 2>&1 || refuse "no swipl on PATH -- the oracle"
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate $GATE || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/w.pl" <<'PL'
:- use_module(library(lists)).
:- use_module(library(dcg/basics)).
:- use_module(library(solution_sequences)).
:- initialization(main).
display(G) :- write(user(G)), nl.
concat_atom(L, R) :- atomic_list_concat(L, '-', R).
t(T, G) :- catch((call(G) -> \+ \+ (numbervars(T, 0, _), writeq(T)) ; writeq(no)), error(E, _), \+ \+ (numbervars(E, 0, _), writeq(caught(E)))), nl.
grp(S, L) :- group_by(S, Lf, (member(N, [12, 127, 7, 28, 42, 5, 113]), divmod(N, 10, S, Lf)), L).
main :-
    display([a, b]),
    maplist([R]>>display(R), [[c], [d]]),
    t(A, concat_atom([x, y, z], A)),
    t(Cs-T, (format(codes(Cs, T), "~w-~a", [12, x]), T = [0'!])),
    t(Hs, (format(chars(Hs, T2), "~d", [345]), T2 = [z])),
    t(C1, (with_output_to(codes(C1, T3), write(abc)), T3 = [])),
    t(C2, (with_output_to(chars(C2, T4), (write(a), write(b))), T4 = [c])),
    t(D1, phrase(integer(12), D1)),
    t(D2, (phrase(integer(345), D2, [0'x]))),
    t(Gs, findall(S-L, grp(S, L), Gs)),
    t(Bs, findall(S-L, (G = (member(N, [12, 127, 7, 28, 42, 5, 113]), divmod(N, 10, S, Lf)), E =.. [v, N], bagof(Lf, E^G, L)), Bs)),
    t(Ss, findall(S-L, (G = (member(N, [12, 127, 7, 28, 42, 5, 113, 7]), divmod(N, 10, S, Lf)), setof(Lf, N^G, L)), Ss)).
PL
( cd "$D" && timeout -k 5 30 swipl -q -t halt w.pl < /dev/null > want 2> /dev/null )
[ -s "$D/want" ] || refuse "swipl printed nothing for the witness"
( cd "$D" && timeout -k 5 30 "$B/scrip" --run w.pl < /dev/null > m3 2> m3.err )
( cd "$D" && timeout -k 5 60 "$B/scrip" --compile -o w.s w.pl < /dev/null 2> m4.err && gcc -no-pie w.s -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" -o w 2>> m4.err && timeout -k 5 30 ./w < /dev/null > m4 2>> m4.err )
n=$(wc -l < "$D/want"); red=0
for m in m3 m4; do
    if cmp -s "$D/want" "$D/$m"; then echo "  $m GREEN: $n of $n lines as swipl"
    else echo "  $m RED: $(diff "$D/want" "$D/$m" 2>/dev/null | grep -c '^<') of $n lines differ from swipl"; diff "$D/want" "$D/$m" 2>/dev/null | head -10 | sed 's/^/    /'; red=1; fi
done
[ "$red" = 0 ] && echo "PASS $GATE"
exit "$red"
