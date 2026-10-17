#!/usr/bin/env bash
# test_sweep_startd_md5.sh — COMPILE-TIME BLAST RADIUS for the START-δ HOME rung (s69).
#
# WHY md5 AND NOT THE BOARD (s66 ruling, measured): two IDENTICAL runs of the 226-program board differ on ~5
# programs, the same magnitude as a whole ON-vs-OFF diff, and the flips go green->red — the direction that
# manufactures false convictions. A byte-identity sweep over emitted .s has NO such floor: a program whose
# emitted machine code is unchanged CANNOT have regressed, by construction rather than by observation.
#
# Usage: bash ../harness/scripts/test_sweep_startd_md5.sh <outfile.tsv> [arm]
#   arm = value for SCRIP_MATCH_RBP (default 1). Emits one "md5<TAB>program" row per program, sorted.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../../SCRIP" && pwd)"
OUT="${1:?usage: $0 <outfile.tsv> [arm]}"
ARM="${2:-1}"
CORPUS="${CORPUS:-$S4E/corpus}"
: > "$OUT"
n=0
while IFS= read -r f; do
    s=$(SCRIP_MATCH_RBP="$ARM" timeout -k 5 30s "$ROOT/scrip" --compile "$f" < /dev/null 2>/dev/null)
    if [ -z "$s" ]; then m="EMPTY_OR_FAIL"; else m=$(printf '%s' "$s" | md5sum | cut -d' ' -f1); fi
    printf '%s\t%s\n' "$m" "${f#$CORPUS/}" >> "$OUT"
    n=$((n+1))
done < <(find "$CORPUS/probe" "$CORPUS/demos" -name '*.sno' | sort)
sort -o "$OUT" "$OUT"
echo "swept=$n arm=$ARM out=$OUT"
