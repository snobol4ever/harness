#!/usr/bin/env bash
# test_gate_gc_a_long_trie_chain_is_visited_without_recursing_the_c_stack.sh -- A COLLECTION OVER A TABLED PREDICATE'S VARIANT TABLE
# COSTS ONE WORKLIST ENTRY PER TRIE NODE, NEVER ONE C FRAME PER NODE (hq_collector 2026-10-25 from hq_prolog's finding at origin 01964419b;
# ARCH-GC section 14/15, the worklist drain).  MEASURED: a tabled predicate called with N distinct goals builds a chain of N trie nodes;
# pl_trie_gc_visit hands each node's value to rt_gc_visit_descr, which runs a typed block at once on every verdict but 3, so a drain in
# progress recurses through gc_run_verdicts and gc_visit_mblk once per node (a 4-frame cycle, 30,900 times in the gdb stop at 123,636 frames).
# 5,000 goals pass and 20,000 die with ERROR 246 stack overflow at -s4096k in both modes; swipl prints done in 0.3 s.  A raised -s is NOT the
# cure (THE LIFETIME RULE does not move a collector's own recursion to a bigger stack); ProPuzzles' twelve tabled programs red on it.
# ARMS: (a) the 80,000-goal witness prints done at -s4096k in mode 3; (b) the same in mode 4; (c) the CONTROL, the same program at 500 goals,
# prints done in both modes, so (a) and (b) are red because of the chain's length and never because the harness cannot run the program.
# FAIL_ONCE=1 grades (a) and (b) against a corrupted expectation and requires both to red: the comparison that carries the claim is seen to say no.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$HERE/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness"; exit 2; }
G="$(basename "${BASH_SOURCE[0]}" .sh)"
SCRIP="$ROOT/scrip"
[ -x "$SCRIP" ] || { echo "⛔ GATE REFUSED(2) [$G]: no scrip binary -- build before grading"; exit 2; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
WANT="done"; [ "${FAIL_ONCE:-0}" = 1 ] && WANT="a line swipl never printed"
prog() { printf ':- table f/2.\nf(N, M) :- M is N + 1.\n:- initialization(((between(1,%s,A),f(A,_),fail ; true), writeln(done), halt)).\n' "$1" > "$T/w$1.pl"; }
RC=0; checks=0; fails=0
ck() { checks=$((checks+1)); if [ "$1" = ok ]; then echo "  ok   $2"; else RC=1; fails=$((fails+1)); echo "  FAIL $2"; fi; }
m3() { ( cd "$T" && env -u SCRIP_HEAP_MB timeout -k 5 300 "$SCRIP" -s4096k "w$1.pl" < /dev/null 2>&1 | tail -1 ); }
m4() { ( cd "$T" && "$SCRIP" --compile "w$1.pl" -o "w$1.s" < /dev/null > /dev/null 2>&1 && gcc -m64 -no-pie -rdynamic "w$1.s" -Wl,-rpath,"$ROOT/out" -L"$ROOT/out" -lscrip_rt -lm -lpthread -o "w$1" 2> /dev/null && env -u SCRIP_HEAP_MB timeout -k 5 300 "./w$1" -s4096k < /dev/null 2>&1 | tail -1 ); }
prog 80000; prog 500
c3="$(m3 500)"; c4="$(m4 500)"
[ "$c3" = done ] && [ "$c4" = done ] && ck ok "(c) CONTROL: 500 goals print done in mode 3 and mode 4" || ck bad "(c) CONTROL: 500 goals print done in both modes -- got m3='$c3' m4='$c4'"
r3="$(m3 80000)"; r4="$(m4 80000)"
[ "$r3" = "$WANT" ] && ck ok "(a) mode 3: 80,000 distinct goals on one tabled predicate print '$WANT'" || ck bad "(a) mode 3: 80,000 goals -- got '$r3'"
[ "$r4" = "$WANT" ] && ck ok "(b) mode 4: 80,000 distinct goals on one tabled predicate print '$WANT'" || ck bad "(b) mode 4: 80,000 goals -- got '$r4'"
if [ "$RC" = 0 ]; then echo "GATE PASS(0) [$G]: a trie chain of 80,000 nodes is collected without recursing the C stack, both modes ($checks arms)"; exit 0; fi
echo "GATE FAIL(1) [$G]: $fails of $checks arm(s) red"; exit 1
