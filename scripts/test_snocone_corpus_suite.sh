#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib_one_runner.sh" && one_runner_guard "${0##*/}" || exit 2
# test_snocone_corpus_suite.sh
#
# Grades the "corpus" family (10 entries) via execution (--run and --compile), diffed per entry
# against expected stdout. Consolidated from 10 loose file pairs 2026-08-28
# (tests-consolidate-snocone, fan-out child of corpus-suites-consolidation): sc1_literals..
# sc10_wordcount, a small language-feature coverage ladder (literals/assign/arith/control/while/
# for/procedure/strings/multiproc/wordcount). Unlike the parser-fixtures suite (graded by
# --dump-ast shape), this family's .ref files hold program OUTPUT, not AST dumps -- hence the
# explicit --modes m3,m4 rather than the LANG_CONFIGS default (ast). 4 of the 10 also needed a
# source fix before conversion (bare relop sugar deliberately removed 2026-08-24 -- same class
# already found in parser-fixtures and crosscheck/rungB09-12); once fixed, all 10 already matched
# their existing .ref content exactly, so nothing needed re-pinning.
#
# ⛔⭐ REPOINTED (seat07 2026-08-30, one-flat-suite cutover): the standalone corpus.sc/.ref pair
# this gate used to read was ABSORBED into tests/snocone/ALL.sc and DELETED once byte-equal-or-no-
# delete verified it. Reading a now-deleted path would SKIP-as-exit-0 forever -- the exact "a
# missing prerequisite must REFUSE, never a green exit" class RULES.md names -- so this gate now
# re-materializes the "corpus" family out of the rungs via `extract-family` (family membership
# from ALL.csv, never a name guess) and grades THAT.
#
# Gate: FAIL=0 over the printed total (do not pin a specific total here -- the fixture count
# drifts; a probe asserts FAIL=0/SKIP=0 over its own denominator, never a copied number -- RULES.md).
#
# ⛔ NOT A DRIFT-DETECTOR (checked under ast-dump-refs-are-self-pins-not-oracles, 2026-09-05): unlike
# its sibling test_snocone_parser_fixtures.sh, this family's .ref holds real program OUTPUT (m3,m4
# execution), graded against what the interpreted program actually printed -- a genuine correctness
# check, not a self-pinned `--dump-ast` comparison. Named here only so a reader searching for
# DRIFT-DETECTOR finds the explicit "this one isn't" rather than silence.
#
# Commit identity: LCherryholmes / lcherryh@yahoo.com  (RULES.md)
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME

set -uo pipefail   # deliberately NOT -e: this script's own diagnostic must never mask a fail count

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNGS_SNO="$S4E/corpus/tests/snocone/ALL.sc"
RUNGS_REF="$S4E/corpus/tests/snocone/ALL.ref"
RUNGS_CSV="$S4E/corpus/tests/snocone/ALL.csv"

echo "=== Snocone corpus suite (m3+m4) ==="

if [ ! -f "$RUNGS_SNO" ] || [ ! -f "$RUNGS_REF" ] || [ ! -f "$RUNGS_CSV" ]; then
    echo "REFUSES rc=2: rungs not found at $RUNGS_SNO / $RUNGS_REF / $RUNGS_CSV -- cannot measure."
    exit 2
fi

W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
if ! python3 "$HERE/corpus_suite_harness.py" extract-family "$RUNGS_SNO" "$RUNGS_REF" "$RUNGS_CSV" corpus "$W/corpus.sc" "$W/corpus.ref" >&2; then
    echo "REFUSES rc=2: could not extract family 'corpus' from the rungs -- see stderr above."
    exit 2
fi

out=$(python3 "$HERE/corpus_suite_harness.py" run "$W/corpus.sc" "$W/corpus.ref" --lang snocone --modes m3,m4 2>&1)
rc=$?
echo "$out"
_board="$(printf '%s\n' "$out" | grep -m1 '^SUITE_BOARD' || true)"
# Pull the three fields a reader of the leaderboard actually needs. Pasting the whole SUITE_BOARD line
# into a table cell is honest but unreadable -- fifteen mostly-zero fields hide the two that matter.
_tot="$(printf '%s' "$_board" | sed -n 's/.*total=\([0-9]*\).*/\1/p')"
_p3="$(printf '%s' "$_board" | sed -n 's/.*m3_pass=\([0-9]*\).*/\1/p')"
_p4="$(printf '%s' "$_board" | sed -n 's/.*m4_pass=\([0-9]*\).*/\1/p')"
_f3="$(printf '%s' "$_board" | sed -n 's/.*m3_fail=\([0-9]*\).*/\1/p')"
_f4="$(printf '%s' "$_board" | sed -n 's/.*m4_fail=\([0-9]*\).*/\1/p')"
# ⛔ ONE LEADERBOARD (RULES.md FACT RULE, Lon 2026-09-03 ~16:05: "any run of a test suite by any
# session will update the ONE LEADERBOARD"). This records the board line printed just above into
# .github/SCORE.md -- it RUNS NOTHING, it only writes down what this script already measured.
# ⛔ NON-FATAL BY DESIGN: a bookkeeping failure must never turn a real measurement into a red board,
# because a gate that goes red for a reason unrelated to the code is a gate people route around. It
# warns and names the unrecorded row instead; it has no silent path.
python3 "$HERE/util_score_row.py" write --lang snocone --column floor --modes m3,m4 \
    --measurer "${S4E_SEAT:-}" --text "corpus suite m3 ${_p3:-?}/${_tot:-?} · m4 ${_p4:-?}/${_tot:-?} (fail ${_f3:-?}/${_f4:-?}, \`test_snocone_corpus_suite.sh\`)" \
    || echo "⚠ SCORE.md NOT UPDATED -- record this row by hand (the REFUSED line above says why)"
# ⛔ PRESERVE THE HARNESS'S OWN rc, DON'T COLLAPSE IT TO A BOOLEAN (adjacent to row every-board-wrapper-
# refuses-on-a-zero-population-instead-of-passing-vacuously, hq_T 2026-09-04): corpus_suite_harness.py
# now REFUSES rc=2 on a zero-entry family (its own population floor); `[ "$rc" -eq 0 ]` alone would
# still report that correctly as non-PASS, but as a bare FAIL(1) indistinguishable from a real graded
# violation. Exiting the harness's own code keeps REFUSED(2) legible as "could not measure" here too.
exit "$rc"
