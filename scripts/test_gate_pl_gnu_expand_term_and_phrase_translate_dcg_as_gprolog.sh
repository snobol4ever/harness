#!/usr/bin/env bash
# test_gate_pl_gnu_expand_term_and_phrase_translate_dcg_as_gprolog.sh -- OUTSIDE THE SWI DIALECT, expand_term/2 AND phrase/2,3 TRANSLATE A DCG AS GNU PROLOG DOES
# (cfo 2026-10-15, row prolog-gnu-builtins-the-drivers-find-128-predicates-gnu-defines-and-scrip-lacks: BipsPl/expand_driver).
#
# SCRIP had one DCG translator, SWI's shape: a head terminal became a body goal S0=[x|S1], {}/1 and !/0 carried a trailing S0=S goal, and a body that is not
# callable reached =.. and raised type_error(atom, X). gprolog's translator is C (BipsPl/expand_c.c, Pl_Dcg_Trans_Rule_2 and Pl_Dcg_Trans_Body_4) and gives
# another clause: a leading terminal list is unified into the head, an in/out equality is made by unification wherever OPT_EQUAL_BETWEEN_IN_OUT_VARS (2,
# steadfast) allows it, a pushback list is checked as a list, and a non-callable body or head raises type_error(callable, X). The base prelude now carries
# that translator clause for branch ('$gnu_dcg_rule', '$gnu_dcg_body', '$gnu_dcg_on', '$gnu_dcg_tl'), and '$expand_term1' and '$phrase' take it when the
# program's '$dialect' flag is not swi; an SWI-dialect program keeps dcg_translate_rule/2 and '$dcg_body' unchanged.
#
# THE ARM: one program, eleven lines, the reference cut from gprolog 1.4.5 (2026-10-15), mode 3 and mode 4.
# FAIL-ONCE, measured on the parent rebuilt (SCRIP d788c71b0): 6 of the 11 lines differ in both modes (the leading terminal folded into the head, the {}/1 and !/0 shapes, and the three error terms).
# rc=0 both modes agree with gprolog · rc=1 a divergence · rc=2 REFUSAL (no build).  ~4 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
G=test_gate_pl_gnu_expand_term_and_phrase_translate_dcg_as_gprolog
refuse() { echo "⛔ REFUSED(2) [$G]: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$G" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/w.pl" <<'PL'
:- initialization(main).
t(G) :- copy_term(G, C), catch(findall(C, C, L), E, true), ( var(E) -> R = L ; E = error(F, _) -> R = error(F) ; R = ball(E) ), \+ \+ ( numbervars(R, 0, _), writeq(R), nl ).
main :- t(expand_term((a --> [x], b), _)), t(expand_term((a --> b, {c}, [d]), _)), t(expand_term((a, [p] --> b), _)), t(expand_term((a --> \+ b), _)),
  t(expand_term((a --> b ; []), _)), t(expand_term((a --> [x], !, [y]), _)), t(expand_term((a --> 3), _)), t(expand_term((a, q --> b), _)),
  t(phrase(3, [a])), t(phrase(([a], [b]), [a, b, c], _)), t(phrase((\+ [b], [a]), [a], [])).
PL
want="$(cat <<'WANT'
[expand_term((a-->[x],b),(a([x|A],B):-b(A,B)))]
[expand_term((a-->b,{c},[d]),(a(A,B):-b(A,C),c,C=[d|B]))]
[expand_term((a,[p]-->b),(a(A,B):-b(A,C),B=[p|C]))]
[expand_term((a--> \+b),(a(A,B):- \+b(A,C),A=B))]
[expand_term((a-->b;[]),(a(A,B):-b(A,B);A=B))]
[expand_term((a-->[x],!,[y]),(a([x|A],B):-!,A=[y|B]))]
error(type_error(callable,3))
error(type_error(list,q))
error(type_error(callable,3))
[phrase(([a],[b]),[a,b,c],[c])]
[phrase((\+[b],[a]),[a],[])]
WANT
)"
m4ok=1
( cd "$D" && timeout -k 5 60 "$B/scrip" --compile --dialect=gnu --out=w.s w.pl < /dev/null > /dev/null 2>&1 && [ -s w.s ] \
  && gcc -m64 -no-pie w.s -o w.bin -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" > /dev/null 2>&1 ) || m4ok=0
red=0
arm() {
    local label="$1"; shift
    local got n
    got="$(cd "$D" && "$@" 2>/dev/null | grep .)"
    n="$(diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | grep -c '^<')"
    if [ "$got" = "$want" ]; then echo "  $label GREEN: 11 of 11 lines as gprolog"
    else echo "  $label RED: $n of 11 gprolog lines missing or different"; diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | sed 's/^/    /'; red=1; fi
}
arm m3 timeout -k 5 20 "$B/scrip" --run --dialect=gnu w.pl < /dev/null
if [ "$m4ok" = 1 ]; then arm m4 timeout -k 5 20 ./w.bin < /dev/null; else echo "  m4 RED: the program did not compile or link in mode 4"; red=1; fi
[ "$red" = 0 ] && echo "PASS $G"
exit "$red"
