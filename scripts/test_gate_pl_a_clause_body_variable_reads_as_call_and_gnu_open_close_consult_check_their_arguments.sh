#!/usr/bin/env bash
# test_gate_pl_a_clause_body_variable_reads_as_call_and_gnu_open_close_consult_check_their_arguments.sh -- A VARIABLE IN GOAL POSITION OF A STORED BODY READS AS call(V),
# AND close/2, open/4 AND (OUTSIDE THE SWI DIALECT) consult/1 CHECK THEIR ARGUMENTS AS THE ORACLES DO
# (cfo 2026-10-15, row prolog-gnu-builtins-the-drivers-find-128-predicates-gnu-defines-and-scrip-lacks: BipsPl/utils_driver).
#
# clause/2 and retract/1 read a stored body through '$clause_unify' (rt_pl_dop_clause_unify_c), which wrapped only a body that IS a variable, and did so
# after the head was unified: clause(h(foo), B) for h(Y) :- Y answered B = foo where swipl and gprolog answer call(foo), and a variable under ',', ';' or
# '->' stayed bare. The body is now converted before the head is unified, every variable in goal position under ',', ';' and '->' becoming call(V) (gprolog's
# '$term_to_goal', BipsPl/utils.pl), and under '*->' and '\+' as well in the SWI dialect, where swipl wraps those too; findall's goal is never wrapped.
# close/2 with force(V) raises instantiation_error (both oracles; SCRIP said domain_error(close_option, force(_))). open/4 with alias(V) raises
# instantiation_error in every dialect, as ISO 8.11.5.3 and swipl do: gprolog's domain_error(stream_option, alias(V)) is an ISO conflict, excluded by ruling
# (CEO-391/1772, the CEO-1789 precedent; gnu_prolog EXCLUDED_LINES.tsv), so g.pl's reference carries ISO's line there. consult/1 checks an atom or
# a list of atoms first ('$check_atom_or_atom_list': instantiation_error, type_error(list, T), type_error(atom, X)) and consults each file of a list.
#
# THE ARMS: two programs, each in mode 3 and mode 4 -- g.pl (no SWI marker, the reference cut from gprolog 1.4.5, nine lines) and s.pl (an SWI marker, the
# reference cut from swipl 9.0.4, five lines), both cut 2026-10-15.
# FAIL-ONCE, measured on the parent rebuilt (SCRIP 7e5bd3989): g.pl 6 of 9 lines differ and s.pl 3 of 5, in both modes.
# rc=0 every arm agrees with its oracle · rc=1 a divergence · rc=2 REFUSAL (no build).  ~6 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
G=test_gate_pl_a_clause_body_variable_reads_as_call_and_gnu_open_close_consult_check_their_arguments
refuse() { echo "⛔ REFUSED(2) [$G]: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$G" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/common.pl" <<'PL'
t(G) :- copy_term(G, C), catch(findall(C, C, L), E, true), ( var(E) -> R = L ; E = error(F, _) -> R = error(F) ; R = ball(E) ), \+ \+ ( numbervars(R, 0, _), writeq(R), nl ).
:- dynamic(h/1).
h0 :- assertz((h(Y) :- Y)), assertz((h(Z) :- (Z *-> true ; Z))), assertz((h(W) :- findall(x, W, _), call(W), \+ (W, true))), assertz((h(V) :- (V -> V ; true), V)).
PL
{ echo ':- initialization(main).'; cat "$D/common.pl"
  echo "main :- h0, t(clause(h(foo), _)), t(retract((h(Q) :- call(Q)))), t(clause(h(_), _)), t(open('probe.txt', write, _, [alias(_)])), t(close(user_output, [force(_)])),"
  echo "  t(close(user_output, [force(maybe)])), t(consult([_])), t(consult(42)), t(consult([abc, 1]))."; } > "$D/g.pl"
{ echo ':- use_module(library(lists)).'; echo ':- initialization(main).'; cat "$D/common.pl"
  echo "main :- h0, t(clause(h(foo), _)), t(retract((h(Q) :- call(Q)))), t(clause(h(_), _)), t(open('probe.txt', write, _, [alias(_)])), t(close(user_output, [force(_)]))."; } > "$D/s.pl"
want_g="$(cat <<'WANT'
[clause(h(foo),call(foo)),clause(h(foo),(foo*->true;call(foo))),clause(h(foo),(findall(x,foo,A),call(foo),\+ (foo,true))),clause(h(foo),((call(foo)->call(foo);true),call(foo)))]
[retract((h(A):-call(A)))]
[clause(h(A),(A*->true;call(A))),clause(h(B),(findall(x,B,C),call(B),\+ (B,true))),clause(h(D),((call(D)->call(D);true),call(D)))]
error(instantiation_error)
error(instantiation_error)
error(domain_error(close_option,force(maybe)))
error(instantiation_error)
error(type_error(list,42))
error(type_error(atom,1))
WANT
)"
want_s="$(cat <<'WANT'
[clause(h(foo),call(foo)),clause(h(foo),(call(foo)*->true;call(foo))),clause(h(foo),(findall(x,foo,A),call(foo),\+ (call(foo),true))),clause(h(foo),((call(foo)->call(foo);true),call(foo)))]
[retract((h(A):-call(A)))]
[clause(h(A),(call(A)*->true;call(A))),clause(h(B),(findall(x,B,C),call(B),\+ (call(B),true))),clause(h(D),((call(D)->call(D);true),call(D)))]
error(instantiation_error)
error(instantiation_error)
WANT
)"
red=0
arm() {
    local label="$1" want="$2" oracle="$3"; shift 3
    local got n t
    got="$(cd "$D" && rm -f probe.txt && "$@" 2>/dev/null | grep .)"
    t="$(printf '%s\n' "$want" | grep -c .)"
    n="$(diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | grep -c '^<')"
    if [ "$got" = "$want" ]; then echo "  $label GREEN: $t of $t lines as $oracle"
    else echo "  $label RED: $n of $t $oracle lines missing or different"; diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | sed 's/^/    /'; red=1; fi
}
for p in g s; do
    if [ "$p" = g ]; then w="$want_g"; o=gprolog; else w="$want_s"; o=swipl; fi
    arm "$p.pl m3" "$w" "$o" timeout -k 5 20 "$B/scrip" --run $([ "$p" = g ] && printf %s --dialect=gnu) "$p.pl" < /dev/null
    if ( cd "$D" && timeout -k 5 60 "$B/scrip" --compile $([ "$p" = g ] && printf %s --dialect=gnu) --out="$p.s" "$p.pl" < /dev/null > /dev/null 2>&1 && [ -s "$p.s" ] \
         && gcc -m64 -no-pie "$p.s" -o "$p.bin" -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" > /dev/null 2>&1 ); then
        arm "$p.pl m4" "$w" "$o" timeout -k 5 20 "./$p.bin" < /dev/null
    else echo "  $p.pl m4 RED: the program did not compile or link in mode 4"; red=1; fi
done
[ "$red" = 0 ] && echo "PASS $G"
exit "$red"
