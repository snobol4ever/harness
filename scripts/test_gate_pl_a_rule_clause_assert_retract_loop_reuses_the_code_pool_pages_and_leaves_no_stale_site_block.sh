#!/usr/bin/env bash
# test_gate_pl_a_rule_clause_assert_retract_loop_reuses_the_code_pool_pages_and_leaves_no_stale_site_block.sh -- the pages of a reclaimed run-time
# Prolog fragment are handed out again by the code pool (src/ir/bb_pool.c hole list, fed by pl_db_reclaim_one in unification.c, taken first fit by
# emit_chain for a packet fragment), and a page handed out again carries no site block of the fragment it held before.
#
# ⛔ THE DEFECT (hq_runtime 2026-11-01 13:2x CST, SCRIP 06f3e7055; the closed row's DONE-WHEN graded FACTS, which take the data road since 9ff999a6b and
# compile no code): 4000 assert/retract cycles of a RULE clause (pr(a,1,M1) :- M1 >= 0) at SCRIP_CODE_POOL_MB=16 stopped with error 204, the
# compiled-code pool full, 12292 of 16384 KB in use, from emit_chain proc_pr/3: pl_db_reclaim_one made a dead fragment's pages PROT_NONE and
# MADV_DONTNEED and dropped its frame maps and site tables, but nothing handed the range out again, and emit_chain reserved a 4 MB cap at the top.
# THE CURE: a hole list (sorted, coalesced; a hole that touches the top lowers the top); emit_chain emits a packet fragment INTO a hole first with
# the hole's bytes as the cap (the overflow loop already reports the bytes wanted), falls back to the top, and when the top cannot reserve the cap
# retries with the room that is left; the db records a fragment's OWN extent and finds a code address through a sorted index built per reclaim pass,
# so the ascending-fragment premise (frag_top) is gone.
#
# THE COLLECTOR'S CONDITION (hq_collector 2026-11-01): a page handed out again must have had rt_gc_frame_sites_drop_range and
# rt_gc_frame_maps_drop_range called over exactly the freed range, and the witness must fail once without the drop. A SNOBOL4 EVAL loop and a loop
# of same-shaped rules read ok and mismatch=0 WITH OR WITHOUT the drop (the stale and the new tables agree), so those readings are blind. THE
# READING THAT DISCRIMINATES is the number of registered site blocks, g_runtime.gc.gc_sblk_n, read under gdb at exit: a loop of rules of 31 different
# lengths puts the table at many different addresses inside the pages the loop reuses; with the drop the count after 10 cycles equals the count
# after 60 (349 and 349 at SCRIP 06f3e7055 plus this cure), without the drop it grows (357 and 379, measured by deleting the two drops from
# pl_db_reclaim_one in a scratch tree). SCRIP_GC_STRESS=1 makes every store a reclaim pass.
#
# THE ARMS:
#   1  m3: the DONE-WHEN loop (4000 cycles of a rule) at a 16 MB pool answers 4000 rc 0, stderr empty
#   2  m4: the same program compiled and linked the harness's way answers the same
#   3  SITE BLOCKS: the registered count after 10 cycles equals the count after 60 (rules of varying length, SCRIP_GC_STRESS=1)
#   4  the chain walk under SCRIP_GC_STRESS=1 SCRIP_GC_CHAIN_CHECK=3 over three rule shapes: ok > 0, mismatch=0, answer done
# EXIT: 0 all arms pass · 1 an arm failed · 2 REFUSED (no binary, no runtime library, no gcc, no gdb, a count gdb did not print).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="$ROOT/scrip"
RT_DIR="$ROOT/out"
NAME=pl_a_rule_clause_assert_retract_loop_reuses_the_code_pool_pages_and_leaves_no_stale_site_block
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
[ -f "$RT_DIR/libscrip_rt.so" ] || refuse "no runtime library at $RT_DIR -- the m4 arm cannot measure"
command -v gcc > /dev/null || refuse "no gcc -- the m4 arm cannot measure"
command -v gdb > /dev/null || refuse "no gdb -- the site block arm cannot measure"
T="$(mktemp -d)" || refuse "no tmpdir"
trap 'rm -rf "$T"' EXIT
printf ':- initialization(main).\n:- dynamic(pr/3).\nloop(0) :- !.\nloop(N) :- ( retract((pr(a, 1, M) :- M >= 0)) -> true ; M = 0 ), M1 is M + 1, assertz((pr(a, 1, M1) :- M1 >= 0)), N1 is N - 1, loop(N1).\nmain :- loop(4000), pr(a, 1, V), write(V), nl, halt.\n' > "$T/r.pl"
for n in 10 60; do
    printf ':- initialization(main).\n:- dynamic(pr/3).\nbody(0, M, M >= 0) :- !.\nbody(K, M, (atom(a), B)) :- K1 is K - 1, body(K1, M, B).\nput(K, M) :- body(K, M, B), assertz((pr(a, 1, M) :- B)).\ndrop :- ( clause(pr(a, 1, _), _, R) -> erase(R) ; true ).\nloop(N, N) :- !.\nloop(I, N) :- drop, K is (I * 7) mod 31, put(K, I), I1 is I + 1, loop(I1, N).\nmain :- loop(0, %d), pr(a, 1, %d), write(done), nl, halt.\n' "$n" "$((n - 1))" > "$T/v$n.pl"
done
printf ':- initialization(main).\n:- dynamic(pr/3).\nput(0, M) :- assertz((pr(a, 1, M) :- M >= 0)).\nput(1, M) :- assertz((pr(a, 1, M) :- M >= 0, atom(a), integer(M), M < 100000000)).\nput(2, M) :- assertz((pr(a, 1, M) :- ( M > 5 -> true ; M >= 0 ), M1 is M + 1, M1 > 0)).\ndrop :- ( clause(pr(a, 1, _), _, R) -> erase(R) ; true ).\nloop(N, N) :- !.\nloop(I, N) :- drop, K is I mod 3, M is I + 1, put(K, M), I1 is I + 1, loop(I1, N).\nmain :- loop(0, 120), pr(a, 1, 120), write(done), nl, halt.\n' > "$T/s.pl"
fail=0; n=0
arm() { n=$((n+1)); if [ "$2" = ok ]; then echo "  ok   arm $n  $1"; else echo "  FAIL arm $n  $1 -- $2"; fail=1; fi; }
( cd "$T" && SCRIP_CODE_POOL_MB=16 timeout -k 5 120 "$SCRIP" r.pl < /dev/null > m3.out 2> m3.err ); rc=$?
arm "m3: 4000 cycles of a rule clause run in a 16 MB code pool" "$([ "$rc" = 0 ] && [ "$(cat "$T/m3.out")" = 4000 ] && [ ! -s "$T/m3.err" ] && echo ok || echo "rc=$rc out=[$(head -c 40 "$T/m3.out")] err=[$(head -c 160 "$T/m3.err" | tr '\n' '|')]")"
( cd "$T" && timeout -k 5 120 "$SCRIP" --compile --out=r.s r.pl < /dev/null > /dev/null 2>&1 && gcc r.s -L"$RT_DIR" -lscrip_rt -Wl,-rpath,"$RT_DIR" -lm -lpthread -o r.bin > /dev/null 2>&1 ) || refuse "the witness did not compile and link in mode 4"
( cd "$T" && SCRIP_CODE_POOL_MB=16 timeout -k 5 120 ./r.bin < /dev/null > m4.out 2> m4.err ); rc=$?
arm "m4: the compiled program runs the same loop in a 16 MB code pool" "$([ "$rc" = 0 ] && [ "$(cat "$T/m4.out")" = 4000 ] && [ ! -s "$T/m4.err" ] && echo ok || echo "rc=$rc out=[$(head -c 40 "$T/m4.out")] err=[$(head -c 160 "$T/m4.err" | tr '\n' '|')]")"
sblk() { ( cd "$T" && SCRIP_GC_STRESS=1 timeout -k 5 250 gdb -q -batch -ex 'set pagination off' -ex 'set breakpoint pending on' -ex 'break exit' -ex run -ex 'print g_runtime.gc.gc_sblk_n' --args "$SCRIP" "$1" < /dev/null 2> /dev/null | sed -n 's/^\$1 = \([0-9][0-9]*\)$/\1/p' | head -1 ); }
a="$(sblk v10.pl)"; b="$(sblk v60.pl)"
case "$a$b" in ''|*[!0-9]*) refuse "gdb did not print a site block count (after 10 cycles [$a], after 60 [$b])";; esac
arm "site blocks: the registered count after 10 cycles ($a) equals the count after 60 ($b), so a reused page keeps no stale block" "$([ "$a" = "$b" ] && echo ok || echo "$a then $b: a stale site block outlived its page")"
( cd "$T" && SCRIP_GC_STRESS=1 SCRIP_GC_CHAIN_CHECK=3 timeout -k 5 250 "$SCRIP" s.pl < /dev/null > st.out 2> st.err ); rc=$?
okn="$(sed -n 's/.*CHAIN-CHECK\] SUMMARY ok=\([0-9]*\) .*/\1/p' "$T/st.err" | head -1)"; mm="$(sed -n 's/.*CHAIN-CHECK\] SUMMARY .* mismatch=\([0-9]*\) .*/\1/p' "$T/st.err" | head -1)"
arm "chain walk under stress over three rule shapes: ok=${okn:-?} mismatch=${mm:-?}" "$([ "$rc" = 0 ] && [ "$(cat "$T/st.out")" = done ] && [ "${okn:-0}" -gt 0 ] && [ "${mm:-1}" = 0 ] && echo ok || echo "rc=$rc out=[$(head -c 40 "$T/st.out")]")"
echo "CODE_POOL_REUSE_BOARD site_blocks_after_10=$a site_blocks_after_60=$b chain_ok=${okn:-?} chain_mismatch=${mm:-?} (tree $(git -C "$ROOT" rev-parse --short HEAD))"
[ "$fail" = 0 ] && { echo "PASS [$NAME]: $n arms"; exit 0; }
echo "FAIL [$NAME]"; exit 1
