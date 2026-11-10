#!/usr/bin/env bash
# test_design_run_switches_steps.sh -- THE STEP-THROUGH HARNESS of DESIGN-PLAN: run-switches (the cto, CTO-575, 2026-11-10, with the cio's CIO-59: the
# SCRIP side of the clean-up of the six masters and of corpus/packages; the design text in skill suites-and-grading reference section 8). The plan is
# harness/designs/run_switches/STEPS.tsv; a step's probe is bash harness/scripts/s4e_probe_run_switches.sh N, the whole measurement, run from S4E_HOME.
#   --list       print the steps and run nothing
#   --step N     run step N's probe (900 s budget; S4E_SEAT names the seat whose /tmp/s4e/<seat> the probe writes under)
# VERDICT: STEP N <slug>: probe rc=<rc> -> GREEN|RED|REFUSED; rc 0 GREEN, 1 RED, 2 could not measure (a stale ./scrip refuses before a probe that runs it).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
STEPS="$HERE/../designs/run_switches/STEPS.tsv"
refuse() { echo "REFUSE(2) [test_design_run_switches_steps]: $*" >&2; exit 2; }
[ -f "$STEPS" ] || refuse "no step table at $STEPS"
mode=""; step=""
while [ $# -gt 0 ]; do
    case "$1" in
        --list) mode=list; shift ;;
        --step|--probe) mode=step; step="${2:-}"; [ -n "$step" ] || refuse "$1 takes a number"; shift 2 ;;
        *) refuse "usage: $0 --list | --step N" ;;
    esac
done
[ -n "$mode" ] || refuse "usage: $0 --list | --step N"
col() { awk -F'\t' -v n="$1" -v k="$2" '!/^#/ && $1 == n {print $k; exit}' "$STEPS"; }
if [ "$mode" = list ]; then
    n="$(awk -F'\t' '!/^#/ && $1 != "step" && NF >= 8' "$STEPS" | wc -l)"
    [ "$n" -gt 0 ] || refuse "the step table names no step"
    echo "DESIGN-PLAN: run-switches -- $n steps ($STEPS)"
    printf '%-4s %-125s %-8s %-8s %s\n' step slug executor depends ruling
    awk -F'\t' '!/^#/ && $1 != "step" && NF >= 8 {printf "%-4s %-125s %-8s %-8s %s\n", $1, $2, $3, $4, $7}' "$STEPS"
    exit 0
fi
slug="$(col "$step" 2)"; probe="$(col "$step" 5)"
[ -n "$slug" ] || refuse "no step $step in $STEPS"
cd "$S4E" || refuse "cannot enter $S4E"
case "$step" in 1|3|6|7|8|9|10|11) [ -n "${SCRIP_BIN:-}" ] || bash "$HERE/util_require_fresh.sh" --gate test_design_run_switches_steps "$S4E/SCRIP/scrip" "$S4E/SCRIP/out/libscrip_rt.so" || exit 2 ;; esac
mkdir -p "/tmp/s4e/${S4E_SEAT:-probe}" || refuse "cannot make the scratch directory"
out="$(mktemp "/tmp/s4e/${S4E_SEAT:-probe}/runsw_step.XXXXXX")" || refuse "mktemp failed"
S4E_HOME="$S4E" timeout -k 5 900 bash -c "$probe" > "$out" 2>&1; rc=$?
tail -6 "$out" | sed 's/^/    /'
refused="$(grep -c 'REFUSE(2)' "$out")"; rm -f "$out"
case "$rc" in
    0) v=GREEN; ec=0 ;;
    124|137) v="REFUSED (the probe ran past its 900 s budget)"; ec=2 ;;
    2) if [ "$refused" -gt 0 ]; then v="REFUSED (could not measure)"; ec=2; else v="RED (the probe exited 2 without its own refusal line)"; ec=1; fi ;;
    *) v=RED; ec=1 ;;
esac
echo "VERDICT: STEP $step $slug: probe rc=$rc -> $v"
exit $ec
