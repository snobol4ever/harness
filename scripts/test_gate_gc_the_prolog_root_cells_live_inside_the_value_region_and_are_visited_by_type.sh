#!/usr/bin/env bash
# test_gate_gc_the_prolog_root_cells_live_inside_the_value_region_and_are_visited_by_type.sh
# ⛔ THE ROW'S GATE (ceo CEO-953, minted on the cto's gdb reading; row prolog-the-64-root-cells-grow-down-from-root-24-...).
# THE DEFECT: unification.c defines PL_DB_CELL0 24 and PL_DB_CELLS_MAX 64, so rt_pl_db_get/rt_pl_nb_set address cell k at
# (root - 24 - 8k) -- 64 cells growing DOWNWARD from root-24, 512 bytes of them.  emit.cpp:3197 places main's ROOT frame map
# cell at the jcon value region as a 16-byte DT_MAP cell, which the cto measured under gdb at root-48 with frame_bytes 272.
# The two regions occupy the same words, so a Prolog program with more than one dynamic predicate or nb global scribbles on
# the frame map cell of its own root frame.
# MEASURED ON MAIN AT 1027e8db2, both modes, SCRIP_HEAP_MB=1, stress 0/1/3/5: the witness reads 3-1-1-1-1 against the swipl
# oracle's 3-3-3-3-3 at EVERY point of the band, stress 0 included.  So the primary defect is the OVERLAP, not a lost root:
# only the first dynamic predicate keeps its clauses and every later one keeps exactly one.  A control arm with literal
# assertz and no =.. reads the same, so this is not the witness's own construction.
# THE CURE the row asks for: the lowerer and emitter place the Prolog cell region INSIDE the tabled value region as PTR_GC
# words -- out of the map cell's way, and visited by type rather than found by a sweep (which is what E removes).
# A stale binary or a missing witness REFUSES rc=2.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"; cd "$ROOT" || exit 2
. "$HERE/lib_gate.sh"
gate_parse_args "$@"
G=gc_the_prolog_root_cells_live_inside_the_value_region_and_are_visited_by_type
WIT="$HERE/gc_witnesses/hb_pl_root_cells.pl"; REF="$HERE/gc_witnesses/hb_pl_root_cells.ref"
[ -f "$WIT" ] && [ -f "$REF" ] || { echo "GATE UNPROVEN(2) [$G]: witness or ref missing ($WIT)"; exit 2; }
bash "$HERE/util_require_fresh.sh" --gate "$G" "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" || exit 2
W="$(mktemp -d "${TMPDIR:-/tmp}/gc_plroot.XXXXXX")" || exit 2
trap 'rm -rf "$W"' EXIT
BAND="${GC_PLROOT_BAND:-0 1 3 5}"
unset SCRIP_HEAP_MB; export SCRIP_HEAP_KB="${SCRIP_HEAP_KB:-128}" SCRIP_HEAP_MAX_MB="${SCRIP_HEAP_MAX_MB:-512}"
want="$(cat "$REF")"; bad=0; runs=0
( cd "$W" && timeout -k 5 180 "$ROOT/scrip" --compile -o pr.s "$WIT" < /dev/null 2>c.err && gcc pr.s -L "$ROOT/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$ROOT/out" -o pr 2>l.err ) || { echo "GATE UNPROVEN(2) [$G]: mode-4 compile or link failed: $(head -c 200 "$W/c.err" "$W/l.err" 2>/dev/null | tr '\n' ' ')"; exit 2; }
echo "arena: SCRIP_HEAP_KB=$SCRIP_HEAP_KB SCRIP_HEAP_MAX_MB=$SCRIP_HEAP_MAX_MB    oracle: swipl -q -t halt (the shipped window; the CEO-1146 sweep moved this off the MB=1 spelling)"
for mode in m3 m4; do line="  $mode"
  for s in $BAND; do runs=$((runs+1))
    if [ "$mode" = m3 ]; then got="$(SCRIP_GC_STRESS=$s timeout -k 5 180 "$ROOT/scrip" "$WIT" < /dev/null 2>/dev/null)"; else got="$(SCRIP_GC_STRESS=$s timeout -k 5 180 "$W/pr" < /dev/null 2>/dev/null)"; fi
    if [ "$got" = "$want" ]; then line="$line stress=$s:ok"; else line="$line stress=$s:RED[$(echo "$got" | head -1)]"; bad=$((bad+1)); fi
  done; echo "$line"; done
echo "population: 2 modes x $(echo $BAND | wc -w) stress levels = $runs runs, want [$(echo "$want" | head -1)] (5 dynamic predicates, 3 clauses each)"
if [ "$bad" -ne 0 ]; then echo "GATE FAIL(1) [$G]: $bad of $runs runs lost clauses of a dynamic predicate -- the 64 Prolog root cells at (root - 24 - 8k) still overlap the ROOT frame map cell at the value region"; exit 1; fi
echo "GATE PASS(0) [$G]: every dynamic predicate keeps its clauses across the stress band in both modes ($runs runs, 0 red) -- the Prolog cell region no longer collides with the ROOT map cell"
