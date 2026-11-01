#!/usr/bin/env bash
# test_gate_pl_a_last_call_that_globalizes_a_fresh_variable_polls_so_a_long_loop_runs_in_a_small_heap.sh -- the tail arm of a Prolog last call GLOBALIZES a fresh variable (a frame
# cell that is still unbound is bound to a new 16-byte heap cell, the WAM's put_unsafe_value, ARCH-PROLOG-ACTIVATION-LIFETIME 1 (c)) and the allocating call is followed by a
# safe point, so the collector reclaims the cell the loop leaves behind. THE RED (hq_prolog 2026-11-01, SCRIP 051409d43, both modes):
#   loop(0, _) :- !.   loop(N, _) :- M is N - 1, loop(M, _).   :- loop(1000000, _).
# at -d4096k died with  [ZHP] HARD CAP REACHED ... REFUSED: rt_gcheap_alloc allocated past the 4096-byte error reserve ... before the poll that follows it could raise the
# resource error (this request 16 payload bytes)  after about 128,000 iterations: the loop allocates 16 payload bytes (32 with the block header) per iteration and no
# safe point stood after the allocation or anywhere else on the loop's path, so no collection ever ran; swipl runs it in constant space. The census util_gc_census.py safe-points
# read the site as UNPOLLED (bb_call_proc_staged.cpp, from SCRIP 642aac59f of 2026-10-22). THE CURE: the poll after the frame cell is bound to the new cell (the new cell is
# reachable only through that frame cell by then, and rax is dead), the serial draw moved ahead of the allocating call so the poll stands within the census's window.
# THE WITNESSES, their refs cut from swipl 9.0.4 with every variable name normalised to _ and blank lines dropped (the same sed runs on SCRIP's output):
# fixtures/hb_pl_last_call_globalize_loops.pl: two loops of 1,000,000 iterations (a last call with an anonymous variable, a mutual recursion whose last call carries one).
# gc_witnesses/hb_pl_a_last_call_that_globalizes_a_fresh_variable_keeps_the_terms_of_its_call_block.pl (also the bare-poll table's witness of the new site): bound heap terms ride
# the same call block while the collector compacts (dead garbage allocated before them), once plain and once under a choice point (the trail arm), run under
# SCRIP_GC_STRESS=1 SCRIP_GC_PLANT_FLIP=1 (a collection at every safe point; a stale pointer becomes a located fault).
# ARCHS: (1) loops mode 3 and (2) mode 4 at the declared -d4096k -s4096k; (3) relocation mode 3 and (4) mode 4 under stress. All four equal their ref, rc 0.
# THE REFS ARE RE-CUT from the live swipl on every run and the gate REFUSES rc=2 when the oracle disagrees with the table. FAIL_ONCE=1 grades against a ref with its first
# line removed, so every arm must red.
# Usage: bash ../harness/scripts/test_gate_pl_a_last_call_that_globalizes_a_fresh_variable_polls_so_a_long_loop_runs_in_a_small_heap.sh
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; G=p
SWIPL=/usr/bin/swipl
[ -x "$ROOT/scrip" ] || { echo "GATE REFUSED(2) [$G]: no $ROOT/scrip -- run make"; exit 2; }
[ -x "$SWIPL" ] || { echo "GATE REFUSED(2) [$G]: no oracle at $SWIPL"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$G" "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" || exit 2
command -v gcc >/dev/null 2>&1 || { echo "GATE REFUSED(2) [$G]: gcc absent"; exit 2; }
F1="$HERE/fixtures/hb_pl_last_call_globalize_loops.pl"; F2="$HERE/gc_witnesses/hb_pl_a_last_call_that_globalizes_a_fresh_variable_keeps_the_terms_of_its_call_block.pl"
for f in "$F1" "$F2"; do [ -f "$f" ] && [ -s "${f%.pl}.ref" ] || { echo "GATE REFUSED(2) [$G]: the witness or its ref is missing ($f)"; exit 2; }; done
W="$(mktemp -d "${TMPDIR:-/tmp}/plgloball.XXXXXX")" || { echo "GATE REFUSED(2) [$G]: no workdir"; exit 2; }; trap 'rm -rf "$W"' EXIT
norm() { sed -E 's/_[A-Z]?[0-9]+/_/g; /^$/d'; }
n=0
for f in "$F1" "$F2"; do
    n=$((n+1)); cp "$f" "$W/w$n.pl"
    "$SWIPL" -q "$W/w$n.pl" -t halt < /dev/null 2> /dev/null | norm > "$W/oracle$n.ref"
    cmp -s "$W/oracle$n.ref" "${f%.pl}.ref" || { echo "GATE REFUSED(2) [$G]: the live swipl disagrees with the table's ref for $(basename "$f") (diff follows) -- re-cut the ref from the oracle"; diff "${f%.pl}.ref" "$W/oracle$n.ref" | head -6; exit 2; }
    if [ "${FAIL_ONCE:-0}" = 1 ]; then sed '1d' "${f%.pl}.ref" > "$W/w$n.ref"; else cp "${f%.pl}.ref" "$W/w$n.ref"; fi
    ( cd "$W" && "$ROOT/scrip" --compile --out="$W/w$n.s" "$W/w$n.pl" < /dev/null > "$W/w$n.cerr" 2>&1 ) || { echo "GATE REFUSED(2) [$G]: witness $n does not compile ($(head -c 120 "$W/w$n.cerr"))"; exit 2; }
    gcc -o "$W/w$n.bin" "$W/w$n.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread > "$W/w$n.lerr" 2>&1 || { echo "GATE REFUSED(2) [$G]: witness $n does not link"; exit 2; }
done
run_arm() {
    local a="$1" w="$2" mode="$3" stress="$4" rc
    if [ "$mode" = m3 ]; then ( cd "$W" && env -u SCRIP_HEAP_KB -u SCRIP_HEAP_MB -u SCRIP_HEAP_CAP_KB -u SCRIP_HEAP_MAX_MB ${stress:+SCRIP_GC_STRESS=1 SCRIP_GC_PLANT_FLIP=1} timeout -k 5 300 "$ROOT/scrip" -d4096k -s4096k "$W/w$w.pl" < /dev/null > "$W/$a.raw" 2> "$W/$a.err" ); rc=$?
    else ( cd "$W" && env -u SCRIP_HEAP_KB -u SCRIP_HEAP_MB -u SCRIP_HEAP_CAP_KB -u SCRIP_HEAP_MAX_MB ${stress:+SCRIP_GC_STRESS=1 SCRIP_GC_PLANT_FLIP=1} timeout -k 5 300 "$W/w$w.bin" -d4096k -s4096k < /dev/null > "$W/$a.raw" 2> "$W/$a.err" ); rc=$?; fi
    grep -v '^\[GC' "$W/$a.raw" | norm > "$W/$a.txt"
    if [ "$rc" -ne 0 ] || ! cmp -s "$W/$a.txt" "$W/w$w.ref"; then echo "  RED ($a) $mode${stress:+ stress}: rc=$rc, the output differs from swipl's (stderr: $(grep -m1 -o 'REFUSED.\{0,60\}\|HARD CAP REACHED\|error [0-9]*' "$W/$a.err" | head -1)):"; diff "$W/w$w.ref" "$W/$a.txt" | head -6; return 1; fi
    echo "  ok  ($a) $mode${stress:+ stress}: rc 0, the $(wc -l < "$W/w$w.ref") swipl lines"
    return 0
}
bad=0
run_arm 1 1 m3 "" || bad=1
run_arm 2 1 m4 "" || bad=1
run_arm 3 2 m3 1 || bad=1
run_arm 4 2 m4 1 || bad=1
TREE="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo '?')$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)"
if [ $bad -eq 0 ]; then echo "GATE PASS(0) [$G]: a last call that globalizes a fresh variable is followed by a safe point: a 1,000,000-iteration loop runs in a 4 MB heap and bound terms survive the compaction, in both modes (tree SCRIP=$TREE)"; exit 0; fi
echo "GATE FAIL(1) [$G]: a last call that globalizes a fresh variable leaks its heap cell or loses a bound term at a collection (tree SCRIP=$TREE)"; exit 1
