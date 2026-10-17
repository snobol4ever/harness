#!/usr/bin/env bash
# util_pl_zd_arm_census.sh — THE PROLOG ζ-ADMISSION CENSUS (PZ-0(c), GOAL-PROLOG-100).
#
# Answers the conversion's denominator question: of every ZD run in every Prolog graph, how many
# are ARMED (ride the ζ spine) and how many are REFUSED — and for the refused, WHICH IR KIND
# refused them.  A ZD run is all-or-nothing (s163: the unlock set is five kinds, all-or-nothing
# per run), so the refusing kind is the load-bearing fact: it names the next admission arm to
# write, and the per-kind rollup is the conversion ladder's progress meter.
#
#   bash ../harness/scripts/util_pl_zd_arm_census.sh [--arm default|cells|both] [--jobs N] [file.pl ...]
#
# Default corpus: corpus/tests/prolog/*.pl + corpus/benchmarks/prolog/bench/*.pl.
# Read the table as CANDIDATES, not verdicts: a kind at the top of the refusal table is where the
# next PZ rung goes.  ⛔ FALSIFY BY INJECTION before believing a zero (run one program you know
# refuses and confirm it appears).  Compile-only sweep — programs are never executed.
set -uo pipefail
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SCRIP="${SCRIP:-$S4E/SCRIP/scrip}"
ARM=both; JOBS=3; FILES=()
while [ $# -gt 0 ]; do
    case "$1" in
        --arm)  ARM="$2"; shift 2 ;;
        --jobs) JOBS="$2"; shift 2 ;;
        *)      FILES+=("$1"); shift ;;
    esac
done
if [ ${#FILES[@]} -eq 0 ]; then
    mapfile -t FILES < <(ls "$S4E"/corpus/tests/prolog/*.pl "$S4E"/corpus/benchmarks/prolog/bench/*.pl 2>/dev/null)
fi
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
census_arm() {
    local armname="$1"
    local env_pfx="$2"
    local out="$TMP/$armname"
    printf '%s\n' "${FILES[@]}" | xargs -P "$JOBS" -I{} env $env_pfx SCRIP_ZD_DIAG=1 timeout -k 5 20 "$SCRIP" --compile {} -o /dev/null 2>>"$out" >/dev/null
    local armed refused
    # ⛔ THE COUNTER TRAP (measured PZ-0(c), 2026-08-21): "[ZD] run ... REFUSED" is the ONLY line a
    # refused run prints, and an ARMED run prints NO "run" line at all -- it prints one
    # "[ZD] h=.. r=.. i=.." line PER NODE.  Counting '^\[ZD\] run' therefore counts refusals and
    # calling the remainder ARMED yields a STRUCTURAL ZERO that looks like a measurement.  Armed
    # runs are counted at their FIRST node (r=0); falsify with --falsify before believing any zero.
    armed=$(grep -c '^\[ZD\] h=[0-9-]* r=0 ' "$out" 2>/dev/null) || armed=0
    refused=$(grep -c 'REFUSED' "$out" 2>/dev/null) || refused=0
    echo ""
    echo "=== ARM: $armname  (programs=${#FILES[@]}) ==="
    echo "ZD runs: ARMED=$armed  REFUSED=$refused  (total=$((armed + refused)))"
    echo "--- refusal attribution (kind → runs refused) ---"
    grep -o 'REFUSED at i=[0-9]* ([A-Z_]* op=[0-9]*)' "$out" 2>/dev/null \
        | sed 's/.*(\([A-Z_]*\) op=\([0-9]*\))/\1 (op=\2)/' | sort | uniq -c | sort -rn
    echo "--- refusal position (i= where the run died) ---"
    grep -o 'REFUSED at i=[0-9]*' "$out" 2>/dev/null | sort -t= -k2 -n | uniq -c | head -8
}
[ "$ARM" = default ] || [ "$ARM" = both ] && census_arm default ""
[ "$ARM" = cells ]   || [ "$ARM" = both ] && census_arm cells "SCRIP_PL_CELLS=1"
echo ""
echo "(ARMED = runs that reached the ζ spine.  A kind at the top of the refusal table is the next admission arm — PZ ladder.)"
