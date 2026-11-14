#!/usr/bin/env bash
# test_design_test_cycle_steps.sh -- THE STEP-THROUGH HARNESS of DESIGN-PLAN: test-cycle (the cto, 2026-11-05, CTO-522; Lon: "We must speed up the test
# suite runs by 10x." / "CTO is to complete redesign the test suite CYCLE loops."; the design text in .github/skills/suites-and-grading/SKILL.md section 7).
# The plan is harness/designs/test_cycle/STEPS.tsv; BASELINE.tsv beside it is the measured baseline the acceptance reads. A step's measurement is its PROBE,
# one bash command run from S4E_HOME, so a step reads RED until its instrument exists and GREEN only while the ledgers say so. This plan has no oracle witnesses:
# its probes read instruments, ledgers and instruction counts; --cut therefore cuts nothing and says so.
#   --list       print the steps and run nothing
#   --step N     run step N's probe (600 s budget; S4E_SEAT names the seat whose /tmp/s4e/<seat> the probe writes under)
# VERDICT: STEP N <slug>: probe rc=<rc> -> GREEN|RED|REFUSED; rc 0 GREEN, 1 RED, 2 could not measure.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib_one_runner.sh" && one_runner_mem_scope   # THE MEMORY DOOR (the cio 2026-11-10 12:3x): a witness at its declared heap runs in its own board scope, never in a seat's
S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
. "$HERE/lib_paths.sh"
WD="$HERE/../designs/test_cycle"; STEPS="$WD/STEPS.tsv"
refuse() { echo "REFUSE(2) [test_design_test_cycle_steps]: $*" >&2; exit 2; }
[ -f "$STEPS" ] || refuse "no step table at $STEPS"
mode=""; step=""
while [ $# -gt 0 ]; do
    case "$1" in
        --list) mode=list; shift ;;
        --step|--probe) mode=step; step="${2:-}"; [ -n "$step" ] || refuse "$1 takes a number"; shift 2 ;;
        --cut) mode=cut; shift ;;
        *) refuse "usage: $0 --list | --step N | --cut" ;;
    esac
done
[ -n "$mode" ] || refuse "usage: $0 --list | --step N | --cut"
col() { awk -F'\t' -v n="$1" -v k="$2" '!/^#/ && $1 == n {print $k; exit}' "$STEPS"; }
if [ "$mode" = list ]; then
    echo "DESIGN-PLAN: test-cycle -- $(awk -F'\t' '!/^#/ && $1 != "step" && NF >= 6' "$STEPS" | wc -l) steps (STEPS.tsv); witnesses in $WD"
    printf '%-4s %-120s %-8s %-10s %s\n' step slug executor depends depends_on_plans
    awk -F'\t' '!/^#/ && $1 != "step" && NF >= 6 {printf "%-4s %-120s %-8s %-10s %s\n", $1, $2, $3, $4, $6}' "$STEPS"
    exit 0
fi
if [ "$mode" = cut ]; then echo "test-cycle has no oracle witnesses: nothing to cut (its probes read instruments and ledgers)"; exit 0; fi
slug="$(col "$step" 2)"; probe="$(col "$step" 5)"
[ -n "$slug" ] || refuse "no step $step in $STEPS"
cd "$S4E" || refuse "cannot enter $S4E"
case "$probe" in *SCRIP/scrip*) [ -n "${SCRIP_BIN:-}" ] || bash "$HERE/util_require_fresh.sh" --gate test_design_test_cycle_steps "$S4E_SCRIP/scrip" "$S4E_SCRIP/out/libscrip_rt.so" || exit 2 ;; esac
mkdir -p "/tmp/s4e/${S4E_SEAT:-coo}"
out="$(mktemp "${TMPDIR:-/tmp}/s4e_batch_grader_step.XXXXXX")"
S4E_HOME="$S4E" timeout -k 5 600 bash -c "$probe" > "$out" 2>&1; rc=$?
tail -5 "$out" | sed 's/^/    /'; refused=0; grep -q 'REFUSE(2)' "$out" && refused=1; rm -f "$out"
case "$rc" in 0) v=GREEN; ec=0 ;; 124|137) v="REFUSED (the probe ran past its 600 s budget)"; ec=2 ;; 2) if [ "$refused" = 1 ]; then v="REFUSED (could not measure)"; ec=2; else v="RED (the probe exited 2 without its own REFUSE(2): scrip refused a switch it does not have yet, or cmp found no output file -- the lines above say which)"; ec=1; fi ;; *) v=RED; ec=1 ;; esac
echo "VERDICT: STEP $step $slug: probe rc=$rc -> $v"
exit $ec
