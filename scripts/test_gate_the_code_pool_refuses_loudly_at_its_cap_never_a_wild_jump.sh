#!/usr/bin/env bash
# test_gate_the_code_pool_refuses_loudly_at_its_cap_never_a_wild_jump.sh -- when the executable code pool (src/ir/bb_pool.c,
# BB_POOL_SIZE or SCRIP_CODE_POOL_MB) cannot hold the next compile, the run stops with a refusal that names the pool, its knob and
# what it held, and never runs on with a missing fragment.
#
# ⛔ THE DEFECT (cto 2026-10-09, measuring the cfo's pool-reuse ask on row prolog-the-code-assertz-generates-is-reclaimed-...):
# bb_alloc answered NULL at the cap, emit_chain returned NULL, pl_runtime_define_pred_x returned NULL, and the assertz road wired
# that into the packet chain, so the next walk of the predicate jumped through it: an assert/retract loop of 4000 cycles at
# SCRIP_CODE_POOL_MB=16 died rc 139 with "fatal signal 11 ... no loaded module holds it: emitted code" and no word about the pool.
# NO FIXED LIMIT A PROGRAM CAN REACH (CEO-1210) allows exactly one refusal, loud exhaustion naming the table, and the EVAL roads already
# give it (rt_code_pool_check: error 204 naming the compiled-code pool, test_gate_sno_eval_chains_..._a_full_code_pool_is_loud.sh); the
# Prolog run-time define dropped the NULL without asking. THE CURE: pl_runtime_define_pred_x calls rt_code_pool_check on a NULL
# emission, so a full pool is the same error 204, and the message names the knob and the asserted clause beside the EVAL chains.
# bb_alloc keeps answering NULL: the EVAL roads turn that NULL into error 204 themselves. The cap itself (2 GB, about 524,288
# one-page run-time compiles) is the pool-reuse row's subject; this gate holds only that reaching it is loud.
#
# THE ARMS:
#   1  m3: the 4000-cycle loop at a 16 MB pool stops nonzero with error 204 naming the compiled-code pool, never rc 139, no answer
#   2  m4: the same program compiled stops the same way (the run-time compiles of a compiled program draw on the same pool)
#   3  CONTROL m3: at a 64 MB pool the loop answers 4000 rc 0, so the refusal is the cap and not the program
# EXIT: 0 all arms pass · 1 an arm failed · 2 REFUSED (no binary, no runtime library, no gcc).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="$ROOT/scrip"
RT_DIR="$ROOT/out"
NAME=the_code_pool_refuses_loudly_at_its_cap_never_a_wild_jump
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
[ -f "$RT_DIR/libscrip_rt.so" ] || refuse "no runtime library at $RT_DIR -- the m4 arm cannot measure"
command -v gcc > /dev/null || refuse "no gcc -- the m4 arm cannot measure"
T="$(mktemp -d)" || refuse "no tmpdir"
trap 'rm -rf "$T"' EXIT
printf ':- initialization(main).\n:- dynamic(pi/3).\nloop(0) :- !.\nloop(N) :- ( retract(pi(a, 1, M)) -> true ; M = 0 ), M1 is M + 1, assertz(pi(a, 1, M1)), N1 is N - 1, loop(N1).\nmain :- loop(4000), pi(a, 1, V), write(V), nl, halt.\n' > "$T/l.pl"
fail=0; n=0
arm() { n=$((n+1)); if [ "$2" = ok ]; then echo "  ok   arm $n  $1"; else echo "  FAIL arm $n  $1 -- $2"; fail=1; fi; }
loud() { [ "$1" != 0 ] && [ "$1" -lt 128 ] && grep -q 'error 204' "$2" && grep -q 'compiled-code pool is full' "$2" && [ ! -s "$3" ] && { echo ok; return; }; echo "rc=$1 stderr=[$(head -c 160 "$2" | tr '\n' '|')]"; }
( cd "$T" && SCRIP_CODE_POOL_MB=16 timeout -k 5 120 "$SCRIP" l.pl < /dev/null > m3.out 2> m3.err ); rc=$?
arm "m3: a 16 MB pool stops the loop with error 204 naming the pool" "$(loud "$rc" "$T/m3.err" "$T/m3.out")"
( cd "$T" && timeout -k 5 120 "$SCRIP" --compile -o l.s l.pl < /dev/null > /dev/null 2>&1 && gcc l.s -L"$RT_DIR" -lscrip_rt -Wl,-rpath,"$RT_DIR" -lm -lpthread -o l.bin > /dev/null 2>&1 ) || refuse "the witness did not compile and link in mode 4"
( cd "$T" && SCRIP_CODE_POOL_MB=16 timeout -k 5 120 ./l.bin < /dev/null > m4.out 2> m4.err ); rc=$?
arm "m4: a 16 MB pool stops the compiled loop with error 204 naming the pool" "$(loud "$rc" "$T/m4.err" "$T/m4.out")"
( cd "$T" && SCRIP_CODE_POOL_MB=64 timeout -k 5 120 "$SCRIP" l.pl < /dev/null > c.out 2> c.err ); rc=$?
arm "CONTROL m3: a 64 MB pool answers 4000" "$([ "$rc" = 0 ] && [ "$(cat "$T/c.out")" = 4000 ] && echo ok || echo "rc=$rc out=[$(head -c 40 "$T/c.out")]")"
[ "$fail" = 0 ] && { echo "PASS [$NAME]: $n arms"; exit 0; }
echo "FAIL [$NAME]"; exit 1
