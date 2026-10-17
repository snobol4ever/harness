#!/usr/bin/env bash
# util_parser_sc_recognition.sh <lang> [OUTDIR] -- DOES bootstrap/parser_<lang>.sc RECOGNISE EVERYTHING THE C PARSER RECOGNISES?
# (Lon 2026-09-30 10:5x, the row parser-raku-sc-recognizes-every-master-entry-...: the .sc and the C parser should recognise the
# entire corpus of the language.) THE POPULATION: every loose corpus file of the language (ALL.* and corpus/library excluded) plus
# every entry of the language's master tests/<lang>/ALL.<ext>, materialised through the suite harness's own extract (never a second
# reader of the container). THE C SIDE: out/parser_<lang>, ONE PROCESS PER FILE (the whole-list run leaks parser state between
# files, cto 2026-09-30), its dump or its Parse Error under a "== path" header. THE GRADE: util_parser_sc_grade.sh, the .sc chain
# compiled once to a mode-4 binary. THE VERDICT is that instrument's own line, PARSER-SC lang=L files=N match=M diff=D fail=F
# crash=K c_refused=R: rc 0 when fail=0 and crash=0 (every file the C parser accepts, the grammar parses -- the trees may differ,
# that is the tree gate's question); rc 1 otherwise; rc 2 could not measure. Population and dumps are cached under OUTDIR
# (default: the scratchpad) and rebuilt when the master or the C parser binary is newer.
set -u
L="${1:-}"; here=$(cd "$(dirname "$0")" && pwd); W=$(cd "$here/.." && pwd); C=$(cd "$W/../corpus" 2>/dev/null && pwd)
OUT="${2:-${TMPDIR:-/tmp}/parser_sc_recognition_$(id -u)/$L}"; mkdir -p "$OUT/master" || exit 2
declare -A EXT=([snobol4]=sno [snocone]=sc [icon]=icn [prolog]=pl [rebus]=reb [raku]=raku [pascal]=pas)
[ -n "$L" ] && [ -n "${EXT[$L]:-}" ] || { echo "PARSER-SC-RECOGNITION ⛔ REFUSE(2): lang must be one of ${!EXT[*]}"; exit 2; }
e=${EXT[$L]}; X="$W/out/parser_$L"; M="$C/tests/$L"
( . "$here/lib_build_currency.sh" && assert_parser_current "$L" "$W" ) || { echo "PARSER-SC-RECOGNITION ⛔ REFUSE(2): $X is missing or older than a source it was compiled from (named above) -- make parsers"; exit 2; }
[ -f "$M/ALL.$e" ] && [ -f "$M/ALL.csv" ] || { echo "PARSER-SC-RECOGNITION ⛔ REFUSE(2): no master under $M"; exit 2; }
LIST="$OUT/list.txt"
if [ ! -s "$LIST" ] || [ "$M/ALL.$e" -nt "$LIST" ] || [ "$M/ALL.csv" -nt "$LIST" ]; then
    find "$C" -type f -name "*.$e" -not -name 'ALL.*' -not -path '*/.git/*' -not -path "$C/library/*" | sort > "$LIST"
    python3 - "$M/ALL.csv" <<'PY' > "$OUT/entries.txt"
import csv, sys
for r in csv.DictReader(open(sys.argv[1])): print(r["entry"])
PY
    n=0; while IFS= read -r en; do o="$OUT/master/$en.$e"; python3 "$here/corpus_suite_harness.py" extract "$M/ALL.$e" "$M/ALL.ref" "$en" "$o" > /dev/null 2>> "$OUT/extract.err" && { echo "$o" >> "$LIST"; n=$((n+1)); }; done < "$OUT/entries.txt"
    [ "$n" -gt 0 ] || { echo "PARSER-SC-RECOGNITION ⛔ REFUSE(2): no master entry could be extracted ($(head -1 "$OUT/extract.err"))"; exit 2; }
    rm -f "$OUT/c.dump"
fi
if [ ! -s "$OUT/c.dump" ] || [ "$X" -nt "$OUT/c.dump" ] || [ "$LIST" -nt "$OUT/c.dump" ]; then
    : > "$OUT/c.dump"
    while IFS= read -r f; do echo "== $f" >> "$OUT/c.dump"; ( cd "$(dirname "$f")" && SNO_LIB="$C/include" timeout -k 5 60 "$X" - < "$f" >> "$OUT/c.dump" 2>/dev/null ) || echo "Parse Error" >> "$OUT/c.dump"; done < "$LIST"
fi
SHOW="${SHOW:-3}" CHUNK="${CHUNK:-25}" bash "$here/util_parser_sc_grade.sh" "$L" "$LIST" "$OUT/c.dump" "$OUT/grade" > "$OUT/grade.out" 2>&1; g=$?
line=$(grep -m1 '^PARSER-SC lang=' "$OUT/grade.out"); [ -n "$line" ] || { echo "PARSER-SC-RECOGNITION ⛔ REFUSE(2): the grader printed no PARSER-SC line: $(head -2 "$OUT/grade.out" | cut -c1-200)"; exit 2; }
fail=$(sed -n 's/.* fail=\([0-9]*\).*/\1/p' <<< "$line"); crash=$(sed -n 's/.* crash=\([0-9]*\).*/\1/p' <<< "$line"); crash=${crash:-0}
echo "PARSER-SC-RECOGNITION $line population=$(wc -l < "$LIST") (loose corpus files + master entries)"
grep -m1 '^FAIL' "$OUT/grade.out" | cut -c1-400
[ "$fail" = 0 ] && [ "$crash" = 0 ] && { echo "PARSER-SC-RECOGNITION ✅ [$L]: the grammar refuses nothing the C parser accepts"; exit 0; }
echo "PARSER-SC-RECOGNITION ⛔ RED [$L]: fail=$fail crash=$crash -- the grammar refuses or dies on a file the C parser accepts"; exit 1
