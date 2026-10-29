#!/usr/bin/env bash
# test_gate_pl_a_static_call_n_in_tail_position_is_a_last_call.sh -- call/N whose goal is known at compile time (call(count, N1),
# call(count(N1))) is lowered inline as its goal's conjunction; when that call/N is the last goal of a clause body or of a branch arm,
# the inline conjunction's last staged call is a last call too and releases the frame, as swipl runs it in constant stack. THE RED
# (CEO-1632 chunk 3; the cfo's s8, 2026-10-10): count(1000000) under -s512k died ERROR 246 for call(count, N1) in an if-then-else's
# else arm, where the same body without call/2 ran after chunk 1: goal_inner's static call/N site lowered the conjunction with no
# tail-node out parameter, so its last staged call was never sealed. THE CURE: the site takes the conjunction's tail node and seals it
# with the plain tail seal when the call/N itself is in tail position; the tail arm's run-time tests (r13 at its entry value, a flat
# spine, the argument cells safe) still decide, so a goal that left a choice runs the ordinary call.
# ARMS: (1)-(3) count(1000000) under -s512k in mode 3 and mode 4 prints done: call/2 in an else arm, call/1 in an else arm, call/2 as
# a clause's last goal. (4) NEGATIVES answering as swipl in both modes: a call/3 whose goal leaves a choice, call/N inside catch/3 as
# the last goal, call/N before another goal. (5) arms 1 and 3 at count(3000) under SCRIP_HEAP_KB=64 SCRIP_GC_STRESS=1
# SCRIP_GC_CHAIN_CHECK=3 in both modes: done, with bad-link, offchain-swept, mismatch and missing 0.
# FAIL_ONCE=1 grades arms 1-3 against ERROR 246, so they red on a cured tree.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; G=pl_a_static_call_n_in_tail_position_is_a_last_call
[ -x "$ROOT/scrip" ] || { echo "GATE REFUSED(2) [$G]: no $ROOT/scrip -- run make"; exit 2; }
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$G" "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" || exit 2
command -v gcc >/dev/null 2>&1 || { echo "GATE REFUSED(2) [$G]: gcc absent"; exit 2; }
command -v swipl >/dev/null 2>&1 || { echo "GATE REFUSED(2) [$G]: swipl absent"; exit 2; }
W="$(mktemp -d "${TMPDIR:-/tmp}/plcalln.XXXXXX")" || { echo "GATE REFUSED(2) [$G]: no workdir"; exit 2; }; trap 'rm -rf "$W"' EXIT
m4() { ( cd "$W" && "$ROOT/scrip" --compile --out="$W/$1.s" "$W/$1.pl" < /dev/null > /dev/null 2>&1 ) && gcc -no-pie -o "$W/$1.bin" "$W/$1.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread > /dev/null 2>&1; }
body() { printf ':- initialization(main).\n%s\nmain :- count(%s), write(done), nl, halt.\n' "$1" "$2"; }
P1='count(N) :- ( N =:= 0 -> true ; N1 is N-1, call(count, N1) ).'
P2='count(N) :- ( N =:= 0 -> true ; N1 is N-1, call(count(N1)) ).'
P3='count(0) :- !.
count(N) :- N1 is N-1, call(count, N1).'
bad=0; i=0
for s in "$P1" "$P2" "$P3"; do
    i=$((i+1)); body "$s" 1000000 > "$W/a$i.pl"; body "$s" 3000 > "$W/c$i.pl"
    want=$(cd "$W" && timeout -k 5 120 swipl -q "$W/a$i.pl" < /dev/null 2>&1 | head -1)
    [ "$want" = done ] || { echo "GATE REFUSED(2) [$G]: swipl prints '$want' for arm $i"; exit 2; }
    [ "${FAIL_ONCE:-0}" = 1 ] && want='scrip: runtime error: ERROR 246'
    o3=$(cd "$W" && timeout -k 5 120 "$ROOT/scrip" -s512k "$W/a$i.pl" < /dev/null 2>&1 | head -1 | cut -c1-31)
    if m4 "a$i"; then o4=$(cd "$W" && timeout -k 5 120 "$W/a$i.bin" -s512k < /dev/null 2>&1 | head -1 | cut -c1-31); else o4='(no build)'; fi
    if [ "$o3" = "$want" ] && [ "$o4" = "$want" ]; then echo "  ok  ($i) count(1000000) under -s512k, m3 and m4: $o3"; else echo "  RED ($i) want '$want', m3 '$o3', m4 '$o4'"; bad=1; fi
done
neg() {
    local tag=$1 src=$2 want o3 o4
    printf ':- initialization(main).\n%s\n' "$src" > "$W/n$tag.pl"
    want=$(cd "$W" && timeout -k 5 60 swipl -q "$W/n$tag.pl" < /dev/null 2>&1)
    [ -n "$want" ] || { echo "GATE REFUSED(2) [$G]: swipl printed nothing for negative $tag"; exit 2; }
    o3=$(cd "$W" && timeout -k 5 60 "$ROOT/scrip" "$W/n$tag.pl" < /dev/null 2>&1)
    if m4 "n$tag"; then o4=$(cd "$W" && timeout -k 5 60 "$W/n$tag.bin" < /dev/null 2>&1); else o4='(no build)'; fi
    if [ "$o3" = "$want" ] && [ "$o4" = "$want" ]; then echo "  ok  (4$tag) $(printf '%s' "$want" | tr '\n' ' ' | cut -c1-70)"
    else echo "  RED (4$tag) swipl '$(printf '%s' "$want" | tr '\n' ' ' | cut -c1-50)', m3 '$(printf '%s' "$o3" | tr '\n' ' ' | cut -c1-50)', m4 '$(printf '%s' "$o4" | tr '\n' ' ' | cut -c1-50)'"; bad=1; fi
}
neg a 'v(N, R) :- ( N =:= 0 -> R = z ; N1 is N - 1, call(w, N1, R) ).
w(N, R) :- ( R = a ; v(N, R) ).
main :- findall(R, v(2, R), L), write(L), nl, halt.'
neg b 'c(N, R) :- catch(( N =:= 0 -> R = z ; N1 is N - 1, call(c2, N1, R) ), E, R = caught(E)).
c2(N, R) :- ( N =:= 0 -> throw(boom) ; c(N, R) ).
main :- findall(R, c(1, R), L), write(L), nl, halt.'
neg c 'p(N, L) :- ( N =:= 0 -> L = [] ; N1 is N - 1, call(p, N1, L0), L = [N|L0] ).
main :- p(5, L), write(L), nl, halt.'
for i in 1 3; do
    m4 "c$i" || { echo "GATE REFUSED(2) [$G]: stress witness $i does not build in mode 4"; exit 2; }
    for m in m3 m4; do
        if [ $m = m3 ]; then r=$(cd "$W" && env -u SCRIP_HEAP_KB -u SCRIP_HEAP_MB SCRIP_HEAP_KB=64 SCRIP_GC_STRESS=1 SCRIP_GC_CHAIN_CHECK=3 timeout -k 5 300 "$ROOT/scrip" "$W/c$i.pl" < /dev/null 2>&1)
        else r=$(cd "$W" && env -u SCRIP_HEAP_KB -u SCRIP_HEAP_MB SCRIP_HEAP_KB=64 SCRIP_GC_STRESS=1 SCRIP_GC_CHAIN_CHECK=3 timeout -k 5 300 "$W/c$i.bin" < /dev/null 2>&1); fi
        out=$(printf '%s\n' "$r" | grep -v '^\[' | head -1); chain=$(printf '%s\n' "$r" | grep -o 'bad-link=[0-9]*\|offchain-swept=[0-9]*\|mismatch=[0-9]*\|missing=[0-9]*' | head -4 | sort | tr '\n' ' ')
        if [ "$out" = done ] && [ "$chain" = "bad-link=0 mismatch=0 missing=0 offchain-swept=0 " ]; then echo "  ok  (5.$i) $m under stress: done, $chain"; else echo "  RED (5.$i) $m under stress: '$out' $chain"; bad=1; fi
    done
done
TREE="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo '?')$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)"
if [ $bad -eq 0 ]; then echo "GATE PASS(0) [$G]: a static call/N in tail position releases its frame, three shapes at count(1000000) under -s512k in both modes; three negatives as swipl; clean under forced collections (tree SCRIP=$TREE)"; exit 0; fi
echo "GATE FAIL(1) [$G]: a static call/N in tail position keeps its frame, a negative answers wrong, or the chain is not clean under forced collections (tree SCRIP=$TREE)"; exit 1
