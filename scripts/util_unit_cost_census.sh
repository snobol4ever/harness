#!/usr/bin/env bash
# util_unit_cost_census.sh -- THE UNIT COST CENSUS OF DESIGN-PLAN cache-tree (the cto, 2026-11-12, CTO-636; skill scrip-build reference section 4).
# What one compile of each SCRIP translation unit costs, in user-space instructions of the compiler (perf stat -e instructions:u over gcc and its
# children, ccache bypassed), never a wall clock (skill speed-measurement). The compile lines are the Makefile's own (make -B -n build-all), so the
# flags are the build's; each object is written to scratch, never into the tree's out/ or objdir.
#   util_unit_cost_census.sh [--root SCRIP] [--match REGEX] [--out TSV] [--jobs N]
#     --root   the SCRIP checkout (default: $S4E_HOME/SCRIP, else the SCRIP beside this harness)
#     --match  only the units whose path matches the extended regex (default: every C and C++ unit; assembler units are never priced)
#     --out    the TSV to write: source<TAB>instructions<TAB>preprocessed_lines (default: stdout)
#     --jobs   parallel compiles (default 2)
# Prints "UNIT_COST_BOARD units=N priced=N failed=N total_Ginstr=X (tree <hash>)" on stderr. rc 0 every matched unit priced; rc 2 no compile line
# matched, make -n failed, perf is absent, or any unit failed to compile (a census that cannot price a unit does not cover its population).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -n "${S4E_BATCH_HELD:-}" ] || exec bash "$HERE/util_batch.sh" bash "$0" "$@"
. "$HERE/lib_paths.sh"; ROOT="$S4E_SCRIP"
MATCH='\.(c|cc|cpp)$'; OUT=""; JOBS=2
while [ $# -gt 0 ]; do
    case "$1" in
        --root) ROOT="$2"; shift 2 ;;
        --match) MATCH="$2"; shift 2 ;;
        --out) OUT="$2"; shift 2 ;;
        --jobs) JOBS="$2"; shift 2 ;;
        *) echo "REFUSE(2): unknown argument $1" >&2; exit 2 ;;
    esac
done
command -v perf >/dev/null || { echo "REFUSE(2): perf is not on PATH: the census counts instructions" >&2; exit 2; }
[ -f "$ROOT/Makefile" ] || { echo "REFUSE(2): $ROOT is not a SCRIP checkout" >&2; exit 2; }
SEAT="${S4E_SEAT:-$(id -un)}"
W="$(mktemp -d "/tmp/s4e/${SEAT}/unit_cost.XXXXXX" 2>/dev/null || mktemp -d)"
trap 'rm -rf "$W"' EXIT
mkdir -p "$W/obj"
(cd "$ROOT" && make -B -n build-all 2>/dev/null) > "$W/make.n" || { echo "REFUSE(2): make -B -n build-all failed in $ROOT" >&2; exit 2; }
grep -E ' -c ' "$W/make.n" | grep -v 'assembler' | while IFS= read -r line; do
    src=$(grep -oE ' -c [^ ]+' <<<"$line" | awk '{print $2}')
    grep -qE "$MATCH" <<<"$src" && printf '%s\n' "$line"
done | awk '!seen[$0]++' > "$W/cmds"
n=$(grep -c . "$W/cmds")
[ "$n" -gt 0 ] || { echo "REFUSE(2): no compile line matches $MATCH" >&2; exit 2; }
cat > "$W/one.sh" <<'EOF'
line="$1"; i="$2"; root="$3"; w="$4"
src=$(grep -oE ' -c [^ ]+' <<<"$line" | awk '{print $2}')
cmd=$(sed -E "s# -o [^ ]+# -o $w/obj/$i.o#; s/ -MMD -MP//; s/^ccache //" <<<"$line")
ins=$(cd "$root" && eval "CCACHE_DISABLE=1 perf stat -e instructions:u -x, $cmd" 2>&1 >/dev/null | grep 'instructions' | cut -d, -f1)
[ -f "$w/obj/$i.o" ] || ins=FAILED
pp=$(cd "$root" && eval "$(sed -E 's/ -c / -E /; s# -o [^ ]+# -o -#' <<<"$cmd")" 2>/dev/null | wc -l)
printf '%s\t%s\t%s\n' "${src#$root/}" "$ins" "$pp"
EOF
nl -ba "$W/cmds" | while IFS=$'\t' read -r i line; do printf '%s\0%s\0%s\0%s\0' "$line" "$(echo $i)" "$ROOT" "$W"; done | xargs -0 -n4 -P"$JOBS" bash "$W/one.sh" > "$W/cost.tsv"
sort -o "$W/cost.tsv" "$W/cost.tsv"
failed=$(awk -F'\t' '$2 !~ /^[0-9]+$/' "$W/cost.tsv" | wc -l)
priced=$(awk -F'\t' '$2 ~ /^[0-9]+$/' "$W/cost.tsv" | wc -l)
tot=$(awk -F'\t' '$2 ~ /^[0-9]+$/ {s += $2} END {printf "%.1f", s / 1e9}' "$W/cost.tsv")
if [ -n "$OUT" ]; then cp "$W/cost.tsv" "$OUT"; else cat "$W/cost.tsv"; fi
echo "UNIT_COST_BOARD units=$n priced=$priced failed=$failed total_Ginstr=$tot (tree $(git -C "$ROOT" rev-parse --short HEAD))" >&2
[ "$failed" = 0 ] || { awk -F'\t' '$2 !~ /^[0-9]+$/ {print "REFUSE(2): did not compile: " $1}' "$W/cost.tsv" | head -5 >&2; exit 2; }
exit 0
