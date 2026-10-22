#!/usr/bin/env bash
# util_planner_pass_census.sh -- THE PLANNER PASS COVERS EVERY CHAIN (ARCH-ZETA-ONE-COORDINATE 3.2, the planner stage; the cto, CEO-1895).
# Compiles every program of util_spine_population.sh with SCRIP_PLANNER_REPORT=1 in mode 4 (--compile) and runs it in mode 3 (--run, stdin
# closed, 20 s), counting the [PLANNER-FALLBACK] lines the emitter prints when a chain reaches emission with no record from the planner's pass.
#   util_planner_pass_census.sh [--lang L] [--scrip PATH]      (--scrip: grade another built tree's binary, for a two-tree proof)
# Prints PLANNER_PASS lang=<l>|total programs=<p> m4_fallbacks=<n> m3_fallbacks=<m> m3_rc_nonzero=<k> m4_unreported=<u>; rc 0 when m4_fallbacks is 0
# everywhere, rc 1 otherwise, rc 2 when it could not measure (a compile that prints no [PLANNER-PASS] summary is a binary without the pass report, never a
# green). A mode-3 fallback is reported, not graded, until the run-time compile roads join the pass.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
SCRIP="$ROOT/SCRIP/scrip"
L=""
while [ $# -gt 0 ]; do case "$1" in --lang) L="$2"; shift 2;; --scrip) SCRIP="$2"; shift 2;; *) echo "usage: util_planner_pass_census.sh [--lang L] [--scrip PATH]" >&2; exit 2;; esac; done
[ -x "$SCRIP" ] || { echo "REFUSE(2): no binary at $SCRIP"; exit 2; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
bash "$HERE/util_spine_population.sh" --corpus "$ROOT/corpus" ${L:+--lang "$L"} > "$T/pop" || { echo "REFUSE(2): no population"; exit 2; }
[ -s "$T/pop" ] || { echo "REFUSE(2): the population is empty${L:+ for $L}"; exit 2; }
declare -A P4 F4 F3 K3 U4
while IFS=$'\t' read -r lang f; do
    [ -n "$f" ] || continue
    t=""; [ "$lang" = prolog ] && t="--target=x86"
    (cd "$(dirname "$f")" && SCRIP_PLANNER_REPORT=1 timeout 300 "$SCRIP" --compile $t -o /dev/null "$(basename "$f")" < /dev/null 2> "$T/e4" >/dev/null)
    n4=$(grep -c '^\[PLANNER-FALLBACK\]' "$T/e4"); grep -q '^\[PLANNER-PASS\]' "$T/e4" || U4[$lang]=$(( ${U4[$lang]:-0} + 1 ))
    (cd "$(dirname "$f")" && SCRIP_PLANNER_REPORT=1 timeout 20 "$SCRIP" "$(basename "$f")" < /dev/null > /dev/null 2> "$T/e3"); r3=$?
    n3=$(grep -c '^\[PLANNER-FALLBACK\]' "$T/e3")
    P4[$lang]=$(( ${P4[$lang]:-0} + 1 )); F4[$lang]=$(( ${F4[$lang]:-0} + n4 )); F3[$lang]=$(( ${F3[$lang]:-0} + n3 )); [ "$r3" = 0 ] || K3[$lang]=$(( ${K3[$lang]:-0} + 1 ))
done < "$T/pop"
tp=0; t4=0; t3=0; tk=0; tu=0
for l in $(printf '%s\n' "${!P4[@]}" | sort); do
    echo "PLANNER_PASS lang=$l programs=${P4[$l]} m4_fallbacks=${F4[$l]:-0} m3_fallbacks=${F3[$l]:-0} m3_rc_nonzero=${K3[$l]:-0} m4_unreported=${U4[$l]:-0}"
    tp=$((tp + P4[$l])); t4=$((t4 + ${F4[$l]:-0})); t3=$((t3 + ${F3[$l]:-0})); tk=$((tk + ${K3[$l]:-0})); tu=$((tu + ${U4[$l]:-0}))
done
echo "PLANNER_PASS total programs=$tp m4_fallbacks=$t4 m3_fallbacks=$t3 m3_rc_nonzero=$tk m4_unreported=$tu (binary $SCRIP, tree $(git -C "$(dirname "$SCRIP")" rev-parse --short HEAD 2>/dev/null))"
[ "$tu" = 0 ] || { echo "REFUSE(2): $tu mode-4 compiles printed no [PLANNER-PASS] line -- this binary carries no planner pass report, so the reading is not a measurement"; exit 2; }
[ "$t4" = 0 ] && exit 0 || exit 1
