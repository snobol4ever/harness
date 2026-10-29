#!/usr/bin/env bash
# test_gate_pl_call_with_depth_limit_answers_as_swipl_for_recursion_control_constructs_and_the_frame_each_builtin_call_costs.sh -- call_with_depth_limit/3 answers as swipl: the depth a proof reached, or depth_limit_exceeded, for recursion, control constructs and builtin calls.
# SCRIP lacked the predicate (ProRosetta integer-sequence-1, graded with swipl's reference, CEO-1926). The prelude's meta-interpreter charges a frame for every
# user or builtin call but none for a control construct, a cut, fail, or a unify/==/\== with a clause variable; a toplevel control construct costs one level;
# once/ignore/forall/catch/call cost one level for the goal inside and findall six (swipl 9.0.4, measured); backtracking into a solution restarts the count at
# 1, an exceeded branch before a solution leaves limit+1, and a nested call_with_depth_limit keeps its own count. NOT MODELLED: the depth of swipl's own library
# recursion (member/2 reads 1 here, 2,3,4 in swipl). Four probes are cut from swipl in THIS run and compared byte for byte with SCRIP's m3 and m4: the shapes of
# a proof, the recursion boundary (tail, non-tail, mutual, a printing loop), and the frame a builtin costs at a limit of 1 (two programs, one clause per builtin).
# The self-test feeds the comparison a corrupted reference and requires it seen.
set -u
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP"; exit 2; }
[ -x "$ROOT/scrip" ] || { echo "GATE REFUSED(2) [$G]: no $ROOT/scrip -- run make"; exit 2; }
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$G" "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" || exit 2
command -v gcc >/dev/null 2>&1 || { echo "GATE REFUSED(2) [$G]: gcc absent"; exit 2; }
. "$HERE/lib_oracle_flags.sh" || { echo "GATE REFUSED(2) [$G]: lib_oracle_flags.sh unloadable -- the one accessor of the oracle binaries"; exit 2; }
SW="$(swipl_bin)"; [ -x "$SW" ] || { echo "GATE REFUSED(2) [$G]: no swipl at $SW -- the oracle (swipl_bin)"; exit 2; }
W="$(mktemp -d "${TMPDIR:-/tmp}/pldepth.XXXXXX")" || { echo "GATE REFUSED(2) [$G]: no workdir"; exit 2; }; trap 'rm -rf "$W"' EXIT
cat > "$W/shapes.pl" <<'PL'
:- dynamic dyn/1.
fact(0, 1) :- !.
fact(N, F) :- N1 is N - 1, fact(N1, F1), F is N * F1.
len([], 0).
len([_|T], N) :- len(T, M), N is M + 1.
spin(N) :- N1 is N + 1, spin(N1).
color(red).
color(green).
color(blue).
deep(0) :- !.
deep(N) :- N1 is N - 1, deep(N1).
r(X) :- deep(20), X = first.
r(second).
neg(X) :- \+ color(X).
ite(X, Y) :- ( color(X) -> Y = yes ; Y = no ).
dsj(X) :- ( X = 1 ; X = 2 ).
dyn(1).
dyn(2) :- dyn(1).
show(G, L) :- catch(( findall(R, call_with_depth_limit(G, L, R), Rs) -> print(Rs) ; print(none) ), error(E, _), print(E)), nl.
:- show(fact(5, _), 100).
:- show(fact(5, _), 3).
:- show(fact(7, _), 6).
:- show(len([a, b, c], _), 100).
:- show(true, 10).
:- show(fail, 10).
:- show(atom_length(abc, _), 5).
:- show((fact(2, _), fact(3, _)), 50).
:- show(spin(0), 6).
:- show(color(_), 10).
:- show(r(_), 12).
:- show(r(_), 100).
:- show(neg(red), 10).
:- show(neg(pink), 10).
:- show(ite(red, _), 10).
:- show(ite(pink, _), 10).
:- show(dsj(_), 10).
:- show(dyn(2), 10).
:- show(dyn(_), 10).
:- show(call_with_depth_limit(fact(3, _), 10, _), 20).
:- show(true, a).
:- show(true, _).
:- show(undefined_pred_xyz, 10).
:- show((color(X), X \== red), 10).
PL
cat > "$W/rec.pl" <<'PL'
t(0).
t(N) :- N > 0, N1 is N - 1, t(N1).
u(0).
u(N) :- N > 0, N1 is N - 1, u(N1), true.
w(0) :- !.
w(N) :- N1 is N - 1, w(N1).
x(0).
x(N) :- N > 0, N1 is N - 1, y(N1).
y(N) :- x(N).
:- forall(member(G, [t(5), u(5), w(5), x(5)]), ( call_with_depth_limit(G, 100, R), writeln(G-R) )).
:- forall(member(G, [t(5), u(5), w(5), x(5)]), forall(member(L, [3, 4, 5, 6, 7, 8, 9, 10, 11]), ( call_with_depth_limit(G, L, R) -> format("~w L=~w R=~w~n", [G, L, R]) ; true ))).
loop(I) :- writeln(I), I1 is I + 1, loop(I1).
loop2(I) :- I1 is I + 1, writeln(I), loop2(I1).
:- call_with_depth_limit(loop(1), 6, R), writeln(R).
:- call_with_depth_limit(loop2(1), 6, R), writeln(R).
PL
cat > "$W/bi1.pl" <<'PL'
:- dynamic zz/1.
c0 :- var(X).
c1 :- nonvar(a).
c2 :- atom(a).
c3 :- integer(1).
c4 :- number(1).
c5 :- atomic(a).
c6 :- compound(f(a)).
c7 :- callable(a).
c8 :- is_list([]).
c9 :- ground(a).
c10 :- X = a.
c11 :- a = a.
c12 :- X = Y.
c13 :- f(X) = f(a).
c14 :- a \= b.
c15 :- X == X.
c16 :- a == a.
c17 :- a \== b.
c18 :- a @< b.
c19 :- 1 < 2.
c20 :- 1 =:= 1.
c21 :- X is 1.
c22 :- a =@= a.
c23 :- true.
c24 :- fail ; true.
c25 :- \+ fail.
c26 :- (true -> true ; fail).
c27 :- call(true).
c28 :- functor(f(a), _, _).
c29 :- arg(1, f(a), _).
c30 :- X =.. [a].
c31 :- copy_term(a, _).
c32 :- atom_length(a, _).
c33 :- nb_setval(k, 1).
c34 :- writeln(x).
c35 :- nl.
c36 :- length([], _).
c37 :- succ(1, _).
c38 :- between(1, 1, _).
c39 :- !.
c40 :- X = 1, X == 1.
cases([c0-0,c1-1,c2-2,c3-3,c4-4,c5-5,c6-6,c7-7,c8-8,c9-9,c10-10,c11-11,c12-12,c13-13,c14-14,c15-15,c16-16,c17-17,c18-18,c19-19,c20-20,c21-21,c22-22,c23-23,c24-24,c25-25,c26-26,c27-27,c28-28,c29-29,c30-30,c31-31,c32-32,c33-33,c34-34,c35-35,c36-36,c37-37,c38-38,c39-39,c40-40]).
name_of(N, C) :- name_tab(N, C).
name_tab(0, "var(X)").
name_tab(1, "nonvar(a)").
name_tab(2, "atom(a)").
name_tab(3, "integer(1)").
name_tab(4, "number(1)").
name_tab(5, "atomic(a)").
name_tab(6, "compound(f(a))").
name_tab(7, "callable(a)").
name_tab(8, "is_list([])").
name_tab(9, "ground(a)").
name_tab(10, "X = a").
name_tab(11, "a = a").
name_tab(12, "X = Y").
name_tab(13, "f(X) = f(a)").
name_tab(14, "a \\= b").
name_tab(15, "X == X").
name_tab(16, "a == a").
name_tab(17, "a \\== b").
name_tab(18, "a @< b").
name_tab(19, "1 < 2").
name_tab(20, "1 =:= 1").
name_tab(21, "X is 1").
name_tab(22, "a =@= a").
name_tab(23, "true").
name_tab(24, "fail ; true").
name_tab(25, "\\+ fail").
name_tab(26, "(true -> true ; fail)").
name_tab(27, "call(true)").
name_tab(28, "functor(f(a), _, _)").
name_tab(29, "arg(1, f(a), _)").
name_tab(30, "X =.. [a]").
name_tab(31, "copy_term(a, _)").
name_tab(32, "atom_length(a, _)").
name_tab(33, "nb_setval(k, 1)").
name_tab(34, "writeln(x)").
name_tab(35, "nl").
name_tab(36, "length([], _)").
name_tab(37, "succ(1, _)").
name_tab(38, "between(1, 1, _)").
name_tab(39, "!").
name_tab(40, "X = 1, X == 1").
:- cases(L), forall(member(G-N, L), ( name_tab(N, C), ( call_with_depth_limit(G, 1, R) -> format('~s ~w~n', [C, R]) ; format('~s failed~n', [C]) ) )).
PL
cat > "$W/bi2.pl" <<'PL'
c0(X, Y, Z) :- X \= Y.
c1(X, Y, Z) :- X \== Y.
c2(X, Y, Z) :- X \== a.
c3(X, Y, Z) :- X @< Y.
c4(X, Y, Z) :- X == Y.
c5(X, Y, Z) :- X == a.
c6(X, Y, Z) :- a == X.
c7(X, Y, Z) :- X = f(Y).
c8(X, Y, Z) :- f(Y) = X.
c9(X, Y, Z) :- a = X.
c10(X, Y, Z) :- fail.
c11(X, Y, Z) :- false.
c12(X, Y, Z) :- X is Y.
c13(X, Y, Z) :- 1 =:= X.
c14(X, Y, Z) :- X =@= Y.
c15(X, Y, Z) :- X > 1.
c16(X, Y, Z) :- X = Y, Y = Z.
c17(X, Y, Z) :- \+ X = a.
c18(X, Y, Z) :- \+ a = a.
c19(X, Y, Z) :- (X = a ; Y = b).
c20(X, Y, Z) :- (X = a -> true ; true).
cases([c0-0,c1-1,c2-2,c3-3,c4-4,c5-5,c6-6,c7-7,c8-8,c9-9,c10-10,c11-11,c12-12,c13-13,c14-14,c15-15,c16-16,c17-17,c18-18,c19-19,c20-20]).
name_tab(0, "X \\= Y").
name_tab(1, "X \\== Y").
name_tab(2, "X \\== a").
name_tab(3, "X @< Y").
name_tab(4, "X == Y").
name_tab(5, "X == a").
name_tab(6, "a == X").
name_tab(7, "X = f(Y)").
name_tab(8, "f(Y) = X").
name_tab(9, "a = X").
name_tab(10, "fail").
name_tab(11, "false").
name_tab(12, "X is Y").
name_tab(13, "1 =:= X").
name_tab(14, "X =@= Y").
name_tab(15, "X > 1").
name_tab(16, "X = Y, Y = Z").
name_tab(17, "\\+ X = a").
name_tab(18, "\\+ a = a").
name_tab(19, "(X = a ; Y = b)").
name_tab(20, "(X = a -> true ; true)").
:- cases(L), forall(member(G-N, L), ( name_tab(N, C), G1 =.. [G, 1, 2, 3], ( call_with_depth_limit(G1, 1, R) -> format('~s ~w~n', [C, R]) ; format('~s failed~n', [C]) ) )).
PL
build() { "$ROOT/scrip" --compile -o "$W/$1.s" "$W/$1.pl" < /dev/null > "$W/$1.c.err" 2>&1 && gcc -no-pie -o "$W/$1.bin" "$W/$1.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread > "$W/$1.l.err" 2>&1; }
bad=0
for p in shapes rec bi1 bi2; do
  timeout -k 5 60 "$SW" -q -t halt "$W/$p.pl" < /dev/null > "$W/$p.ref" 2> "$W/$p.ref.err"
  [ "$(grep -c . "$W/$p.ref")" -ge 8 ] || { echo "GATE REFUSED(2) [$G]: swipl did not answer the $p probe ($(head -c 160 "$W/$p.ref.err"))"; exit 2; }
  timeout -k 5 60 "$ROOT/scrip" "$W/$p.pl" < /dev/null > "$W/$p.m3" 2> "$W/$p.m3.err"
  build $p || { echo "GATE REFUSED(2) [$G]: the $p probe does not build ($(head -c 160 "$W/$p.c.err" "$W/$p.l.err"))"; exit 2; }
  timeout -k 5 60 "$W/$p.bin" < /dev/null > "$W/$p.m4" 2> "$W/$p.m4.err"
  sed '1s/.*/corrupted/' "$W/$p.ref" > "$W/$p.bad"
  if cmp -s "$W/$p.m3" "$W/$p.bad"; then echo "GATE REFUSED(2) [$G]: the comparison accepted a corrupted reference -- the gate could not fail"; exit 2; fi
  for m in m3 m4; do
    sed -e 's/_G*[0-9][0-9]*/_V/g' "$W/$p.ref" > "$W/$p.ref.n"; sed -e 's/_G*[0-9][0-9]*/_V/g' "$W/$p.$m" > "$W/$p.$m.n"
    if cmp -s "$W/$p.$m.n" "$W/$p.ref.n"; then echo "  ok  $m $p: as swipl"; else echo "  RED $m $p: differs from swipl:"; diff "$W/$p.ref.n" "$W/$p.$m.n" | head -6; bad=1; fi
  done
done
TREE="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo '?')$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)"
if [ $bad -eq 0 ]; then echo "GATE PASS(0) [$G]: call_with_depth_limit/3 answers as swipl for recursion, control constructs and the frame each builtin call costs, in both modes (self-test: a corrupted reference is seen) (tree SCRIP=$TREE)"; exit 0; fi
echo "GATE FAIL(1) [$G]: call_with_depth_limit/3 differs from swipl (tree SCRIP=$TREE)"; exit 1
