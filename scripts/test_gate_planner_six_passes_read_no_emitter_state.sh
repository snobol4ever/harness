#!/usr/bin/env bash
# test_gate_planner_six_passes_read_no_emitter_state.sh -- PLANNER CHUNK 1 (ARCH-THREE-ZETAS-EMISSION 10 (1); ARCH-ZETA-ONE-COORDINATE 3.5; the ceo's
# CEO-1923: the cto builds chunks 1 to 3). The planner is its own stage: its inputs come from LOWER and the closed registry, none from emission.
# Six bars, every one a reading of today's tree:
#   CONSTRUCTS  src/ir/IR.h declares the construct registry (IR_construct_t; IR_graph_t's constructs and n_constructs), and --dump-plan counts
#               constructs > 0 over the witnesses (the lowerers set it because the construct is in the source)
#   PASSES      src/planner defines the six passes and the stage driver calls them in dependency order: planner_pass_definiteness, _homes,
#               _carves, _depths, _layout, _site_rules, inside planner_stage, which the driver calls between lower and the emitter
#   STAGE_LINE  src/planner names g_emitter, g_emit_cfg and g_emit nowhere and calls no emit_* function (at 642aac59f: 366 + 100 + 21 and 27)
#   DELETED     drive_slots_all, zd_edge_retains, planner_home_dyn and planner_retains_emitter_view are named nowhere in src/; xop_frame_slot nowhere in
#               src/planner (the retains column of the table replaces the three views; the planner calls no emitter decider)
#   TABLE       ./scrip --dump-plan prints, per graph, a PLAN line with its serial and one row per node with the thirteen columns E X K definite
#               zeta off depth retains_code owner fenced gpop wpop restore, for one witness of every language; SCRIP_PLANNER_REPORT=1 prints no
#               [PLANNER-FALLBACK] on any of them
#   CENSUS      util_placement_predicates_census.py reads at most 27 alive (the chunks move deciders, the switches delete them)
# Byte identity is each landing's own proof (util_population_asm_identity.sh against its parent, in the commit), never this gate's.
#   test_gate_planner_six_passes_read_no_emitter_state.sh [--root DIR]      (--root: grade another root's SCRIP, for a two-tree reading)
# rc 0 every bar met · rc 1 a bar unmet (each named, with its count) · rc 2 could not measure (unreadable sources, a stale or missing binary).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
[ "${1:-}" = "--root" ] && ROOT="$2"
SC="$ROOT/SCRIP"; SRC="$SC/src"
for f in ir/IR.h planner/zeta_plan.cpp planner/planner.h driver/scrip.c; do [ -r "$SRC/$f" ] || { echo "REFUSE(2): cannot read $SRC/$f"; exit 2; }; done
[ "$ROOT" = "$(cd "$HERE/../.." && pwd)" ] && { "$HERE/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?; }
[ -x "$SC/scrip" ] || { echo "REFUSE(2): no binary at $SC/scrip"; exit 2; }
bad=0
PL=$(ls "$SRC"/planner/*.c "$SRC"/planner/*.cpp "$SRC"/planner/*.h 2>/dev/null)
red() { echo "RED: $*"; bad=1; }
grep -q 'IR_construct_t' "$SRC/ir/IR.h" && grep -q 'n_constructs' "$SRC/ir/IR.h" || red "CONSTRUCTS src/ir/IR.h declares no construct registry (IR_construct_t, n_constructs)"
for p in definiteness homes carves depths layout site_rules; do grep -q "planner_pass_$p(" $PL || red "PASSES src/planner defines no planner_pass_$p"; done
order=$(awk '/^[a-z].* planner_stage\(/{f=1} f{print} f&&/^}/{exit}' $PL | grep -o 'planner_pass_[a-z_]*(' | tr -d '(' | awk '!s[$0]++' | tr '\n' ' ')
[ "$order" = "planner_pass_definiteness planner_pass_homes planner_pass_carves planner_pass_depths planner_pass_layout planner_pass_site_rules " ] || red "PASSES planner_stage calls, in order: '${order:-none}'"
grep -q 'planner_stage(' "$SRC/driver/scrip.c" || red "PASSES the driver (src/driver/scrip.c) never calls planner_stage"
ne=$(cat $PL | grep -o '\bg_emitter\b' | wc -l); nc=$(cat $PL | grep -o '\bg_emit_cfg\b' | wc -l); ng=$(cat $PL | grep -o '\bg_emit\b' | wc -l)
nf=$(cat $PL | grep -oP '\bemit_\w+(?=\s*\()' | wc -l)
echo "STAGE_LINE g_emitter=$ne g_emit_cfg=$nc g_emit=$ng emit_calls=$nf (bar 0 each; 366 100 21 27 at 642aac59f)"
[ $((ne + nc + ng + nf)) = 0 ] || red "STAGE_LINE src/planner reads emitter state $((ne + nc + ng)) times and calls emit_* $nf times"
for s in drive_slots_all zd_edge_retains planner_home_dyn planner_retains_emitter_view; do
    k=$(grep -rlw "$s" "$SRC" 2>/dev/null | wc -l); [ "$k" = 0 ] || red "DELETED $s is named in $k file(s) of src/"; done
k=$(cat $PL | grep -cw 'xop_frame_slot'); [ "$k" = 0 ] || red "DELETED src/planner names xop_frame_slot $k time(s)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
bash "$HERE/util_spine_population.sh" --corpus "$ROOT/corpus" > "$T/pop" 2>/dev/null || { echo "REFUSE(2): no population"; exit 2; }
ncons=0
for lang in snobol4 icon prolog pascal raku snocone rebus; do
    f=$(awk -F'\t' -v l="$lang" '$1 == l {print $2}' "$T/pop" | while read -r p; do printf '%s\t%s\n' "$(wc -c < "$p")" "$p"; done | sort -n | head -1 | cut -f2)
    [ -n "$f" ] || { red "TABLE no $lang witness in the population"; continue; }
    (cd "$(dirname "$f")" && SCRIP_PLANNER_REPORT=1 timeout 120 "$SC/scrip" --dump-plan "$(basename "$f")" < /dev/null > "$T/d" 2> "$T/e")
    np=$(grep -c '^PLAN graph=' "$T/d"); nr=$(grep -c '^PLAN_ROW ' "$T/d"); nfb=$(grep -c '^\[PLANNER-FALLBACK\]' "$T/e")
    cols=$(grep -m1 '^PLAN_COLUMNS ' "$T/d" | cut -d' ' -f2-)
    c=$(grep '^PLAN graph=' "$T/d" | grep -o 'constructs=[0-9]*' | cut -d= -f2 | awk '{s+=$1} END {print s+0}'); ncons=$((ncons + c))
    echo "TABLE lang=$lang witness=$(basename "$f") graphs=$np rows=$nr constructs=$c fallbacks=$nfb"
    [ "$cols" = "E X K definite zeta off depth retains_code owner fenced gpop wpop restore" ] || red "TABLE $lang: --dump-plan prints no PLAN_COLUMNS line with the thirteen columns (read '${cols:-none}')"
    [ "$np" -gt 0 ] && [ "$nr" -gt 0 ] || red "TABLE $lang: --dump-plan printed $np PLAN lines and $nr rows"
    [ "$nfb" = 0 ] || red "TABLE $lang: $nfb [PLANNER-FALLBACK] lines"
done
[ "$ncons" -gt 0 ] || red "CONSTRUCTS --dump-plan counted 0 constructs over the seven witnesses"
cen=$(cd "$SC" && python3 "$HERE/util_placement_predicates_census.py" 2>/dev/null | grep '^PLACEMENT_PREDICATES' | grep -o 'alive=[0-9]*' | cut -d= -f2)
echo "CENSUS placement predicates alive=${cen:-unread} (bar at most 27)"
[ -n "$cen" ] && [ "$cen" -le 27 ] || red "CENSUS util_placement_predicates_census.py reads alive=${cen:-unread}"
[ "$bad" = 0 ] && { echo "GATE OK: the planner is its own stage -- six passes in dependency order over the construct registry, its table printed, no emitter state read"; exit 0; }
echo "GATE RED: planner chunk 1 is not done (row planner-chunk-1-..., CEO-1923)"; exit 1
