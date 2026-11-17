#!/usr/bin/env bash
# test_design_one_container_steps.sh -- the step harness of DESIGN-PLAN one-container (the grader 2026-11-17; table designs/one_container/STEPS.tsv,
# design text skill suites-and-grading section 10). --list prints the table; --step N reads step N's probe: conform=N (util_container_check.py --min N),
# probe=SCRIPT ARGS (that probe, rc 0), check (util_container_check.py --check). rc 0 GREEN, 1 RED, 2 refused.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; T="$HERE/../designs/one_container/STEPS.tsv"
[ -f "$T" ] || { echo "REFUSE(2): no step table $T"; exit 2; }
case "${1:-}" in
    --list) grep -v '^#' "$T" | cut -f1-5; exit 0 ;;
    --step) n="${2:-}"; row="$(awk -F'\t' -v n="$n" '!/^#/ && $1 == n' "$T")"; [ -n "$row" ] || { echo "REFUSE(2): no step $n in $T"; exit 2; }
        p="$(printf '%s' "$row" | cut -f5)"
        case "$p" in
            conform=*) python3 -I "$HERE/util_container_check.py" --min "${p#conform=}" | tail -1; rc=${PIPESTATUS[0]} ;;
            check) python3 -I "$HERE/util_container_check.py" --check | tail -1; rc=${PIPESTATUS[0]} ;;
            probe=*) set -- ${p#probe=}; [ -f "$HERE/$1" ] || { echo "STEP $n RED: its probe script $1 is not built yet"; exit 1; }
                     [ -z "${2:-}" ] || grep -qF -- "$2" "$HERE/$1" || { echo "STEP $n RED: $1 has no $2 yet"; exit 1; }
                     case "$1" in *.py) python3 -I "$HERE/$1" "${@:2}" ;; *) bash "$HERE/$1" "${@:2}" ;; esac; rc=$? ;;
            *) echo "REFUSE(2): step $n has an unknown probe token '$p'"; exit 2 ;;
        esac
        [ "$rc" = 0 ] && echo "STEP $n GREEN" || { [ "$rc" = 2 ] && { echo "STEP $n REFUSED"; exit 2; }; echo "STEP $n RED"; exit 1; } ;;
    *) echo "usage: test_design_one_container_steps.sh --list | --step N"; exit 2 ;;
esac
