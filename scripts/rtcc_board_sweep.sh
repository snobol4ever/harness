#!/usr/bin/env bash
# rtcc_board_sweep.sh -- GOAL-RTCC RC-2 crater instrument.
#
# WHY THIS EXISTS.  The CRATER ATTRIBUTION law says a flip rung lands on a board that
# ZETA-MECH may still be recovering, so a raw PASS count compared against a floor recorded
# at another HEAD cannot attribute a regression to RTCC.  This sweep removes the confound
# by construction: it runs the SAME BINARY over the SAME board TWICE, changing only the
# SCRIP_RTCC gate, and diffs the two fail sets BY SET.  Any program that fails ON but
# passes OFF is RTCC's, and nothing else in the tree can be blamed for it.
#
# Usage: bash ../harness/scripts/rtcc_board_sweep.sh [--mode 3|4] [--out DIR]
# Output: <out>/off.txt <out>/on.txt (one "STATUS name" line each) plus a BY-SET diff.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
set -u
MODE=3; OUT=/tmp/rtcc_board; CORPUS=${CORPUS:-$S4E/corpus}
while [ $# -gt 0 ]; do
    case "$1" in
        --mode) MODE="$2"; shift 2;;
        --out)  OUT="$2";  shift 2;;
        *) echo "unknown arg: $1" >&2; exit 2;;
    esac
done
mkdir -p "$OUT"
SCRIP=./scrip
[ -x "$SCRIP" ] || { echo "no ./scrip -- build first" >&2; exit 2; }
if [ "$MODE" = "3" ]; then FLAG=--run; else FLAG=--compile; fi

run_arm() {
    gate="$1"; dest="$2"
    : > "$dest"
    for sno in $(find "$CORPUS/crosscheck" -name '*.sno' | sort); do
        base="${sno%.sno}"; name=$(basename "$sno" .sno)
        ref=""
        for cand in "$base.ref" "$(dirname "$sno")/$name.ref"; do
            [ -f "$cand" ] && { ref="$cand"; break; }
        done
        out=$(timeout -k 5 30s env SCRIP_RTCC="$gate" "$SCRIP" $FLAG "$sno" < /dev/null 2>/dev/null)
        rc=$?
        if [ $rc -eq 124 ]; then st=TIMEOUT
        elif [ $rc -ne 0 ]; then st=ERROR
        elif [ -z "$ref" ]; then st=NOREF
        elif [ "$out" = "$(cat "$ref")" ]; then st=PASS
        else st=DIVERGE
        fi
        echo "$st $name" >> "$dest"
    done
}

echo "=== RTCC board sweep: mode $MODE, $(find "$CORPUS/crosscheck" -name '*.sno' | wc -l) programs ==="
echo "--- arm OFF (SCRIP_RTCC=0) ---"; run_arm 0 "$OUT/off.txt"
echo "--- arm ON  (SCRIP_RTCC=1) ---"; run_arm 1 "$OUT/on.txt"

summ() { awk '{c[$1]++} END {printf "PASS=%d DIVERGE=%d ERROR=%d TIMEOUT=%d NOREF=%d\n", c["PASS"], c["DIVERGE"], c["ERROR"], c["TIMEOUT"], c["NOREF"]}' "$1"; }
echo ""
echo "OFF: $(summ "$OUT/off.txt")"
echo "ON : $(summ "$OUT/on.txt")"
echo ""
echo "=== BY-SET DIFF (the only attribution that survives the concurrency protocol) ==="
awk 'NR==FNR {off[$2]=$1; next} {if (off[$2] != $1) printf "  %-44s OFF=%-8s ON=%s\n", $2, off[$2], $1}' \
    "$OUT/off.txt" "$OUT/on.txt" > "$OUT/byset.txt"
if [ -s "$OUT/byset.txt" ]; then
    echo "PROGRAMS WHOSE STATUS MOVED ($(wc -l < "$OUT/byset.txt")):"
    cat "$OUT/byset.txt"
else
    echo "  EMPTY -- no program changed status between gate OFF and gate ON."
fi
