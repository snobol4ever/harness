#!/usr/bin/env bash
export S4E_ONE_RUNNER_FIXTURE="gate arm ${0##*/}: a runner invoked as an instrument fixture, not a board (CEO-523)"
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_gc_a_collection_over_a_small_live_set_stays_under_its_instruction_budget.sh -- THE FIXED COST OF A COLLECTION, PINNED.
# At the shipped 128 KB arena table_access spends 76% of its instructions in 2,482 collections of a ~712-block live set, and the
# cost of one such collection is mostly walks that do not depend on the live set: the root walks over the name and function
# tables, the defer-cell scan, the vacated-ground ledger, the plant seams read per block, the slot fixup's second lookup, the
# worklist traffic of integer descriptors (ceo 2026-09-25, CEO-1256). The CEO-1256 landing cut that from 851 K to about 650 K Ir
# per collection; this gate keeps it from creeping back. THE INSTRUMENT is callgrind (load-immune: instructions, not time) on the
# table_access iteration twin at 128 KB: gc_collect_ex inclusive Ir divided by the collection count the runtime reports.
# ARMS: (1) the twin computes its value; (2) collections >= 100 (population); (3) Ir per collection <= 760,000.
# FAIL_ONCE (recorded): the pre-cure runtime at 0f560a28e read 851 K per collection; this tree reads about 650 K.
# Cost ~8 s (callgrind over ten repetitions). EXIT 0 all arms; 1 a red; 2 REFUSED (valgrind, the kernel or the build missing).
# ⛔ RE-POINTED 2026-09-26 (cfo, the CEO-1274 board row), TWO CHANGES UNDER IT AND BOTH NAMED: (a) corpus cb366317c made
# table_access a straight-line snippet (964-block live set, not 712; the twin prints kernel=main), so the gate now measures
# its OWN frozen copy, ../harness/scripts/fixtures/gc_budget_table_access.sno -- the form the budget was measured on; (b) since CEO-1261/
# 1262 SCRIP_HEAP_KB is the collector's WINDOW under a 128 MB cap, so the arena is stated on the twin's command line as
# SPITBOL switches, -i128k -d128k (window = cap = 128 KB), and a run that grew or hit the cap is REFUSED (clause 4).
# Re-measured on this fixture 2026-09-26: 240 collections, grew=0, 676,429 Ir per collection.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"; S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
K="$HERE/fixtures/gc_budget_table_access.sno"; [ -f "$K" ] && [ -f "${K%.sno}.ref" ] || { echo "REFUSED(2): the fixture $K or its .ref is missing"; exit 2; }
[ -x "$ROOT/scrip" ] && [ -f "$ROOT/out/libscrip_rt.so" ] || { echo "REFUSED(2): $ROOT/scrip or out/libscrip_rt.so not built"; exit 2; }
command -v valgrind >/dev/null 2>&1 && command -v callgrind_annotate >/dev/null 2>&1 || { echo "REFUSED(2): valgrind/callgrind_annotate missing -- the budget is an instruction count"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
python3 "$HERE/bench_wrap_snobol4.py" "$K" --mode iter --n 10 -o "$W/ta.sno" > /dev/null 2>&1 || { echo "REFUSED(2): twin generation failed"; exit 2; }
( cd "$W" && "$ROOT/scrip" --compile -o "$W/ta.s" ta.sno < /dev/null > /dev/null 2>&1 && gcc "$W/ta.s" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$W/ta.bin" ) 2>/dev/null || { echo "REFUSED(2): the twin did not build in mode 4"; exit 2; }
unset SCRIP_HEAP_MB SCRIP_HEAP_KB SCRIP_HEAP_CAP_KB SCRIP_HEAP_MAX_MB
( cd "$W" && SCRIP_GC_EXERCISE=1 timeout -k 5 300 valgrind --tool=callgrind --callgrind-out-file="$W/cg.out" ./ta.bin -i128k -d128k < /dev/null > "$W/ta.out" 2> "$W/ta.err" )
red=0
want=$(tail -1 "${K%.sno}.ref" | sed 's/.* = //')
grep -q "BENCH mode=iter kernel=TABLE_ACCESS iters=10 .*mismatched=0 value=$want\$" "$W/ta.err" && echo "ok  (1) the twin computed value=$want (the fixture's own .ref) over 10 repetitions" || { echo "RED (1) the twin did not print value=$want: $(grep -o 'BENCH.*' "$W/ta.err" | head -1)"; red=1; }
ex=$(grep -o '\[GC-EXERCISE\].*' "$W/ta.err" | tail -1)
case "$ex" in *' arena_kb=128 '*' capped=0 grew=0 cap_kb=128 '*) echo "ok  (0) the arena is the one the budget names: $(printf '%s' "$ex" | grep -oE 'arena_kb=[0-9]+|capped=[0-9]+|grew=[0-9]+|cap_kb=[0-9]+' | tr '\n' ' ')";;
  *) echo "REFUSED(2): the run is not evidence of a 128 KB arena (clause 4: grew>0 or capped>0 disqualifies it): [${ex:-no GC-EXERCISE line}]"; exit 2;; esac
coll=$(grep -o 'collections=[0-9]*' "$W/ta.err" | tail -1 | cut -d= -f2); coll=${coll:-0}
[ "$coll" -ge 100 ] || { echo "REFUSED(2): only $coll collections at 128 KB -- too few to grade a per-collection budget"; exit 2; }
echo "ok  (2) collections=$coll (population)"
ir=$(callgrind_annotate --inclusive=yes "$W/cg.out" 2>/dev/null | grep 'gc_heap.c:gc_collect_ex' | head -1 | awk '{gsub(",","",$1); print $1}')
[ -n "$ir" ] || { echo "REFUSED(2): callgrind_annotate reported no gc_collect_ex line"; exit 2; }
per=$((ir / coll))
if [ "$per" -le 760000 ]; then echo "ok  (3) gc_collect_ex $ir Ir over $coll collections = $per Ir per collection <= 760000"
else echo "RED (3) gc_collect_ex $ir Ir over $coll collections = $per Ir per collection > 760000: a fixed cost crept back into the collection"; red=1; fi
[ "$red" -eq 0 ] && { echo "GATE OK: a collection over table_access's live set at 128 KB stays under its instruction budget"; exit 0; }
echo "GATE FAILED: see the RED lines above"; exit 1
