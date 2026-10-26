#!/bin/bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# ⭐ RUNG 3, STEP (d), OF frame-slot-reuse-a-live-range-in-a-byrd-graph-extends-to-every-point-reachable-by-recession
# (cto, CEO-684 slice 2): THE DEAD-RESULT SCRATCH OVERLAYS A POOL SLOT.  Every sealed det leaf whose result nothing
# reads still stores rax:rdx at its gamma (bb_call_fn.cpp, both arms, unconditionally) into ONE shared scratch slot.
# That write lands at spine position 2p+1 (reads at 2p, writes at 2p+1, the rung-1 convention), so the scratch may
# share a pool slot q exactly when NO dead writer's 2p+1 lies inside ANY pooled interval [2w+1, 2r] on q.  The
# planner (frame_layout.c, the grant loop) tries each pool slot in order, takes the first that no dead write reaches,
# and otherwise keeps the scratch's own slot; it REFUSES (fails closed) when a dead writer is unplaced, in a nested
# scope, or a beta-capable box, or when the graph carries a gamma back-edge.  The verdict is printed on every
# graph's summary line as scratch=overlay(...) | own(REFUSED: <writer> dead write at P lands inside <temp> [lo..hi]
# on every pool slot) | own(no pool slot) | own(loop: ...) | none.
# ⛔ THE SILENT-WRONG-ANSWER SHAPE, PROVEN FAIL-ONCE BEFORE THE CHECK LANDED: atom_length/2, atom_chars/2 and
# functor/3 lower to a guard leaf ($pl_anum_guard2/3) and the builtin leaf SHARING the operand temps, so the pooled
# operand's interval covers the guard's dead write.  With the interval check ablated the planner overlaid anyway,
# the guard's success value replaced the operand, and main :- atom_length(abc, N), write(N) printed 1 with rc=0
# (ref 3), atom_chars(hi, L) printed [1] (ref [h,i]), functor(foo(a,b), F, A) printed 1/0 (ref foo/2).
# ⛔ THE CLAIM IS HELD BY INSTRUMENTS, NOT BY MEMORY: (1) r/1 <= 208 (224 - the scratch slot) and its summary reads
# scratch=overlay; (2) the prelude's atom_length/2 summary reads scratch=own(REFUSED: ... lands inside ...) -- the
# refusal is visible; (3) util_frame_refs_land_in_grants.py finds 0 unlanded references over the prelude; (4) answers
# both modes: the r/1 witness, the guard witness above (refs cut from swipl), the rung-3(e) nested witness, the
# rung-3(a) backtrack witness, Icon and SNOBOL4.
# RED-BEFORE on the rung-3(e) tree d5f59c9ad: r/1 224, no scratch= verdict printed, rc=1.
# ⛔ REFUSES rc=2 when --dump-zeta yields no r/1 graph.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="${S4E_HOME:-$(cd "$HERE/../../SCRIP" && pwd)}"; [ -x "$ROOT/scrip" ] || ROOT="$(cd "$HERE/../.." && pwd)/SCRIP"
cd "$ROOT" || exit 2
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
cp ../harness/scripts/fixtures/frame_r1_witness.pl "$T/w.pl"; echo "ok" > "$T/w.pl.ref"
printf ':- initialization(main).\nmain :- atom_length(abc, N), write(N), nl, atom_chars(hi, L), write(L), nl, functor(foo(a,b), F, A), write(F/A), nl.\n' > "$T/guard.pl"
printf '3\n[h,i]\nfoo/2\n' > "$T/guard.pl.ref"
printf 'q(X, Y) :- Y is X - 1.\np(X, Z) :- Z is (X - 1) * (X + 2).\nu(X) :- 1 = X.\nv(X) :- X = 1.\n:- initialization(main).\nmain :- q(5, Y), write(Y), nl, p(5, Z), write(Z), nl, ( u(1) -> write(u_ok) ; write(u_bad) ), nl, ( v(1) -> write(v_ok) ; write(v_bad) ), nl, ( u(2) -> write(u2_bad) ; write(u2_ok) ), nl.\n' > "$T/nest.pl"
printf '4\n28\nu_ok\nv_ok\nu2_ok\n' > "$T/nest.pl.ref"
printf 'p(X) :- q(X), s(X).\nq(1).\nq(2).\nq(3).\ns(3).\n:- initialization(main).\nmain :- p(X), write(X), nl, halt.\n' > "$T/bt.pl"; echo "3" > "$T/bt.pl.ref"
printf 'procedure main()\n   every write(image(1), 1 to 3);\nend\n' > "$T/w.icn"; printf '11\n12\n13\n' > "$T/w.icn.ref"
printf "        S = 'abcabc'\n        S BREAK('c') . T\n        OUTPUT = T\nEND\n" > "$T/w.sno"; echo "ab" > "$T/w.sno.ref"
bad=0
timeout -k 5 20s ./scrip --dump-zeta "$T/w.pl" </dev/null 2>/dev/null > "$T/pl.dump"
line="$(grep -E "^; graph [0-9]+ 'r/1'" "$T/pl.dump")"
[ -n "$line" ] || { echo "⛔ REFUSE(2): --dump-zeta printed no r/1 graph for the witness"; exit 2; }
end="$(printf '%s\n' "$line" | sed -n 's/.*region_end=\([0-9]*\).*/\1/p')"
sum="$(grep -E "^;   reuse 'r/1'" "$T/pl.dump")"
scr="$(printf '%s\n' "$sum" | sed -n 's/.*scratch=\([a-z]*\).*/\1/p')"
echo "r/1 region_end=$end (bar <= 208; rung-3(e) tree read 224) scratch=${scr:-absent}"
[ -n "$end" ] && [ "$end" -le 208 ] || { echo "  ⛔ r/1 frame is $end bytes, above the rung-3(d) bar of 208"; bad=$((bad+1)); }
[ "${scr:-}" = "overlay" ] || { echo "  ⛔ r/1's dead-result scratch does not overlay a pool slot (scratch=${scr:-absent})"; bad=$((bad+1)); }
# NO-RESULT WRITERS (cto 2026-10-17, CEO-1807): the planner skips IR_UNIFY_CONST, IR_UNIFY_FIRST and IR_UNIFY_VALUE as dead writers
# (frame_layout.c zls_writes_no_result) because their boxes bind through the dereferenced cell and jump to gamma or omega without
# storing a result slot; the claim spans the planner and three templates, so this arm reads the templates: a store to the box's
# own slot (FRQ(_.op_off ...)) in any of them reds here, and the planner must learn it before that box can write.
nw=0; for b in bb_unify_const bb_unify_first bb_unify_value; do [ -f "src/templates/bb/$b.cpp" ] || { echo "⛔ REFUSE(2): src/templates/bb/$b.cpp is missing"; exit 2; }; k="$(grep -c 'FRQ(_.op_off' "src/templates/bb/$b.cpp")"; [ "$k" -eq 0 ] || { echo "  ⛔ $b.cpp stores its result slot ($k sites) but zls_writes_no_result skips it as a dead writer"; bad=$((bad+1)); nw=1; }; done
grep -q 'static int zls_writes_no_result(IR_e op) { return op == IR_UNIFY_CONST || op == IR_UNIFY_FIRST || op == IR_UNIFY_VALUE; }' src/planner/frame_layout.c || { echo "  ⛔ zls_writes_no_result in frame_layout.c is not the three boxes this arm reads"; bad=$((bad+1)); nw=1; }
[ "$nw" -eq 0 ] && echo "no-result writers: bb_unify_const, bb_unify_first, bb_unify_value store no result slot, as zls_writes_no_result assumes"
al="$(grep -E "^;   reuse 'atom_length/2'" "$T/pl.dump")"
printf '%s\n' "$al" | grep -qE 'scratch=own\(REFUSED: IR_CALL dead write at [0-9]+ lands inside IR_VAR_REF \[[0-9]+\.\.[0-9]+\] on every pool slot\)' || { echo "  ⛔ the prelude's atom_length/2 (guard and builtin share the operand temps) is not visibly REFUSED: $al"; bad=$((bad+1)); }
nov="$(grep -cE "^;   reuse '.*scratch=overlay\(" "$T/pl.dump")"; nref="$(grep -cE "^;   reuse '.*scratch=own\(REFUSED" "$T/pl.dump")"
echo "prelude+witness graphs: overlay=$nov refused=$nref"
[ "$nov" -ge 3 ] || { echo "  ⛔ fewer than three graphs overlay (r/1, main/0, \$fc/3 and ,/2 did on the landing tree)"; bad=$((bad+1)); }
refs="$(timeout -k 5 120s python3 ../harness/scripts/util_frame_refs_land_in_grants.py "$T/w.pl" 2>/dev/null | grep -E '^; grants TOTAL')"
echo "$refs"
printf '%s\n' "$refs" | grep -qE 'findings=0\b' || { echo "  ⛔ a body references a frame quad the layout no longer grants"; bad=$((bad+1)); }
for w in w.pl guard.pl nest.pl bt.pl w.icn w.sno; do
    out3="$(timeout -k 5 20s ./scrip "$T/$w" </dev/null 2>&1)"
    if [ "$out3" != "$(cat "$T/$w.ref")" ]; then echo "  ⛔ $w mode 3 printed [$out3], ref [$(cat "$T/$w.ref" | tr '\n' ' ')]"; bad=$((bad+1)); fi
    if timeout -k 5 20s ./scrip --compile "$T/$w" > "$T/$w.s" 2>/dev/null && gcc -c "$T/$w.s" -o "$T/$w.o" 2>/dev/null && gcc "$T/$w.o" -Lout -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$T/$w.bin" 2>/dev/null; then
        out4="$(timeout -k 5 20s "$T/$w.bin" </dev/null 2>&1)"
        if [ "$out4" != "$(cat "$T/$w.ref")" ]; then echo "  ⛔ $w mode 4 printed [$out4], ref [$(cat "$T/$w.ref" | tr '\n' ' ')]"; bad=$((bad+1)); fi
    else echo "  ⛔ $w mode 4 did not build"; bad=$((bad+1)); fi
done
if [ "$bad" -gt 0 ]; then echo "⛔ GATE FAIL: $bad finding(s) -- rung 3(d) does not hold"; exit 1; fi
echo "GATE OK: r/1 reads $end bytes with its dead-result scratch overlaid on a pool slot, the guard-sharing prelude graphs are visibly refused, every body reference lands in a grant, and the six witnesses print their refs in both modes"
