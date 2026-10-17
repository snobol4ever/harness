#!/usr/bin/env bash
# audit_bb_fixup_rank.sh — whole-tree TEMPLATE SPEC v2 lap-progress table for GOAL-BB-FIXUP.md
# Prints a sorted table of all BB_templates/*.cpp files with their violation counts.
# Clean files (total=0) are shown at the bottom; dirty files ranked worst-first.
# Run at session open and close to measure lap progress.
# ONE RULER (2026-09-28): every count is audit_bb_fixup_file.sh's own, so the census GRAND is the sum of the per-file TOTALs
# (the sweep's rank TOTAL != per-file TOTAL finding: this table used to omit cv9_param_str and cv10_graph).
# Usage: bash ../harness/scripts/audit_bb_fixup_rank.sh [--dirty-only]
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
cd "$ROOT"
dirty_only=0
[ "${1:-}" = "--dirty-only" ] && dirty_only=1
strip() { perl -0777 -pe 's{/\*.*?\*/}{}gs; s{//[^\n]*}{}g' "$1"; }
declare -a rows
total_files=0
total_dirty=0
total_clean=0
grand_violations=0
for f in src/templates/bb/bb_*.cpp src/templates/xa/xa_*.cpp; do
    [ -f "$f" ] || continue
    name="$(basename "$f")"
    total_files=$((total_files + 1))
    eval "$(bash "$HERE/audit_bb_fixup_file.sh" "$f" | awk '/^  [a-z0-9_]+ +\(/ { print "c_" $1 "=" $NF } /^  TOTAL violations:/ { print "tot=" $NF }')"
    em=$c_emit_blind; nw=$c_neighbor_walk; bs=$c_bsize; rb=$c_raw_bytes; mt=$c_medium_any; ef=$c_emit_fmt; lc=$c_line_comments
    bl=$c_blank_lines; pe=$c_port_english; lv=$c_local_vars; rp=$c_returns_plus; hc=$c_helper_count; sd=$c_sig_decls; cl=$c_over_col
    ml=$c_multi_x86; xc=$c_extra_cmts; bp=$c_bypass; c9=$c_cv9_param_str; c10=$c_cv10_graph; lb=$c_lang_blind
    grand_violations=$((grand_violations + tot))
    if [ "$tot" -gt 0 ]; then
        total_dirty=$((total_dirty + 1))
        rows+=("$(printf "%05d %s eb=%d nw=%d bs=%d rb=%d mt=%d ef=%d lc=%d bl=%d pe=%d lv=%d rp=%d hc=%d sd=%d cl=%d ml=%d xc=%d bp=%d c9=%d c10=%d lb=%d TOTAL=%d" "$tot" "$name" "$em" "$nw" "$bs" "$rb" "$mt" "$ef" "$lc" "$bl" "$pe" "$lv" "$rp" "$hc" "$sd" "$cl" "$ml" "$xc" "$bp" "$c9" "$c10" "$lb" "$tot")")
    else
        total_clean=$((total_clean + 1))
        [ "$dirty_only" -eq 0 ] && rows+=("$(printf "00000 %s CLEAN" "$name")")
    fi
done
echo "=== BB-FIXUP LAP PROGRESS TABLE ($(date '+%Y-%m-%d %H:%M')) ==="
printf "%-52s %s\n" "FILE" "VIOLATIONS"
echo "--------------------------------------------------------------------"
if [ ${#rows[@]} -gt 0 ]; then
    printf '%s\n' "${rows[@]}" | sort -rn | while IFS= read -r row; do
        score="${row%% *}"
        rest="${row#* }"
        name="${rest%% *}"
        detail="${rest#* }"
        if [ "$score" = "00000" ]; then
            printf "  %-50s CLEAN\n" "$name"
        else
            printf "  %-50s %s\n" "$name" "$detail"
        fi
    done
fi
echo "--------------------------------------------------------------------"
printf "  FILES: %d total / %d dirty / %d clean\n" "$total_files" "$total_dirty" "$total_clean"
printf "  GRAND TOTAL violations: %d\n" "$grand_violations"
if [ "$total_dirty" -eq 0 ]; then
    echo "  LAP STATUS: ALL CLEAN — lap complete"
else
    echo "  LAP STATUS: $total_dirty file(s) need fixup"
fi

# ⭐ V2-5 GATE HONESTY: this script had NO exit statement -- "83 file(s) need fixup" exited 0.
. "$(dirname "$0")/lib_gate.sh"
gate_floor "$total_files" 50 "bb_*/xa_* template files"
gate_verdict "$total_dirty" "template file(s) need fixup"
