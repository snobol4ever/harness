#!/usr/bin/env bash
# test_gate_generated_units_build_and_grade_by_verdict_line.sh -- A PER-GOAL SUITE IS A CONTAINER OF GENERATED PROGRAMS GRADED BY ITS VERDICT LINE
# (CIO-22 D, the coo 2026-11-10 on the cio's design; row cycle-generated-units-a-per-goal-suite-is-a-container-of-generated-programs-graded-by-its-verdict-line).
# On a scratch package whose CONTRACT.tsv reads units=generated and generator=fixtures/generated_units_stub_cases, util_build_package_suite.py
# builds the container from the generator alone (no oracle run): four cases absorbed, the one EXCLUDED_CASES.tsv names and the one the generator
# cannot plan excluded by name, absorbed plus excluded equal to the table; ALL.csv gains compare=verdict-line and cwd for the absorbed four.
# Then corpus_suite_harness.py grades each absorbed entry alone in mode 3: a verdict line among other lines PASS, a verdict read from a file
# beside its cwd PASS, a wrong verdict FAIL (output mismatch), no verdict line FAIL (no verdict line).
# rc 0 green · 1 red (the failing arm named) · 2 could not measure.
set -uo pipefail
GATE_NAME=test_gate_generated_units_build_and_grade_by_verdict_line
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "⛔ REFUSE(2) [$GATE_NAME]: no SCRIP beside harness at $HERE/../../SCRIP"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"
RT="${RT_DIR:-$ROOT/out}"
[ -x "$SCRIP" ] || { echo "⛔ REFUSE(2) [$GATE_NAME]: no scrip at $SCRIP -- a missing binary prints a plausible all-FAIL board"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
D=$(mktemp -d "${TMPDIR:-/tmp}/gen_units_gate.XXXXXX") || { echo "⛔ REFUSE(2) [$GATE_NAME]: no tmpdir"; exit 2; }
trap 'rm -rf "$D"' EXIT
P="$D/pkg"; mkdir -p "$P/sub" || exit 2
RED=0; ARMS=0
arm() { ARMS=$((ARMS+1)); if [ "$2" = "$3" ]; then echo "  ok   $1"; else RED=$((RED+1)); echo "  RED  $1"; echo "       got:  [$2]"; echo "       want: [$3]"; fi; }
printf 'hello.\n' > "$P/sub/data.txt"
printf 'units\tgenerated\tthe gate'"'"'s scratch package: every entry is a generated case\ngenerator\tfixtures/generated_units_stub_cases\tthe gate'"'"'s six-case stub\n' > "$P/CONTRACT.tsv"
printf 'excluded_by_name\tSTUB_EXCLUDED\tthe gate names it, so the builder must not absorb it\n' > "$P/EXCLUDED_CASES.tsv"
{ echo "rank,entry,origin,package,n_lines,stdin,want_rc,heap_kb,stack_kb,timeout_s,section"
  n=0; for c in says_succ_among_noise reads_its_cwd says_fail says_nothing excluded_by_name cannot_plan; do n=$((n+1)); echo "$n,$c,$c,pkg,1,0,0,131072,4096,60,stub"; done; } > "$P/ALL.csv"
# THE BUILD: no oracle, the generator alone, the identity checked.
( cd "$D" && timeout -k 5 300 python3 "$HERE/util_build_package_suite.py" "$P" --lang prolog < /dev/null ) > "$D/build.log" 2>&1; brc=$?
arm "the builder builds units=generated (rc)" "$brc" 0
arm "the builder's balance line" "$(grep -c 'GENERATED 4 absorbed, 2 excluded, 6 in the table (balanced)' "$D/build.log")" 1
arm "no oracle ran" "$(grep -cE ': (ABSORBED|EXCLUDED \(oracle)' "$D/build.log")" 0
cells="$(python3 -c '
import csv, sys
for r in csv.DictReader(open(sys.argv[1])): print("%s=%s|%s" % (r["entry"], r.get("compare", "?"), r.get("cwd", "?")))' "$P/ALL.csv" 2>/dev/null | tr '\n' ' ')"
arm "ALL.csv compare and cwd cells" "$cells" "says_succ_among_noise=verdict-line|. reads_its_cwd=verdict-line|sub says_fail=verdict-line|. says_nothing=verdict-line|. excluded_by_name=| cannot_plan=| "
arm "ALL.omit names the two by name" "$(cut -d: -f1 "$P/ALL.omit" 2>/dev/null | tr '\n' ' ')" "cannot_plan excluded_by_name "
[ "$brc" = 0 ] && [ -f "$P/ALL.pl" ] && [ -f "$P/ALL.ref" ] || { echo "GATE FAIL [$GATE_NAME]: the builder wrote no container ($RED of $ARMS arms red; $D/build.log)"; tail -5 "$D/build.log"; exit 1; }
( cd "$P" && python3 "$HERE/util_suite_partition.py" build ALL.csv ) > "$D/part.log" 2>&1 || { echo "⛔ REFUSE(2) [$GATE_NAME]: util_suite_partition.py build refused on the scratch table ($(tail -1 "$D/part.log"))"; exit 2; }
# THE GRADE: each absorbed entry alone, mode 3, its verdict and its reason.
grade() {   # name -> "PASS" | "FAIL:<detail>" | "NONE:<rc>"
    local o rc; o="$( cd "$ROOT" && S4E_PROGRESS_OFF=1 S4E_BATCH=0 timeout -k 5 300 python3 "$HERE/corpus_suite_harness.py" run "$P/ALL.pl" "$P/ALL.ref" --lang prolog --modes m3 --partition "entry:$1" 2>&1 < /dev/null )"; rc=$?
    if printf '%s\n' "$o" | grep -q '^SUITE_BOARD .* m3_pass=1 '; then echo PASS
    elif printf '%s\n' "$o" | grep -q '^SUITE_BOARD .* m3_fail=1 '; then echo "FAIL:$(printf '%s\n' "$o" | sed -n "s/^ *FAIL m3 $1: \([a-z ]*\).*/\1/p" | head -1 | sed 's/ *$//')"
    elif printf '%s\n' "$o" | grep -q "compare cell 'verdict-line'"; then echo "REFUSED:the harness does not admit verdict-line"
    else echo "NONE:$rc"; printf '%s\n' "$o" | grep -E 'REFUS|Error|error' | head -3 >&2; fi
}
v1="$(grade says_succ_among_noise)"; v2="$(grade reads_its_cwd)"; v3="$(grade says_fail)"; v4="$(grade says_nothing)"
for v in "$v1" "$v2" "$v3" "$v4"; do case "$v" in NONE:*) echo "⛔ REFUSE(2) [$GATE_NAME]: the harness printed no SUITE_BOARD for an entry ($v) -- cannot measure"; exit 2;; esac; done
arm "a verdict line among other lines PASS" "$v1" PASS
arm "a verdict read beside its cwd PASS" "$v2" PASS
arm "a wrong verdict FAIL" "$v3" "FAIL:output mismatch"
arm "no verdict line FAIL" "$v4" "FAIL:no verdict line"
[ "$RED" = 0 ] && { echo "GATE OK [$GATE_NAME]: $ARMS arms green -- units=generated builds 4 of 6 with the 2 excluded by name and no oracle run; verdict-line grades PASS, PASS, FAIL, FAIL"; exit 0; }
echo "GATE FAIL [$GATE_NAME]: $RED of $ARMS arms red"; exit 1
