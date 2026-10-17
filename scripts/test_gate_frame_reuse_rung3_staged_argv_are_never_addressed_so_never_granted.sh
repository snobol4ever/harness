#!/bin/bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# ⭐ RUNG 3, STEP (a), OF frame-slot-reuse-a-live-range-in-a-byrd-graph-extends-to-every-point-reachable-by-recession
# (cto, CEO-684 slice 2): THE STAGED CALL'S ARGV NON-GRANT.  bb_call_proc_staged marshals a callee's arguments over rsp
# (x86_rsp_store64 32+16i) from the PRODUCER boxes' own slots (bcps_arg_slot: bb_slot_get / zls_off of the argument node),
# and its beta resumes the callee through the callgen.act quad -- it never writes and never reads the call's own
# call.argv quads, in any arm, alpha or beta (the census named them NOREF at 09c0e5608; every [rbp+N] of every body
# lands in a grant, test_gate_dump_zeta_is_the_emitted_frame.sh).  A quad no template writes cannot carry a value
# any recession could re-read, so the layout stops granting it: an IR_CALL_PROC_STAGED gets its result and, for a
# generator callee, ONE callgen.act quad whose offset the template takes from zls_act_off (the layout's own field),
# not from result + 16*(1+nargs).  The act quad's two halves are described as what the template writes (+0 the
# epilogue-once flag / the callee's retained frame base, +8 the callee's graph beta or the saved rsp -- WRITTEN, not
# a pad).
# ⛔ THE CLAIM IS HELD BY TWO INSTRUMENTS, NOT BY MEMORY: (1) the honest dump shows no call.argv field on any
# IR_CALL_PROC_STAGED in the witness, and r/1 <= 272 (304 - 2 x 16); (2) util_frame_refs_land_in_grants.py finds 0
# unlanded references over the whole prelude -- if any body still addressed a staged argv quad, that reference would
# now land in no grant and this gate goes red.
# ⛔ THE FAILURE MODE IS SILENCE, so answers are graded too: the backtrack witness p(X) :- q(X), s(X) with q/1 three
# alternatives and s/1 matching only the third must print 3 in both modes (the beta path INTO the first staged call,
# resumed after the second fails, with the argv quads absent; ref cut from swipl and gprolog, both print 3), plus the
# three witnesses of rungs 1 and 2.
# RED-BEFORE on the rung-2 tree bbd5c370a: r/1 304 with 2 staged argv fields, rc=1.
# ⛔ REFUSES rc=2 when --dump-zeta yields no r/1 graph.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="${S4E_HOME:-$(cd "$HERE/../../SCRIP" && pwd)}"; [ -x "$ROOT/scrip" ] || ROOT="$(cd "$HERE/../.." && pwd)/SCRIP"
cd "$ROOT" || exit 2
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
cp ../harness/scripts/fixtures/frame_r1_witness.pl "$T/w.pl"; echo "ok" > "$T/w.pl.ref"
printf 'p(X) :- q(X), s(X).\nq(1).\nq(2).\nq(3).\ns(3).\n:- initialization(main).\nmain :- p(X), write(X), nl, halt.\n' > "$T/bt.pl"; echo "3" > "$T/bt.pl.ref"
printf 'procedure main()\n   every write(image(1), 1 to 3);\nend\n' > "$T/w.icn"; printf '11\n12\n13\n' > "$T/w.icn.ref"
printf "        S = 'abcabc'\n        S BREAK('c') . T\n        OUTPUT = T\nEND\n" > "$T/w.sno"; echo "ab" > "$T/w.sno.ref"
bad=0
timeout -k 5 20s ./scrip --dump-zeta "$T/w.pl" </dev/null 2>/dev/null > "$T/pl.dump"
line="$(grep -E "^; graph [0-9]+ 'r/1'" "$T/pl.dump")"
[ -n "$line" ] || { echo "⛔ REFUSE(2): --dump-zeta printed no r/1 graph for the witness"; exit 2; }
end="$(printf '%s\n' "$line" | sed -n 's/.*region_end=\([0-9]*\).*/\1/p')"
echo "r/1 region_end=$end (bar <= 272; rung-2 tree read 304)"
[ -n "$end" ] && [ "$end" -le 272 ] || { echo "  ⛔ r/1 frame is $end bytes, above the rung-3(a) bar of 272"; bad=$((bad+1)); }
sargv="$(grep -cE 'call\.argv +IR_CALL_PROC_STAGED' "$T/pl.dump")"; sact="$(grep -cE 'callgen\.act \+0.*IR_CALL_PROC_STAGED' "$T/pl.dump")"; pad="$(grep -c 'callgen.act pad (unused)' "$T/pl.dump")"
echo "prelude: staged call.argv fields=$sargv staged callgen.act quads=$sact 'pad (unused)' descriptions=$pad"
[ "$sargv" -eq 0 ] || { echo "  ⛔ $sargv staged call.argv field(s) still granted"; bad=$((bad+1)); }
[ "$sact" -ge 2 ] || { echo "  ⛔ the staged calls of the witness lost their callgen.act quad ($sact)"; bad=$((bad+1)); }
[ "$pad" -eq 0 ] || { echo "  ⛔ $pad act quad(s) still describe their written half as an unused pad"; bad=$((bad+1)); }
refs="$(timeout -k 5 120s python3 ../harness/scripts/util_frame_refs_land_in_grants.py "$T/w.pl" 2>/dev/null | grep -E '^; grants TOTAL')"
echo "$refs"
printf '%s\n' "$refs" | grep -qE 'findings=0\b' || { echo "  ⛔ a body references a frame quad the layout no longer grants"; bad=$((bad+1)); }
for w in w.pl bt.pl w.icn w.sno; do
    out3="$(timeout -k 5 20s ./scrip "$T/$w" </dev/null 2>&1)"
    if [ "$out3" != "$(cat "$T/$w.ref")" ]; then echo "  ⛔ $w mode 3 printed [$out3], ref [$(cat "$T/$w.ref" | tr '\n' ' ')]"; bad=$((bad+1)); fi
    if timeout -k 5 20s ./scrip --compile "$T/$w" > "$T/$w.s" 2>/dev/null && gcc -c "$T/$w.s" -o "$T/$w.o" 2>/dev/null && gcc "$T/$w.o" -Lout -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$T/$w.bin" 2>/dev/null; then
        out4="$(timeout -k 5 20s "$T/$w.bin" </dev/null 2>&1)"
        if [ "$out4" != "$(cat "$T/$w.ref")" ]; then echo "  ⛔ $w mode 4 printed [$out4], ref [$(cat "$T/$w.ref" | tr '\n' ' ')]"; bad=$((bad+1)); fi
    else echo "  ⛔ $w mode 4 did not build"; bad=$((bad+1)); fi
done
if [ "$bad" -gt 0 ]; then echo "⛔ GATE FAIL: $bad finding(s) -- rung 3(a) does not hold"; exit 1; fi
echo "GATE OK: r/1 reads $end bytes, no staged call carries argv quads, every body reference lands in a grant, and the four witnesses print their refs in both modes"
