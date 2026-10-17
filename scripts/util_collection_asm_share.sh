#!/usr/bin/env bash
# util_collection_asm_share.sh -- THE COLLECTION RUNS IN ASM (Lon 2026-10-15 13:3x CDT, in-chat to the ceo, verbatim: "Have the GC collection code
# written in ASM versus C."; ceo CEO-1793). Books every instruction executed INSIDE a collection by layer, on three fixed witnesses that collect,
# one per focus language, in both modes, and passes only when the C runtime's share of those instructions is at or under the bar.
#
# THE MEASUREMENT: ../harness/scripts/util_runtime_leaf_census.sh under callgrind with --collect-atstart=no --toggle-collect=gc_collect_ex, so the profile holds
# exactly the instructions run between entering and leaving the collection's one funnel (the mark phase, the root walk, the fix-up and slide runs,
# every visitor and every helper they call); its LEAF_CENSUS line's c_runtime field is the share this row drives to the bar. SCRIP_DIAG=0, so the
# collector's self-checks (verify, auditor, birth ledger, census) are off and may stay C: they are instruments, not the collection.
#
# THE FUNNEL IS gc_collect_ex: a collection that does not pass through it profiles nothing, and the census REFUSES rc 2 on a profile with no totals,
# so a renamed or bypassed funnel reads COULD NOT MEASURE, never green -- the asm rewrite keeps the symbol (RTX_FUNC(gc_collect_ex)) or re-cuts
# this instrument in the same landing, naming the new funnel.
#
# THE WITNESSES (each collects; counted with SCRIP_ZETA_TELEM=1 at SCRIP a2fbe4342): SNOBOL4 table_access.sno 21 collections and Prolog browse.pl
# 166 at a 64 KB collector window (SCRIP_HEAP_KB, the WINDOW, as make test-arena uses it -- the program's own -d/-s come from its sidecars);
# Icon geddump.icn 14 collections at its declared sizes (CEO-1792), graded in MODE 4 ONLY: valgrind 3.22 itself dies ("the 'impossible' happened",
# killed by a fatal signal) on Icon mode-3 runs under callgrind -- geddump and bench_icnstr_concat_table both, 2026-10-15, SCRIP 19e10ef38 -- while
# both run clean outside valgrind. The collection is libscrip_rt code, the same in both modes, and SNOBOL4 and Prolog carry its mode-3 cells.
#
# OUTPUT: one COLLECTION_ASM line per cell, then
#   COLLECTION_ASM_BOARD green=G red=R refused=U cells=N bar_c_runtime=B tree=<hash>
# rc 0 every cell at or under the bar; rc 1 a cell above it; rc 2 a cell could not be measured (G+R+U=N asserted).
# READ RED at SCRIP 19e10ef38 (2026-10-15, the ceo): table_access m3 87.15 / m4 88.71 percent C; browse m3 91.44 / m4 92.88; geddump m4 86.00.
# COLLECTION_ASM_BAR overrides the bar (default 1.00 percent).
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
refuse() { echo "⛔ REFUSED (rc=2): util_collection_asm_share: $*"; exit 2; }
CORPUS="${CORPUS_DIR:-$(cd "$ROOT/../corpus" 2>/dev/null && pwd)}"
[ -d "$CORPUS/benchmarks" ] || refuse "no corpus beside $ROOT (set CORPUS_DIR)"
BAR="${COLLECTION_ASM_BAR:-1.00}"
WITNESSES=("snobol4/table_access.sno 64 m3,m4" "prolog/bench/browse.pl 64 m3,m4" "icon/geddump.icn - m4")
for w in "${WITNESSES[@]}"; do [ -f "$CORPUS/benchmarks/${w%% *}" ] || refuse "witness benchmarks/${w%% *} is missing"; done
G=0; R=0; U=0; N=0
for w in "${WITNESSES[@]}"; do
  read -r rel win modes <<<"$w"; prog="$CORPUS/benchmarks/$rel"
  for mode in ${modes//,/ }; do
    N=$((N+1))
    if [ "$win" = - ]; then
      out="$(SCRIP_DIAG=0 LEAF_VG_FLAGS='--collect-atstart=no --toggle-collect=gc_collect_ex' bash "$HERE/util_runtime_leaf_census.sh" "$prog" --mode "$mode" --top 8 2>&1)"
    else
      out="$(SCRIP_HEAP_KB="$win" SCRIP_DIAG=0 LEAF_VG_FLAGS='--collect-atstart=no --toggle-collect=gc_collect_ex' bash "$HERE/util_runtime_leaf_census.sh" "$prog" --mode "$mode" --top 8 2>&1)"
    fi
    line="$(printf '%s\n' "$out" | grep -m1 '^LEAF_CENSUS ')"
    c="$(printf '%s\n' "$line" | sed -n 's/.* c_runtime=\([0-9.]*\).*/\1/p')"
    a="$(printf '%s\n' "$line" | sed -n 's/.* asm_leaf=\([0-9.]*\).*/\1/p')"
    t="$(printf '%s\n' "$line" | sed -n 's/.* total_ir=\([0-9]*\).*/\1/p')"
    if [ -z "$c" ] || [ -z "$t" ] || [ "$t" = 0 ]; then
      why="$(printf '%s\n' "$out" | grep -m1 -E 'REFUSED|STALE|stale|refus')"; [ -n "$why" ] || why="$(printf '%s\n' "$out" | grep -v '^[[:space:]]*$' | tail -1)"
      U=$((U+1)); echo "COLLECTION_ASM witness=$(basename "$prog") mode=$mode verdict=REFUSED reason=$(printf '%s' "$why" | cut -c1-200)"
      continue
    fi
    top="$(printf '%s\n' "$out" | grep '^LEAF_C ' | awk '{split($5,s,"="); if (s[2] > 0) print $2}' | sed 's/^fn=//' | head -4 | paste -sd, -)"
    if awk -v c="$c" -v b="$BAR" 'BEGIN { exit !(c + 0 <= b + 0) }'; then v=GREEN; G=$((G+1)); else v=RED; R=$((R+1)); fi
    echo "COLLECTION_ASM witness=$(basename "$prog") mode=$mode verdict=$v collection_ir=$t c_runtime=$c asm_leaf=$a c_top=${top:-none}"
  done
done
[ $((G+R+U)) -eq "$N" ] || refuse "the cells do not add up (green=$G red=$R refused=$U of $N)"
echo "COLLECTION_ASM_BOARD green=$G red=$R refused=$U cells=$N bar_c_runtime=$BAR tree=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)"
[ "$U" -gt 0 ] && exit 2
[ "$R" -gt 0 ] && exit 1
exit 0
