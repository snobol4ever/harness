#!/usr/bin/env bash
# test_gate_pl_a_last_call_in_a_disjunction_or_soft_cut_branch_pops_this_frames_dead_choice.sh -- a staged call ending the LAST arm of
# a disjunction, the else arm of a soft cut, or the then arm of a soft cut whose condition has no redo, in a clause body's last goal,
# is a last call even though the construct made this frame the youngest choice: that choice is dead there (every earlier arm is
# exhausted, the condition cannot be resumed), so the tail arm takes r13 back to the caller's choice and releases the frame, as swipl
# runs these shapes in constant stack. THE RED (CEO-1632, after chunk 1 at SCRIP 45e63ef51): count(1000000) under -s512k died ERROR 246
# for the disjunction and soft-cut shapes because x86_pl_disj_open sets r13 to this frame's header and nothing returned it before the
# last arm, so the tail arm's r13 test declined. THE CURE: the lowering seals such a call IR_SEAL_TAIL_POP only when every enclosing
# construct is proven dead at the call and the clause body holds no other choice-opening node (IR_DISJUNCTION, IR_TO, IR_TO_BY or a
# mark not proven dead), never in a dynamic predicate or a clause compiled at run time; the tail arm then also accepts r13 equal to this
# frame's header when the clause-alternative word [kt-56] is 0, and loads r13 from [kt-40] before the release.
# ARMS: (1)-(4) count(1000000) under -s512k in mode 3 and mode 4 prints done: a disjunction's last arm, a three-arm disjunction, a soft
# cut's then arm, a soft cut's else arm. (5) NEGATIVES, each answering as swipl in both modes: an earlier disjunction's alternative
# still pending, between/3 before the branch, the call in a disjunction's FIRST arm, a soft cut over a condition with a redo, a
# disjunction inside catch/3 as the last goal whose popped call would throw past a released handler, a dynamic predicate -- every
# tail argument bound or a head variable, never a fresh local, so the tail arm reaches the r13 test (an unbound local declines first). (6) arms 1 and 3 at count(3000) under SCRIP_HEAP_KB=64
# SCRIP_GC_STRESS=1 SCRIP_GC_CHAIN_CHECK=3 in both modes: done, with bad-link, offchain-swept, mismatch and missing 0.
# FAIL_ONCE=1 grades arms 1-4 against ERROR 246, so they red on a cured tree.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; G=pl_a_last_call_in_a_disjunction_or_soft_cut_branch_pops_this_frames_dead_choice
[ -x "$ROOT/scrip" ] || { echo "GATE REFUSED(2) [$G]: no $ROOT/scrip -- run make"; exit 2; }
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$G" "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" || exit 2
command -v gcc >/dev/null 2>&1 || { echo "GATE REFUSED(2) [$G]: gcc absent"; exit 2; }
command -v swipl >/dev/null 2>&1 || { echo "GATE REFUSED(2) [$G]: swipl absent"; exit 2; }
W="$(mktemp -d "${TMPDIR:-/tmp}/plpop.XXXXXX")" || { echo "GATE REFUSED(2) [$G]: no workdir"; exit 2; }; trap 'rm -rf "$W"' EXIT
m4() { ( cd "$W" && "$ROOT/scrip" --compile -o "$W/$1.s" "$W/$1.pl" < /dev/null > /dev/null 2>&1 ) && gcc -no-pie -o "$W/$1.bin" "$W/$1.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread > /dev/null 2>&1; }
body() { printf ':- initialization(main).\n%s\nmain :- count(%s), write(done), nl, halt.\n' "$1" "$2"; }
P1='count(N) :- ( N =:= 0, ! ; N1 is N-1, count(N1) ).'
P2='count(N) :- ( N =:= 0, ! ; N < 0, !, fail ; N1 is N-1, count(N1) ).'
P3='count(N) :- ( N > 0 *-> N1 is N-1, count(N1) ; true ).'
P4='count(N) :- ( N =:= 0 *-> true ; N1 is N-1, count(N1) ).'
bad=0; i=0
for s in "$P1" "$P2" "$P3" "$P4"; do
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
    if [ "$o3" = "$want" ] && [ "$o4" = "$want" ]; then echo "  ok  (5$tag) $(printf '%s' "$want" | tr '\n' ' ' | cut -c1-70)"
    else echo "  RED (5$tag) swipl '$(printf '%s' "$want" | tr '\n' ' ' | cut -c1-50)', m3 '$(printf '%s' "$o3" | tr '\n' ' ' | cut -c1-50)', m4 '$(printf '%s' "$o4" | tr '\n' ' ' | cut -c1-50)'"; bad=1; fi
}
neg a 't(N, R) :- ( R = a ; R = b ), ( N =:= 0, ! ; N1 is N - 1, t(N1, R) ).
main :- findall(R, t(1, R), L), write(L), nl, halt.'
neg b 'u(N, X) :- between(1, 3, X), ( N =:= 0, ! ; N1 is N - 1, u(N1, X) ).
main :- findall(X, u(2, X), L), write(L), nl, halt.'
neg c 'v(N, R) :- ( N > 0, N1 is N - 1, v(N1, R) ; R = last ).
main :- findall(R, v(2, R), L), write(L), nl, halt.'
neg d 'w(N, X) :- ( member(X, [1, 2]) *-> ( N =< 0 -> true ; N1 is N - 1, w(N1, X) ) ; true ).
main :- findall(X, w(1, X), L), write(L), nl, halt.'
neg e 'c(N, R) :- catch(( N =< 0, R = z ; N > 0, N1 is N - 1, c2(N1, R) ), E, R = caught(E)).
c2(N, R) :- ( N =:= 0 -> throw(boom) ; c(N, R) ).
main :- findall(R, c(1, R), L), write(L), nl, halt.'
neg f ':- dynamic d/2.
d(N, R) :- ( N =< 0, R = s ; N > 0, N1 is N - 1, d(N1, R) ).
main :- assertz(d(_, extra)), findall(R, d(2, R), L), write(L), nl, halt.'
for i in 1 3; do
    m4 "c$i" || { echo "GATE REFUSED(2) [$G]: stress witness $i does not build in mode 4"; exit 2; }
    for m in m3 m4; do
        if [ $m = m3 ]; then r=$(cd "$W" && env -u SCRIP_HEAP_KB -u SCRIP_HEAP_MB SCRIP_HEAP_KB=64 SCRIP_GC_STRESS=1 SCRIP_GC_CHAIN_CHECK=3 timeout -k 5 300 "$ROOT/scrip" "$W/c$i.pl" < /dev/null 2>&1)
        else r=$(cd "$W" && env -u SCRIP_HEAP_KB -u SCRIP_HEAP_MB SCRIP_HEAP_KB=64 SCRIP_GC_STRESS=1 SCRIP_GC_CHAIN_CHECK=3 timeout -k 5 300 "$W/c$i.bin" < /dev/null 2>&1); fi
        out=$(printf '%s\n' "$r" | grep -v '^\[' | head -1); chain=$(printf '%s\n' "$r" | grep -o 'bad-link=[0-9]*\|offchain-swept=[0-9]*\|mismatch=[0-9]*\|missing=[0-9]*' | head -4 | sort | tr '\n' ' ')
        if [ "$out" = done ] && [ "$chain" = "bad-link=0 mismatch=0 missing=0 offchain-swept=0 " ]; then echo "  ok  (6.$i) $m under stress: done, $chain"; else echo "  RED (6.$i) $m under stress: '$out' $chain"; bad=1; fi
    done
done
TREE="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo '?')$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)"
if [ $bad -eq 0 ]; then echo "GATE PASS(0) [$G]: a last call in a disjunction's last arm or a soft cut's arm pops this frame's dead choice and releases the frame; six negatives keep their choices; clean under forced collections (tree SCRIP=$TREE)"; exit 0; fi
echo "GATE FAIL(1) [$G]: a dead in-frame choice is not popped, a live one was, or the chain is not clean under forced collections (tree SCRIP=$TREE)"; exit 1
