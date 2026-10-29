#!/usr/bin/env bash
# test_gate_pl_dynamic_first_argument_index_answers_as_swipl_and_a_keyed_call_costs_the_same_at_either_end_of_the_table.sh -- THE DYNAMIC FIRST-ARGUMENT INDEX (ARCH-PROLOG-DATABASE section 7; hq_runtime, row prolog-dynamic-fact-table-scales-long-primes-1): the TO db walk of clause/2 and
# retract/1 and the retractall walk visit the candidates of ONE KEY (an atom, a small integer, a functor, or the one list of the other kinds) and not every slot, and answer exactly
# as the walk over every slot did.
#   ARM 1 (answers): a witness over the key kinds (small and negative integers, atoms, a float, a string, a compound of two functors, a big integer, the atom 1 against the integer 1),
#     assertz and asserta order, duplicates of one key, a clause with a body, a first-argument variable arriving after the index exists (the index is dropped, the walk is every slot),
#     retract during an iteration over its own key, abolish, and retractall by a key, by a variable and by a second argument -- cut from swipl in THIS run and compared byte for byte
#     with SCRIP's mode 3 and mode 4.
#   ARM 2 (cost): the same 200-fact table is asked 1000 times for its LAST key and for its FIRST key, each run under callgrind; the two readings differ by at most 5,000,000 instructions
#     (a walk over every slot makes the last key 199 slots dearer than the first, a difference in the tens of millions; measured on the walk before the index, 25 K instructions per ask at 1000 slots)
#   FAIL-ONCE (a proper test, never a seam in SCRIP): the same table asked for its last key through an UNBOUND first argument (clause(f(X,_),true), X == 200), which has no key and
#     walks every slot, must read dearer than the keyed ask by more than 100,000,000 instructions -- an instrument that cannot see a full walk is refused rc 2.
#   ARM 3 (collection): a 600-fact table asserted, asked, half retracted and asked again, then extended, under SCRIP_GC_STRESS=1 at a 128 KB window (a collection at every
#     safe point; the index block is reached only through the db record, which the collector moves), answers as swipl in both modes.
# The answers arm is the swipl comparison; the cost arm is an instruction count (CEO-1785/1786), never a clock.
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
W="$(mktemp -d "${TMPDIR:-/tmp}/plindex.XXXXXX")" || { echo "GATE REFUSED(2) [$G]: no workdir"; exit 2; }; trap 'rm -rf "$W"' EXIT
BOUND=5000000; FULLWALK=100000000
cat > "$W/ix.pl" <<'PL'
:- dynamic t/2, u/1, v/2, w/1.
show(G) :- ( findall(G, G, L) -> \+ \+ ( numbervars(L, 0, _), write(L) ) ; write(none) ), nl.
fill :- forall(between(1, 40, I), (J is I * I, assertz(t(I, J)))).
:- fill.
:- show(clause(t(7, X), B)).
:- show(retract(t(7, X))).
:- show(clause(t(7, X), B)).
:- show(retract(t(99, X))).
:- assertz(t(7, a)), assertz(t(7, b)), assertz(t(8, c)).
:- show(clause(t(7, X), true)).
:- show(clause(t(8, X), true)).
:- asserta(t(7, first)).
:- show(clause(t(7, X), true)).
:- show(clause(t(X, 49), true)).
:- show(clause(t(X, Y), true)).
:- assertz((t(3, Z) :- Z = body)).
:- show(clause(t(3, X), B)).
:- show(retract((t(3, X) :- B))).
:- show(clause(t(3, X), B)).
:- assertz(t(1.5, flt)), format(string(S0), '~w', [str]), assertz(t(S0, s)), assertz(t(f(1), c1)), assertz(t(f(1, 2), c2)), assertz(t(-5, neg)), assertz(t(123456789012345678901234567890, big)), assertz(t('1', atomone)), assertz(t(1, intone)).
:- show(clause(t(1.5, X), true)).
:- format(string(S1), '~w', [str]), show(clause(t(S1, X), true)).
:- show(clause(t(f(1), X), true)).
:- show(clause(t(f(_), X), true)).
:- show(clause(t(f(1, 2), X), true)).
:- show(clause(t(f(_, _), X), true)).
:- show(clause(t(-5, X), true)).
:- show(clause(t(123456789012345678901234567890, X), true)).
:- show(clause(t('1', X), true)).
:- show(clause(t(1, X), true)).
:- show(clause(t(2.5, X), true)).
:- show(clause(t(zzz, X), true)).
:- forall(retract(t(5, X)), (assertz(t(5, again)), write(r(X)), nl)).
:- show(clause(t(5, X), true)).
:- show(retract(t(9, _))).
:- show(retract(t(1, X))).
:- show(clause(t(1, X), true)).
:- assertz(t(_, anyclause)).
:- show(clause(t(10, X), true)).
:- show(clause(t(f(1), X), true)).
:- show(retract(t(10, X))).
:- show(retract(t(10, X))).
:- forall(between(1, 30, I), (format(atom(A), 'k~w', [I]), assertz(u(A)))).
:- show(clause(u(k7), true)).
:- show(retract(u(k7))).
:- show(clause(u(k7), true)).
:- show(retract(u(k30))).
:- show(clause(u(X), true)).
:- forall(between(1, 12, I), (J is I mod 3, assertz(v(J, I)))).
:- show(clause(v(0, X), true)).
:- show(clause(v(1, X), true)).
:- show(clause(v(2, X), true)).
:- show(retract(v(1, 4))).
:- show(clause(v(1, X), true)).
:- show(retract(v(1, X))).
:- show(clause(v(1, X), true)).
:- assertz(w(1)), assertz(w(2)), asserta(w(0)).
:- forall(between(3, 20, I), assertz(w(I))).
:- show(clause(w(0), true)).
:- show(retract(w(15))).
:- show(clause(w(15), true)).
:- show(clause(w(X), true)).
:- abolish(w/1).
:- catch(show(clause(w(1), true)), error(E, _), (write(E), nl)).
:- show(retract(t(zzz, _))).
:- retractall(t(8, _)).
:- show(clause(t(8, X), true)).
:- show(clause(t(9, X), true)).
:- retractall(u(k3)).
:- show(clause(u(k3), true)).
:- show(clause(u(k4), true)).
:- retractall(t(f(1), _)).
:- show(clause(t(f(1), X), true)).
:- show(clause(t(f(1, 2), X), true)).
:- retractall(t(nokey, _)).
:- retractall(t(1.5, _)).
:- show(clause(t(1.5, X), true)).
:- retractall(v(_, 3)).
:- show(clause(v(0, X), true)).
:- retractall(v(_, _)).
:- show(clause(v(2, X), true)).
:- assertz(v(2, again)).
:- show(clause(v(2, X), true)).
PL
build() { "$ROOT/scrip" --compile -o "$W/$1.s" "$W/$1.pl" < /dev/null > "$W/$1.c.err" 2>&1 && gcc -no-pie -o "$W/$1.bin" "$W/$1.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread > "$W/$1.l.err" 2>&1; }
bad=0
p=ix
timeout -k 5 60 "$SW" -q -t halt "$W/$p.pl" < /dev/null > "$W/$p.ref" 2> "$W/$p.ref.err"
[ "$(grep -c . "$W/$p.ref")" -ge 40 ] || { echo "GATE REFUSED(2) [$G]: swipl did not answer the $p witness ($(head -c 160 "$W/$p.ref.err"))"; exit 2; }
timeout -k 5 120 "$ROOT/scrip" "$W/$p.pl" < /dev/null > "$W/$p.m3" 2> "$W/$p.m3.err"
build $p || { echo "GATE REFUSED(2) [$G]: the $p witness does not build ($(head -c 160 "$W/$p.c.err" "$W/$p.l.err"))"; exit 2; }
timeout -k 5 120 "$W/$p.bin" < /dev/null > "$W/$p.m4" 2> "$W/$p.m4.err"
sed '1s/.*/corrupted/' "$W/$p.ref" > "$W/$p.bad"
if cmp -s "$W/$p.m3" "$W/$p.bad"; then echo "GATE REFUSED(2) [$G]: the comparison accepted a corrupted reference -- the gate could not fail"; exit 2; fi
for m in m3 m4; do
  if cmp -s "$W/$p.$m" "$W/$p.ref"; then echo "  ok  arm 1 $m: the key-kinds witness answers as swipl ($(grep -c . "$W/$p.ref") lines)"; else echo "  RED arm 1 $m: differs from swipl:"; diff "$W/$p.ref" "$W/$p.$m" | head -8; bad=1; fi
done
cat > "$W/gcs.pl" <<'PL'
:- dynamic g/2.
fill(N) :- forall(between(1, N, I), (J is I * 3, assertz(g(I, J)))).
chk(N) :- forall(between(1, N, I), (J is I * 3, ( clause(g(I, X), true) -> true ; X = none ), ( ( X == J ; X == none, I mod 2 =:= 0 ) -> true ; write(bad(I, X)), nl ))).
drop(N) :- forall(between(1, N, I), ( I mod 2 =:= 0 -> retract(g(I, _)) ; true )).
:- fill(600), chk(600), drop(600), chk(600), forall(between(601, 700, I), assertz(g(I, I))), findall(K, clause(g(K, _), true), L), length(L, Len), write(Len), nl.
PL
timeout -k 5 60 "$SW" -q -t halt "$W/gcs.pl" < /dev/null > "$W/gcs.ref" 2> "$W/gcs.ref.err"
[ "$(cat "$W/gcs.ref")" = "400" ] || { echo "GATE REFUSED(2) [$G]: swipl did not answer the collection witness 400 ($(head -c 160 "$W/gcs.ref" "$W/gcs.ref.err"))"; exit 2; }
build gcs || { echo "GATE REFUSED(2) [$G]: the collection witness does not build ($(head -c 160 "$W/gcs.c.err" "$W/gcs.l.err"))"; exit 2; }
SCRIP_GC_STRESS=1 SCRIP_HEAP_KB=128 timeout -k 5 600 "$ROOT/scrip" "$W/gcs.pl" < /dev/null > "$W/gcs.m3" 2> "$W/gcs.m3.err"
SCRIP_GC_STRESS=1 SCRIP_HEAP_KB=128 timeout -k 5 600 "$W/gcs.bin" < /dev/null > "$W/gcs.m4" 2> "$W/gcs.m4.err"
for m in m3 m4; do
  if cmp -s "$W/gcs.$m" "$W/gcs.ref"; then echo "  ok  arm 3 $m: the table answers as swipl through a collection at every safe point"; else echo "  RED arm 3 $m: differs from swipl under SCRIP_GC_STRESS:"; diff "$W/gcs.ref" "$W/gcs.$m" | head -6; bad=1; fi
done
mk() { printf ':- dynamic f/2.\nfill(N) :- forall(between(1, N, I), assertz(f(I, I))).\n:- fill(200).\n%s\n:- write(done), nl.\n' "$2" > "$W/$1.pl"; }
mk last ':- forall(between(1, 1000, _), clause(f(200, _), true)).'
mk first ':- forall(between(1, 1000, _), clause(f(1, _), true)).'
mk unkeyed ':- forall(between(1, 1000, _), (clause(f(X, _), true), X == 200)).'
for k in last first unkeyed; do
  v="$(ir_measure "$ROOT/scrip" "$W/$k.pl")"
  ir_is_number "$v" || { echo "GATE REFUSED(2) [$G]: the $k probe gave no instruction reading ($(ir_cell "$v"): $(ir_reason "$v"))"; exit 2; }
  eval "ir_$k=$v"
done
d=$(( ir_last > ir_first ? ir_last - ir_first : ir_first - ir_last ))
full=$(( ir_unkeyed - ir_last ))
if [ "$full" -le "$FULLWALK" ]; then echo "GATE REFUSED(2) [$G]: the unkeyed ask cost only $full more than the keyed one (need over $FULLWALK) -- the instrument cannot see a walk over every slot"; exit 2; fi
if [ "$d" -le "$BOUND" ]; then echo "  ok  arm 2 cost: 1000 asks of the last key read $ir_last, of the first key $ir_first (difference $d, bound $BOUND); the unkeyed ask reads $full more than the keyed one, so a full walk is seen"
else echo "  RED arm 2 cost: the last key's asks read $ir_last and the first key's $ir_first, a difference of $d over the bound $BOUND -- the walk is not by key"; bad=1; fi
TREE="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo '?')$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)"
if [ $bad -eq 0 ]; then echo "GATE PASS(0) [$G]: clause/2, retract/1 and retractall walk the candidates of one key and answer as swipl in both modes, and a keyed ask costs the same at either end of the table (self-test: a corrupted reference is seen, an unkeyed walk reads dearer) (tree SCRIP=$TREE)"; exit 0; fi
echo "GATE FAIL(1) [$G]: the dynamic first-argument index differs from swipl or from a keyed cost (tree SCRIP=$TREE)"; exit 1
