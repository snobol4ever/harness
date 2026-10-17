#!/usr/bin/env bash
# test_gate_gc_a_bignum_held_only_in_a_heap_aggregate_survives.sh -- THE DT_BIG ARM OF gc_visit_one, THE STRESS BAND, BOTH MODES, THE TINY ARENA.
# ⛔ THE MEASURED DEFECT (ceo 2026-09-19, CEO-952; the cto found the missing arm while building the E switch and it is red on main WITHOUT E):
# gc_visit_one's switch had no DT_BIG case, so a bignum descriptor fell to `default: return;` and its BIG_t block was never marked and its
# holder slot never registered for relocation.  hb_wsb_bignum.icn did not see it because it holds its bignum in a STACK local, where the
# conservative sweep finds the block by value; gc_kind_witnesses.tsv did not see it because that table is keyed by BLOCK KIND and HB_WSB
# already had a witness.  The axis nothing tested is the HOLDER TAG: a value whose only holder is inside a heap aggregate is reachable
# ONLY by gc_visit_arblk/gc_visit_tbblk -> gc_visit_one, and a missing tag arm there is a silent loss no stack sweep can cover.
# MEASURED ON MAIN AT 41323bc8e, SCRIP_HEAP_MB=1: stress 0 green both modes; stress 1 WRONG DIGITS both modes (L2..L6 alias one reclaimed
# block); stress 3 and 5 SIGABRT rc=134 both modes, aborting on a 5790260276-byte request -- a limb count read through a dangling pointer,
# which is the [ZHP] "CORRUPTED LENGTH" path.  With the arm: 16 of 16 green (stress 0,1,3,5 x m3,m4 x arena 1 MB and 512 MB).
# The .ref is cut from the Arizona oracle (icont -s -x), never from ./scrip.  A stale binary or a missing witness REFUSES rc=2.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"; cd "$ROOT" || exit 2
. "$HERE/lib_gate.sh"
gate_parse_args "$@"
G=gc_a_bignum_held_only_in_a_heap_aggregate_survives
WIT="$HERE/gc_witnesses/hb_big_in_aggregate.icn"; REF="$HERE/gc_witnesses/hb_big_in_aggregate.ref"
[ -f "$WIT" ] && [ -f "$REF" ] || { echo "GATE UNPROVEN(2) [$G]: witness or ref missing ($WIT)"; exit 2; }
bash "$HERE/util_require_fresh.sh" --gate "$G" "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" || exit 2
W="$(mktemp -d "${TMPDIR:-/tmp}/gc_bigagg.XXXXXX")" || exit 2
trap 'rm -rf "$W"' EXIT
BAND="${GC_BIGAGG_BAND:-0 1 3 5}"
unset SCRIP_HEAP_MB; export SCRIP_HEAP_KB="${SCRIP_HEAP_KB:-128}" SCRIP_HEAP_MAX_MB="${SCRIP_HEAP_MAX_MB:-512}"
want="$(cat "$REF")"; bad=0; runs=0
( cd "$W" && timeout -k 5 180 "$ROOT/scrip" --compile -o bg.s "$WIT" < /dev/null 2>c.err && gcc bg.s -L "$ROOT/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$ROOT/out" -o bg 2>l.err ) || { echo "GATE UNPROVEN(2) [$G]: mode-4 compile or link failed: $(head -c 200 "$W/c.err" "$W/l.err" 2>/dev/null | tr '\n' ' ')"; exit 2; }
echo "arena: SCRIP_HEAP_KB=$SCRIP_HEAP_KB SCRIP_HEAP_MAX_MB=$SCRIP_HEAP_MAX_MB (the shipped window; the CEO-1146 sweep moved this off the MB=1 spelling, which named 1024 KB -- EIGHT TIMES what we ship -- and collected ZERO times on four of six witnesses)"
for mode in m3 m4; do line="  $mode"
  for s in $BAND; do runs=$((runs+1))
    if [ "$mode" = m3 ]; then got="$(SCRIP_GC_STRESS=$s timeout -k 5 180 "$ROOT/scrip" "$WIT" < /dev/null 2>/dev/null)"; else got="$(SCRIP_GC_STRESS=$s timeout -k 5 180 "$W/bg" < /dev/null 2>/dev/null)"; fi
    if [ "$got" = "$want" ]; then line="$line stress=$s:ok"; else line="$line stress=$s:RED"; bad=$((bad+1)); fi
  done; echo "$line"; done
echo "population: 2 modes x $(echo $BAND | wc -w) stress levels = $runs runs against the icont ref (12 bignums, every holder inside a list or a table)"
if [ "$bad" -ne 0 ]; then echo "GATE FAIL(1) [$G]: $bad of $runs runs lost or failed to relocate a BIG_t whose only holder is a heap aggregate element -- gc_visit_one has no arm for that DESCR tag"; exit 1; fi
echo "GATE PASS(0) [$G]: every bignum held only inside a heap aggregate survives and relocates across the stress band in both modes ($runs runs, 0 red)"
