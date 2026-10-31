#!/usr/bin/env bash
# test_design_clause_source_record_steps.sh -- THE STEP-THROUGH HARNESS of DESIGN-PLAN: consulted-clause-source-record (the cto, 2026-10-31, CEO-2064/2065;
# .github/ARCH-PROLOG-DATABASE.md section 23). The plan is corpus/tests/prolog/clause_source_record/STEPS.tsv; the witnesses are the csr_*.pl beside it,
# each with a .ref cut from swipl 9.0.4 (-q -t halt, twice), the one SWI-dialect oracle (CEO-1603); csr_consulted_lib.pl is data the consult witness loads.
#
#   --list         print the steps and run nothing
#   --step N       grade step N: every witness of the step in mode 3 (./scrip w.pl) and mode 4 (--compile, gcc, run), from the witness folder,
#                  byte-equal to its .ref with rc 0; probe 'witnesses' is green when every witness passes both modes
#   --with-smoke   on the finish step (probe 'finish') also run test_smoke_prolog.sh, the lander smoke of CEO-1928 (the cqo's to run, never a board)
#   --out DIR      where the .s, binaries and logs go (default /tmp/s4e-design-clause-source-record: never under the root, Lon 2026-10-29/31)
#
# VERDICT: STEP N <slug>: m3=<pass>/<n> m4=<pass>/<n> probe=<reading> -> GREEN|RED|REFUSED; rc 0 GREEN, 1 RED, 2 could not measure (no ./scrip,
# no witness, no ref). It grades no corpus population: a witness folder is not a suite (CEO-1342).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
SC="$ROOT/SCRIP"
WD="$ROOT/corpus/tests/prolog/clause_source_record"
STEPS="$WD/STEPS.tsv"
OUT="/tmp/s4e-design-clause-source-record"
refuse() { echo "REFUSE(2): $*" >&2; exit 2; }
[ -f "$STEPS" ] || refuse "no step table at $STEPS"
mode=""; step=""; smoke=0
while [ $# -gt 0 ]; do
    case "$1" in
        --list) mode=list; shift ;;
        --step) mode=step; step="${2:-}"; [ -n "$step" ] || refuse "--step takes a number"; shift 2 ;;
        --with-smoke) smoke=1; shift ;;
        --out) OUT="${2:-}"; shift 2 ;;
        *) refuse "usage: $0 --list | --step N [--with-smoke] [--out DIR]" ;;
    esac
done
[ -n "$mode" ] || refuse "usage: $0 --list | --step N [--with-smoke] [--out DIR]"
col() { awk -F'\t' -v n="$1" -v k="$2" '!/^#/ && $1 == n {print $k; exit}' "$STEPS"; }
if [ "$mode" = list ]; then
    echo "DESIGN-PLAN: consulted-clause-source-record -- $(awk -F'\t' '!/^#/ && $1 != "step" && NF > 1' "$STEPS" | wc -l) steps (STEPS.tsv); witnesses in $WD"
    printf '%-4s %-22s %-8s %-10s %s\n' step slug executor probe witnesses
    for n in $(awk -F'\t' '!/^#/ && $1 != "step" && NF > 1 {print $1}' "$STEPS"); do
        printf '%-4s %-22s %-8s %-10s %s\n' "$n" "$(col "$n" 2)" "$(col "$n" 3)" "$(col "$n" 4)" "$(col "$n" 5)"
    done
    exit 0
fi
[ -n "$(col "$step" 1)" ] || refuse "no step $step in $STEPS (--list names them)"
slug="$(col "$step" 2)"; probe="$(col "$step" 4)"; wits="$(col "$step" 5)"
[ -x "$SC/scrip" ] || refuse "no $SC/scrip"
[ -n "$wits" ] || refuse "step $step names no witnesses"
mkdir -p "$OUT/step$step"
if [ -z "${S4E_RUN_SLOT_HELD:-}" ]; then
    nslots="${S4E_RUN_SLOTS:-8}"; slotdir_="${S4E_RUN_SLOT_DIR:-/tmp/s4e-run-slots}"; mkdir -p "$slotdir_"; got=""
    while [ -z "$got" ]; do
        for i in $(seq 0 $((nslots - 1))); do exec 9>"$slotdir_/slot$i"; flock -n 9 && { got=$i; break; }; done
        [ -n "$got" ] || sleep 0.5
    done
    export S4E_RUN_SLOT_HELD=1
fi
m3p=0; m4p=0; n=0; reds=""
for w in $wits; do
    n=$((n + 1)); src="$WD/$w.pl"; ref="$WD/$w.ref"; o="$OUT/step$step/$w"
    [ -f "$src" ] && [ -f "$ref" ] || refuse "witness $w has no .pl or .ref in $WD"
    ( cd "$WD" && timeout -k 5 60 "$SC/scrip" "$w.pl" < /dev/null > "$o.m3.out" 2> "$o.m3.err" ); rc=$?
    if [ "$rc" = 0 ] && cmp -s "$o.m3.out" "$ref"; then m3p=$((m3p + 1)); else reds="$reds m3:$w(rc$rc)"; fi
    if ( cd "$WD" && timeout -k 5 120 "$SC/scrip" --compile --out="$o.s" "$w.pl" < /dev/null > /dev/null 2> "$o.m4c.err" ) \
       && gcc -c "$o.s" -o "$o.o" 2> /dev/null && gcc "$o.o" -L"$SC/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$SC/out" -o "$o.bin" 2> /dev/null; then
        ( cd "$WD" && timeout -k 5 60 "$o.bin" < /dev/null > "$o.m4.out" 2> "$o.m4.err" ); rc=$?
        if [ "$rc" = 0 ] && cmp -s "$o.m4.out" "$ref"; then m4p=$((m4p + 1)); else reds="$reds m4:$w(rc$rc)"; fi
    else reds="$reds m4:$w(no-build)"; fi
done
pv="witnesses=$((m3p + m4p))/$((2 * n))"; pr=RED
[ "$m3p" = "$n" ] && [ "$m4p" = "$n" ] && pr=GREEN
if [ "$probe" = finish ] && [ "$smoke" = 1 ]; then
    if S4E_ONE_RUNNER_OVERRIDE="CEO-1928 lander smoke, design clause-source-record step $step" bash "$HERE/test_smoke_prolog.sh" > "$OUT/step$step/smoke_prolog.log" 2>&1; then pv="$pv smoke=green"; else pv="$pv smoke=RED($OUT/step$step/smoke_prolog.log)"; pr=RED; fi
fi
echo "STEP $step $slug: m3=$m3p/$n m4=$m4p/$n probe=$pv -> $pr${reds:+ (reds:$reds)}"
[ "$pr" = GREEN ]
