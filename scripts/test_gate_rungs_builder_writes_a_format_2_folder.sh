#!/usr/bin/env bash
# test_gate_rungs_builder_writes_a_format_2_folder.sh -- THE BUILDER WRITES THE FORMAT ITS FOLDER IS IN (CIO-45 (1) b; the format CIO-24 f,
# CIO-25, CIO-44). util_build_rungs_suite.py reads a format-2 folder through read_suite already; its writes went to ALL.<ext>, ALL.ref and
# ALL.csv by os.replace, so a run on a converted folder put the old files back beside MULTI.md, or rewrote ALL.csv without its group column,
# and every reader then refused rc 2. THE ARMS, on a scratch root holding a copy of the snobol4 master in format 2 (lib_fmt2_fixture.sh):
#   1  --reindex reads rc 0 and the folder is still format 2: MULTI.md, ONE.sno and ONE.out stand, ALL.sno, ALL.ref and ALL.in do not,
#      ALL.csv has its group column, and every test reads back as it read before (name, order, every attribute);
#   2  --resort reads rc 0 and leaves the same;
#   3  --split-write, whose ONE.*/MULTI.* by kind is not format 2, refuses rc 2 on a format-2 folder and changes no byte.
# EXIT 0 all hold; 1 an arm failed; 2 could not measure.
export S4E_ONE_RUNNER_FIXTURE="gate arm ${0##*/}: the builder over a scratch root outside the corpus, not a board (R-547)"
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib_gate.sh" || { echo "REFUSING(2): cannot load lib_gate.sh"; exit 2; }
GATE_NAME=rungs_builder_writes_a_format_2_folder
gate_parse_args "$@"
H="$HERE/corpus_suite_harness.py"; gate_require "$H" "corpus_suite_harness.py" || exit 2
B="$HERE/util_build_rungs_suite.py"; gate_require "$B" "util_build_rungs_suite.py" || exit 2
. "$HERE/lib_fmt2_fixture.sh" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: cannot load lib_fmt2_fixture.sh"; exit 2; }
S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
W=$(mktemp -d) || exit 2; trap 'rm -rf "$W"' EXIT INT TERM
export TMPDIR="$W"
msg=$(fmt2_fixture "$W/r") || { echo "GATE UNPROVEN(2) [$GATE_NAME]: $msg"; exit 2; }
D="$W/r/corpus/tests/snobol4"
fmt2_entries "$D" "$W/e0" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: the fixture does not read as format 2"; exit 2; }
[ -s "$W/e0" ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: the fixture holds no test"; exit 2; }
fails=0; n=0
ck() { n=$((n+1)); if eval "$2"; then echo "  ok   $1"; else fails=$((fails+1)); echo "  FAIL $1"; fi; }
is_fmt2() { [ -f "$D/MULTI.md" ] && [ -f "$D/ONE.sno" ] && [ -f "$D/ONE.out" ] && [ ! -e "$D/ALL.sno" ] && [ ! -e "$D/ALL.ref" ] && [ ! -e "$D/ALL.in" ] && head -1 "$D/ALL.csv" | grep -q '^rank,entry,group,road,nonl,'; }
same() { fmt2_entries "$D" "$W/e1" 2>/dev/null && cmp -s "$W/e0" "$W/e1"; }

S4E_HOME="$W/r" timeout -k 5 600 python3 "$B" --lang snobol4 --reindex > "$W/a1.log" 2>&1; r1=$?
ck "--reindex rc 0 ($r1)" '[ $r1 = 0 ]'
ck "--reindex leaves the folder format 2" 'is_fmt2'
ck "--reindex: every test reads back as before" 'same'

S4E_HOME="$W/r" timeout -k 5 600 python3 "$B" --lang snobol4 --resort > "$W/a2.log" 2>&1; r2=$?
ck "--resort rc 0 ($r2)" '[ $r2 = 0 ]'
ck "--resort leaves the folder format 2, every test as before" 'is_fmt2 && same'

before=$(cd "$D" && find . -type f | sort | xargs sha1sum | sha1sum)
S4E_HOME="$W/r" timeout -k 5 600 python3 "$B" --lang snobol4 --split-write --write > "$W/a3.log" 2>&1; r3=$?
ck "--split-write refuses rc 2 on a format-2 folder ($r3) and changes no byte" '[ $r3 = 2 ] && [ "$(cd "$D" && find . -type f | sort | xargs sha1sum | sha1sum)" = "$before" ]'

for f in a1 a2 a3; do [ -s "$W/$f.log" ] && { echo "  -- $f: $(tail -1 "$W/$f.log" | cut -c1-200)"; }; done
if [ "$fails" -eq 0 ]; then echo "GATE PASS [$GATE_NAME]: $n of $n checks hold"; gate_stamp; exit 0; fi
echo "⛔ GATE FAIL [$GATE_NAME]: $fails of $n check(s) failed"; gate_stamp; exit 1
