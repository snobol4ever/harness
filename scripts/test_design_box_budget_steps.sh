#!/usr/bin/env bash
# test_design_box_budget_steps.sh -- THE STEP-THROUGH HARNESS of DESIGN-PLAN: box-budget (the cto, 2026-11-04, CTO-474/475/478; the design text
# in .github/skills/shared-box/SKILL.md's DESIGN section). The plan is corpus/tests/shared/box_budget/STEPS.tsv. A step's measurement is its PROBE,
# one bash command run from S4E_HOME against the live ledgers and instruments, so a step reads RED until its instrument exists and GREEN only while
# the box meets it (a DONE-WHEN a deletion satisfies is false, R-1386).
#   --list       print the steps and run nothing
#   --step N     run step N's probe (600 s budget)
#   --probe N    the same (the plan has no witness programs; its witnesses are the ledgers)
# VERDICT: STEP N <slug>: probe rc=<rc> -> GREEN|RED|REFUSED; rc 0 GREEN, 1 RED, 2 could not measure.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
STEPS="$S4E/corpus/tests/shared/box_budget/STEPS.tsv"
refuse() { echo "REFUSE(2) [test_design_box_budget_steps]: $*" >&2; exit 2; }
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
    echo "DESIGN-PLAN: box-budget -- $(awk -F'\t' '!/^#/ && $1 != "step" && NF >= 5' "$STEPS" | wc -l) steps (STEPS.tsv); the witnesses are the ledgers each probe reads"
    printf '%-4s %-50s %-8s %-14s %s\n' step slug executor depends probe
    awk -F'\t' '!/^#/ && $1 != "step" && NF >= 5 {printf "%-4s %-50s %-8s %-14s %s\n", $1, $2, $3, $4, substr($5, 1, 70)}' "$STEPS"
    exit 0
fi
slug="$(col "$step" 2)"; probe="$(col "$step" 5)"
[ -n "$slug" ] || refuse "no step $step in $STEPS"
cd "$S4E" || refuse "cannot enter $S4E"
out="$(mktemp "${TMPDIR:-/tmp}/s4e_box_budget_step.XXXXXX")"
timeout -k 5 600 bash -c "$probe" > "$out" 2>&1; rc=$?
tail -5 "$out" | sed 's/^/    /'; rm -f "$out"
case "$rc" in 0) v=GREEN; ec=0 ;; 124|137) v="REFUSED (the probe ran past its 600 s budget)"; ec=2 ;; *) v=RED; ec=1 ;; esac
echo "VERDICT: STEP $step $slug: probe rc=$rc -> $v"
exit $ec
