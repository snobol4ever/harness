#!/usr/bin/env bash
# test_gate_area_smoke_reads_the_attribute_rows.sh -- THE AREA SMOKE'S GATE (coo 2026-09-28, row instruments-the-area-smoke-a-seat-
# runs-per-landing-...-ceo-1342; RULES.md section ONE TESTING OFFICER, ONE SCORE BOARD, THE AREA SMOKE clause 4).
# WHAT IT PROVES, each arm on a scratch copy of the rebus rungs (43 entries; the smallest table with the SNOBOL4 feature columns):
#   1  the selector picks EXACTLY the one row doctored to carry FENCE (and nothing else in the table);
#   2  FAIL-ONCE: with the mark dropped the smoke REFUSES rc=2 on a zero selection, running nothing;
#   3  a feature no table knows REFUSES rc=2 naming it;
#   4  the run grades that one entry in both modes through run_suite_entry with the row's attributes, prints AREA_SMOKE_TOTAL
#      entries=1, and APPENDS NO PROGRESS ROW (a scratch S4E_PROGRESS_DB stays absent) -- a smoke is not a board (CEO-547);
#   5  the smoke body sources no one-runner guard and no progress writer (static, the harness's own source);
#   6  test_area_smoke.sh with NO argument maps a touched bb_match_fence0.cpp through area_map.tsv to FENCE (Lon's sixth question:
#      the seat does not have to know) and selects the same one row; a touched src/ file with NO map row refuses rc=2 naming it;
#      a tree equal to its base prints NO-DIFF rc=0; a file mapped to `-` prints NO-AREA rc=0;
#   7  THE MAP COVERS THE VOCABULARY: every feature column of every runnable table (real corpus, read only) has an explicit row
#      (unqualified, or qualified <lang>:<column> by the language of the table that carries the column),
#      and every carrier in the map exists in this tree (a file, a directory, or a symbol grep finds under src/).
# EXIT: 0 every arm holds; 1 an arm failed; 2 could not measure. Population printed.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
. "$HERE/lib_gate.sh" || { echo "REFUSING(2): cannot load lib_gate.sh"; exit 2; }
GATE_NAME=area_smoke_reads_the_attribute_rows
gate_parse_args "$@"
H="$HERE/corpus_suite_harness.py"; SMOKE="$HERE/test_area_smoke.sh"; MAP="$HERE/area_map.tsv"
gate_require "$H" "corpus_suite_harness.py" || exit 2
gate_require "$SMOKE" "test_area_smoke.sh" || exit 2
gate_require "$MAP" "area_map.tsv" || exit 2
S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"; SRC="$S4E/corpus/tests/rebus"
gate_require "$SRC/ALL.csv" "rebus rungs index" || exit 2
gate_require "$SRC/ALL.reb" "rebus rungs" || exit 2
gate_require "$SRC/ALL.ref" "rebus rungs refs" || exit 2
SCRATCH="${S4E_SCRATCH:-$(cd "$ROOT/.." && pwd)/.scratch}"; mkdir -p "$SCRATCH" || exit 2
WORK=$(mktemp -d "$SCRATCH/gate_area_smoke_XXXXXX") || exit 2
trap '[ -n "${WORK:-}" ] && rm -rf "$WORK"' EXIT INT TERM
fails=0; n=0
ck() { n=$((n+1)); if eval "$2"; then echo "  ok   $1"; else fails=$((fails+1)); echo "  FAIL $1"; fi; }

# the scratch world: one table, its rows doctored by python (the ONE csv grammar), the chosen entry the first ranked row
mkdir -p "$WORK/corpus/tests/rebus"
for f in ALL.reb ALL.ref ALL.csv ALL.in ALL.wantrc ALL.argv ALL.mask ALL.outside.tsv ALL.xfail; do [ -f "$SRC/$f" ] && cp "$SRC/$f" "$WORK/corpus/tests/rebus/"; done
doctor() {  # doctor <csv> <entry-or-empty>: FENCE and fence_guarded_fail 0 everywhere, FENCE 1 on the named entry
  python3 - "$1" "$2" <<'EOF'
import csv, sys
p, who = sys.argv[1], sys.argv[2]
rows = list(csv.DictReader(open(p, newline="")))
fields = list(rows[0].keys())
for r in rows:
    r["FENCE"] = "1" if (who and r["entry"] == who) else "0"
    r["fence_guarded_fail"] = "0"
w = csv.DictWriter(open(p, "w", newline=""), fieldnames=fields, lineterminator="\n")
w.writeheader(); w.writerows(rows)
EOF
}
CHOSEN=$(python3 -c 'import csv,sys; rs=[r for r in csv.DictReader(open(sys.argv[1], newline="")) if r.get("xfail","0")!="1"]; print(rs[0]["entry"])' "$SRC/ALL.csv")
[ -n "$CHOSEN" ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: no non-xfail entry in $SRC/ALL.csv"; gate_stamp; exit 2; }
doctor "$WORK/corpus/tests/rebus/ALL.csv" "$CHOSEN"
export S4E_PROGRESS_DB="$WORK/progress.tsv"

echo "--- ARM 1: the selector picks exactly the doctored row ---"
o1=$(S4E_HOME="$WORK" python3 "$H" smoke FENCE --list-only --tables tests/rebus 2>&1); r1=$?
ck "1 rc 0 and selected=1 of $(($(wc -l <"$SRC/ALL.csv")-1)), the row named ($CHOSEN)" '[ "$r1" = 0 ] && grep -q "AREA_SMOKE_SELECT table=tests/rebus features=FENCE selected=1 of " <<<"$o1" && grep -q ": $CHOSEN\$" <<<"$o1"'
[ "$r1" = 0 ] || printf '%s\n' "$o1" | tail -3 | sed 's/^/      /'

echo "--- ARM 2: FAIL-ONCE -- the mark dropped, zero selection refuses ---"
cp "$WORK/corpus/tests/rebus/ALL.csv" "$WORK/keep.csv"; doctor "$WORK/corpus/tests/rebus/ALL.csv" ""
o2=$(S4E_HOME="$WORK" python3 "$H" smoke FENCE --list-only --tables tests/rebus 2>&1); r2=$?
ck "2 rc 2 naming ZERO entries (nothing run)" '[ "$r2" = 2 ] && grep -q "ZERO" <<<"$o2"'
cp "$WORK/keep.csv" "$WORK/corpus/tests/rebus/ALL.csv"

echo "--- ARM 3: an unknown feature refuses by name ---"
o3=$(S4E_HOME="$WORK" python3 "$H" smoke NOSUCHFEATURE --list-only --tables tests/rebus 2>&1); r3=$?
ck "3 rc 2 naming NOSUCHFEATURE" '[ "$r3" = 2 ] && grep -q "NOSUCHFEATURE" <<<"$o3"'

echo "--- ARM 4: the run grades the one entry in both modes and appends no progress row ---"
o4=$(S4E_HOME="$WORK" python3 "$H" smoke FENCE --tables tests/rebus 2>&1); r4=$?
ck "4a rc 0 or 1 (measured), AREA_SMOKE_TOTAL entries=1 in modes m3,m4" '{ [ "$r4" = 0 ] || [ "$r4" = 1 ]; } && grep -q "AREA_SMOKE_TOTAL features=FENCE modes=m3,m4 tables=1 entries=1 " <<<"$o4"'
ck "4b AREA_SMOKE_ENTRY line names $CHOSEN with an m3= and an m4= verdict" 'grep -q "AREA_SMOKE_ENTRY table=tests/rebus entry=$CHOSEN m3=[A-Z]* m4=[A-Z]*" <<<"$o4"'
ck "4c no progress row appended: the scratch S4E_PROGRESS_DB does not exist" '[ ! -e "$WORK/progress.tsv" ]'
ck "4d the total line says so: no progress row, no score cell, not a board" 'grep -q "no progress row appended, no score cell written: an area smoke is not a board" <<<"$o4"'
[ "$r4" = 0 ] || [ "$r4" = 1 ] || printf '%s\n' "$o4" | tail -4 | sed 's/^/      /'

echo "--- ARM 5: the smoke body sources no guard and no progress writer (static) ---"
body=$(python3 - "$H" <<'EOF'
import ast, sys
src = open(sys.argv[1]).read(); tree = ast.parse(src)
names = set()
for node in ast.walk(tree):
    if isinstance(node, ast.FunctionDef) and node.name in ("cmd_smoke", "smoke_select", "smoke_tables", "smoke_feature_columns"):
        for sub in ast.walk(node):
            if isinstance(sub, ast.Name): names.add(sub.id)
            if isinstance(sub, ast.Attribute): names.add(sub.attr)
print(" ".join(sorted(names)))
EOF
)
ck "5 cmd_smoke and its readers name neither _one_runner_guard nor _progress_record nor util_progress_append" '[ -n "$body" ] && ! grep -qwE "_one_runner_guard|_progress_record|util_progress_append|util_score_row" <<<"$body"'

echo "--- ARM 6: the wrapper maps a landing's diff through the carrier map ---"
R="$WORK/r"; mkdir -p "$WORK/harness/scripts" "$R/src/templates/bb" "$R/src/tools"
cp "$MAP" "$WORK/harness/scripts/area_map.tsv"; printf 'box\n' > "$R/src/templates/bb/bb_match_fence0.cpp"; printf 'tool\n' > "$R/src/tools/zz.c"
( cd "$R" && git init -q && git add -A && git -c user.name=g -c user.email=g@g commit -q -m base ) || { echo "GATE UNPROVEN(2) [$GATE_NAME]: cannot make the fixture repo"; gate_stamp; exit 2; }
o6a=$(cd "$R" && AREA_SMOKE_ROOT="$R" AREA_SMOKE_BASE=HEAD S4E_HOME="$WORK" bash "$SMOKE" --list-only 2>&1); r6a=$?
ck "6a a tree equal to its base prints NO-DIFF, rc 0" '[ "$r6a" = 0 ] && grep -q "AREA_SMOKE NO-DIFF" <<<"$o6a"'
printf 'box moved\n' > "$R/src/templates/bb/bb_match_fence0.cpp"
o6b=$(cd "$R" && AREA_SMOKE_ROOT="$R" AREA_SMOKE_BASE=HEAD S4E_HOME="$WORK" bash "$SMOKE" --list-only 2>&1); r6b=$?
ck "6b a touched bb_match_fence0.cpp maps to FENCE (+ fence_guarded_fail) with no argument given" '[ "$r6b" = 0 ] && grep -q "AREA_SMOKE_MAP src/templates/bb/bb_match_fence0.cpp -> FENCE fence_guarded_fail" <<<"$o6b"'
ck "6c and selects the same one doctored row ($CHOSEN) over the two mapped columns" 'grep -q "AREA_SMOKE_SELECT table=tests/rebus features=FENCE,fence_guarded_fail selected=1 of " <<<"$o6b" && grep -q ": $CHOSEN\$" <<<"$o6b"'
[ "$r6b" = 0 ] || printf '%s\n' "$o6b" | tail -4 | sed 's/^/      /'
printf 'new\n' > "$R/src/zzz_unmapped.c"
o6d=$(cd "$R" && AREA_SMOKE_ROOT="$R" AREA_SMOKE_BASE=HEAD S4E_HOME="$WORK" bash "$SMOKE" --list-only 2>&1); r6d=$?
ck "6d a touched src/ file with no map row refuses rc 2 naming it" '[ "$r6d" = 2 ] && grep -q "NO ROW in ../harness/scripts/area_map.tsv: src/zzz_unmapped.c" <<<"$o6d"'
rm -f "$R/src/zzz_unmapped.c"; ( cd "$R" && git checkout -q -- src/templates/bb/bb_match_fence0.cpp ); printf 'tool moved\n' > "$R/src/tools/zz.c"
o6e=$(cd "$R" && AREA_SMOKE_ROOT="$R" AREA_SMOKE_BASE=HEAD S4E_HOME="$WORK" bash "$SMOKE" --list-only 2>&1); r6e=$?
ck "6e a file mapped to - alone prints NO-AREA, rc 0" '[ "$r6e" = 0 ] && grep -q "AREA_SMOKE NO-AREA" <<<"$o6e"'
( cd "$R" && git checkout -q -- src/tools/zz.c ) ; rm -f "$R/src/templates/bb/bb_match_fence0.cpp"
o6f=$(cd "$R" && AREA_SMOKE_ROOT="$R" AREA_SMOKE_BASE=HEAD S4E_HOME="$WORK" bash "$SMOKE" --list-only 2>&1); r6f=$?
ck "6f a src/ file the landing deletes is named as deleted and does not refuse (its row left with it, its successors carry theirs)" '[ "$r6f" = 0 ] && grep -q "AREA_SMOKE no area (deleted by this landing.*): src/templates/bb/bb_match_fence0.cpp" <<<"$o6f" && grep -q "AREA_SMOKE NO-AREA" <<<"$o6f"'
( cd "$R" && git checkout -q -- src/templates/bb/bb_match_fence0.cpp )
# 6g/6h: a SYMBOL row inside a shared-node file (src/runtime/ maps to *) still selects its feature beside the shared node -- only for the function the diff touched
mkdir -p "$R/src/runtime"; printf 'int zz_fence_fn(int a) {\n    int x = 1;\n    int y = 2;\n    return a;\n}\nint zz_other_fn(int a) {\n    int x = 1;\n    int y = 2;\n    return a;\n}\n' > "$R/src/runtime/zz_shared.c"
printf 'FENCE\tzz_fence_fn\n' >> "$WORK/harness/scripts/area_map.tsv"; ( cd "$R" && git add -A && git -c user.name=g -c user.email=g@g commit -q -m shared )
sed -i '3s/int y = 2;/int y = 3;/' "$R/src/runtime/zz_shared.c"
o6g=$(cd "$R" && AREA_SMOKE_ROOT="$R" AREA_SMOKE_BASE=HEAD S4E_HOME="$WORK" bash "$SMOKE" --list-only 2>&1); r6g=$?
ck "6g an edit inside zz_fence_fn (a FENCE symbol row) in a * file reads SHARED-NODE and still selects FENCE and the doctored row" '[ "$r6g" = 0 ] && grep -q "AREA_SMOKE SHARED-NODE" <<<"$o6g" && grep -q "AREA_SMOKE_MAP src/runtime/zz_shared.c -> \* FENCE" <<<"$o6g" && grep -q "AREA_SMOKE features (1): FENCE" <<<"$o6g" && grep -q ": $CHOSEN\$" <<<"$o6g"'
( cd "$R" && git checkout -q -- src/runtime/zz_shared.c ); sed -i '8s/int y = 2;/int y = 3;/' "$R/src/runtime/zz_shared.c"
o6h=$(cd "$R" && AREA_SMOKE_ROOT="$R" AREA_SMOKE_BASE=HEAD S4E_HOME="$WORK" bash "$SMOKE" --list-only 2>&1); r6h=$?
ck "6h an edit inside zz_other_fn (no symbol row) in the same file is the shared node alone: NO-AREA, no feature" '[ "$r6h" = 0 ] && grep -q "AREA_SMOKE SHARED-NODE" <<<"$o6h" && grep -q "AREA_SMOKE NO-AREA" <<<"$o6h" && ! grep -q "AREA_SMOKE features" <<<"$o6h"'
( cd "$R" && git checkout -q -- src/runtime/zz_shared.c )

echo "--- ARM 7: the map covers the vocabulary and every carrier exists (real corpus, read only) ---"
vocab=$(python3 "$H" smoke --vocabulary 2>&1); rv=$?
[ "$rv" = 0 ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: smoke --vocabulary rc=$rv: $(tail -1 <<<"$vocab")"; gate_stamp; exit 2; }
# a column is named by an unqualified row, or by a row qualified with the language of the table that carries it (<lang>:<col>)
missing_feats=$(printf '%s\n' "$vocab" | grep ' runnable=yes ' | awk '{split($2,p,"[=/]"); for (i=4;i<=NF;i++) print p[3]":"$i}' | sort -u | while IFS=: read -r l f; do [ -n "$f" ] || continue; awk -F'\t' -v f="$f" -v q="$l:$f" '$1==f || $1==q {found=1} END {exit !found}' "$MAP" || printf '%s ' "$l:$f"; done)
ntab=$(printf '%s\n' "$vocab" | grep -c ' runnable=yes ')
ck "7a every feature column of the $ntab runnable table(s) has an explicit row in area_map.tsv" '[ -z "$missing_feats" ]'
[ -z "$missing_feats" ] || echo "      unmapped feature column(s): $missing_feats"
bad_car=$(awk -F'\t' '$1 !~ /^#/ && NF==2 {print $2}' "$MAP" | sort -u | while read -r c; do case "$c" in */) [ -d "$ROOT/$c" ] || printf '%s ' "$c";; */*|*.*) [ -f "$ROOT/$c" ] || printf '%s ' "$c";; *) grep -rqw -- "$c" "$ROOT/src" || printf '%s ' "$c";; esac; done)
ncar=$(awk -F'\t' '$1 !~ /^#/ && NF==2 {print $2}' "$MAP" | sort -u | wc -l)
ck "7b every one of the $ncar carrier(s) exists in this tree (file, directory, or a symbol under src/)" '[ -z "$bad_car" ]'
[ -z "$bad_car" ] || echo "      missing carrier(s): $bad_car"
bad_rows=$(awk -F'\t' '$1 !~ /^#/ && NF>0 && NF!=2 {print NR": "$0}' "$MAP" | head -5)
ck "7c every map row is feature<TAB>carrier" '[ -z "$bad_rows" ]'

echo "------------------------------------------------------------"
echo "population: $n check(s) over a $(($(wc -l <"$SRC/ALL.csv")-1))-row scratch copy of the rebus rungs, a 3-file fixture repo, and the real map ($ncar carriers) against $ntab runnable table(s)"
if [ "$fails" -eq 0 ]; then echo "GATE PASS [$GATE_NAME]: $n of $n checks hold"; gate_stamp; exit 0; fi
echo "⛔ GATE FAIL [$GATE_NAME]: $fails of $n check(s) failed"; gate_stamp; exit 1
