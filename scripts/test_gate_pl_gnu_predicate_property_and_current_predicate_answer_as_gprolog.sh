#!/usr/bin/env bash
# test_gate_pl_gnu_predicate_property_and_current_predicate_answer_as_gprolog.sh -- OUTSIDE THE SWI DIALECT predicate_property/2 ALSO ANSWERS gprolog's PROPERTIES;
# IN THE SWI DIALECT current_predicate/1 AND predicate_property/2 ANSWER AS swipl (cfo 2026-10-15, GNU drivers row: BipsPl/pred_driver).
#
# SCRIP answered SWI's property set only (static/dynamic, file, defined, built_in). gprolog adds, for a user predicate, private|public, monofile|multifile,
# user, prolog_file(F), prolog_line(L); for a built-in or a library predicate static, private, monofile, built_in (built_in_fd for fd_*), native_code, and
# control_construct for , ; -> call/1 ! catch/3 throw/1 true fail; an unknown property is domain_error(predicate_property, P). Outside the SWI dialect the
# runtime road (pl_pp_prop, which a meta-called predicate_property takes and the static road now defers to, portray/1 excepted) answers the UNION of both
# sets, because iso-dialect programs are graded against swipl as well as gprolog; '$pl_pp_pcheck' raises the domain error for a name in neither set. The
# line and the multifile flag reach the runtime through the declaration table ($db_decls kinds 5 and 6, stored on the key record). current_predicate/1
# keeps ISO's type_error(predicate_indicator, PI) outside the SWI dialect (ISO 8.8.2.3, held by the Logtalk ISO groups of iso_rung3; gprolog deviates
# there, a ruling for the ceo); in the SWI dialect current_predicate(foo/ -1) now raises domain_error(not_less_than_zero, -1) and predicate_property(4, P)
# fails, both as swipl.
#
# THE ARMS: g.pl (no SWI marker, 22 lines cut from gprolog 1.6.0) and s.pl (an SWI marker, 11 lines cut from swipl 9.0.4), each in mode 3 and mode 4,
# both cut 2026-10-15. FAIL-ONCE, measured on the parent rebuilt (SCRIP f07fede23): g.pl 14 of 22 and s.pl 2 of 11 lines differ in both modes.
# rc=0 every arm agrees with its oracle · rc=1 a divergence · rc=2 REFUSAL (no build).  ~6 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
G=test_gate_pl_gnu_predicate_property_and_current_predicate_answer_as_gprolog
refuse() { echo "⛔ REFUSED(2) [$G]: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$G" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/g.pl" <<'PL'
:- initialization((main, g)).
:- dynamic(pd/1).
:- multifile(pm/1).
pd(1).
pm(a).
ps(X, Y) :- Y is X + 1.
t(G) :- copy_term(G, C), catch(findall(C, C, L), E, true), ( var(E) -> R = L ; E = error(F, _) -> R = error(F) ; R = ball(E) ), \+ \+ ( numbervars(G-R, 0, _), writeq(G), write(' => '), writeq(R), nl ).
main :- t(current_predicate(ps/2)), t(current_predicate(4)),
  t(predicate_property(ps(_,_), static)), t(predicate_property(pd(_), dynamic)), t(predicate_property(ps(_,_), dynamic)), t(predicate_property(atom_length(_,_), built_in)),
  t(predicate_property(nosuch(_), dynamic)), t(predicate_property(4, dynamic)).
g :- t(predicate_property(ps(_,_), user)), t(predicate_property(ps(_,_), private)), t(predicate_property(pd(_), public)), t(predicate_property(pm(_), multifile)),
  t(predicate_property(ps(_,_), monofile)), t(predicate_property(ps(_,_), prolog_line(_))), t(predicate_property(pd(_), prolog_line(_))), t(predicate_property(atom_length(_,_), native_code)),
  t(predicate_property(atom_length(_,_), static)), t(predicate_property(append(_,_,_), built_in)), t(predicate_property(call(_), control_construct)), t(predicate_property((_,_), control_construct)),
  t(predicate_property(ps(_,_), bogus)), t(predicate_property(ps(_,_), 3)).
PL
cat > "$D/s.pl" <<'PL'
:- use_module(library(lists)).
:- initialization(main).
:- dynamic(pd/1).
pd(1).
ps(X, Y) :- Y is X + 1.
t(G) :- copy_term(G, C), catch(findall(C, C, L), E, true), ( var(E) -> R = L ; E = error(F, _) -> R = error(F) ; R = ball(E) ), \+ \+ ( numbervars(G-R, 0, _), writeq(G), write(' => '), writeq(R), nl ).
main :- t(current_predicate(ps/2)), t(current_predicate(foo/bar)), t(current_predicate(foo/(-1))), t(current_predicate(3/1)), t(current_predicate(4)),
  t(predicate_property(ps(_,_), static)), t(predicate_property(pd(_), dynamic)), t(predicate_property(ps(_,_), dynamic)), t(predicate_property(atom_length(_,_), built_in)),
  t(predicate_property(nosuch(_), dynamic)), t(predicate_property(4, dynamic)).
PL
want_g="$(cat <<'WANT'
current_predicate(ps/2) => [current_predicate(ps/2)]
current_predicate(4) => error(type_error(predicate_indicator,4))
predicate_property(ps(A,B),static) => [predicate_property(ps(C,D),static)]
predicate_property(pd(A),dynamic) => [predicate_property(pd(B),dynamic)]
predicate_property(ps(A,B),dynamic) => []
predicate_property(atom_length(A,B),built_in) => [predicate_property(atom_length(C,D),built_in)]
predicate_property(nosuch(A),dynamic) => []
predicate_property(4,dynamic) => error(type_error(callable,4))
predicate_property(ps(A,B),user) => [predicate_property(ps(C,D),user)]
predicate_property(ps(A,B),private) => [predicate_property(ps(C,D),private)]
predicate_property(pd(A),public) => [predicate_property(pd(B),public)]
predicate_property(pm(A),multifile) => [predicate_property(pm(B),multifile)]
predicate_property(ps(A,B),monofile) => [predicate_property(ps(C,D),monofile)]
predicate_property(ps(A,B),prolog_line(C)) => [predicate_property(ps(D,E),prolog_line(6))]
predicate_property(pd(A),prolog_line(B)) => [predicate_property(pd(C),prolog_line(4))]
predicate_property(atom_length(A,B),native_code) => [predicate_property(atom_length(C,D),native_code)]
predicate_property(atom_length(A,B),static) => [predicate_property(atom_length(C,D),static)]
predicate_property(append(A,B,C),built_in) => [predicate_property(append(D,E,F),built_in)]
predicate_property(call(A),control_construct) => [predicate_property(call(B),control_construct)]
predicate_property((A,B),control_construct) => [predicate_property((C,D),control_construct)]
predicate_property(ps(A,B),bogus) => error(domain_error(predicate_property,bogus))
predicate_property(ps(A,B),3) => error(domain_error(predicate_property,3))
WANT
)"
want_s="$(cat <<'WANT'
current_predicate(ps/2) => [current_predicate(ps/2)]
current_predicate(foo/bar) => error(type_error(predicate_indicator,foo/bar))
current_predicate(foo/ -1) => error(domain_error(not_less_than_zero,-1))
current_predicate(3/1) => error(type_error(predicate_indicator,3/1))
current_predicate(4) => error(type_error(predicate_indicator,4))
predicate_property(ps(A,B),static) => [predicate_property(ps(C,D),static)]
predicate_property(pd(A),dynamic) => [predicate_property(pd(B),dynamic)]
predicate_property(ps(A,B),dynamic) => []
predicate_property(atom_length(A,B),built_in) => [predicate_property(atom_length(C,D),built_in)]
predicate_property(nosuch(A),dynamic) => []
predicate_property(4,dynamic) => []
WANT
)"
red=0
arm() {
    local label="$1" want="$2" oracle="$3"; shift 3
    local got n t
    got="$(cd "$D" && "$@" 2>/dev/null | grep .)"
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
