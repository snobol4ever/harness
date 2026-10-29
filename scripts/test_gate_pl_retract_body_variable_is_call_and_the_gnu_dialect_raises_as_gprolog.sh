#!/usr/bin/env bash
# test_gate_pl_retract_body_variable_is_call_and_the_gnu_dialect_raises_as_gprolog.sh -- retract/1 UNIFIES THE BODY AS clause/2 DOES, AND THE GNU DIALECT RAISES WHERE gprolog RAISES
# (cfo 2026-10-15, row prolog-gnu-builtins-the-drivers-find-128-predicates-gnu-defines-and-scrip-lacks: BipsPl/assert_driver).
#
# (1) retract((H :- B)) on a stored clause whose body is a variable (assertz((pv(G) :- G))) binds B to call(G) in swipl 9.0.4 and gprolog 1.4.5 alike; the
#     retract road unified with '$unify' and answered the bare G. It now unifies with '$clause_unify', clause/2's own road, in every dialect.
# (2) retract((H :- 3)) is type_error(callable, 3) in gprolog and a plain failure in swipl; clause(sp(_), _) on a static procedure is
#     permission_error(access, private_procedure, sp/1) in gprolog and an answer in swipl. The dialect flag ($dialect: a program with a
#     module/use_module directive or a dict reads as swi) picks: outside the SWI dialect the two raise, inside it swipl's answers stand.
#
# THE ARM: two six-line programs -- g.pl (no dialect marker, the reference cut from gprolog 1.4.5) and s.pl (the same body behind a use_module
# directive, the reference cut from swipl 9.0.4) -- each in mode 3 and mode 4. FAIL-ONCE, measured on the parent rebuilt: g.pl 3 of 6 lines differ.
# rc=0 both modes agree with the oracle for both programs · rc=1 a divergence · rc=2 REFUSAL (no build).  ~5 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
G=test_gate_pl_retract_body_variable_is_call_and_the_gnu_dialect_raises_as_gprolog
refuse() { echo "⛔ REFUSED(2) [$G]: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$G" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/g.pl" <<'PL'
:- dynamic(pv/1).
:- dynamic(pw/1).
:- dynamic(ds/1).
sp(1).
sp(2).
t(G) :- copy_term(G, C), catch(findall(C, C, L), E, true),
        (   var(E) -> R = L ;   E = error(F, _) -> R = error(F) ;   R = ball(E) ),
        \+ \+ ( numbervars(G-R, 0, _), writeq(G), write(' => '), writeq(R), nl ).
:- initialization(main).
main :- assertz((pv(G) :- G)), assertz((pw(W) :- (W = 1 ; W = 2), \+ W = 3)), assertz(ds(1)), assertz(ds(2)),
  t(retract((pv(_) :- _))),
  t(retract((pw(_) :- 3))),
  t(retract((ds(_) :- true))),
  t(clause(sp(_), _)),
  t(clause(ds(_), _)),
  t(retract(sp(1))).
PL
sed 's/^:- initialization(main).$/:- use_module(library(lists)).\n:- initialization(main)./' "$D/g.pl" > "$D/s.pl"
want_g="$(cat <<'WANT'
retract((pv(A):-B)) => [retract((pv(C):-call(C)))]
retract((pw(A):-3)) => error(type_error(callable,3))
retract((ds(A):-true)) => [retract((ds(1):-true)),retract((ds(2):-true))]
clause(sp(A),B) => error(permission_error(access,private_procedure,sp/1))
clause(ds(A),B) => []
retract(sp(1)) => error(permission_error(modify,static_procedure,sp/1))
WANT
)"
want_s="$(cat <<'WANT'
retract((pv(A):-B)) => [retract((pv(C):-call(C)))]
retract((pw(A):-3)) => []
retract((ds(A):-true)) => [retract((ds(1):-true)),retract((ds(2):-true))]
clause(sp(A),B) => [clause(sp(1),true),clause(sp(2),true)]
clause(ds(A),B) => []
retract(sp(1)) => error(permission_error(modify,static_procedure,sp/1))
WANT
)"
red=0
arm() {
    local label="$1" want="$2"; shift 2
    local got n
    got="$(cd "$D" && "$@" 2>/dev/null | grep .)"
    n="$(diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | grep -c '^<')"
    if [ "$got" = "$want" ]; then echo "  $label GREEN: 6 of 6 lines as the oracle"
    else echo "  $label RED: $n of 6 oracle lines missing or different"; diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | sed 's/^/    /'; red=1; fi
}
for p in g s; do
    want="$want_g"; [ "$p" = s ] && want="$want_s"
    m4ok=1
    ( cd "$D" && timeout -k 5 60 "$B/scrip" --compile $([ "$p" = g ] && printf %s --dialect=gnu) --out="$p.s" "$p.pl" < /dev/null > /dev/null 2>&1 && [ -s "$p.s" ] \
      && gcc -m64 -no-pie "$p.s" -o "$p.bin" -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" > /dev/null 2>&1 ) || m4ok=0
    arm "$p.pl m3" "$want" timeout -k 5 20 "$B/scrip" --run $([ "$p" = g ] && printf %s --dialect=gnu) "$p.pl" < /dev/null
    if [ "$m4ok" = 1 ]; then arm "$p.pl m4" "$want" timeout -k 5 20 "./$p.bin" < /dev/null; else echo "  $p.pl m4 RED: the program did not compile or link in mode 4"; red=1; fi
done
[ "$red" = 0 ] && echo "PASS $G"
exit "$red"
