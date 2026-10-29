#!/usr/bin/env bash
# test_gate_gc_the_chain_stops_at_a_coexpression_body_frame_as_its_coroutine_start.sh -- (cto, 2026-10-15, TENET; the
# coo's scriptix red demos/scriptix/infinite_snobol4, first-bad d51164383 STEP B, ARCH-GC 13.9 ONE).
#
# WHAT WAS THERE. An Icon co-expression body runs in its creator's graph on a frame the trampoline carves on the
# co-expression's own thread and fills from the frame image; that frame's link words lie outside the copied image, so
# they hold whatever the fresh stack held. When the creator is main, the root map ended the walk there by the root rule;
# when the creator is any other procedure, the walk followed the body frame's link to a return pc of zero, no site, and
# STEP B's refusal bombed the collection (rc 134) while the co-expression was parked or after it died.
#
# WHAT IS HERE. The trampoline stores the body frame's rbp in the entry package (body_rbp, 56(pkg)); scrip_co_body_base
# returns it, and gc_sw_run stops after visiting that frame with stop 8, the coroutine start a parked segment admits.
#
# ARMS. (1) the witness below (a co-expression created inside a procedure, drained to failure across three calls, then
# strings allocated so collections run while it is parked and while it is dead) prints exactly icont's stdout in mode 3
# and mode 4: sixty thousand strings at the shipped arena, three hundred at SCRIP_GC_STRESS=1 and 3. The refs are cut
# from icont at run time; icont missing is a REFUSE. FAIL-ONCE: on SCRIP bae359133 (the commit before the cure) every
# leg aborts rc 134 with the [GC-CHAIN] nosite refusal.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
. "$HERE/lib_oracle_flags.sh"
ICONT="$(icont_bin)" || exit 2
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/w.icn" <<'ICN'
global gen
procedure walk(n)
    local i;
    every i := 1 to n do suspend i * 10;
end
procedure batch(n)
    local k, e, L;
    /gen := create walk(5);
    L := [];
    k := 0;
    while k < n & e := @gen do { put(L, e); k +:= 1; };
    if k = 0 then fail;
    return L;
end
procedure main(args)
    local L, M, i, t, n;
    n := integer(args[1]) | 60000;
    t := 0;
    while L := batch(2) do t +:= *L;
    M := [];
    every i := 1 to n do put(M, string(i) || "-" || string(i + 1));
    write(t, " ", *M, " ", M[*M]);
end
ICN
echo "  HOLDS: the chain over the maps stops at a co-expression body's frame as its coroutine start -- collections while a co-expression made inside a procedure is parked or dead answer as icont does in both modes"
( cd "$T" && "$ICONT" -s w.icn -x </dev/null > ref 2>/dev/null && "$ICONT" -s w.icn -x 300 </dev/null > ref300 2>/dev/null ) && [ -s "$T/ref" ] && [ -s "$T/ref300" ] || { echo "⛔ GATE REFUSE(2) [$G]: icont could not run the witness"; exit 2; }
( cd "$T" && "$SCRIP" --compile w.icn > w.s 2>/dev/null </dev/null && gcc w.s -o w4 -L"$ROOT/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$ROOT/out" 2>/dev/null ) || { echo "  arm 1 FAIL: the witness does not build in mode 4"; echo "GATE FAIL(1) [$G]"; exit 1; }
band=""; bad=0
for st in 0 1 3; do
    if [ "$st" = 0 ]; then n=""; rf="$T/ref"; else n=300; rf="$T/ref300"; fi
    o3="$( cd "$T" && SCRIP_GC_STRESS=$st timeout -k 5 120 "$SCRIP" w.icn -- $n 2>/dev/null </dev/null )"; r3=$?
    o4="$( cd "$T" && SCRIP_GC_STRESS=$st timeout -k 5 120 ./w4 $n 2>/dev/null </dev/null )"; r4=$?
    if [ "$o3" = "$(cat "$rf")" ] && [ "$o4" = "$(cat "$rf")" ]; then band="$band @$st:ok"; else band="$band @$st:m3=rc$r3,m4=rc$r4"; bad=1; fi
done
if [ "$bad" = 0 ]; then echo "  arm 1 PASS: icont's answers [$(cat "$T/ref")] at stress 0 and [$(cat "$T/ref300")] at stress 1,3 (300 strings) in both modes --$band"; echo "GATE PASS(0) [$G]: the chain stops at a co-expression body's frame as its coroutine start (examined 1 arm)"; RC=0
else echo "  arm 1 FAIL: a collection while the co-expression was parked or dead did not answer as icont --$band"; echo "GATE FAIL(1) [$G]: a co-expression body's frame did not end the chain (examined 1 arm)"; RC=1; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
