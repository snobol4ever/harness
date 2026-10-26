#!/usr/bin/env bash
# test_gate_planner_objects_leave_no_emitter_symbol_undefined.sh [--list] [--at-most N] -- THE PLANNER IS A STAGE THAT LINKS WITHOUT THE EMITTER (ARCH-THREE-ZETAS-EMISSION 8 chunk 1,
# "the planner reads no emitter state"; CEO-1990; the ceo's ruling of 2026-10-26 14:0x CDT that this reading, not the token census, is the row's finish line).
# util_emitter_memory_model_census.py counts the TOKENS g_emit_cfg, g_emit. and g_emitter. in src/planner, and the planner went on reading the emitter's state through the
# emitter's FUNCTIONS (fence0_release_bytes read g_emit_cfg from inside the depth plan; once the planner ran before emission that was NULL and the plan's release was 0, so the
# omega path of a SPAN-then-FENCE pattern released 16 bytes too many: SCRIP cde9bfc80, cured at a11ed1ed8). The link is the honest measure: every object compiled from src/planner/
# is read with nm, its undefined symbols are intersected with the symbols DEFINED by the objects compiled from src/emitter/ and src/templates/, and each hit is one planner
# dependence on the emitter (a function it calls or a datum it reads). A hit moves to src/planner, or to a neutral header the two share, or the planner is handed its value.
#   --list        print each hit with the emitter object that defines it and the planner objects that need it (default prints only the count line)
#   --at-most N   the bar (default 0): rc 1 when the count is above it
# rc 0 the count is at most the bar · rc 1 above it · rc 2 could not measure (no objects built from this tree, an unreadable source dir, a stale binary).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
SC="$ROOT/SCRIP"
LIST=0; BAR=0
while [ $# -gt 0 ]; do
    case "$1" in
        --list) LIST=1 ;;
        --at-most) shift; BAR="${1:-}"; case "$BAR" in ''|*[!0-9]*) echo "REFUSE(2): --at-most needs a number"; exit 2 ;; esac ;;
        *) echo "REFUSE(2): unknown argument $1"; exit 2 ;;
    esac
    shift
done
for d in src/planner src/emitter src/templates; do [ -d "$SC/$d" ] || { echo "REFUSE(2): no $SC/$d"; exit 2; }; done
"$HERE/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
command -v nm >/dev/null 2>&1 || { echo "REFUSE(2): no nm"; exit 2; }
OBJDIR=$(cd "$SC" && make -s buildinfo 2>/dev/null | sed -n 's/^RT_OBJDIR  *: *\([^ ]*\).*/\1/p' | head -1)
[ -n "$OBJDIR" ] || { echo "REFUSE(2): make buildinfo names no RT_OBJDIR"; exit 2; }
case "$OBJDIR" in /*) ;; *) OBJDIR="$SC/$OBJDIR" ;; esac
[ -d "$OBJDIR" ] || { echo "REFUSE(2): no object directory $OBJDIR"; exit 2; }
TMP=$(mktemp -d "${TMPDIR:-/tmp}/s4e-plink.XXXXXX") || exit 2
trap 'rm -rf "$TMP"' EXIT
objs_of() { local dir="$1" f b; shift; for f in $(find "$SC/$dir" -type f \( -name '*.c' -o -name '*.cpp' \) | sort); do b=$(basename "$f"); b="${b%.*}"; [ -f "$OBJDIR/$b.o" ] && echo "$OBJDIR/$b.o"; done; }
objs_of src/planner > "$TMP/planner.objs"
{ objs_of src/emitter; objs_of src/templates; } | sort -u > "$TMP/emitter.objs"
np=$(wc -l < "$TMP/planner.objs"); ne=$(wc -l < "$TMP/emitter.objs")
[ "$np" -ge 5 ] || { echo "REFUSE(2): only $np planner objects found under $OBJDIR (build first: make)"; exit 2; }
[ "$ne" -ge 20 ] || { echo "REFUSE(2): only $ne emitter and template objects found under $OBJDIR (build first: make)"; exit 2; }
while read -r o; do nm -u "$o" 2>/dev/null | awk -v o="$(basename "$o")" 'NF == 2 && $1 == "U" {print $2 "\t" o}'; done < "$TMP/planner.objs" | sort -u > "$TMP/need.tsv"
while read -r o; do nm --defined-only "$o" 2>/dev/null | awk -v o="$(basename "$o")" 'NF == 3 && $2 ~ /^[TDBRVWSG]$/ {print $3 "\t" o}'; done < "$TMP/emitter.objs" | sort -u > "$TMP/def.tsv"
while read -r o; do nm --defined-only "$o" 2>/dev/null | awk 'NF == 3 && $2 ~ /^[TDBRVW]$/ {print $3}'; done < "$TMP/planner.objs" | sort -u > "$TMP/own.txt"
awk -F'\t' 'NR == FNR {def[$1] = def[$1] (def[$1] ? "," : "") $2; next} ($1 in def) {need[$1] = need[$1] (need[$1] ? "," : "") $2; dby[$1] = def[$1]} END {for (s in need) print s "\t" dby[s] "\t" need[s]}' "$TMP/def.tsv" "$TMP/need.tsv" | sort > "$TMP/hits.tsv"
awk -F'\t' 'NR == FNR {own[$1] = 1; next} !($1 in own)' "$TMP/own.txt" "$TMP/hits.tsv" > "$TMP/hits2.tsv"
N=$(wc -l < "$TMP/hits2.tsv")
echo "PLANNER_LINK emitter_symbols=$N bar=$BAR planner_objects=$np emitter_objects=$ne objdir=$(basename "$OBJDIR")"
if [ "$LIST" = 1 ] || [ "$N" -gt "$BAR" ]; then
    while IFS=$'\t' read -r s d n; do printf '  %-40s defined in %-28s needed by %s\n' "$(echo "$s" | c++filt)" "$d" "$n"; done < "$TMP/hits2.tsv"
fi
[ "$N" -le "$BAR" ] && exit 0
exit 1
