#!/usr/bin/env bash
# test_gate_pas_fpc_suite_grades_against_a_corrected_ref_and_refuses_a_stale_or_missing_one.sh -- the ALL.corrected.tsv arms of the corpus harness (Lon 2026-10-05: where the
# oracle is wrong and we are right, the program is graded PASSING against the ISO-correct output, never the oracle's defect). The deleted test_pascal_fpc_suite.sh
# held these arms until 2026-11-08; corpus_suite_harness.py run holds them today (the block at its ALL.corrected.tsv reader). This gate grades the one grader
# (ruling of gates-the-37-gates-of-the-coos-lanes-that-name-a-deleted-package-runner-are-ruled-one-by-one, officer_01 2026-11-11: RE-AIM).
# Every arm runs the harness over a mktemp copy of the shipped container corpus/packages/pascal/fpc_tests with progress OFF (S4E_PROGRESS_OFF=1: no row is written):
#   good    the shipped test_tisobuf3 row is read, printed with its reason, and grades PASS in mode 3 (the harness drops mode 4 by COO-487)
#   unknown a corrected row naming an entry the container lacks REFUSES rc 2
#   missing the row's .ref.corrected deleted REFUSES rc 2
#   stale   the .ref.corrected made equal to the oracle's .out (the shipped oracle output) REFUSES rc 2
# FAIL_ONCE=1 corrupts the .ref.corrected in the good copy; the good arm must then read FAIL. EXIT: 0 every arm as stated, 1 an arm differs, 2 REFUSED (no SCRIP,
# no harness, no shipped container, no shipped row).
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$G" || exit $?
PY="$HERE/corpus_suite_harness.py"; SHIP="$ROOT/../corpus/packages/pascal/fpc_tests"; N=test_tisobuf3
[ -f "$PY" ] && [ -d "$SHIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: harness or shipped container missing"; exit 2; }
[ -f "$SHIP/$N.ref.corrected" ] && [ -f "$SHIP/$N.out" ] || { echo "⛔ GATE REFUSE(2) [$G]: no shipped $N.out and $N.ref.corrected"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
export S4E_PROGRESS_OFF=1
RC=0; NARM=0
chk() { NARM=$((NARM+1)); if [ "$2" = "$3" ]; then echo "  ok   $1"; else echo "  ⛔ $1: got [$2] want [$3]"; RC=1; fi; }
copy() { local d="$T/$1"; cp -r "$SHIP" "$d" && echo "$d"; }
run() { RUNOUT="$(timeout -k 5 600 python3 "$PY" run "$1/ALL.pas" "$1/ALL.ref" --lang pascal --modes m3 --partition "entry:$N" 2>&1)"; RUNRC=$?; }
G1=$(copy good); [ -n "${FAIL_ONCE:-}" ] && printf 'corrupted\n' >> "$G1/$N.ref.corrected"
run "$G1"
chk "good: the shipped row is read and printed with its reason" "$(grep -c "CORRECTED_REFS n=1 .*$N" <<<"$RUNOUT")" 1
chk "good: the run exits 0" "$RUNRC" 0
chk "good: $N grades PASS in mode 3 on the board" "$(grep -cE '^SUITE_BOARD .*m3_pass=1 m3_fail=0 ' <<<"$RUNOUT")" 1
G2=$(copy unknown); printf 'ghost\tx\n' > "$G2/ALL.corrected.tsv"; run "$G2"
chk "unknown: a row naming an entry the container lacks refuses rc 2" "$RUNRC" 2
chk "unknown: the refusal names the missing entry" "$(grep -c 'does not carry' <<<"$RUNOUT")" 1
G3=$(copy missing); rm "$G3/$N.ref.corrected"; run "$G3"
chk "missing: a row whose .ref.corrected is missing refuses rc 2" "$RUNRC" 2
chk "missing: the refusal names the missing file" "$(grep -c 'missing beside it' <<<"$RUNOUT")" 1
G4=$(copy stale); cp "$G4/$N.out" "$G4/$N.ref.corrected"; run "$G4"
chk "stale: a .ref.corrected equal to the oracle's ref refuses rc 2" "$RUNRC" 2
chk "stale: the refusal names the stale file" "$(grep -c 'equals the oracle' <<<"$RUNOUT")" 1
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: the harness's corrected-ref arms read, refuse unknown/missing/stale rows, and $N grades green in mode 3, $NARM of $NARM arms"; else echo "GATE FAIL(1) [$G]: see above"; fi
exit $RC
