#!/usr/bin/env bash
# test_gate_pl_a_last_call_in_an_if_then_else_branch_releases_its_frame.sh -- a staged call that ends a branch of an if-then-else
# which is itself the clause body's last goal is a last call: it takes the tail arm and releases the clause frame, so a recursion
# through the branch runs in constant stack as swipl's does. THE RED (the cfo 2026-10-10, measured by the ceo at CEO-1632, row
# prolog-a-last-call-inside-a-branch-of-a-control-construct-keeps-its-frame-...): count(1000000) under -s512k printed done for a plain
# clause body's last call but died ERROR 246 for every branch shape. THE CAUSE: lower_prolog.c sealed PL_SEAL_TAIL only on the clause
# body's own tail node; when the last goal is an if-then-else the tail node is its IR_GATE, so the call ending a branch was never
# sealed. THE CURE (this landing, the row's first chunk): a tail flag on the lowering context travels to the clause body's last goal
# and into each arm of an if-then-else, a soft cut and a disjunction (never a condition), and pl_seal_branch_tail seals an arm's last
# staged call. The existing tail arm's run-time test (r13 equal to the frame's saved entry value, a flat spine) is the safety net:
# a disjunction arm or a soft cut still runs with this frame as the youngest choice, so their calls decline at run time and fall back
# to the ordinary call -- that is the row's second step (pop a dead in-frame choice), not this gate.
# ARMS, each under -s512k in mode 3 and mode 4 against swipl's line: (1) the else branch; (2) the then branch; (3) an if-then-else as
# the last goal after another one; (4) an else branch calling a helper whose own last call recurses. (5) the four at count(3000)
# under SCRIP_HEAP_KB=64 SCRIP_GC_STRESS=1 SCRIP_GC_CHAIN_CHECK=3, both modes, reading bad-link, offchain-swept, mismatch and missing 0.
# FAIL_ONCE=1 runs the arms with the sealing seen as absent by grading against ERROR 246, so every arm reds.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"; G=pl_a_last_call_in_an_if_then_else_branch_releases_its_frame
[ -x "$ROOT/scrip" ] || { echo "GATE REFUSED(2) [$G]: no $ROOT/scrip -- run make"; exit 2; }
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$G" "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" || exit 2
command -v gcc >/dev/null 2>&1 || { echo "GATE REFUSED(2) [$G]: gcc absent"; exit 2; }
command -v swipl >/dev/null 2>&1 || { echo "GATE REFUSED(2) [$G]: swipl absent"; exit 2; }
W="$(mktemp -d "${TMPDIR:-/tmp}/pllco.XXXXXX")" || { echo "GATE REFUSED(2) [$G]: no workdir"; exit 2; }; trap 'rm -rf "$W"' EXIT
body() { printf ':- initialization(main).\n%s\nmain :- count(%s), write(done), nl, halt.\n' "$1" "$2"; }
S1='count(N) :- ( N =:= 0 -> true ; N1 is N-1, count(N1) ).'
S2='count(N) :- ( N > 0 -> N1 is N-1, count(N1) ; true ).'
S3='count(N) :- ( N > 0 -> N1 is N-1 ; N1 = stop ), ( N1 == stop -> true ; count(N1) ).'
S4='count(N) :- ( N =:= 0 -> true ; N1 is N-1, step(N1) ).
step(N) :- count(N).'
i=0
for s in "$S1" "$S2" "$S3" "$S4"; do i=$((i+1)); body "$s" 1000000 > "$W/a$i.pl"; body "$s" 3000 > "$W/c$i.pl"; done
bad=0
for i in 1 2 3 4; do
    want=$(cd "$W" && timeout -k 5 120 swipl -q "$W/a$i.pl" < /dev/null 2>&1 | head -1)
    [ "$want" = done ] || { echo "GATE REFUSED(2) [$G]: swipl prints '$want' for arm $i"; exit 2; }
    [ "${FAIL_ONCE:-0}" = 1 ] && want='scrip: runtime error: ERROR 246'
    o3=$(cd "$W" && timeout -k 5 120 "$ROOT/scrip" -s512k "$W/a$i.pl" < /dev/null 2>&1 | head -1 | cut -c1-31)
    ( cd "$W" && "$ROOT/scrip" --compile -o "$W/a$i.s" "$W/a$i.pl" < /dev/null > /dev/null 2>&1 ) && gcc -no-pie -o "$W/a$i.bin" "$W/a$i.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread > /dev/null 2>&1 \
        && o4=$(cd "$W" && timeout -k 5 120 "$W/a$i.bin" -s512k < /dev/null 2>&1 | head -1 | cut -c1-31) || o4='(no build)'
    if [ "$o3" = "$want" ] && [ "$o4" = "$want" ]; then echo "  ok  ($i) count(1000000) under -s512k, m3 and m4: $o3"; else echo "  RED ($i) want '$want', m3 '$o3', m4 '$o4'"; bad=1; fi
done
for i in 1 2 3 4; do
    for m in m3 m4; do
        if [ $m = m3 ]; then r=$(cd "$W" && env -u SCRIP_HEAP_KB -u SCRIP_HEAP_MB SCRIP_HEAP_KB=64 SCRIP_GC_STRESS=1 SCRIP_GC_CHAIN_CHECK=3 timeout -k 5 300 "$ROOT/scrip" "$W/c$i.pl" < /dev/null 2>&1)
        else ( cd "$W" && "$ROOT/scrip" --compile -o "$W/c$i.s" "$W/c$i.pl" < /dev/null > /dev/null 2>&1 ) && gcc -no-pie -o "$W/c$i.bin" "$W/c$i.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread > /dev/null 2>&1
             r=$(cd "$W" && env -u SCRIP_HEAP_KB -u SCRIP_HEAP_MB SCRIP_HEAP_KB=64 SCRIP_GC_STRESS=1 SCRIP_GC_CHAIN_CHECK=3 timeout -k 5 300 "$W/c$i.bin" < /dev/null 2>&1); fi
        out=$(printf '%s\n' "$r" | grep -v '^\[' | head -1); chain=$(printf '%s\n' "$r" | grep -o 'bad-link=[0-9]*\|offchain-swept=[0-9]*\|mismatch=[0-9]*\|missing=[0-9]*' | head -4 | sort | tr '\n' ' ')
        if [ "$out" = done ] && [ "$chain" = "bad-link=0 mismatch=0 missing=0 offchain-swept=0 " ]; then echo "  ok  (5.$i) $m under stress: done, $chain"; else echo "  RED (5.$i) $m under stress: '$out' $chain"; bad=1; fi
    done
done
TREE="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo '?')$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)"
if [ $bad -eq 0 ]; then echo "GATE PASS(0) [$G]: a last call ending an if-then-else branch releases its frame, four shapes at count(1000000) under -s512k in both modes and clean under forced collections (tree SCRIP=$TREE)"; exit 0; fi
echo "GATE FAIL(1) [$G]: a last call ending an if-then-else branch keeps its frame, or the chain is not clean under forced collections (tree SCRIP=$TREE)"; exit 1
