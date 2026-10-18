#!/usr/bin/env bash
# test_gate_gc_an_if_then_else_commit_over_a_callees_choice_point_leaves_no_stale_frame_link.sh -- after an if-then-else commits
# over a condition whose callee left a choice point, no frame link in the caller's map points below the live frames, so the chain
# walk at the next collection reads bad-link 0. THE RED (the cto 2026-10-10, found on the attributed-variable matrix of
# test_gate_pl_an_attributed_variable_wakes_inside_a_multi_goal_branch.sh and reduced to four lines with no attributed variable):
# run(10, pplus(A, B, C)) :- ( noop(x), B is C - A ; true ). try(N) :- ( run(N, pplus(4, Y, 9)) -> write(N-bound(Y)) ;
# write(N-failed) ), nl. Under SCRIP_HEAP_KB=64 SCRIP_GC_STRESS=1 SCRIP_GC_CHAIN_CHECK=3 the collection at the write's allocation
# prints FRAME-LINK REFUSED: the target lies outside the segment (linking frame try/1 ... slot +496 holds <an address 15 KB
# below the frame>) and the walk reads bad-link 3 in mode 3 and mode 4 (2 when the clause is run/1); the same program with
# write(yes) in place of the structure, or without the if-then-else, reads 0. Row
# gc-an-if-then-else-commit-over-a-callees-choice-point-leaves-a-stale-frame-link-in-the-callers-map (owner cto).
# ARMS: (1) mode 3 and (2) mode 4 at a 64 KB window under SCRIP_GC_STRESS=1 with SCRIP_GC_CHAIN_CHECK=3 print the ref line and read
# bad-link 0, offchain-swept 0, mismatch 0 and missing 0. FAIL_ONCE=1 grades against an empty ref, so both arms must red.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; G=gc_an_if_then_else_commit_over_a_callees_choice_point_leaves_no_stale_frame_link
[ -x "$ROOT/scrip" ] || { echo "GATE REFUSED(2) [$G]: no $ROOT/scrip -- run make"; exit 2; }
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$G" "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" || exit 2
command -v gcc >/dev/null 2>&1 || { echo "GATE REFUSED(2) [$G]: gcc absent"; exit 2; }
S1="$HERE/fixtures/hb_pl_an_if_then_else_commit_over_a_callees_choice_point_leaves_a_stale_frame_link.pl"
[ -f "$S1" ] && [ -s "${S1%.pl}.ref" ] || { echo "GATE REFUSED(2) [$G]: the witness or its ref is missing ($S1)"; exit 2; }
W="$(mktemp -d "${TMPDIR:-/tmp}/plstale.XXXXXX")" || { echo "GATE REFUSED(2) [$G]: no workdir"; exit 2; }; trap 'rm -rf "$W"' EXIT
cp "$S1" "$W/r.pl"
if [ "${FAIL_ONCE:-0}" = 1 ]; then : > "$W/r.ref"; else cp "${S1%.pl}.ref" "$W/r.ref"; fi
( cd "$W" && "$ROOT/scrip" --compile -o "$W/r.s" "$W/r.pl" < /dev/null > "$W/r.cerr" 2>&1 ) || { echo "GATE REFUSED(2) [$G]: the witness does not compile ($(head -c 120 "$W/r.cerr"))"; exit 2; }
gcc -o "$W/r.bin" "$W/r.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread > "$W/r.lerr" 2>&1 || { echo "GATE REFUSED(2) [$G]: the witness does not link"; exit 2; }
STRESS="SCRIP_HEAP_KB=64 SCRIP_GC_STRESS=1 SCRIP_GC_CHAIN_CHECK=3"
run_arm() {
    local n="$1" mode="$2" rc k v reading=""
    if [ "$mode" = m3 ]; then ( cd "$W" && env -u SCRIP_HEAP_KB -u SCRIP_HEAP_MB -u SCRIP_HEAP_CAP_KB -u SCRIP_HEAP_MAX_MB $STRESS timeout -k 5 120 "$ROOT/scrip" "$W/r.pl" < /dev/null > "$W/$n.out" 2> "$W/$n.err" ); rc=$?
    else ( cd "$W" && env -u SCRIP_HEAP_KB -u SCRIP_HEAP_MB -u SCRIP_HEAP_CAP_KB -u SCRIP_HEAP_MAX_MB $STRESS timeout -k 5 120 "$W/r.bin" < /dev/null > "$W/$n.out" 2> "$W/$n.err" ); rc=$?; fi
    grep -v '^\[GC-\|^\[CHAIN' "$W/$n.out" > "$W/$n.txt"
    if [ "$rc" -ne 0 ] || ! cmp -s "$W/$n.txt" "$W/r.ref"; then echo "  RED ($n) $mode: rc=$rc, the output differs from the ref:"; diff "$W/r.ref" "$W/$n.txt" | head -4; return 1; fi
    for k in bad-link offchain-swept mismatch missing; do
        v=$(grep -h -o "$k=[0-9]*" "$W/$n.err" "$W/$n.out" | head -1)
        [ -n "$v" ] || { echo "  RED ($n) $mode: the chain check printed no $k reading"; return 1; }
        [ "$v" = "$k=0" ] || { echo "  RED ($n) $mode: the chain reads $v ($(grep -c 'FRAME-LINK REFUSED' "$W/$n.err" "$W/$n.out" | awk -F: '{s+=$2} END {print s}') refused links: $(grep -h -m1 'FRAME-LINK REFUSED' "$W/$n.err" "$W/$n.out" | head -c 160))"; return 1; }
        reading="$reading $v"
    done
    echo "  ok  ($n) $mode under $STRESS: the ref line, the chain reads$reading"
    return 0
}
bad=0
run_arm 1 m3 || bad=1
run_arm 2 m4 || bad=1
TREE="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo '?')$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)"
if [ $bad -eq 0 ]; then echo "GATE PASS(0) [$G]: an if-then-else commit over a callee's choice point leaves no stale frame link in the caller's map, in both modes under forced collections (tree SCRIP=$TREE)"; exit 0; fi
echo "GATE FAIL(1) [$G]: the chain walk refuses a frame link the if-then-else commit left behind, or the witness answers wrong (tree SCRIP=$TREE)"; exit 1
