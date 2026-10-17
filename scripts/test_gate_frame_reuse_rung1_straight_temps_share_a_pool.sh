#!/bin/bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# ⭐ RUNG 1 OF frame-slot-reuse-a-live-range-in-a-byrd-graph-extends-to-every-point-reachable-by-recession
# (cto, CEO-684 slice 2): THE CHEAPEST REAL CASE.  A straight box (LIT/VAR/VAR_REF/BINOP/CMP_TEST) whose every reader
# sits on the gamma spine with NO beta-capable box and NO back-edge span between the write and the last read, and
# whose reader's template reads operand slots on alpha only (verified for the straight ops, IR_CALL and
# IR_CALL_PROC_STAGED: bb_call_fn/bb_call/bb_call_proc_staged marshal on alpha, beta falls to omega), takes a slot
# from a per-activation POOL by interval colouring instead of a fresh 16 bytes of its own.
# ⛔ THE CLAIM EACH POOLED SLOT MAKES, PRINTED BESIDE IT BY --dump-zeta (rung 0's relation, now read FROM THE PLAN
# THE GRANTER USED, not recomputed): no recession edge lands between its write and its last read.  A slot that
# cannot state that claim keeps its own storage -- every call result, every generator, every pattern box.
# ⛔ THE FAILURE MODE IS SILENCE, so this gate grades ANSWERS as well as bytes: the three witnesses must print
# their oracle refs in BOTH modes (ok / 11 12 13 / ab) -- a wrong reuse here would be a wrong value, not a crash.
# BYTES: r/1 of the DONE-WHEN witness read 576 on the rung-0 tree; rung 0's relation predicted 448 from
# packed_min=2 over 10 candidates, and the rung-1 tree read 448 -- ON A DUMP THAT WAS NOT THE EMITTED FRAME.
# ⛔ RE-BASED 2026-09-16 (cto, rung 2 opener, second instrument): --dump-zeta ran slot assignment without the
# proc registry, so a staged call to a registered generator callee (every Prolog predicate) was granted no
# callgen.act quad in the dump while the emitter granted one: r/1 emitted 480 while the dump said 448, and
# every number this row reported was 32 low (688/576/448 read 720/608/480 in the frame the code addresses).
# The dump path now shares the compile path's registration and drive (register_procs_all + drive_slots_all,
# emission byte-identical); test_gate_dump_zeta_is_the_emitted_frame.sh holds that claim.  The bar is the TRUE
# rung-1 number, <= 480 (RED-BEFORE of rung 1 on the same honest dump: 576 + 32 = 608 on the rung-0 binary by the same correction, not re-measured; rc=1).
# ⛔ REFUSES rc=2 when --dump-zeta yields no r/1 graph -- a runner that cannot measure never prints the success shape.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="${S4E_HOME:-$(cd "$HERE/../../SCRIP" && pwd)}"; [ -x "$ROOT/scrip" ] || ROOT="$(cd "$HERE/../.." && pwd)/SCRIP"
cd "$ROOT" || exit 2
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
cp ../harness/scripts/fixtures/frame_r1_witness.pl "$T/w.pl"; echo "ok" > "$T/w.pl.ref"
printf 'procedure main()\n   every write(1, 1 to 3);\nend\n' > "$T/w.icn"; printf '11\n12\n13\n' > "$T/w.icn.ref"
printf "        S = 'abcabc'\n        S BREAK('c') . T\n        OUTPUT = T\nEND\n" > "$T/w.sno"; echo "ab" > "$T/w.sno.ref"
bad=0
line="$(timeout -k 5 20s ./scrip --dump-zeta "$T/w.pl" </dev/null 2>/dev/null | grep -E "^; graph [0-9]+ 'r/1'")"
[ -n "$line" ] || { echo "⛔ REFUSE(2): --dump-zeta printed no r/1 graph for the witness"; exit 2; }
end="$(printf '%s\n' "$line" | sed -n 's/.*region_end=\([0-9]*\).*/\1/p')"
echo "r/1 region_end=$end (bar <= 480, the emitted frame; rung-0 tree read 608 on the same dump)"
[ -n "$end" ] && [ "$end" -le 480 ] || { echo "  ⛔ r/1 frame is $end bytes, above the rung-1 bar of 480"; bad=$((bad+1)); }
pooled="$(timeout -k 5 20s ./scrip --dump-zeta "$T/w.pl" </dev/null 2>/dev/null | awk "/^; graph [0-9]+ 'r\/1'/{p=1} /^; graph [0-9]+ 'q\/1'/{p=0} p" | grep -c 'CANDIDATE.*pooled')"
echo "r/1 pooled candidates=$pooled"
[ "$pooled" -ge 1 ] || { echo "  ⛔ no candidate in r/1 reads pooled -- the plan and the granter disagree"; bad=$((bad+1)); }
for w in w.pl w.icn w.sno; do
    out3="$(timeout -k 5 20s ./scrip "$T/$w" </dev/null 2>&1)"
    if [ "$out3" != "$(cat "$T/$w.ref")" ]; then echo "  ⛔ $w mode 3 printed [$out3], ref [$(cat "$T/$w.ref" | tr '\n' ' ')]"; bad=$((bad+1)); fi
    if timeout -k 5 20s ./scrip --compile "$T/$w" > "$T/$w.s" 2>/dev/null && gcc -c "$T/$w.s" -o "$T/$w.o" 2>/dev/null && gcc "$T/$w.o" -Lout -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$T/$w.bin" 2>/dev/null; then
        out4="$(timeout -k 5 20s "$T/$w.bin" </dev/null 2>&1)"
        if [ "$out4" != "$(cat "$T/$w.ref")" ]; then echo "  ⛔ $w mode 4 printed [$out4], ref [$(cat "$T/$w.ref" | tr '\n' ' ')]"; bad=$((bad+1)); fi
    else echo "  ⛔ $w mode 4 did not build"; bad=$((bad+1)); fi
done
if [ "$bad" -gt 0 ]; then echo "⛔ GATE FAIL: $bad finding(s) -- rung 1 does not hold"; exit 1; fi
echo "GATE OK: r/1 reads $end bytes with $pooled pooled temps and all three witnesses print their refs in both modes"
