#!/usr/bin/env bash
# test_gate_gc_aggregates_are_collectable_not_immortal.sh -- a dead list, table, set or record is RECLAIMED: the collector marks the four HB_WS/HB_WSS/HB_DINST/HB_ARR types from their roots like every other block instead of force-marking them live at every regeneration (ceo CEO-661, GC-5 rung 1, on Lon's "we do not allow pinning in our heap since we slide").
#
# MEASURED 2026-09-13 on 71b32337f: `every i := 1 to 4000000 do L := [i, i+1, i+2]` -- a program holding ONE list --
# died with SIGABRT at 997 MB, because gc_heap.c force-marked every block of those four types live at every collection
# (hb_pinned, the mark loop) since ac044419d. Cure: the force-mark is gone by default; the four types are reached
# through the roots. That exposed a real hole the exemption had been hiding: the name/value table's own entries are
# rt_pinned_alloc'd HB_WS blocks and core_gc_roots walked the buckets WITHOUT marking the entries, their names or their
# chain -- so with the exemption gone the table was collected out from under itself and the next collection read a
# freed entry's `cell` as a pointer (SIGSEGV in rt_gc_visit_descr). core_gc_roots now marks the table it walks, the
# way the Pascal heap table became a movable root.
# ARMS: (1) the 4M-list churn COMPLETES with the right answer and stays under 800 MB; (2) the control arm
# (Historic, pre-CEO-799:) SCRIP_GC_PIN_AGGREGATES=1 restored the old policy and still died; that knob was deleted with the pinning mechanism on 2026-09-16 and the control arm is now the spelling census.
# nothing; (3) correctness under heavy collection: 200000 lists into a table, byte-identical to icont.
# FAIL_ONCE has no control knob to route through any more (CEO-799); the census arm is the control.
#
# ⭐ THE LIFT LANDED (cto 2026-09-17, CEO-821, SCRIP this landing): arm 1's 800 MB bound BLOCKS AGAIN. The Icon
# allocating-box polls of F6 step 1b put a g_gc_pending poll at the return of the list constructor, after the result
# is stored to its mapped cell, and this witness went back from ONE collection at 861956 KB to FIVE at 161208 KB in
# mode 3 (156448 KB in mode 4), answer "done 3" both. The shape and the rate are held by
# test_gate_gc_icon_allocating_boxes_poll_after_storing_the_result.sh; this gate grades the memory consequence.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
ICONT="${ICONT_BIN:-/home/resources/icon-master/bin/icont}"; [ -x "$ICONT" ] || { echo "⛔ GATE REFUSE(2) [$G]: no icont at $ICONT -- the correctness arm's ref is CUT FROM THE ORACLE"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0
printf 'procedure main()\n   local i, L;\n   every i := 1 to 4000000 do L := [i, i+1, i+2];\n   write("done ", *L);\nend\n' > "$T/churn.icn"
printf 'procedure main()\n   local i, L, T, R;\n   T := table(0);\n   every i := 1 to 200000 do { L := [i, i+1]; T[i %% 7] := L[1] + L[2] };\n   R := 0; every i := 0 to 6 do R +:= T[i];\n   write("sum ", R, " ", *T);\nend\n' > "$T/corr.icn"
run_rss() { /usr/bin/time -f '%M' -o "$T/rss" timeout -k 5 300 env "$@" >"$T/out" 2>"$T/err"; echo $?; }
rc=$(run_rss "$SCRIP" "$T/churn.icn"); rss=$(tail -1 "$T/rss" 2>/dev/null || echo 0); got=$(cat "$T/out")
if [ "$rc" = 0 ] && [ "$got" = "done 3" ] && [ "$rss" -lt 819200 ]; then echo "  churn PASS (4M dead lists: completed, answer \"$got\", RSS ${rss} KB under 800 MB)"
else echo "  churn FAIL (rc=$rc answer=\"$got\" RSS=${rss} KB -- a program holding one list did not survive four million dead ones, or the 800 MB bound is back over the line the Icon polls brought it under)"; RC=1; fi
if grep -rqE 'SCRIP_GC_PIN_AGGREGATES|hb_root_blanket' "$ROOT/src"; then echo "  control FAIL (the immortal policy is back in src/ under its old spelling -- CEO-799 deleted it 2026-09-16; test_gate_gc_no_pinned_lifetime_class holds the census)"; RC=1
else echo "  control PASS (no immortal-policy knob exists in src/ to restore: SCRIP_GC_PIN_AGGREGATES and hb_root_blanket were deleted with the pinning mechanism, CEO-799, 2026-09-16)"; fi
( cd "$T" && "$ICONT" -s corr.icn -x ) >"$T/corr.ref" 2>&1
( cd "$T" && timeout -k 5 120 "$SCRIP" corr.icn </dev/null ) >"$T/corr.out" 2>&1
if diff -q "$T/corr.ref" "$T/corr.out" >/dev/null; then echo "  correctness PASS (200000 lists through a table under heavy collection, byte-identical to icont: $(cat "$T/corr.ref"))"
else echo "  correctness FAIL (collection changed the answer: got \"$(cat "$T/corr.out")\", icont \"$(cat "$T/corr.ref")\")"; RC=1; fi
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: dead aggregates are reclaimed, no immortal-policy knob survives in src/, and collection does not change an answer"
else echo "GATE FAIL(1) [$G]: aggregates are immortal again, or the control arm stopped discriminating (examined 3 arms)"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
