#!/usr/bin/env bash
# test_gate_pl_a_predicates_frame_overlays_its_clauses_construct_slots.sh -- a Prolog predicate's activation frame is the size its
# LARGEST clause needs, not the sum over its clauses: only one clause of an activation is ever live (clause k+1 is tried only once
# clause k is exhausted), so every slot a clause's constructs hold -- a call's staged arguments, an if-then-else or disjunction
# record -- overlays the same slots in every other clause, as the clause variables already do. THE RED (the cto 2026-10-11, bracketing
# the cfo's hakank_swi_nvalue for CEO-1632): nvalue dies ERROR 246 at its declared 4 MB with nothing printed where swipl prints its
# solutions, and runs at 6 MB. Under gdb on a mode-4 build the fault is NOT deep recursion: it is the rep stos that zeroes
# clpfd run_propagator/2's frame, 0x35a70 = 219,760 bytes for its 51 clauses, crossing the 4 KB guard page below the stack after rsp
# jumped past it -- about 18 nested propagator runs fill 4 MB. MEASURED on generated predicates (mode 4, the sub rsp of FN__p): one
# clause grows 48 bytes per call, 112 per disjunction and 240 per if-then-else; 12 variables per clause cost 64 bytes per added clause
# (overlaid), but 16 if-then-elses per clause cost 4,016 / 7,600 / 14,768 / 29,104 bytes at 1 / 2 / 4 / 8 clauses (summed).
# ARMS: (1) 8 clauses x 16 if-then-elses frame within 7 x 128 bytes of 1 clause x 16; (2) the same for 8 clauses each with 8
# if-then-elses, 8 disjunctions and 8 calls; (3) hakank_swi_nvalue at its declared -s4096k in mode 3 prints swipl's lines; (4) a
# 3-clause predicate whose first clause binds heap terms in its if-then-else records and fails late, whose second allocates, at
# count 200 under SCRIP_HEAP_KB=64 SCRIP_GC_STRESS=1 SCRIP_GC_CHAIN_CHECK=3 in both modes: swipl's line and bad-link, offchain-swept,
# mismatch and missing 0. FAIL_ONCE=1 grades arms 1 and 2 against the summed size, so they red on a cured tree.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"; G=pl_a_predicates_frame_overlays_its_clauses_construct_slots
[ -x "$ROOT/scrip" ] || { echo "GATE REFUSED(2) [$G]: no $ROOT/scrip -- run make"; exit 2; }
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$G" "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" || exit 2
command -v gcc >/dev/null 2>&1 || { echo "GATE REFUSED(2) [$G]: gcc absent"; exit 2; }
command -v swipl >/dev/null 2>&1 || { echo "GATE REFUSED(2) [$G]: swipl absent"; exit 2; }
PZ="$(cd "$ROOT/.." && pwd)/corpus/packages/prolog/puzzles"
[ -f "$PZ/hakank_swi_nvalue.pl" ] && [ -f "$PZ/hakank_utils.pl" ] || { echo "GATE REFUSED(2) [$G]: no $PZ/hakank_swi_nvalue.pl or hakank_utils.pl"; exit 2; }
W="$(mktemp -d "${TMPDIR:-/tmp}/plfso.XXXXXX")" || { echo "GATE REFUSED(2) [$G]: no workdir"; exit 2; }; trap 'rm -rf "$W"' EXIT
gen() { python3 -c '
import sys
c, ite, dis, cal, out = int(sys.argv[1]), int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4]), sys.argv[5]
L = [":- initialization(main)."]
for k in range(c):
    g = ["( X == b -> q(X, Z%d) ; true )" % i for i in range(ite)] + ["( q(X, W%d) ; true )" % i for i in range(dis)] + ["q(X, Y%d)" % i for i in range(cal)]
    L.append("p(%d, X) :- %s." % (k, ", ".join(g)))
L.append("q(_, _).\nmain :- p(0, a), write(ok), nl, halt.")
open(out, "w").write("\n".join(L) + "\n")' "$@"; }
frame() { ( cd "$W" && "$ROOT/scrip" --compile -o "$W/$1.s" "$W/$1.pl" < /dev/null > /dev/null 2>&1 ) || { echo 0; return; }
          awk '/^FN__p\$2F2:/ { f = 1; next } f && /sub +rsp, *[0-9]+/ { sub(/.*rsp, */, ""); print $1 + 0; exit } f && ++n > 4 { exit }' "$W/$1.s"; }
bad=0; F1=0
[ "${FAIL_ONCE:-0}" = 1 ] && F1=1
arm_frame() {
    local tag=$1 ite=$2 dis=$3 cal=$4 one eight
    gen 1 "$ite" "$dis" "$cal" "$W/${tag}1.pl"; gen 8 "$ite" "$dis" "$cal" "$W/${tag}8.pl"
    one=$(frame "${tag}1"); eight=$(frame "${tag}8")
    if [ "${one:-0}" -le 0 ] || [ "${eight:-0}" -le 0 ]; then echo "GATE REFUSED(2) [$G]: arm $tag could not read FN__p's frame (1 clause '$one', 8 clauses '$eight')"; exit 2; fi
    local lim=$((one + 7 * 128))
    [ "$F1" = 1 ] && lim=$((one * 7))
    if { [ "$F1" = 0 ] && [ "$eight" -le "$lim" ]; } || { [ "$F1" = 1 ] && [ "$eight" -ge "$lim" ]; }; then
        echo "  ok  ($tag) 8 clauses take $eight bytes against $one for 1 (limit $lim): the clauses overlay"
    else echo "  RED ($tag) 8 clauses take $eight bytes against $one for 1 (limit $lim): the clauses' construct slots are summed"; bad=1; fi
}
arm_frame 1 16 0 0
arm_frame 2 8 8 8
cp "$PZ/hakank_swi_nvalue.pl" "$PZ/hakank_utils.pl" "$W/"
want=$(cd "$W" && timeout -k 5 120 swipl -q "$W/hakank_swi_nvalue.pl" < /dev/null 2>/dev/null)
[ -n "$want" ] || { echo "GATE REFUSED(2) [$G]: swipl printed nothing for hakank_swi_nvalue"; exit 2; }
got=$(cd "$W" && timeout -k 5 300 "$ROOT/scrip" -s4096k "$W/hakank_swi_nvalue.pl" < /dev/null 2>&1)
if [ "$got" = "$want" ]; then echo "  ok  (3) hakank_swi_nvalue at -s4096k prints swipl's $(printf '%s\n' "$want" | wc -l) lines"
else echo "  RED (3) hakank_swi_nvalue at -s4096k: $(printf '%s\n' "$got" | tail -1 | cut -c1-100) (swipl: $(printf '%s\n' "$want" | wc -l) lines)"; bad=1; fi
cat > "$W/g.pl" <<'EOF'
:- initialization(main).
p(N, R) :- ( N > 0 -> L1 = [a, b, c, N] ; L1 = [] ), ( atom(L1) -> L2 = L1 ; L2 = f(L1, L1) ), mk(50, _), N < 0, R = L2.
p(N, R) :- ( N > 1 -> M = g(N, [x, y]) ; M = h ), ( M = g(_, _) -> R = ok(M) ; R = no ), mk(100, _).
p(_, last).
mk(0, []) :- !.
mk(K, [K-x|T]) :- K1 is K - 1, mk(K1, T).
main :- forall(between(1, 200, I), ( p(I, R), ( I =:= 200 -> write(R), nl ; true ) )), halt.
EOF
gw=$(cd "$W" && timeout -k 5 60 swipl -q "$W/g.pl" < /dev/null 2>/dev/null | head -1)
[ -n "$gw" ] || { echo "GATE REFUSED(2) [$G]: swipl printed nothing for the stress witness"; exit 2; }
( cd "$W" && "$ROOT/scrip" --compile -o "$W/g.s" "$W/g.pl" < /dev/null > /dev/null 2>&1 ) && gcc -no-pie -o "$W/g.bin" "$W/g.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread > /dev/null 2>&1 || { echo "GATE REFUSED(2) [$G]: the stress witness does not build in mode 4"; exit 2; }
for m in m3 m4; do
    if [ $m = m3 ]; then r=$(cd "$W" && env -u SCRIP_HEAP_KB -u SCRIP_HEAP_MB SCRIP_HEAP_KB=64 SCRIP_GC_STRESS=1 SCRIP_GC_CHAIN_CHECK=3 timeout -k 5 300 "$ROOT/scrip" "$W/g.pl" < /dev/null 2>&1)
    else r=$(cd "$W" && env -u SCRIP_HEAP_KB -u SCRIP_HEAP_MB SCRIP_HEAP_KB=64 SCRIP_GC_STRESS=1 SCRIP_GC_CHAIN_CHECK=3 timeout -k 5 300 "$W/g.bin" < /dev/null 2>&1); fi
    out=$(printf '%s\n' "$r" | grep -v '^\[' | head -1); chain=$(printf '%s\n' "$r" | grep -o 'bad-link=[0-9]*\|offchain-swept=[0-9]*\|mismatch=[0-9]*\|missing=[0-9]*' | head -4 | sort | tr '\n' ' ')
    if [ "$out" = "$gw" ] && [ "$chain" = "bad-link=0 mismatch=0 missing=0 offchain-swept=0 " ]; then echo "  ok  (4) $m under stress: $out, $chain"; else echo "  RED (4) $m under stress: '$out' (swipl '$gw') $chain"; bad=1; fi
done
TREE="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo '?')$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)"
if [ $bad -eq 0 ]; then echo "GATE PASS(0) [$G]: a predicate's frame is its largest clause's, nvalue runs at its declared 4 MB, and overlaid slots are clean under forced collections (tree SCRIP=$TREE)"; exit 0; fi
echo "GATE FAIL(1) [$G]: a predicate's frame sums its clauses' construct slots, or an overlaid slot is not clean under forced collections (tree SCRIP=$TREE)"; exit 1
