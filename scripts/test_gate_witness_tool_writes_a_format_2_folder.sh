#!/usr/bin/env bash
# test_gate_witness_tool_writes_a_format_2_folder.sh -- THE ADD-A-WITNESS TOOL WRITES THE FORMAT ITS FOLDER IS IN (CIO-45 (1) b; the format
# CIO-24 f, CIO-25, CIO-44). util_add_ladder_witness.py appended to ALL.<ext> and ALL.ref by text comparison, and since harness ac2eaea02 it
# refuses a format-2 folder by name. THE ARMS, on a scratch root holding a copy of the snobol4 master in format 2 (lib_fmt2_fixture.sh):
#   1  adding one witness (--family fmt2probe, its answer cut from sbl -bf by the tool) reads rc 0;
#   2  the folder is still format 2: MULTI.md, ONE.sno and ONE.out stand, ALL.sno, ALL.ref and ALL.in do not;
#   3  the reader reads one test more, the new one named fmt2probe__<stem> with the oracle's answer, and every other test as before;
#   4  a dry run (no --apply) changes no byte.
# EXIT 0 all hold; 1 an arm failed; 2 could not measure.
export S4E_ONE_RUNNER_FIXTURE="gate arm ${0##*/}: the witness tool over a scratch root outside the corpus, not a board (R-547)"
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib_gate.sh" || { echo "REFUSING(2): cannot load lib_gate.sh"; exit 2; }
GATE_NAME=witness_tool_writes_a_format_2_folder
gate_parse_args "$@"
. "$HERE/lib_oracle_flags.sh" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: cannot load lib_oracle_flags.sh"; exit 2; }
SBL="$(sbl_correctness_bin)" && [ -x "$SBL" ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: the SNOBOL4 oracle is not installed"; exit 2; }
H="$HERE/corpus_suite_harness.py"; gate_require "$H" "corpus_suite_harness.py" || exit 2
T="$HERE/util_add_ladder_witness.py"; gate_require "$T" "util_add_ladder_witness.py" || exit 2
. "$HERE/lib_fmt2_fixture.sh" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: cannot load lib_fmt2_fixture.sh"; exit 2; }
S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
W=$(mktemp -d) || exit 2; trap 'rm -rf "$W"' EXIT INT TERM
export TMPDIR="$W"
msg=$(fmt2_fixture "$W/r") || { echo "GATE UNPROVEN(2) [$GATE_NAME]: $msg"; exit 2; }
D="$W/r/corpus/tests/snobol4"
fmt2_entries "$D" "$W/e0" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: the fixture does not read as format 2"; exit 2; }
n0=$(wc -l < "$W/e0"); [ "$n0" -gt 0 ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: the fixture holds no test"; exit 2; }
printf "        OUTPUT = 'format two witness'\nEND\n" > "$W/zw.sno"
fails=0; n=0
ck() { n=$((n+1)); if eval "$2"; then echo "  ok   $1"; else fails=$((fails+1)); echo "  FAIL $1"; fi; }
is_fmt2() { [ -f "$D/MULTI.md" ] && [ -f "$D/ONE.sno" ] && [ -f "$D/ONE.out" ] && [ ! -e "$D/ALL.sno" ] && [ ! -e "$D/ALL.ref" ] && [ ! -e "$D/ALL.in" ]; }
add() { S4E_HOME="$W/r" timeout -k 5 600 python3 "$T" --lang snobol4 --family fmt2probe --source "$W/zw.sno" --rungs-dir "$D" --compile-args "" "$@"; }

before=$(cd "$D" && find . -type f | sort | xargs sha1sum | sha1sum)
add > "$W/dry.log" 2>&1
ck "a dry run changes no byte" '[ "$(cd "$D" && find . -type f | sort | xargs sha1sum | sha1sum)" = "$before" ]'
add --apply > "$W/a1.log" 2>&1; r1=$?
ck "adding one witness reads rc 0 ($r1)" '[ $r1 = 0 ]'
ck "the folder is still format 2" 'is_fmt2'
fmt2_entries "$D" "$W/e1" 2>"$W/e1.err"; rr=$?
ck "the reader reads one test more, fmt2probe__zw among them" '[ $rr = 0 ] && [ "$(wc -l < "$W/e1")" = $((n0 + 1)) ] && grep -q "^fmt2probe__zw " "$W/e1"'
ck "the new test holds the oracle answer" 'grep "^fmt2probe__zw " "$W/e1" | grep -q "format two witness"'
ck "every other test reads as before, in order" 'grep -v "^fmt2probe__zw " "$W/e1" | cmp -s - "$W/e0"'

echo "  -- apply: $(tail -1 "$W/a1.log" | cut -c1-200)"
if [ "$fails" -eq 0 ]; then echo "GATE PASS [$GATE_NAME]: $n of $n checks hold"; gate_stamp; exit 0; fi
echo "⛔ GATE FAIL [$GATE_NAME]: $fails of $n check(s) failed"; gate_stamp; exit 1
