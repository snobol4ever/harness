#!/usr/bin/env bash
# test_gate_pl_a_dynamic_predicate_of_ground_facts_asserts_without_a_code_fragment_and_answers_as_swipl.sh -- THE FACTS-ONLY DATA PATH (ARCH-PROLOG-DATABASE section 13 items 1 and 3; hq_runtime, row prolog-dynamic-fact-table-scales-long-primes-1): a dynamic predicate whose clauses are
# ground facts is stored as slots and called through one data proc per predicate (the TO db walk over the first-argument key, unifying the stored cells in place with copy-on-bind),
# and assertz compiles NO code fragment for such a fact; the first rule or non-ground fact leaves the path for good and compiles the slots.
#   ARM 1 (answers): a witness over order and duplicates, asserta, an atomic and a compound argument (a compound bound by a call is a COPY: setarg on it changes nothing stored), a
#     deterministic exit (setup_call_cleanup runs its cleanup at the exit of a one-solution call), the logical update view, a variable-argument fact arriving, a RULE asserted into a facts-only
#     predicate DURING an iteration over it, retract of every fact followed by a rule, retractall then facts again, attributed variables (freeze, dif) as call arguments, and the aggregates,
#     meta-calls and cuts over a fact table -- cut from swipl in THIS run and compared with SCRIP's mode 3 and mode 4.
#   ARM 2 (cost): asserting 300 ground facts costs at most 20 M instructions more than the program that asserts none (a compiled fragment per fact cost 2.6 M each, 780 M for the 300), under callgrind.
#   FAIL-ONCE (a proper test, never a seam in SCRIP): the same 300 facts after ONE non-ground fact (which leaves the path and compiles every fact) must read over 200 M instructions dearer than the
#     data path, else the instrument cannot see a compile and refuses rc 2.
#   ARM 3 (collection): the witness under SCRIP_GC_STRESS=1 at a 128 KB window, mode 3, answers as swipl.
# The cost arm is an instruction count (CEO-1785/1786), never a clock.
set -u
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP"; exit 2; }
[ -x "$ROOT/scrip" ] || { echo "GATE REFUSED(2) [$G]: no $ROOT/scrip -- run make"; exit 2; }
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$G" "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" || exit 2
command -v gcc >/dev/null 2>&1 || { echo "GATE REFUSED(2) [$G]: gcc absent"; exit 2; }
. "$HERE/lib_oracle_flags.sh" || { echo "GATE REFUSED(2) [$G]: lib_oracle_flags.sh unloadable -- the one accessor of the oracle binaries"; exit 2; }
. "$HERE/lib_ir_measure.sh" || { echo "GATE REFUSED(2) [$G]: lib_ir_measure.sh unloadable -- the one authority for an Ir reading"; exit 2; }
ir_have_valgrind || { echo "GATE REFUSED(2) [$G]: no valgrind or callgrind_annotate -- the cost arm reads instructions"; exit 2; }
SW="$(swipl_bin)"; [ -x "$SW" ] || { echo "GATE REFUSED(2) [$G]: no swipl at $SW -- the oracle (swipl_bin)"; exit 2; }
W="$(mktemp -d "${TMPDIR:-/tmp}/pldata.XXXXXX")" || { echo "GATE REFUSED(2) [$G]: no workdir"; exit 2; }; trap 'rm -rf "$W"' EXIT
BOUND=20000000; COMPILE=200000000
cat > "$W/dp.pl" <<'PL'
:- dynamic t/2, u/1, w/2, e/1, nd/1, r2/1, big/2.
show(G) :- ( findall(G, G, L) -> \+ \+ ( numbervars(L, 0, _), write(L) ) ; write(none) ), nl.
:- assertz(t(1, a)), assertz(t(2, b)), asserta(t(0, z)), assertz(t(2, bb)).
:- show(t(_, _)).
:- show(t(2, _)).
:- show(t(_, b)).
:- show(t(7, _)).
:- setup_call_cleanup(true, t(1, _), ( write(det_cleanup_1), nl )).
:- setup_call_cleanup(true, t(2, _), ( write(det_cleanup_2), nl )), write(after_t2), nl, !.
:- setup_call_cleanup(true, t(0, _), ( write(det_cleanup_0), nl )).
:- assertz(u(g(1, 2))), assertz(u([a, b, c])), assertz(u(1.5)), assertz(u(-7)), assertz(u('A b')).
:- ( u(X), X = g(_, _), setarg(1, X, 99), write(changed(X)), nl, fail ; true ).
:- show(u(_)).
:- u(g(A, B)), write(A-B), nl.
:- show(u(g(1, _))).
:- show(u([a|_])).
:- show(u(-7)).
:- show(u(1.5)).
:- show(u(2.5)).
:- forall(t(K, _), assertz(t(K, new))).
:- show(t(2, _)).
:- forall(retract(t(2, V)), ( write(r(V)), nl )).
:- show(t(_, _)).
:- assertz(w(1, a)), assertz(w(2, b)).
:- assertz(w(_, anyv)).
:- show(w(1, _)).
:- show(w(3, _)).
:- show(w(_, _)).
:- assertz(e(1)), assertz(e(2)), assertz(e(3)).
:- forall(e(X), ( X == 2 -> assertz(( e(Y) :- Y = rule )) ; true )).
:- show(e(_)).
:- show(e(rule)).
:- show(e(2)).
:- assertz(r2(1)), assertz(r2(2)), retract(r2(1)), retract(r2(2)).
:- assertz(( r2(Z) :- Z = fromrule )).
:- show(r2(_)).
:- assertz(nd(1)), retractall(nd(_)), assertz(nd(2)), assertz(nd(3)), show(nd(_)).
:- show(nd(3)).
:- retractall(nd(2)), show(nd(_)).
:- forall(between(1, 30, I), ( J is I * I, assertz(big(I, J)) )).
:- show(big(30, _)).
:- show(big(_, 100)).
:- retract(big(30, _)), show(big(30, _)).
:- assertz(big(31, 961)), show(big(31, _)).
:- clause(big(5, X), B), write(X-B), nl.
:- aggregate_all(count, big(_, _), N), write(N), nl.
:- dynamic fa/1, fb/2, fc/1.
:- assertz(fa(1)), assertz(fa(2)), assertz(fa(3)).
:- ( freeze(X, ( write(woke(X)), nl )), fa(X), write(got(X)), nl, fail ; true ).
:- dif(X, 2), findall(X, fa(X), L), write(L), nl.
:- freeze(X, X > 1), findall(X, fa(X), L), write(L), nl.
:- assertz(fb(a, 1)), assertz(fb(b, 2)), assertz(fb(a, 3)).
:- catch(( fb(a, X), X > 2, write(x(X)), nl ), E, ( write(E), nl )).
:- forall(fb(K, V), ( write(K-V), nl )).
:- findall(K-V, ( fb(K, V), V > 1 ), L), write(L), nl.
:- bagof(V, fb(a, V), L), write(L), nl.
:- aggregate_all(count, fb(a, _), C), write(C), nl.
:- aggregate_all(sum(V), fb(_, V), S), write(S), nl.
:- setof(K, V^fb(K, V), L), write(L), nl.
:- ( \+ fb(c, _) -> write(no_c) ; write(c) ), nl.
:- ( fb(a, 3) -> write(yes) ; write(no) ), nl.
:- call(fb, b, W), write(w(W)), nl.
:- G = fb(a, Z), call(G), write(z(Z)), nl.
:- retract(fb(a, 1)), findall(V, fb(a, V), L), write(L), nl.
:- assertz(fc(f(X, Y))), write(unreachable), nl ; write(nonground_ok), nl.
:- fc(Q), write(Q), nl.
:- forall(between(1, 5, I), assertz(fb(k, I))), findall(V, fb(k, V), L), write(L), nl.
:- fb(k, 3), !, write(cut_ok), nl.
:- once(fb(k, V)), write(once(V)), nl.
:- \+ \+ ( fb(k, 4), write(inner), nl ).
:- length(L, 2), L = [fb(k, 5), fb(k, 1)], maplist(call, L), write(ok_maplist), nl.
PL
build() { "$ROOT/scrip" --compile --out="$W/$1.s" "$W/$1.pl" < /dev/null > "$W/$1.c.err" 2>&1 && gcc -no-pie -o "$W/$1.bin" "$W/$1.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread > "$W/$1.l.err" 2>&1; }
norm() { sed -e 's/_G*[0-9][0-9]*/_V/g' "$1"; }
bad=0
p=dp
timeout -k 5 60 "$SW" -q -t halt "$W/$p.pl" < /dev/null > "$W/$p.ref" 2> "$W/$p.ref.err"
[ "$(grep -c . "$W/$p.ref")" -ge 50 ] || { echo "GATE REFUSED(2) [$G]: swipl did not answer the $p witness ($(head -c 160 "$W/$p.ref.err"))"; exit 2; }
timeout -k 5 120 "$ROOT/scrip" "$W/$p.pl" < /dev/null > "$W/$p.m3" 2> "$W/$p.m3.err"
build $p || { echo "GATE REFUSED(2) [$G]: the $p witness does not build ($(head -c 160 "$W/$p.c.err" "$W/$p.l.err"))"; exit 2; }
timeout -k 5 120 "$W/$p.bin" < /dev/null > "$W/$p.m4" 2> "$W/$p.m4.err"
sed '1s/.*/corrupted/' "$W/$p.ref" > "$W/$p.bad"
if cmp -s "$W/$p.m3" "$W/$p.bad"; then echo "GATE REFUSED(2) [$G]: the comparison accepted a corrupted reference -- the gate could not fail"; exit 2; fi
norm "$W/$p.ref" > "$W/$p.ref.n"
for m in m3 m4; do
  norm "$W/$p.$m" > "$W/$p.$m.n"
  if cmp -s "$W/$p.$m.n" "$W/$p.ref.n"; then echo "  ok  arm 1 $m: the data-path witness answers as swipl ($(grep -c . "$W/$p.ref") lines)"; else echo "  RED arm 1 $m: differs from swipl:"; diff "$W/$p.ref.n" "$W/$p.$m.n" | head -8; bad=1; fi
done
SCRIP_GC_STRESS=1 SCRIP_HEAP_KB=128 timeout -k 5 900 "$ROOT/scrip" "$W/$p.pl" < /dev/null > "$W/$p.gc" 2> "$W/$p.gc.err"
norm "$W/$p.gc" > "$W/$p.gc.n"
if cmp -s "$W/$p.gc.n" "$W/$p.ref.n"; then echo "  ok  arm 3 m3: the witness answers as swipl through a collection at every safe point"; else echo "  RED arm 3 m3: differs from swipl under SCRIP_GC_STRESS:"; diff "$W/$p.ref.n" "$W/$p.gc.n" | head -6; bad=1; fi
mk() { printf ':- dynamic f/2.\nfill(N) :- forall(between(1, N, I), assertz(f(I, I))).\n%s\n:- write(done), nl.\n' "$2" > "$W/$1.pl"; }
mk none ':- true.'
mk facts ':- fill(300).'
mk leave ':- assertz(f(_, any)), fill(300).'
for k in none facts leave; do
  v="$(ir_measure "$ROOT/scrip" "$W/$k.pl")"
  ir_is_number "$v" || { echo "GATE REFUSED(2) [$G]: the $k probe gave no instruction reading ($(ir_cell "$v"): $(ir_reason "$v"))"; exit 2; }
  eval "ir_$k=$v"
done
cost=$(( ir_facts - ir_none )); compile=$(( ir_leave - ir_facts ))
if [ "$compile" -le "$COMPILE" ]; then echo "GATE REFUSED(2) [$G]: 300 facts after a non-ground fact cost only $compile more than the data path (need over $COMPILE) -- the instrument cannot see a compile"; exit 2; fi
if [ "$cost" -le "$BOUND" ]; then echo "  ok  arm 2 cost: asserting 300 ground facts reads $cost instructions over the program that asserts none (bound $BOUND); after a non-ground fact the same 300 read $compile more, so a compile is seen"
else echo "  RED arm 2 cost: asserting 300 ground facts reads $cost instructions over none, over the bound $BOUND -- a fact still compiles code"; bad=1; fi
TREE="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo '?')$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)"
if [ $bad -eq 0 ]; then echo "GATE PASS(0) [$G]: a dynamic predicate of ground facts asserts without a code fragment, answers as swipl in both modes and through a collection, and leaves the path when a rule or a non-ground fact arrives (self-test: a corrupted reference is seen, a compile reads dearer) (tree SCRIP=$TREE)"; exit 0; fi
echo "GATE FAIL(1) [$G]: the facts-only data path differs from swipl or from its cost (tree SCRIP=$TREE)"; exit 1
