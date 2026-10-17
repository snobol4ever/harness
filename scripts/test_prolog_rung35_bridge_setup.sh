#!/usr/bin/env bash
# test_prolog_rung35_bridge_setup.sh — PR-19e driver tests for setup_call_cleanup/3
# D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORPUS=$S4E/corpus/tests/prolog
FAMILY=rung35_bridge_setup
SNO="$CORPUS/$FAMILY.pl"
REF="$CORPUS/$FAMILY.ref"

echo "=== rung35_bridge_setup: setup_call_cleanup/3 with goal-as-variable (PR-19e driver) ==="

# consolidated 2026-08-29 (tests-consolidate-prolog, hq_P): the loose $CORPUS/$FAMILY/*.pl
# directory this script used to glob was replaced by one suite pair. ⛔ THE OLD FORM WENT
# FALSE-GREEN THE MOMENT THE DIRECTORY EMPTIED -- an unmatched glob left PASS=0 FAIL=0 and
# the trailing [ "$FAIL" -eq 0 ] exited 0, reporting success having run nothing (measured on
# rung27/rung28/rung39_atom_iso at conversion time). A suite file is NEVER run whole
# (corpus_suite_harness.py's own docstring) -- delegate to `run`, which extracts and runs
# each entry alone in its own temp dir, and REFUSE rc=2 when the suite is absent.
# ⛔⭐⭐ ABSORBED FALLBACK (hq_B 2026-08-30) — THIS SCRIPT'S REFUSAL HAD BECOME A PERMANENT NO-OP.
# Two generations of decay, each fix correct for its own moment and neither following the data:
#   gen 1  loose $CORPUS/$FAMILY/*.pl  -> emptied -> unmatched glob -> FALSE GREEN
#          (cured by the refusal below, exactly right at the time)
#   gen 2  the per-family suite pair itself was absorbed into the ONE FLAT ALL.* set
#          -> $SNO/$REF can never exist again -> the refusal fires FOREVER, grading nothing
# ⛔ MEASURED 2026-08-30: 24 rung graders sat at rc=2 "cannot measure" while owning 143 entries
# that were present and gradable in ALL.pl the whole time. rc=2 is the SAFEST hiding place a
# partial grader has — greens get audited and reds get triaged, but a refusal is DESIGNED to be
# non-alarming, so nobody re-examines it (hq_C's shape: a partial grader hides best behind a
# non-green verdict; neither audit path ever checks the DENOMINATOR).
# The fallback materializes this family back out of ALL.* and hands the SAME downstream logic a
# real suite pair, so each script keeps its own --modes and its own verdict accounting unchanged.
# ⛔ KEYED ON THE `origin` COLUMN, never the entry name and never a family-name prefix: origin is
# the durable provenance link and survives the renames consolidation performs (extract-family's
# own docstring: family membership comes from the CSV, not from a name convention).
if [ ! -f "$SNO" ] || [ ! -f "$REF" ]; then
    _ALLP="$CORPUS/ALL.pl"; _ALLR="$CORPUS/ALL.ref"; _ALLC="$CORPUS/ALL.csv"
    if [ -f "$_ALLP" ] && [ -f "$_ALLR" ] && [ -f "$_ALLC" ]; then
        _absdir="$(mktemp -d)"; _n=0
        for _fam in $(python3 -c "import csv,sys; print(chr(10).join(sorted({r['family'] for r in csv.DictReader(open(sys.argv[1])) if (r['origin'] or '').startswith(sys.argv[2])})))" "$_ALLC" "$FAMILY"); do
            if python3 "$HERE/corpus_suite_harness.py" extract-family "$_ALLP" "$_ALLR" "$_ALLC" "$_fam" "$_absdir/p_${_n}.pl" "$_absdir/p_${_n}.ref" >/dev/null 2>&1; then _n=$((_n+1)); fi
        done
        if [ "$_n" -gt 0 ]; then
            cat "$_absdir"/p_*.pl > "$_absdir/FAM.pl"; cat "$_absdir"/p_*.ref > "$_absdir/FAM.ref"
            SNO="$_absdir/FAM.pl"; REF="$_absdir/FAM.ref"
            trap 'rm -rf "$_absdir"' EXIT
            echo "  [absorbed] $FAMILY: materialized $_n family/families out of the flat ALL.* set"
        else
            rm -rf "$_absdir"
        fi
    fi
fi
if [ ! -f "$SNO" ] || [ ! -f "$REF" ]; then
    echo "REFUSE (rc=2): $FAMILY suite not found (expected $SNO / $REF) -- cannot measure, not a pass"; exit 2
fi

out=$(python3 "$HERE/corpus_suite_harness.py" run "$SNO" "$REF" --lang prolog --modes m3,m4 2>&1)
echo "$out" | grep -v '^SUITE_BOARD'
board=$(echo "$out" | grep '^SUITE_BOARD')
[ -n "$board" ] || { echo "REFUSE (rc=2): harness produced no SUITE_BOARD line -- cannot measure, not a pass"; exit 2; }
BAD=0; PASSN=0
for m in m3 m4; do
  for k in fail crash hang unproven; do BAD=$((BAD + $(echo "$board" | grep -oP "${m}_${k}=\K[0-9]+"))); done
  PASSN=$((PASSN + $(echo "$board" | grep -oP "${m}_pass=\K[0-9]+")))
done
echo ""
echo "PASS=$PASSN FAIL=$BAD"
[ "$BAD" -eq 0 ]
