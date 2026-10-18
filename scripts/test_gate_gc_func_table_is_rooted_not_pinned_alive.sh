#!/usr/bin/env bash
# test_gate_gc_func_table_is_rooted_not_pinned_alive.sh -- THE DEFINE TABLE IS A ROOT, NOT A BLOCK THAT SURVIVES BECAUSE IT CANNOT MOVE.
# ⛔ THE MEASURED DEFECT (hq_V 2026-09-14, row icon-gc-root-the-func-buckets-static-array-before-rung-2-...): _func_buckets (core.c) is a
# static array of FNCBLK_t chains, every field of every entry rt_pinned_alloc'd, and core_gc_roots walked _var_buckets and _udef_types
# but NEVER _func_buckets -- pinning was the only thing keeping the DEFINE table's pointers valid, and making the four aggregate
# types slide (GC-5 rung 2) segfaulted a five-statement SNOBOL4 program 20/20 in strcmp under APPLY. Same class as dat_types[].blk
# (gc2, SCRIP 5dafed741) one table over. TWO ARMS, HONESTLY LABELLED: the STRUCTURAL arm (core_gc_roots must name _func_buckets) is
# the one that discriminates while pinned blocks are immortal; the BEHAVIOURAL arm (100 DEFINEd functions APPLYed after measured
# collections) is vacuous today and becomes the real guard the day FNCBLK_t blocks slide. Red on the pre-cure tree by the structural
# arm (measured rc=1 2026-09-16 10:49); a stale binary or an unreachable witness REFUSES rc=2.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; cd "$ROOT" || exit 2
bash ../harness/scripts/util_require_fresh.sh >/dev/null 2>&1 || { echo "REFUSES rc=2: stale or missing ./scrip -- run make"; exit 2; }
bad=0
n=$(awk '/^void core_gc_roots\(void\)/{f=1} f&&/_func_buckets/{c++} f&&/^}/{exit} END{print c+0}' src/runtime/core/core.c)
if [ "$n" -ge 1 ]; then echo "  structural PASS: core_gc_roots names _func_buckets $n time(s)"; else echo "  structural RED: core_gc_roots does not walk _func_buckets -- the DEFINE table has no root and pinning is its only alibi"; bad=1; fi
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
{ for i in $(seq 1 100); do echo "        DEFINE(\"F$i(X)\")"; done; echo "        N = 0"; echo "LOOP    N = N + 1"; echo "        S = DUPL(\"x\", 20000)"; echo "        LT(N, 30000)   :S(LOOP)"; for i in $(seq 1 100); do echo "        OUTPUT = APPLY(\"F$i\", $i)"; done; echo "        OUTPUT = \"DONE\""; echo "        :(END)"; for i in $(seq 1 100); do echo "F$i      F$i = X * 2   :(RETURN)"; done; echo "END"; } > "$W/w.sno"
( cd "$W" && SCRIP_GC_COVERAGE=1 timeout -k 5 120 "$ROOT/scrip" w.sno < /dev/null > out.txt 2> err.txt ); r=$?; c=$(grep -c GC-COV "$W/err.txt")
if [ "$r" -eq 0 ] && [ "$(tail -1 "$W/out.txt")" = "DONE" ] && [ "$(sed -n 100p "$W/out.txt")" = "200" ]; then echo "  behavioural PASS: rc=0, $c collection(s), 100 APPLYed DEFINEs answered after them$( [ "$c" -ge 1 ] || echo ' -- VACUOUS, zero collections observed')"; else echo "  behavioural RED: rc=$r after $c collection(s) -- an APPLYed DEFINE did not survive collection (last line: $(tail -1 "$W/out.txt"))"; bad=1; fi
if [ "$bad" -ne 0 ]; then echo "GATE FAIL(1) [gc_func_table_is_rooted_not_pinned_alive]: the DEFINE table is not a root"; exit 1; fi
echo "GATE PASS(0) [gc_func_table_is_rooted_not_pinned_alive]: core_gc_roots walks _func_buckets and DEFINEd functions survive collection (2 arms, 0 red)"
