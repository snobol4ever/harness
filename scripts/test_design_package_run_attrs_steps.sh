#!/usr/bin/env bash
# test_design_package_run_attrs_steps.sh -- THE STEP-THROUGH HARNESS of DESIGN-PLAN: package-run-attrs (CIO-132, the cio's design 2026-11-11, cut by officer_05
# 2026-11-11; the design text is the header of the step table). The plan is harness/designs/package_run_attrs/STEPS.tsv. A step's measurement is its PROBE,
# one bash command run from S4E_HOME, harness/scripts/s4e_probe_package_run_attrs.sh N, which works on a scratch copy of corpus/packages/icon/ipl, so a step
# reads RED until its reader, applier, cut, census or util does what CIO-132 says and GREEN only while it does (a DONE-WHEN a deletion satisfies is false, R-1386).
#   --list       print the steps and run nothing
#   --step N     run step N's probe (900 s budget)
#   --probe N    the same (the plan has no witness programs; its witnesses are scratch copies of the package)
# VERDICT: STEP N <slug>: probe rc=<rc> -> GREEN|RED|REFUSED; rc 0 GREEN, 1 RED, 2 could not measure.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib_one_runner.sh" && one_runner_mem_scope   # THE MEMORY DOOR (the cio 2026-11-10 12:3x): a witness at its declared heap runs in its own board scope, never in a seat's
S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
STEPS="$HERE/../designs/package_run_attrs/STEPS.tsv"
refuse() { echo "REFUSE(2) [test_design_package_run_attrs_steps]: $*" >&2; exit 2; }
[ -f "$STEPS" ] || refuse "no step table at $STEPS"
mode=""; step=""
while [ $# -gt 0 ]; do
    case "$1" in
        --list) mode=list; shift ;;
        --step|--probe) mode=step; step="${2:-}"; [ -n "$step" ] || refuse "$1 takes a number"; shift 2 ;;
        *) refuse "usage: $0 --list | --step N | --probe N" ;;
    esac
done
[ -n "$mode" ] || refuse "usage: $0 --list | --step N | --probe N"
col() { awk -F'\t' -v n="$1" -v k="$2" '!/^#/ && $1 == n {print $k; exit}' "$STEPS"; }
if [ "$mode" = list ]; then
    echo "DESIGN-PLAN: package-run-attrs -- $(awk -F'\t' '!/^#/ && $1 != "step" && NF >= 5' "$STEPS" | wc -l) steps (STEPS.tsv); the witnesses are scratch copies of the package each probe builds"
    printf '%-4s %-50s %-8s %-14s %s\n' step slug executor depends probe
    awk -F'\t' '!/^#/ && $1 != "step" && NF >= 5 {printf "%-4s %-50s %-8s %-14s %s\n", $1, $2, $3, $4, substr($5, 1, 70)}' "$STEPS"
    exit 0
fi
slug="$(col "$step" 2)"; probe="$(col "$step" 5)"
[ -n "$slug" ] || refuse "no step $step in $STEPS"
cd "$S4E" || refuse "cannot enter $S4E"
out="$(mktemp "${TMPDIR:-/tmp}/s4e_package_run_attrs_step.XXXXXX")"
timeout -k 5 900 bash -c "$probe" > "$out" 2>&1; rc=$?
tail -5 "$out" | sed 's/^/    /'; rm -f "$out"
case "$rc" in 0) v=GREEN; ec=0 ;; 124|137) v="REFUSED (the probe ran past its 900 s budget)"; ec=2 ;; *) v=RED; ec=1 ;; esac
echo "VERDICT: STEP $step $slug: probe rc=$rc -> $v"
exit $ec
