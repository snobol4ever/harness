#!/usr/bin/env bash
# test_design_random_codegen_scope_steps.sh -- THE STEP-THROUGH HARNESS of DESIGN-PLAN: random-codegen-scope (the cto, 2026-10-28, CEO-1998/1999;
# .github/ARCH-RANDOM-SNOBOL4-GENERATOR.md). Lon, verbatim: "CTO should make detailed plans and test sources and harnesses for the HQs to execute
# and step through." The plan is corpus/demos/scriptix/infinite_snobol4/STEPS.tsv; the vocabulary each step must reach is COVERAGE.tsv beside it.
#
#   --list       print the steps, the generator's landed scope ceiling and each instrument step's landed probe; RUNS NOTHING (greps only)
#   --step N     run step N: the COVERAGE arm (is the construct family emitted at --scope N? red before the generator change, green after), then
#                one ENGINE arm per port engine present in this root (dotnet, jvm: the step's batches under the differential driver against
#                sbl -bf; differ=0 is GREEN, a differing batch is RED, an engine this root does not hold is REFUSED, never green)
#   --out DIR    where the batches go (default <root>/.scratch/inf_snobol4/design)
#
# VERDICT: one line per step, STEP N <slug>: coverage=V dotnet=V jvm=V -> GREEN|RED|REFUSED. rc 0 every graded arm GREEN (a REFUSED engine arm
# is named, not counted); rc 1 any arm RED; rc 2 no arm could be graded. A generator that refuses scope=N ("bad option") is the measured
# state of a generator step that has not landed and reads RED, not REFUSED; a missing icont or oracle is REFUSED.
# THE RUN SLOT: the engine arms are harness children, so this script holds one of the box-wide S4E_RUN_SLOTS (CEO-1894) for its whole run.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
INF="$ROOT/corpus/demos/scriptix/infinite_snobol4"
STEPS="$INF/STEPS.tsv"
GEN_MD="$INF/infinite_snobol4.md"
DRV="$HERE/util_inf_snobol4_differential.py"
CEN="$HERE/util_inf_snobol4_coverage_census.py"
ENUM="$HERE/util_program_enumerator.py"
RED="$HERE/util_inf_snobol4_reduce.py"
OUT="$ROOT/.scratch/inf_snobol4/design"
refuse() { echo "REFUSE(2): $*" >&2; exit 2; }
[ -f "$STEPS" ] || refuse "no step table at $STEPS"
[ -f "$GEN_MD" ] || refuse "no generator at $GEN_MD"
mode=""; step=""
while [ $# -gt 0 ]; do
    case "$1" in
        --list) mode=list; shift ;;
        --step) mode=step; step="${2:-}"; [ -n "$step" ] || refuse "--step takes a number"; shift 2 ;;
        --out) OUT="${2:-}"; shift 2 ;;
        *) refuse "usage: $0 --list | --step N [--out DIR]" ;;
    esac
done
[ -n "$mode" ] || refuse "usage: $0 --list | --step N [--out DIR]"
# the step table's columns are read by number with awk: a tab-separated row with EMPTY cells cannot go through bash read (its IFS collapses them)
col() { awk -F'\t' -v n="$1" -v k="$2" '!/^#/ && $1 == n {print $k; exit}' "$STEPS"; }
# the landed probes: a grep over the sources, never a run
ceiling() { sed -n '/^procedure inf_scope_max/,/^end/p' "$GEN_MD" | grep -oE 'return [0-9]+' | head -1 | grep -oE '[0-9]+'; }
probe() {   # prints landed|not-landed for an instrument step
    case "$1" in
        1)  c="$(ceiling)"; [ -n "$c" ] && echo "landed (ceiling $c)" || echo "not-landed (no inf_scope_max in the generator)" ;;
        2)  [ -f "$RED" ] && echo "landed" || echo "not-landed (no $(basename "$RED"))" ;;
        13) grep -q -- "'--engine'" "$ENUM" && echo "landed" || echo "not-landed (the enumerator has no --engine)" ;;
        14) grep -q -- "'--leaf-kinds'" "$ENUM" && echo "landed" || echo "not-landed (the enumerator has no --leaf-kinds)" ;;
        16) grep -q -- "'--grammar'" "$ENUM" && echo "landed" || echo "not-landed (the enumerator has no --grammar)" ;;
        17) grep -q -- "'--statements'" "$ENUM" && echo "landed" || echo "not-landed (the enumerator has no --statements)" ;;
        18) [ -f "$INF/HARVEST.tsv" ] && echo "landed" || echo "not-landed (no HARVEST.tsv)" ;;
        15) grep -q -- "'--pin'" "$DRV" && echo "landed (the driver pins)" || echo "not-landed" ;;
        *)  c="$(ceiling)"; [ -n "$c" ] && [ "$c" -ge "$1" ] && echo "landed (scope $1 <= ceiling $c)" || echo "not-landed (ceiling ${c:-0} < $1)" ;;
    esac
}
if [ "$mode" = list ]; then
    c="$(ceiling)"
    echo "DESIGN-PLAN: random-codegen-scope -- $(grep -c -v '^#' "$STEPS" | awk '{print $1-1}') steps (STEPS.tsv); generator scope ceiling: ${c:-none (step 1 not landed)}"
    printf '%-4s %-36s %-9s %-19s %-44s %s\n' step slug instrument executor landed families
    for n in $(awk -F'\t' '!/^#/ && $1 != "step" {print $1}' "$STEPS"); do
        printf '%-4s %-36s %-9s %-19s %-44s %s\n' "$n" "$(col "$n" 2)" "$(col "$n" 3)" "$(col "$n" 4)" "$(probe "$n")" "$(col "$n" 10)"
    done
    exit 0
fi
[ -n "$(col "$step" 1)" ] || refuse "no step $step in $STEPS (--list names them)"
slug="$(col "$step" 2)"; inst="$(col "$step" 3)"; exec="$(col "$step" 4)"; seed0="$(col "$step" 5)"; batches="$(col "$step" 6)"; size="$(col "$step" 7)"
pins="$(col "$step" 8)"; need="$(col "$step" 9)"; fams="$(col "$step" 10)"
mkdir -p "$OUT"
# one box-wide run slot for the whole step (CEO-1894), the shape of corpus_suite_harness._bounded_run
if [ -z "${S4E_RUN_SLOT_HELD:-}" ]; then
    nslots="${S4E_RUN_SLOTS:-8}"; mkdir -p /tmp/s4e-run-slots; got=""
    for i in $(seq 0 $((nslots - 1))); do exec 9>"/tmp/s4e-run-slots/slot$i"; flock -n 9 && { got=$i; break; }; done
    [ -n "$got" ] || { exec 9>"/tmp/s4e-run-slots/slot$(( $$ % nslots ))"; flock 9; }
    export S4E_RUN_SLOT_HELD=1
fi
cov=UNGRADED; dn=UNGRADED; jv=UNGRADED
pin_args=(); if [ -n "$pins" ] && [ "$inst" != enum ]; then IFS=';' read -r -a plist <<< "$pins"; for p in "${plist[@]}"; do pin_args+=(--pin "$p"); done; fi
engine_present() { bash "$HERE/run_snobol4$1.sh" --binaries > /dev/null 2>&1; }
driver_verdict() {   # $1 engine, the rest the driver's arguments; prints GREEN|RED(differ=d)|REFUSED
    local e="$1"; shift
    local log="$OUT/step${step}_$e.log"
    python3 "$DRV" --engine "$e" --out "$OUT/step$step" "$@" > "$log" 2>&1; local rc=$?
    case $rc in
        0) echo GREEN ;;
        1) echo "RED(differ=$(grep -oE 'differ=[0-9]+' "$log" | tail -1 | cut -d= -f2))" ;;
        *) echo "REFUSED($(tail -1 "$log" | cut -c1-80))" ;;
    esac
}
enum_verdict() {   # $1 engine, the rest the enumerator's arguments
    local e="$1"; shift
    local log="$OUT/step${step}_$e.log"
    python3 "$ENUM" --engine "$e" --out "$OUT/step$step/enum_$e" "$@" > "$log" 2>&1; local rc=$?
    case $rc in 0) echo GREEN ;; 1) echo "RED(divergence-classes=$(grep -oE 'DIVERGENCE-CLASSES=[0-9]+' "$log" | tail -1 | cut -d= -f2))" ;; *) echo "REFUSED($(tail -1 "$log" | cut -c1-80))" ;; esac
}
case "$inst" in
    gen|gen+eval)
        if [ "$step" = 1 ]; then
            log="$OUT/step1_scope.log"
            if python3 "$DRV" --engine dotnet --generate-only --scope 1 --seed0 "$seed0" 1 --out "$OUT/step1" > "$log" 2>&1; then cov=GREEN
            elif grep -q 'refuses scope=' "$log"; then cov="RED(the generator refuses scope=1: step 1 not landed)"
            else cov="REFUSED($(tail -1 "$log" | cut -c1-80))"; fi
            scope=1
        elif [ "$step" = 15 ]; then
            grep -q -- "'--pin'" "$DRV" && cov=GREEN || cov="RED(the driver has no --pin)"
            scope=0
        else
            log="$OUT/step${step}_coverage.log"
            python3 "$CEN" --step "$step" --scope "$step" --need "$need" --seeds 2 --size 300 --out "$OUT/step$step/census" > "$log" 2>&1; rc=$?
            case $rc in
                0) cov=GREEN ;;
                1) cov="RED($(grep -oE '[0-9]+ below need' "$log" | tail -1))" ;;
                *) if grep -q 'refuses scope=' "$log"; then cov="RED(the generator refuses scope=$step: step $step not landed)"; else cov="REFUSED($(tail -1 "$log" | cut -c1-80))"; fi ;;
            esac
            scope="$step"
        fi
        for e in dotnet jvm; do
            if ! engine_present "$e"; then v="REFUSED(no $e engine in this root)"
            elif [ "$step" = 15 ]; then
                v=GREEN
                for cfg in "walk=every;kind=expr;preset=1;elimit=1" "walk=every;kind=expr;preset=1;elimit=2" "walk=every;kind=match;preset=1;plimit=1;climit=1" "walk=every;kind=match;preset=1;plimit=2;climit=2" "walk=every;kind=match;preset=3;plimit=1;climit=1"; do
                    pa=(); IFS=';' read -r -a plist <<< "$cfg"; for p in "${plist[@]}"; do pa+=(--pin "$p"); done
                    w="$(driver_verdict "$e" --scope 0 --seed0 "$seed0" 1 --size "$size" "${pa[@]}")"
                    case "$w" in GREEN) ;; RED*) v="$w"; break ;; *) [ "$v" = GREEN ] && v="$w" ;; esac
                done
            else
                v="$(driver_verdict "$e" --scope "$scope" --seed0 "$seed0" "$batches" --size "$size" "${pin_args[@]}")"
            fi
            [ "$e" = dotnet ] && dn="$v" || jv="$v"
        done ;;
    harness)
        if [ -f "$RED" ]; then python3 "$RED" --selftest > "$OUT/step2_selftest.log" 2>&1 && cov=GREEN || cov="RED(selftest rc $?)"
        else cov="RED(no $(basename "$RED"): step 2 not landed)"; fi ;;
    enum)
        flag=""; extra=(); len="${pins#to-length }"
        case "$step" in 13) flag="'--engine'" ;; 14) flag="'--leaf-kinds'"; extra=(--leaf-kinds "int,var,str,real") ;; 16) flag="'--grammar'"; extra=(--grammar match) ;; 17) flag="'--statements'"; extra=(--statements) ;; esac
        if grep -q -- "$flag" "$ENUM"; then
            cov=GREEN
            for e in dotnet jvm; do
                if engine_present "$e"; then v="$(enum_verdict "$e" --to-length "$len" "${extra[@]}")"; else v="REFUSED(no $e engine in this root)"; fi
                [ "$e" = dotnet ] && dn="$v" || jv="$v"
            done
        else cov="RED(the enumerator has no $flag: step $step not landed)"; fi ;;
    corpus)
        if [ ! -f "$INF/HARVEST.tsv" ]; then cov="RED(no HARVEST.tsv: step 18 not landed)"
        else
            missing=0; total=0
            while IFS=$'\t' read -r d e sc s0 b l cls origin rowname; do
                [ -n "$origin" ] || continue; total=$((total + 1))
                grep -q ",$origin," "$ROOT/corpus/tests/snobol4/ALL.csv" || { missing=$((missing + 1)); echo "  unharvested: $origin (batch $b line $l, $e)"; }
            done < <(grep -v '^#' "$INF/HARVEST.tsv" | tail -n +2)
            if python3 "$HERE/util_suite_partition.py" check "$ROOT/corpus/tests/snobol4/ALL.csv" > "$OUT/step18_partition.log" 2>&1; then part=current; else part=stale; fi
            if [ "$missing" = 0 ] && [ "$part" = current ]; then cov="GREEN($total harvested)"; else cov="RED($missing of $total unharvested, partition $part)"; fi
        fi ;;
    *) refuse "step $step has an instrument this harness does not grade: $inst" ;;
esac
verdict=GREEN; graded=0
for v in "$cov" "$dn" "$jv"; do
    case "$v" in GREEN*) graded=$((graded + 1)) ;; RED*) verdict=RED; graded=$((graded + 1)) ;; esac
done
[ "$graded" = 0 ] && verdict=REFUSED
echo "STEP $step $slug: coverage=$cov dotnet=$dn jvm=$jv -> $verdict"
case "$verdict" in GREEN) exit 0 ;; RED) exit 1 ;; *) exit 2 ;; esac
