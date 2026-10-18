#!/usr/bin/env bash
# test_gate_gc_every_allocating_runtime_entry_returns_to_a_safe_point.sh -- THE ALLOCATOR NEVER COLLECTS (frozen design
# .github/ARCH-GC-COMPILE-TIME-FRAME-MAPS.md section 7 F4, F6 step 1; Lon 2026-09-17 CEO-812 "the collector guesses
# nothing"; cfo's row gc-safe-points-the-allocator-never-collects-...).
#
# WHAT STEP 1 ESTABLISHES, AND WHAT IT DOES NOT. c_rt_gcheap_alloc collected at three unshielded sites (gc_heap.c :192
# the detax fast path, :206 the pacing line, :207 the end of the arena) with every runtime C frame live and unmapped.
# Those three now set g_gc_pending; the arena is a contiguous virtual reserve (mmap PROT_NONE MAP_NORESERVE, cap
# SCRIP_HEAP_MAX_MB, default 8x SCRIP_HEAP_MB) whose soft end g_hp_end advances 2 MB at a time when the allocator must
# not collect, and the exhaustion abort fires only at the cap. Arms 1-3 measure exactly that and BLOCK.
#
# ⭐ ARM 4 (SAFE-POINT COVERAGE) BLOCKS AS OF THE cto's ICON POLLS, SCRIP 5dd2d79f0 -- the lift this gate named
# when it was written has landed and the arm was re-armed on the cfo's own instruction rather than left on the ramp.
# THE HISTORY, because the bound is only meaningful beside it: with F6 step 1 alone the allocator stopped collecting
# and an Icon every-do loop reached NO safe point at all, so the 4M-dead-list witness collected ONCE, at exit, at
# 861932 KB, against origin's 5 collections at 157144 KB through the allocator. With the polls it reads 5 collections
# at ~161000 KB. THE BOUND IS A RATE, NOT AN RSS FIGURE: at least TWO collections, which is the difference between a
# loop that reaches a safe point INSIDE itself and one that only collects at exit. RSS is graded by
# test_gate_gc_aggregates_are_collectable_not_immortal and is deliberately not duplicated here -- two gates printing
# one number from different code is how they drift apart.
# ⛔ THE FAIL-ONCE FOR THIS ARM IS MEASURED BUT ON A SUPERSEDED TREE (step 1 alone: 1 collection, 861932 KB), and
# that is said rather than dressed up. Live corroboration that the figure is a MEASUREMENT AND NOT A CONSTANT, taken
# on this tree: SCRIP_GC_LINE_MB=128 reads 5 collections and SCRIP_GC_LINE_MB=3000 reads 2, so the number moves with
# the pacing line. Anyone who can rebuild the poll-less state should re-take the fail-once against it.
# FAIL-ONCE IS MEASURED, NOT ASSERTED: run against origin 162e8a172 (the cure stashed, the runtime rebuilt, the gate
# file left in place) all three blocking arms read red -- census 3 collect calls, reserve 0 soft-end advances, cap
# rc=0 with no cap-named exhaustion -- and all three read green on the cure. FAIL_ONCE=1 additionally plants the
# pre-cure census count for a cheap re-check that arm 1 still discriminates without a rebuild.
# ⛔ ARMS 2 AND 3 CHANGED THEIR WITNESS 2026-09-17 (cto, CEO-821 F6 step 1b), AND THE REASON IS THE POINT OF THIS ROW:
# they grew the arena with FOUR HUNDRED THOUSAND DEAD LISTS, which grew only because an Icon allocation loop reached no
# safe point. With the Icon allocating-box polls landed that loop COLLECTS instead of growing (soft-end advances 0), so
# the arms read red on a tree that is strictly better. The witness is now 400000 LIVE lists held by one list: growth is
# unavoidable there whatever the collector does, which is what these two arms actually grade -- 30 soft-end advances at
# (RE-READ 2026-09-23 cto: the telemetry the two arms grep moved under CEO-1101 -- a grow prints `[ZHP] lazy commit -> N KB of a M KB
# hard cap` and the cap abort says `heap exhausted AT THE HARD CAP`; the arms grepped the retired `soft end ->` and `reserve cap`
# wordings and read red on every tree since, which no landing was allowed to see through the count arm. The greps follow the
# telemetry; the properties they grade are unchanged.)
# SCRIP_HEAP_MB=8 SCRIP_HEAP_MAX_MB=512, and a cap-named abort (rc=134) when the cap equals the window.
# ⛔ THE CAP ARM GRADES A CLEAN ABORT, NOT ONLY A NAMED ONE (cfo 2026-09-27, CFO-169). Under make test-arena (SCRIP_HEAP_KB=128, which the
# runtime reads after SCRIP_HEAP_MB, so the window is 128 KB under the 8 MB cap) the heap fills to its last byte. Since 572981e49 the
# error's own report copies &ERRTEXT onto the heap, so it asked the full heap again: error 307 was re-raised 3904 times (4.9 MB of
# stderr) and the run died of ERROR 246. On 8064f4679, 572981e49's parent, it is raised once. The arm now requires 307 exactly
# once and no 246. It reads the output through here-strings, because `printf | grep -q` under pipefail took SIGPIPE (rc 141)
# on that output and graded a phrase that was present as absent. At the shipped window the failing request is a 1 MB block,
# the report still fits, and the arm is green either way.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ REFUSE(2): no scrip at $SCRIP"; exit 2; }
SRC="$ROOT/src/runtime/rt/gc_heap.c"; [ -f "$SRC" ] || { echo "⛔ REFUSE(2): $SRC absent"; exit 2; }
command -v /usr/bin/time >/dev/null || { echo "⛔ REFUSE(2): /usr/bin/time is the RSS instrument and it is absent"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0; examined=0
examined=$((examined+1))
n=$(grep -c 'rt_gc_collect();' "$SRC")
[ -n "${FAIL_ONCE:-}" ] && n=3
if [ "$n" -eq 0 ]; then echo "  census PASS (the allocator contains 0 collect-from-inside-a-runtime-call sites in gc_heap.c)"
else echo "  census FAIL ($n collect call(s) inside gc_heap.c: a collection with live unmapped C frames is back)"; RC=1; fi
examined=$((examined+1))
printf 'procedure main()\n   local i, L;\n   L := [];\n   every i := 1 to 400000 do put(L, [i, i+1, i+2]);\n   write("done ", *L);\nend\n' > "$T/grow.icn"
out=$(cd "$T" && SCRIP_ZETA_TELEM=1 SCRIP_HEAP_MB=8 SCRIP_HEAP_MAX_MB=512 timeout -k 5 120 "$SCRIP" grow.icn 2>&1); g=$(printf '%s\n' "$out" | grep -c 'lazy commit ->')
if [ "$(printf '%s\n' "$out" | grep -c '^done 400000$')" = 1 ] && [ "$g" -gt 0 ]; then echo "  reserve PASS (an 8 MB window inside a 512 MB reserve grew its soft end $g time(s) into the reserve instead of collecting, answer intact)"
else echo "  reserve FAIL (soft-end advances=$g, answer=[$(printf '%s\n' "$out" | grep '^done' | head -1)] -- the arena did not grow when the allocator refused to collect)"; RC=1; fi
examined=$((examined+1))
out=$(cd "$T" && SCRIP_HEAP_MB=8 SCRIP_HEAP_MAX_MB=8 timeout -k 5 120 "$SCRIP" grow.icn 2>&1); r=$?
n307=$(grep -c 'error 307' <<< "$out"); n246=$(grep -c 'ERROR 246' <<< "$out")
if [ "$r" -ne 0 ] && grep -q 'heap exhausted AT THE HARD CAP' <<< "$out" && [ "$n307" = 1 ] && [ "$n246" = 0 ]; then echo "  cap PASS (growth is refused at the cap, the abort names it, and error 307 is raised once, rc=$r)"
else echo "  cap FAIL (rc=$r, error 307 raised $n307 time(s), ERROR 246 $n246 time(s) -- the reserve is unbounded, the abort does not name the cap, or the abort's own report asked the full heap again and re-raised)"; RC=1; fi
examined=$((examined+1))
printf 'procedure main()\n   local i, L;\n   every i := 1 to 4000000 do L := [i, i+1, i+2];\n   write("done ", *L);\nend\n' > "$T/churn.icn"
( cd "$T" && SCRIP_ZETA_TELEM=1 /usr/bin/time -f 'RSS=%M' timeout -k 5 180 "$SCRIP" churn.icn ) >"$T/c.out" 2>"$T/c.err"
col=$(grep -c 'ZGC. regeneration' "$T/c.err"); rss=$(grep -o 'RSS=[0-9]*' "$T/c.err" | tail -1 | cut -d= -f2)
if [ -n "$col" ] && [ "$col" -ge 2 ] && [ "$(head -1 "$T/c.out")" = "done 3" ]; then echo "  coverage PASS (the Icon 4M-dead-list loop reached a safe point $col time(s) at ${rss:-?} KB RSS -- it collects DURING the loop, not once at the end)"
else echo "  coverage FAIL (the Icon 4M-dead-list loop collected ${col:-?} time(s) at ${rss:-?} KB RSS, answer [$(head -1 "$T/c.out")] -- an allocation loop that collects fewer than twice reached no safe point INSIDE itself and only collected at exit; the emitted polls have regressed)"; RC=1; fi
if [ "$RC" = 0 ]; then echo "GATE PASS(0) [$(basename "${BASH_SOURCE[0]}" .sh)]: the allocator never collects, the arena is a virtual reserve that grows and is capped (examined $examined arms, coverage arm blocking since the cto's Icon polls)"
else echo "GATE FAIL(1) [$(basename "${BASH_SOURCE[0]}" .sh)]: the allocator collects again, or the reserve does not grow or is not capped, or an Icon allocation loop stopped reaching a safe point (examined $examined arms)"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
