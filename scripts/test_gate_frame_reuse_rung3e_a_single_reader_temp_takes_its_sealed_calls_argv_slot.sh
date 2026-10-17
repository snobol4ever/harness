#!/bin/bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# ⭐ RUNG 3, STEP (e), OF frame-slot-reuse-a-live-range-in-a-byrd-graph-extends-to-every-point-reachable-by-recession
# (cto, CEO-684 slice 2): DIRECT MARSHAL.  A straight temp (VAR_REF / VAR / LIT / a sealed call's own result) whose
# ONLY reader is a sealed det leaf's marshal at operand j is granted the argv block's slot j as its result slot; the
# marshal then finds producer == destination and copies nothing (bb_call.cpp marshal_call_arg).  The temp's live
# range [w, r] carries the same guard as the pool (no beta-capable box between write and read), so the reuse is
# sound exactly when nothing ELSE writes slot j inside [w, r].
# ⛔ THE SILENT-WRONG-ANSWER SHAPE, PROVEN FAIL-ONCE BEFORE THE CHECK LANDED: a nested sealed call ($is_v(N1, $ax_sub(N, 1)))
# marshals ITS operands into slots 0..1 while the OUTER call's operand 0 (the VAR_REF N1, written before the inner call)
# is live -- with the interval check ablated the planner granted N1 slot 0, $ax_sub's marshal overwrote it with N, and
# BOTH the r/1 witness and the nested witness FAILED SILENTLY (rc=1, nothing printed: 5 is 4).  So the planner
# (frame_layout.c zls_direct_slot) REFUSES a temp whose slot-j interval [2w+1, 2r] meets another sealed call's marshal
# (2d, arity > j) or another direct temp's interval on the same slot; the refused temp stays pooled.
# ⛔ THE CLAIM IS HELD BY INSTRUMENTS, NOT BY MEMORY: (1) r/1 <= 224 (272 - 3 pool slots), direct >= 9, pool_slots == 1;
# (2) the operand that precedes the nested call (VAR_REF w=8 r=12) still reads POOLED in the dump -- the refusal is
# visible; (3) util_frame_refs_land_in_grants.py finds 0 unlanded references over the prelude; (4) answers both modes:
# the r/1 witness, the nested witness (q(5,Y) -> 4, (5-1)*(5+2) -> 28, the const-unify leaf with the literal on either
# side, refs cut from swipl), the rung-3(a) backtrack witness, Icon and SNOBOL4.
# RED-BEFORE on the rung-3(a) tree 946630f40: r/1 272, direct absent, rc=1.
# ⛔ REFUSES rc=2 when --dump-zeta yields no r/1 graph.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="${S4E_HOME:-$(cd "$HERE/../../SCRIP" && pwd)}"; [ -x "$ROOT/scrip" ] || ROOT="$(cd "$HERE/../.." && pwd)/SCRIP"
cd "$ROOT" || exit 2
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
cp ../harness/scripts/fixtures/frame_r1_witness.pl "$T/w.pl"; echo "ok" > "$T/w.pl.ref"
printf 'q(X, Y) :- Y is X - 1.\np(X, Z) :- Z is (X - 1) * (X + 2).\nu(X) :- 1 = X.\nv(X) :- X = 1.\n:- initialization(main).\nmain :- q(5, Y), write(Y), nl, p(5, Z), write(Z), nl, ( u(1) -> write(u_ok) ; write(u_bad) ), nl, ( v(1) -> write(v_ok) ; write(v_bad) ), nl, ( u(2) -> write(u2_bad) ; write(u2_ok) ), nl.\n' > "$T/nest.pl"
printf '4\n28\nu_ok\nv_ok\nu2_ok\n' > "$T/nest.pl.ref"
printf 'p(X) :- q(X), s(X).\nq(1).\nq(2).\nq(3).\ns(3).\n:- initialization(main).\nmain :- p(X), write(X), nl, halt.\n' > "$T/bt.pl"; echo "3" > "$T/bt.pl.ref"
printf 'procedure main()\n   every write(image(1), 1 to 3);\nend\n' > "$T/w.icn"; printf '11\n12\n13\n' > "$T/w.icn.ref"
printf "        S = 'abcabc'\n        S BREAK('c') . T\n        OUTPUT = T\nEND\n" > "$T/w.sno"; echo "ab" > "$T/w.sno.ref"
bad=0
timeout -k 5 20s ./scrip --dump-zeta "$T/w.pl" </dev/null 2>/dev/null > "$T/pl.dump"
line="$(grep -E "^; graph [0-9]+ 'r/1'" "$T/pl.dump")"
[ -n "$line" ] || { echo "⛔ REFUSE(2): --dump-zeta printed no r/1 graph for the witness"; exit 2; }
awk "/^; graph [0-9]+ 'r\/1'/{p=1;print;next} /^; graph /{p=0} p" "$T/pl.dump" > "$T/r1.dump"
end="$(printf '%s\n' "$line" | sed -n 's/.*region_end=\([0-9]*\).*/\1/p')"
sum="$(grep -E "^;   reuse 'r/1'" "$T/r1.dump")"
direct="$(printf '%s\n' "$sum" | sed -n 's/.*direct=\([0-9]*\).*/\1/p')"; pslots="$(printf '%s\n' "$sum" | sed -n 's/.*pool_slots=\([0-9]*\).*/\1/p')"
echo "r/1 region_end=$end (bar <= 224; rung-3(a) tree read 272) direct=${direct:-absent} pool_slots=${pslots:-absent}"
[ -n "$end" ] && [ "$end" -le 224 ] || { echo "  ⛔ r/1 frame is $end bytes, above the rung-3(e) bar of 224"; bad=$((bad+1)); }
[ -n "$direct" ] && [ "$direct" -ge 5 ] || { echo "  ⛔ fewer than five temps of r/1 marshal directly (nine before rung 3(f) removed the head unify and its two operands, seven before R4.1 734797863 made r(0)'s head constant unify and its two operands an IR_UNIFY_CONST box) (${direct:-absent})"; bad=$((bad+1)); }
[ -n "$pslots" ] && [ "$pslots" -eq 1 ] || { echo "  ⛔ r/1's result pool is not one slot (${pslots:-absent})"; bad=$((bad+1)); }
grep -qE '^;     reuse \+[0-9]+ +IR_VAR_REF +w=5 +r=9 +CANDIDATE reads=1 pooled' "$T/r1.dump" || { echo "  ⛔ the outer operand written before the nested sealed call (VAR_REF w=5 r=9; w=8 r=12 before rung 3(f)) is not REFUSED into the pool -- the interval check is not holding"; bad=$((bad+1)); }
ndir="$(grep -cE 'CANDIDATE reads=1 direct: argv block slot [0-9]+, the marshal copies nothing' "$T/r1.dump")"
[ "$ndir" -eq "${direct:-0}" ] || { echo "  ⛔ the summary says direct=$direct but $ndir candidate lines read direct"; bad=$((bad+1)); }
refs="$(timeout -k 5 120s python3 ../harness/scripts/util_frame_refs_land_in_grants.py "$T/w.pl" 2>/dev/null | grep -E '^; grants TOTAL')"
echo "$refs"
printf '%s\n' "$refs" | grep -qE 'findings=0\b' || { echo "  ⛔ a body references a frame quad the layout no longer grants"; bad=$((bad+1)); }
for w in w.pl nest.pl bt.pl w.icn w.sno; do
    out3="$(timeout -k 5 20s ./scrip "$T/$w" </dev/null 2>&1)"
    if [ "$out3" != "$(cat "$T/$w.ref")" ]; then echo "  ⛔ $w mode 3 printed [$out3], ref [$(cat "$T/$w.ref" | tr '\n' ' ')]"; bad=$((bad+1)); fi
    if timeout -k 5 20s ./scrip --compile "$T/$w" > "$T/$w.s" 2>/dev/null && gcc -c "$T/$w.s" -o "$T/$w.o" 2>/dev/null && gcc "$T/$w.o" -Lout -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$T/$w.bin" 2>/dev/null; then
        out4="$(timeout -k 5 20s "$T/$w.bin" </dev/null 2>&1)"
        if [ "$out4" != "$(cat "$T/$w.ref")" ]; then echo "  ⛔ $w mode 4 printed [$out4], ref [$(cat "$T/$w.ref" | tr '\n' ' ')]"; bad=$((bad+1)); fi
    else echo "  ⛔ $w mode 4 did not build"; bad=$((bad+1)); fi
done
if [ "$bad" -gt 0 ]; then echo "⛔ GATE FAIL: $bad finding(s) -- rung 3(e) does not hold"; exit 1; fi
echo "GATE OK: r/1 reads $end bytes with $direct temps marshalled directly and one pool slot, the pre-nested operand is refused, every body reference lands in a grant, and the five witnesses print their refs in both modes"
