#!/usr/bin/env bash
# test_gate_pl_backtrackable_global_and_setarg_assignments_restore_as_swipl_and_keep_no_trail_in_a_deterministic_loop.sh -- b_setval/2 and setarg/3 write
# a trail entry so that backtracking can restore the old value; the entry is needed only when a choice point newer than the written cell exists. SCRIP
# logged EVERY assignment of a heap-resident cell while any choice point existed (the directive's own catch frame is one), so a deterministic loop of
# two million b_setval or setarg calls kept every old value alive and exhausted a 16 MB heap with resource_error(stack) where swipl runs it in constant
# space (CHR keeps each constraint store in a b_setval cell, one assignment per constraint added or removed: ProRosetta hailstone-sequence-6, CEO-2005).
# Two halves, both modes. RESTORE: 21 cases (nested choice points, an assignment between two choice points, \+, findall, catch, a mutation of a term older
# than the choice point and of a term newer than it) printed by SCRIP and by swipl in THIS run, compared byte for byte; the cases print what the next
# alternative sees, so a skipped entry that was needed reads wrong. LEAK: a b_setval loop and a setarg loop of two million rounds each under -d16384k
# -s4096k must print done. The self-test feeds the comparison a corrupted reference and requires it seen.
set -u
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP"; exit 2; }
[ -x "$ROOT/scrip" ] || { echo "GATE REFUSED(2) [$G]: no $ROOT/scrip -- run make"; exit 2; }
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$G" "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" || exit 2
command -v gcc >/dev/null 2>&1 || { echo "GATE REFUSED(2) [$G]: gcc absent"; exit 2; }
. "$HERE/lib_oracle_flags.sh" || { echo "GATE REFUSED(2) [$G]: lib_oracle_flags.sh unloadable -- the one accessor of the oracle binaries"; exit 2; }
SW="$(swipl_bin)"; [ -x "$SW" ] || { echo "GATE REFUSED(2) [$G]: no swipl at $SW -- the oracle (swipl_bin)"; exit 2; }
W="$(mktemp -d "${TMPDIR:-/tmp}/pltrl.XXXXXX")" || { echo "GATE REFUSED(2) [$G]: no workdir"; exit 2; }; trap 'rm -rf "$W"' EXIT
build() { "$ROOT/scrip" --compile --out="$W/$1.s" "$W/$1.pl" < /dev/null > "$W/$1.c.err" 2>&1 && gcc -no-pie -o "$W/$1.bin" "$W/$1.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread > "$W/$1.l.err" 2>&1; }
cat > "$W/restore.pl" <<'EOF'
g(V) :- nb_getval(k, V).
t1 :- nb_setval(k, a), ( b_setval(k, b), b_setval(k, c), fail ; g(V), writeln(t1(V)) ).
t2 :- nb_setval(k, a), b_setval(k, b), ( b_setval(k, c), b_setval(k, d), fail ; g(V), writeln(t2(V)) ).
t3 :- nb_setval(k, a), ( member(X, [1, 2, 3]), b_setval(k, x(X)), b_setval(k, y(X)), g(V), writeln(t3(X, V)), fail ; g(W), writeln(t3_end(W)) ).
t4 :- nb_setval(k, a), b_setval(k, b), ( ( member(X, [1, 2]), b_setval(k, c(X)), b_setval(k, d(X)), g(V1), writeln(t4in(X, V1)), fail ; g(V2), writeln(t4mid(V2)) ), b_setval(k, e), fail ; g(V3), writeln(t4end(V3)) ).
t5 :- nb_setval(k, a), ( b_setval(k, 1), ( b_setval(k, 2), b_setval(k, 3), g(A), writeln(t5a(A)), fail ; g(B), writeln(t5b(B)), b_setval(k, 4), b_setval(k, 5), fail ) ; g(C), writeln(t5c(C)) ).
t6 :- nb_setval(k, a), \+ ( b_setval(k, p), b_setval(k, q), fail ), g(V), writeln(t6(V)).
t7 :- nb_setval(k, a), findall(X, ( member(X, [1, 2]), b_setval(k, X), b_setval(k, z) ), L), g(V), writeln(t7(L, V)).
t8 :- nb_setval(k, a), catch(( b_setval(k, m), b_setval(k, n), throw(oops) ), oops, true), g(V), writeln(t8(V)).
t9 :- nb_setval(k, a), ( ( b_setval(k, 1), b_setval(k, 2) ; b_setval(k, 3), b_setval(k, 4) ), g(V), writeln(t9(V)), fail ; g(W), writeln(t9_end(W)) ).
s1 :- T = f(a,b), ( setarg(1, T, x), setarg(2, T, y), fail ; writeln(s1(T)) ).
s2 :- ( member(_, [1,2]), T = f(a), setarg(1, T, z), writeln(s2(T)), fail ; true ).
s3 :- T = f(a), ( member(X, [1,2,3]), setarg(1, T, X), writeln(s3(T)), fail ; writeln(s3_end(T)) ).
s4 :- T = g(1,2,3), ( setarg(1, T, p), ( setarg(2, T, q), fail ; writeln(s4a(T)) ), setarg(3, T, r), fail ; writeln(s4b(T)) ).
s5 :- T = h(0), ( between(1, 3, I), setarg(1, T, I), I >= 3 -> writeln(s5(T)) ; writeln(no) ).
s6 :- T = k(a), \+ ( setarg(1, T, b), fail ), writeln(s6(T)).
s7 :- T = k(a), findall(x, (member(_, [1,2]), setarg(1, T, c)), _), writeln(s7(T)).
s8 :- T = m(a,b), catch((setarg(1,T,x), throw(e)), e, true), writeln(s8(T)).
s9 :- ( member(X, [1,2]), T = f(X), setarg(1, T, new), writeln(s9(T)), fail ; true ).
s10 :- T = c(0), ( between(1, 50000, I), setarg(1, T, I), I >= 50000 -> writeln(s10(T)) ; true ), ( T = c(V), V > 0, fail ; writeln(s10b(T)) ).
s11 :- T = d(a, b), ( member(X, [1,2]), setarg(X, T, n(X)), numlist(1, 5000, L), length(L, _), writeln(s11(T)), fail ; writeln(s11_end(T)) ).
s12 :- T = e(1), ( setarg(1, T, f(2)), T = e(f(A)), setarg(1, T, A), writeln(s12(T)), fail ; writeln(s12_end(T)) ).
:- t1, t2, t3, t4, t5, t6, t7, t8, t9, s1, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11, s12, halt.
EOF
cat > "$W/bloop.pl" <<'EOF'
:- nb_setval(k, []).
t(0) :- !.
t(N) :- nb_getval(k, _), b_setval(k, [N, x, y, z]), N1 is N - 1, t(N1).
:- t(2000000), writeln(done).
EOF
cat > "$W/sloop.pl" <<'EOF'
t(0) :- !.
t(N) :- T = f(a, b, c), setarg(2, T, x), setarg(1, T, N), N1 is N - 1, t(N1).
:- t(2000000), writeln(done).
EOF
timeout -k 5 60 "$SW" -q -t halt "$W/restore.pl" < /dev/null > "$W/ref" 2> "$W/ref.err"
[ "$(grep -c . "$W/ref")" -ge 40 ] || { echo "GATE REFUSED(2) [$G]: swipl did not answer the restore cases ($(head -c 160 "$W/ref.err"))"; exit 2; }
timeout -k 5 120 "$ROOT/scrip" "$W/restore.pl" < /dev/null > "$W/m3" 2>&1
build restore || { echo "GATE REFUSED(2) [$G]: the restore witness does not build ($(head -c 160 "$W/restore.c.err" "$W/restore.l.err"))"; exit 2; }
timeout -k 5 120 "$W/restore.bin" < /dev/null > "$W/m4" 2>&1
sed '1s/.*/corrupted/' "$W/ref" > "$W/bad"
if cmp -s "$W/m3" "$W/bad"; then echo "GATE REFUSED(2) [$G]: the comparison accepted a corrupted reference -- the gate could not fail"; exit 2; fi
bad=0
for m in m3 m4; do
  if cmp -s "$W/$m" "$W/ref"; then echo "  ok  $m restore: the 21 cases print what swipl prints"; else echo "  RED $m restore: output differs from swipl:"; diff "$W/ref" "$W/$m" | head -6; bad=1; fi
done
for p in bloop sloop; do
  timeout -k 5 120 "$ROOT/scrip" -d16384k -s4096k "$W/$p.pl" < /dev/null > "$W/$p.m3" 2>&1
  build $p || { echo "GATE REFUSED(2) [$G]: the $p witness does not build"; exit 2; }
  timeout -k 5 120 "$W/$p.bin" -d16384k -s4096k < /dev/null > "$W/$p.m4" 2>&1
  for m in m3 m4; do
    if grep -qx done "$W/$p.$m"; then echo "  ok  $m $p: two million rounds in constant space"; else echo "  RED $m $p: did not finish under a 16 MB heap: $(head -c 120 "$W/$p.$m")"; bad=1; fi
  done
done
TREE="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo '?')$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)"
if [ $bad -eq 0 ]; then echo "GATE PASS(0) [$G]: b_setval and setarg restore on backtracking as swipl does and a deterministic loop of two million of either runs under a 16 MB heap, in both modes (self-test: a corrupted reference is seen) (tree SCRIP=$TREE)"; exit 0; fi
echo "GATE FAIL(1) [$G]: a backtrackable assignment restores wrongly or leaks in one mode (tree SCRIP=$TREE)"; exit 1
