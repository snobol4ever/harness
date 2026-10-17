#!/bin/bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# ⭐ RUNG 2 OF frame-slot-reuse-a-live-range-in-a-byrd-graph-extends-to-every-point-reachable-by-recession
# (cto, CEO-684 slice 2): THE DET-LEAF ARGV NON-GRANT.  A call the lowerer SEALED as a det leaf (IR_SEAL_CALL_DET_LEAF,
# rung 2 step 1: the emitter's registry knows the callee, bb_call_fn marshals the argv on alpha and calls a C function
# that returns once, beta falls to omega) has argv that are live ONLY between that call's alpha and its gamma -- the
# marshal is straight copies and NV_GET, no box of this activation runs between the marshal and the call -- so every
# sealed call of a graph marshals into ONE argv block (16 x the widest sealed arity) instead of its own; the block is
# granted once per graph with the claim in its description, and the call's result goes through the ordinary reader
# rule (straight temps' pool, or the shared dead-result scratch when nothing reads it).  The templates take the argv
# base from zls_argv_off (its default is result+16, byte-identical for every unsealed call: Icon and SNOBOL4 emission
# did not move).
# ⛔ THE CLAIM EACH SEALED CALL MAKES, PRINTED BESIDE IT BY --dump-zeta: "det leaf <name>: no beta, argv dead at gamma,
# argv@+N pooled".  A call the registry does not know is never sealed, keeps its own argv and prints "own" or nothing.
# ⛔ THE FAILURE MODE IS SILENCE, so this gate grades ANSWERS as well as bytes: the Prolog witness (ok), the Icon
# silent-failure witness `every write(image(1), 1 to 3)` -- an UNSEALED builtin call whose result is read across the
# generator -- must print 11 12 13 in both modes and its call result must read PINNED (never a pooled candidate),
# and the SNOBOL4 witness (ab) -- in BOTH modes.
# BYTES: r/1 of the DONE-WHEN witness read 480 on the rung-1 tree (the honest dump); the rung's bar is <= 320.
# RED-BEFORE on ffebafe8e (rung 2 step 1): r/1 480, no pooled argv block, rc=1.
# ⛔ REFUSES rc=2 when --dump-zeta yields no r/1 graph -- a runner that cannot measure never prints the success shape.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="${S4E_HOME:-$(cd "$HERE/../../SCRIP" && pwd)}"; [ -x "$ROOT/scrip" ] || ROOT="$(cd "$HERE/../.." && pwd)/SCRIP"
cd "$ROOT" || exit 2
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
cp ../harness/scripts/fixtures/frame_r1_witness.pl "$T/w.pl"; echo "ok" > "$T/w.pl.ref"
printf 'procedure main()\n   every write(image(1), 1 to 3);\nend\n' > "$T/w.icn"; printf '11\n12\n13\n' > "$T/w.icn.ref"
printf "        S = 'abcabc'\n        S BREAK('c') . T\n        OUTPUT = T\nEND\n" > "$T/w.sno"; echo "ab" > "$T/w.sno.ref"
bad=0
timeout -k 5 20s ./scrip --dump-zeta "$T/w.pl" </dev/null 2>/dev/null > "$T/pl.dump"
line="$(grep -E "^; graph [0-9]+ 'r/1'" "$T/pl.dump")"
[ -n "$line" ] || { echo "⛔ REFUSE(2): --dump-zeta printed no r/1 graph for the witness"; exit 2; }
end="$(printf '%s\n' "$line" | sed -n 's/.*region_end=\([0-9]*\).*/\1/p')"
echo "r/1 region_end=$end (bar <= 320; rung-1 tree read 480 on the same honest dump)"
[ -n "$end" ] && [ "$end" -le 320 ] || { echo "  ⛔ r/1 frame is $end bytes, above the rung-2 bar of 320"; bad=$((bad+1)); }
awk "/^; graph [0-9]+ 'r\/1'/{p=1} /^; graph [0-9]+ 'q\/1'/{p=0} p" "$T/pl.dump" > "$T/r1.dump"
ablk="$(grep -c 'call.argv (pooled' "$T/r1.dump")"; sealed="$(grep -c 'det leaf .*argv@+[0-9]* pooled' "$T/r1.dump")"; own="$(grep -c 'det leaf .*argv@+[0-9]* own' "$T/r1.dump")"; ownargv="$(grep -E '^;     \+[0-9]+ +16 +DESCR +call.argv +IR_CALL$' "$T/r1.dump" | wc -l)"
echo "r/1 pooled argv block slots=$ablk sealed calls pooled=$sealed sealed calls own=$own unsealed IR_CALL argv slots=$ownargv"
[ "$ablk" -ge 1 ] || { echo "  ⛔ r/1 grants no pooled argv block"; bad=$((bad+1)); }
[ "$sealed" -ge 3 ] || { echo "  ⛔ fewer than the three sealed calls of r/1 (five before rung 3(f) removed the head unify, four before R4.1 734797863 made r(0)'s head constant an IR_UNIFY_CONST box) marshal into the pooled block ($sealed)"; bad=$((bad+1)); }
[ "$own" -eq 0 ] || { echo "  ⛔ $own sealed call(s) of r/1 still hold their own argv"; bad=$((bad+1)); }
[ "$ownargv" -eq 0 ] || { echo "  ⛔ $ownargv per-call argv slot(s) survive in r/1 (every IR_CALL of r/1 is sealed)"; bad=$((bad+1)); }
timeout -k 5 20s ./scrip --dump-zeta "$T/w.icn" </dev/null 2>/dev/null > "$T/icn.dump"
icall="$(grep -E '^;     reuse .*IR_CALL_ICON .*PINNED' "$T/icn.dump" | wc -l)"; ipool="$(grep -cE 'IR_CALL_ICON .*(CANDIDATE|pooled)' "$T/icn.dump")"; iargv="$(grep -c 'call.argv (pooled' "$T/icn.dump")"
echo "icon witness: IR_CALL_ICON pinned=$icall candidate/pooled=$ipool pooled argv blocks=$iargv"
[ "$icall" -ge 2 ] && [ "$ipool" -eq 0 ] && [ "$iargv" -eq 0 ] || { echo "  ⛔ the Icon builtin call read across the generator is not PINNED, or an unsealed graph grew a pooled argv block"; bad=$((bad+1)); }
for w in w.pl w.icn w.sno; do
    out3="$(timeout -k 5 20s ./scrip "$T/$w" </dev/null 2>&1)"
    if [ "$out3" != "$(cat "$T/$w.ref")" ]; then echo "  ⛔ $w mode 3 printed [$out3], ref [$(cat "$T/$w.ref" | tr '\n' ' ')]"; bad=$((bad+1)); fi
    if timeout -k 5 20s ./scrip --compile "$T/$w" > "$T/$w.s" 2>/dev/null && gcc -c "$T/$w.s" -o "$T/$w.o" 2>/dev/null && gcc "$T/$w.o" -Lout -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$T/$w.bin" 2>/dev/null; then
        out4="$(timeout -k 5 20s "$T/$w.bin" </dev/null 2>&1)"
        if [ "$out4" != "$(cat "$T/$w.ref")" ]; then echo "  ⛔ $w mode 4 printed [$out4], ref [$(cat "$T/$w.ref" | tr '\n' ' ')]"; bad=$((bad+1)); fi
    else echo "  ⛔ $w mode 4 did not build"; bad=$((bad+1)); fi
done
if [ "$bad" -gt 0 ]; then echo "⛔ GATE FAIL: $bad finding(s) -- rung 2 does not hold"; exit 1; fi
echo "GATE OK: r/1 reads $end bytes, $sealed sealed calls share one argv block of $ablk slot(s), the Icon call result stays pinned, and all three witnesses print their refs in both modes"
