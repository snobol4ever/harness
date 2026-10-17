#!/usr/bin/env bash
# test_gate_pl_swi_libraries_hashtable_nb_set_solution_sequences_csv_terms_random_answer_as_swipl.sh -- SIX MORE OF SWIPL 9.0.4'S OWN LIBRARIES ANSWER AS SWIPL, IN BOTH MODES
# (hq_prolog 2026-10-15, row prolog-every-suite-to-100-under-tenet-ceo-1562; CEO-1473's scheme, SCRIP's prelude libraries).
#
# THE CURE: library(hashtable), library(nb_set), library(solution_sequences), library(csv), library(terms) and library(random), vendored
# verbatim under src/parsers/prolog/prelude/ and embedded by util_gen_prolog_prelude_libs.py, reach a program that names one of their
# exports.  library(csv) is read AS SWI COMPILES IT (the EXPANDED set): its `:- record csv_options(...)` directive is expanded by
# library(record)'s own term expansion into the accessor clauses the library calls, the expander printing the expansion of a record
# directive instead of the directive.  library(random)'s `:- initialization check_gmp` only warns when SWI is built without GMP and is
# dropped by name.  The C-side helpers their closures call and SCRIP lacked are hand-typed in the base prelude: '$filled_array'/4,
# duplicate_term/2 (SCRIP's copy_term/2 already copies ground subterms), functor/4 (library(terms)' mapargs/3, mapsubterms/3,
# foldsubterms/4,5 and same_functor/2 call it) and '$term_size'/3 (term_size/2, in the cells swipl counts: a compound is its arity plus
# one cell, a float 3, a string (length+1)//8+3, an integer outside the 60-bit tagged range 3 plus its 64-bit limbs).
# NOT GRADED HERE, and why: a zero-arity compound f() (SCRIP reads it as the atom f), a rational's size, a shared subterm's size (swipl
# counts it once), and must_be(between(L,U), Bad) from an ISO-dialect program (clause/2 on the vendored library's has_type/2 is a
# permission_error outside the SWI dialect).
# THE ARM: one witness, each line a call cut against swipl -q in this run and diffed in mode 3 and mode 4.  RED BEFORE (the parent
# 7e5bd3989): every line names existence_error for its predicate.
# rc=0 both modes agree with swipl · rc=1 a divergence · rc=2 REFUSAL (no swipl, no build).  ~4 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
GATE=test_gate_pl_swi_libraries_hashtable_nb_set_solution_sequences_csv_terms_random_answer_as_swipl
refuse() { echo "⛔ REFUSED(2) [$GATE]: $*"; exit 2; }
command -v swipl >/dev/null 2>&1 || refuse "no swipl on PATH -- the oracle"
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate $GATE || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/w.pl" <<'PL'
:- set_prolog_flag(double_quotes, string).
:- initialization(main).
t(T, G) :- catch((call(G) -> \+ \+ (numbervars(T, 0, _), writeq(T)) ; writeq(no)), error(E, _), \+ \+ (numbervars(E, 0, _), writeq(caught(E)))), nl.
main :-
    t(r(N, V, S), (ht_new(H0), ht_put(H0, a, 1), ht_put(H0, b, 2), ht_put(H0, a, 3), ht_size(H0, N), ht_get(H0, a, V), ht_pairs(H0, Ps), msort(Ps, S))),
    t(r(Old, Sz), (ht_new(H1), ht_put_new(H1, k, 1), \+ ht_put_new(H1, k, 2), ht_del(H1, k, Old), ht_size(H1, Sz))),
    t(r(N2, KL, V2), (ht_new(H2), forall(between(1, 40, I), ht_put(H2, I, f(I))), ht_size(H2, N2), ht_keys(H2, Ks), length(Ks, KL), ht_get(H2, 7, V2))),
    t(r(O3, N3), (ht_new(H3), ht_put(H3, x, 1), ht_update(H3, x, O3, 9), ht_get(H3, x, N3))),
    t(r(New, Sz0, L0), (empty_nb_set(S0), add_nb_set(a, S0), add_nb_set(b, S0), add_nb_set(a, S0, New), size_nb_set(S0, Sz0), nb_set_to_list(S0, L0))),
    t(L1, (empty_nb_set(S1), forall(member(E, [c, a, b, a, c]), add_nb_set(E, S1)), nb_set_to_list(S1, L1))),
    t(L2, findall(X1, distinct(X1, member(X1, [a, b, a, c, b])), L2)),
    t(L3, findall(X2-Y2, distinct(X2, member(X2-Y2, [a-1, b-2, a-3])), L3)),
    t(L4, findall(X3, order_by([asc(X3)], member(X3, [c, a, b])), L4)),
    t(L5, findall(X4, order_by([desc(X4)], member(X4, [c, a, b])), L5)),
    t(L6, findall(X5-Y5, order_by([asc(X5), desc(Y5)], member(X5-Y5, [b-1, a-1, a-2, b-3])), L6)),
    t(L7, findall(X6, limit(2, member(X6, [a, b, c, d])), L7)),
    t(L8, findall(X7, offset(2, member(X7, [a, b, c, d])), L8)),
    t(L9, findall(N8-X8, call_nth(member(X8, [a, b, c]), N8), L9)),
    t(X9, call_nth(member(X9, [a, b, c]), 2)),
    t(L11, findall(K-L10, group_by(K, V10, member(K-V10, [a-1, b-2, a-3]), L10), L11)),
    t(L12, findall(X11, reduced(member(X11, [a, b, a])), L12)),
    t(Rows, phrase(csv(Rows), `a,b,c\n1,2,3\n`)),
    t(Rows2, phrase(csv(Rows2), `a,"b c",3\n`)),
    t(Rows3, phrase(csv(Rows3, [separator(0';)]), `a;b\n1;2\n`)),
    t(Rows4, phrase(csv(Rows4, [functor(r), convert(false)]), `x,1\n`)),
    t(Rows5, phrase(csv(Rows5, [strip(true)]), ` a , b \n`)),
    t(A6, (phrase(csv([row(a, 'b c'), row(1, 'x,y')]), Cs), atom_codes(A6, Cs))),
    t(Sk-Sub, term_factorized(f(g(a), g(a)), Sk, Sub)),
    t(Sk2-Sub2, term_factorized(h(X12, X12, k), Sk2, Sub2)),
    t(yes, variant(f(_, a), f(_, a))), t(yes, variant(f(A13, A13), f(_, _))),
    t(yes, subsumes(f(_, b), f(a, b))), t(yes, subsumes(f(a, b), f(_, b))),
    t(G, term_subsumer(f(a, b), f(c, b), G)),
    t(T14, mapargs([X14, Y14]>>(Y14 is X14 * 2), f(1, 2, 3), T14)),
    t(T15, mapsubterms([X15, Y15]>>(integer(X15), Y15 is X15 + 1), f(1, g(2), a), T15)),
    t(S18, foldsubterms([X16, S16, S17]>>(integer(X16), S17 is S16 + X16), f(1, g(2), a), 0, S18)),
    t(F19/A19, (same_functor(f(a, b), T19), functor(T19, F19, A19))),
    t(Sz20, term_size(f(a, g(b)), Sz20)),
    t(yes, maybe(1, 1)), t(yes, maybe(0, 5)), t(yes, maybe(1.0)), t(yes, maybe(0.0)),
    t(M, random_member(M, [z])),
    t(E22-R22, random_select(E22, [a], R22)),
    t(S23, (randseq(3, 3, S22), msort(S22, S23))),
    t(S24, randset(3, 3, S24)),
    t(D25, (duplicate_term(f(g(a), B25, B25), D25))),
    t(T26-C26, (T26 = f(g(a)), duplicate_term(T26, C26), arg(1, C26, G26), setarg(1, G26, b))),
    t(N30-A30-Ty30, functor(foo, N30, A30, Ty30)), t(N31-A31-Ty31, functor(f(x), N31, A31, Ty31)), t(N32-A32-Ty32, functor(1, N32, A32, Ty32)),
    t(Ty33, functor("s", _, _, Ty33)), t(yes, functor(foo, _, _, callable)), t(yes, functor(f(x), _, _, callable)), t(yes, functor(foo, _, _, atomic)),
    t(yes, functor(foo, _, _, compound)), t(yes, functor(f(x), _, _, atom)), t(yes, functor(1, _, _, callable)),
    t(T34, functor(T34, f, 2, compound)), t(T35, functor(T35, f, 0, atom)), t(T36, functor(T36, f, 2, callable)), t(T37, functor(T37, f, 0, callable)),
    t(T38, functor(T38, 1, 0, atomic)), t(T39, functor(T39, f, 0, atomic)), t(T40, functor(T40, f, 2, atom)), t(T41, functor(T41, f, 2, atomic)),
    t(T42, functor(T42, f, 2, _)), t(T43, functor(T43, f, 0, _)), t(T44, functor(T44, 1, 0, _)), t(T45, functor(T45, f(x), 0, _)), t(T46, functor(T46, _, 2, compound)),
    t(T47, functor(T47, f, a, compound)), t(T48, functor(T48, f, 2, bad)), t(T49, functor(T49, "s", 0, _)), t(T50, functor(T50, 1, 2, compound)),
    t(S51, term_size(a, S51)), t(S52, term_size(1, S52)), t(S53, term_size(_, S53)), t(S54, term_size(1.5, S54)), t(S55, term_size("abc", S55)), t(S56, term_size("abcdefghij", S56)),
    t(S57, term_size([a,b,c], S57)), t(S58, term_size(f(X58,X58), S58)), t(S59, term_size(100000000000000000000, S59)), t(S60, term_size(f(1.5, "abc"), S60)),
    t(S61, term_size('', S61)), t(S62, term_size(99999999999999999999999999999999999999999999999999, S62)), t(S63, term_size(f(Y63, Z63, Y63, Z63), S63)),
    t(S64, term_size(1152921504606846976, S64)), t(S65, term_size(4611686018427387904, S65)), t(S66, term_size(-9223372036854775807, S66)),
    t(S67, term_size("abcdefg", S67)), t(S68, term_size("abcdefgh", S68)), t(S69, term_size(g(f(a, b), "x", 2.5), S69)).
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
