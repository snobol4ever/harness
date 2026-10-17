#!/usr/bin/env bash
# test_gate_pl_a_module_qualified_goal_runs_its_goal_as_swipl.sh
#
# THE ROW: prolog-a-module-qualified-goal-runs-its-goal-call-m-g-is-an-existence-error-on-colon-2 (hq_prolog, rank 1; the
# gateway of the tabling class: tabling_testlib's compare_real_expected_answers/3 runs findall(.., M:G2, ..)). SCRIP has
# one namespace, so Module:Goal runs Goal. Two arms, one per road: the LOWERER strips an atom-qualified body goal
# (lower_prolog.c goal_inner: lists:append(..) lowers as append(..), resolved statically), and the PRELUDE defines ':'/2..
# ':'/9 for the run-time road (call(user:G), call(M:G, X), a qualified goal held in a variable), with M unbound an
# instantiation_error as swipl raises it.
#
# THE ARM: 13 lines -- findall over user:p(X), call(user:G), call(M:G, X) through a closure, a qualified body goal,
# call/3 over a qualified closure, success and failure, a doubly qualified goal, an unbound module, \+ and forall/2
# over a qualified goal, a module held in a variable -- the ref cut from SWI-Prolog 9.0.4, in both modes.
# rc=0 clean · rc=1 a divergence · rc=2 REFUSAL.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
refuse() { echo "⛔ REFUSES rc=2: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built -- cannot measure"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/g.pl" <<'PL'
:- initialization(main).
p(1). p(2).
r(X, Y) :- Y is X * 10.
q(M, G) :- findall(X, call(M:G, X), L), write(L), nl.
t(G) :- catch((G -> write(yes) ; write(no)), error(E, _), write(E)), nl.
main :-
  findall(X, user:p(X), L), write(L), nl,
  G = p(Y), call(user:G), write(Y), nl,
  q(user, p),
  lists:append([a], [b], Z), write(Z), nl,
  call(user:r, 4, R), write(R), nl,
  t(user:p(2)), t(user:p(3)),
  t(user:user:p(1)),
  t(call(_:p(1))),
  t(\+ user:p(3)),
  forall(user:p(V), (write(V), nl)),
  M = user, t(M:p(1)),
  halt.
PL
cat > "$D/g.ref" <<'REF'
[1,2]
1
[1,2]
[a,b]
40
yes
no
yes
instantiation_error
yes
1
2
yes
REF
( cd "$D" && timeout -k 5 30 "$B/scrip" g.pl < /dev/null > g.m3 2>&1 )
( cd "$D" && timeout -k 5 60 "$B/scrip" --compile -o g.s g.pl < /dev/null > /dev/null 2>&1 && gcc -no-pie g.s -L"$B/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$B/out" -o g.bin 2>/dev/null ) || refuse "g.pl: mode 4 did not build"
( cd "$D" && timeout -k 5 30 ./g.bin < /dev/null > g.m4 2>&1 )
red=0
for m in m3 m4; do
    if cmp -s "$D/g.ref" "$D/g.$m"; then echo "  ok   $m: 13 of 13 lines answer as swipl"
    else echo "  FAIL $m: diverges from swipl:"; diff "$D/g.ref" "$D/g.$m" | head -12; red=$((red + 1)); fi
done
if [ $red -eq 0 ]; then echo "GATE PASS(0): a module-qualified goal runs its goal as swipl runs it, in both modes"; exit 0; fi
echo "GATE FAIL(1): $red of 2 mode(s) diverge"; exit 1
