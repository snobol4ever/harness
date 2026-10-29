#!/usr/bin/env bash
# test_gate_planner_six_passes_read_no_emitter_state.sh -- THE PLANNER STAGE'S GREEN ARMS (ARCH-THREE-ZETAS-EMISSION 10 (1) and 11.7; the ceo's CEO-1923
# row planner-chunk-1, RETIRED on the cto's ruling 11.7 of 2026-10-29: its substance is on origin -- the registry, the table, --dump-plan, the stage driver).
# Re-cut to the arms that read green. The six literal planner_pass_<name> functions and their call order are withdrawn (CTO-352 and 3.5's correction: the six
# passes are the dependency order of what the stage computes, not six names), the STAGE_LINE bar is the census's D bar and step 11's finish line, and the four
# deleted names (drive_slots_all, zd_edge_retains, planner_home_dyn, planner_retains_emitter_view) are counted down by test_design_planner_finish_steps.sh
# --step 11's finish token under the plan whose steps delete them.
#   CONSTRUCTS  src/ir/IR.h declares the construct registry (IR_construct_t; IR_graph_t's constructs and n_constructs), and --dump-plan counts
#               constructs > 0 over the witnesses (the lowerers set it because the construct is in the source)
#   DRIVER      src/driver/scrip.c calls planner_stage
#   DELETED     xop_frame_slot is named nowhere in src/planner (the retains column of the table replaces the planner's call of an emitter decider)
#   TABLE       ./scrip --dump-plan prints, per graph, a PLAN line with its serial and one row per node with the fourteen columns E X K definite
#               zeta off depth retains_code owner fenced gpop wpop restore act, for one witness of every language; SCRIP_PLANNER_REPORT=1 prints no
#               [PLANNER-FALLBACK] on any of them
#   CENSUS      util_placement_predicates_census.py reads 0 alive
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
grep -q 'planner_stage(' "$SRC/driver/scrip.c" || red "DRIVER the driver (src/driver/scrip.c) never calls planner_stage"
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
    [ "$cols" = "E X K definite zeta off depth retains_code owner fenced gpop wpop restore act" ] || red "TABLE $lang: --dump-plan prints no PLAN_COLUMNS line with the fourteen columns (read '${cols:-none}'; act is the ACT word's cause, ARCH-THREE-ZETAS-EMISSION 6.1, CEO-1942/1943, the cto 2026-10-24)"
    [ "$np" -gt 0 ] && [ "$nr" -gt 0 ] || red "TABLE $lang: --dump-plan printed $np PLAN lines and $nr rows"
    [ "$nfb" = 0 ] || red "TABLE $lang: $nfb [PLANNER-FALLBACK] lines"
done
[ "$ncons" -gt 0 ] || red "CONSTRUCTS --dump-plan counted 0 constructs over the seven witnesses"
cen=$(cd "$SC" && python3 "$HERE/util_placement_predicates_census.py" 2>/dev/null | grep '^PLACEMENT_PREDICATES' | grep -o 'alive=[0-9]*' | cut -d= -f2)
echo "CENSUS placement predicates alive=${cen:-unread} (bar 0)"
[ -n "$cen" ] && [ "$cen" = 0 ] || red "CENSUS util_placement_predicates_census.py reads alive=${cen:-unread}"
[ "$bad" = 0 ] && { echo "GATE OK: the planner stage is on the construct registry, its table printed for every language, no placement predicate alive"; exit 0; }
echo "GATE RED: the planner stage regressed (ARCH-THREE-ZETAS-EMISSION 10 (1), 11.7)"; exit 1
