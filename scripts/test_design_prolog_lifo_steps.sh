#!/usr/bin/env bash
# test_design_prolog_lifo_steps.sh -- THE STEP-THROUGH HARNESS of DESIGN-PLAN: prolog-lifo (the cto, 2026-10-28, CEO-1997/1998;
# .github/ARCH-PROLOG-ACTIVATION-LIFETIME.md section 9). The plan is corpus/tests/prolog/lifo/STEPS.tsv; the witnesses are the .pl beside it, each
# with a .ref cut from swipl 9.0.4 (-q -t halt), the one SWI-dialect oracle (CEO-1603).
#
#   --list       print the steps and run nothing
#   --step N     grade step N: every witness of the step in mode 3 (./scrip w.pl) and mode 4 (--compile, as, gcc, run) under SCRIP_ZD_RTCHECK=1,
#                byte-equal to its .ref with rc 0 (a SIGILL is the depth check firing and reads RED(depth-check)); then the step's PROBE over the
#                witnesses (the mode-4 .s, the placement census, the predictor report): red before the step lands, green after
#   --out DIR    where the .s and logs go (default <root>/.scratch/prolog_lifo)
#
# VERDICT: STEP N <slug>: m3=<pass>/<n> m4=<pass>/<n> probe=<reading> -> GREEN|RED|REFUSED; rc 0 GREEN, 1 RED, 2 could not measure (no ./scrip,
# no witness, no oracle ref). Step 7 (the finish) runs the fleet's instruments, which take minutes, and names each.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
SC="$ROOT/SCRIP"
WD="$ROOT/corpus/tests/prolog/lifo"
STEPS="$WD/STEPS.tsv"
OUT="$ROOT/.scratch/prolog_lifo"
refuse() { echo "REFUSE(2): $*" >&2; exit 2; }
[ -f "$STEPS" ] || refuse "no step table at $STEPS"
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
col() { awk -F'\t' -v n="$1" -v k="$2" '!/^#/ && $1 == n {print $k; exit}' "$STEPS"; }
if [ "$mode" = list ]; then
    echo "DESIGN-PLAN: prolog-lifo -- $(grep -c -v '^#' "$STEPS" | awk '{print $1-1}') steps (STEPS.tsv); witnesses in $WD"
    printf '%-4s %-40s %-10s %-14s %s\n' step slug executor probe witnesses
    for n in $(awk -F'\t' '!/^#/ && $1 != "step" {print $1}' "$STEPS"); do
        printf '%-4s %-40s %-10s %-14s %s\n' "$n" "$(col "$n" 2)" "$(col "$n" 3)" "$(col "$n" 4)" "$(col "$n" 5)"
    done
    exit 0
fi
[ -n "$(col "$step" 1)" ] || refuse "no step $step in $STEPS (--list names them)"
slug="$(col "$step" 2)"; probe="$(col "$step" 4)"; wits="$(col "$step" 5)"
[ -x "$SC/scrip" ] || refuse "no $SC/scrip"
mkdir -p "$OUT/step$step"
# one box-wide run slot for the step (CEO-1894)
if [ -z "${S4E_RUN_SLOT_HELD:-}" ]; then
    nslots="${S4E_RUN_SLOTS:-8}"; mkdir -p /tmp/s4e-run-slots; got=""
    for i in $(seq 0 $((nslots - 1))); do exec 9>"/tmp/s4e-run-slots/slot$i"; flock -n 9 && { got=$i; break; }; done
    [ -n "$got" ] || { exec 9>"/tmp/s4e-run-slots/slot$(( $$ % nslots ))"; flock 9; }
    export S4E_RUN_SLOT_HELD=1
fi
m3p=0; m4p=0; n=0; reds=""
for w in $wits; do
    n=$((n + 1)); src="$WD/$w.pl"; ref="$WD/$w.ref"; o="$OUT/step$step/$w"
    [ -f "$src" ] && [ -f "$ref" ] || refuse "witness $w has no .pl or .ref in $WD"
    ( cd "$WD" && SCRIP_ZD_RTCHECK=1 timeout -k 5 120 "$SC/scrip" "$w.pl" < /dev/null > "$o.m3.out" 2> "$o.m3.err" ); rc=$?
    if [ "$rc" = 0 ] && cmp -s "$o.m3.out" "$ref"; then m3p=$((m3p + 1)); else reds="$reds m3:$w(rc$rc$( [ "$rc" = 132 ] && echo ,depth-check ))"; fi
    if ( cd "$WD" && SCRIP_ZD_RTCHECK=1 timeout -k 5 300 "$SC/scrip" --compile -o "$o.s" "$w.pl" < /dev/null > /dev/null 2> "$o.m4c.err" ) \
       && gcc -c "$o.s" -o "$o.o" 2> /dev/null && gcc "$o.o" -L"$SC/out" -lscrip_rt -lm -Wl,-rpath,"$SC/out" -o "$o.bin" 2> /dev/null; then
        ( cd "$WD" && SCRIP_ZD_RTCHECK=1 timeout -k 5 120 "$o.bin" < /dev/null > "$o.m4.out" 2> "$o.m4.err" ); rc=$?
        if [ "$rc" = 0 ] && cmp -s "$o.m4.out" "$ref"; then m4p=$((m4p + 1)); else reds="$reds m4:$w(rc$rc$( [ "$rc" = 132 ] && echo ,depth-check ))"; fi
    else reds="$reds m4:$w(no-build)"; fi
done
# THE SHIPPED BEHAVIOUR (hq_prolog 2026-10-28): the RTCHECK run above is a diagnostic, and a witness that traps there can still answer as swipl in the binary the coo grades. Every witness also runs PLAIN, both modes, and a plain red is a
# regression or a defect of the shipped build whatever the probe says (LIFO step 2 once landed with the two clpfd witnesses segfaulting plain while the parent ran them EQUAL: a baseline taken only under RTCHECK read that as unchanged).
q3=0; q4=0; preds=""
for w in $wits; do
    src="$WD/$w.pl"; ref="$WD/$w.ref"; o="$OUT/step$step/$w.plain"
    ( cd "$WD" && timeout -k 5 120 "$SC/scrip" "$w.pl" < /dev/null > "$o.m3.out" 2> "$o.m3.err" ); rc=$?
    if [ "$rc" = 0 ] && cmp -s "$o.m3.out" "$ref"; then q3=$((q3 + 1)); else preds="$preds plain-m3:$w(rc$rc)"; fi
    if ( cd "$WD" && timeout -k 5 300 "$SC/scrip" --compile -o "$o.s" "$w.pl" < /dev/null > /dev/null 2> "$o.m4c.err" ) \
       && gcc -c "$o.s" -o "$o.o" 2> /dev/null && gcc "$o.o" -L"$SC/out" -lscrip_rt -lm -Wl,-rpath,"$SC/out" -o "$o.bin" 2> /dev/null; then
        ( cd "$WD" && timeout -k 5 120 "$o.bin" < /dev/null > "$o.m4.out" 2> "$o.m4.err" ); rc=$?
        if [ "$rc" = 0 ] && cmp -s "$o.m4.out" "$ref"; then q4=$((q4 + 1)); else preds="$preds plain-m4:$w(rc$rc)"; fi
    else preds="$preds plain-m4:$w(no-build)"; fi
done
rm -f "$OUT/step$step"/*.plain.s "$OUT/step$step"/*.plain.o
sfiles=$(ls "$OUT/step$step"/*.s 2>/dev/null)
srcs=""; for w in $wits; do srcs="$srcs $WD/$w.pl"; done
census_class() {   # $1 class, $2 kind or '' -> the count over the witnesses' whole compiles (the prelude included)
    ( cd "$SC" && env -u S4E_HOME python3 "$HERE/util_bb_placement_census.py" --files $srcs ) 2> /dev/null \
      | awk -v c="$1" -v k="$2" '/^BB_HOSTS_RBP_KIND prolog / { cls=""; kind=""; cnt=0; for (i = 3; i <= NF; i++) { split($i, a, "="); if (a[1] == "class") cls = a[2]; if (a[1] == "kind") kind = a[2]; if (a[1] == "count") cnt = a[2] } if (cls == c && (k == "" || kind == k)) s += cnt } END { print s + 0 }'
}
pv=""; pr=RED
case "$probe" in
    beta-reset)
        if [ -n "$sfiles" ]; then cl="$(python3 "$HERE/util_rsp_reset_by_port_census.py" $sfiles | grep '^RSP_RESET functions=')"; b="$(echo "$cl" | grep -o 'beta=[0-9]*' | cut -d= -f2)"; [ -n "$cl" ] && b="${b:-0}"; pv="beta-resets=${b:-?}"; [ "${b:-1}" = 0 ] && pr=GREEN; else pv="no .s"; pr=REFUSED; fi ;;
    one-decider)
        t=0; for f in "$SC"/src/planner/*.c "$SC"/src/planner/*.cpp "$SC"/src/planner/*.h; do c="$(grep -c 'planner_pl_indef0\|planner_pl_definite\|SCRIP_PL_DEFCMP' "$f" 2>/dev/null)"; t=$((t + ${c:-0})); done
        pv="predictor-names=$t"; [ "$t" = 0 ] && pr=GREEN ;;
    gate-record)
        c="$(census_class construct-record GATE)"; pv="construct-record(GATE)=$c"; [ "$c" = 0 ] && pr=GREEN ;;
    bound-record)
        c="$(census_class record-across-excursion '')"; l=0; [ -n "$sfiles" ] && l="$(grep -c -E 'mov +rsp, qword ptr \[rbp' $sfiles | awk -F: '{s += $2} END {print s + 0}')"
        pv="record-across-excursion=$c rsp-loads-from-frame=$l"; [ "$c" = 0 ] && [ "$l" = 0 ] && pr=GREEN ;;
    operand-edge)
        c="$(census_class operand-across-retaining-edge '')"; pv="operand-across-retaining-edge=$c"; [ "$c" = 0 ] && pr=GREEN ;;
    retry-note)
        l=0; [ -n "$sfiles" ] && l="$(grep -c 'a clause retry starts at the frame base' $sfiles | awk -F: '{s += $2} END {print s + 0}')"; pv="clause-retry-resets=$l"; [ "$l" = 0 ] && pr=GREEN ;;
    finish)
        pr=GREEN; pv=""
        for g in "test_gate_no_rsp_reset_at_beta.sh --lang prolog" "util_pl_rbp_operand_classes.sh --at-most 11" "test_gate_no_spine_preallocation.sh --lang prolog" "test_smoke_prolog.sh"; do
            s="${g%% *}"; ( cd "$SC" && bash "$HERE/$g" > "$OUT/step7_${s%.sh}.log" 2>&1 ); rc=$?
            pv="$pv $s=rc$rc"; [ "$rc" = 0 ] || pr=RED
        done ;;
    *) refuse "step $step names a probe this harness does not grade: $probe" ;;
esac
wit=GREEN; [ "$m3p" = "$n" ] && [ "$m4p" = "$n" ] || wit=RED
[ "$q3" = "$n" ] && [ "$q4" = "$n" ] || wit=RED
verdict=GREEN; { [ "$wit" = RED ] || [ "$pr" = RED ]; } && verdict=RED; [ "$pr" = REFUSED ] && [ "$wit" = GREEN ] && verdict=REFUSED
echo "STEP $step $slug: m3=$m3p/$n m4=$m4p/$n plain=$q3/$n,$q4/$n probe=$pv${reds:+ reds:$reds}${preds:+ PLAIN-REDS:$preds} -> $verdict"
case "$verdict" in GREEN) exit 0 ;; RED) exit 1 ;; *) exit 2 ;; esac
