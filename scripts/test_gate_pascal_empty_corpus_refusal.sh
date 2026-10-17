#!/bin/bash
# test_gate_pascal_empty_corpus_refusal.sh -- DONE-WHEN for pascal-m3-empty-corpus-false-pass /
# pascal-m4-empty-corpus-false-pass. Those rows' own literal DONE-WHEN ("bash
# test_gate_pascal_m3.sh"/"_m4.sh") cannot close on this tree: Pascal has ~42-52 real,
# pre-existing, separately-tracked failures (pascal-restore-prezeta's territory), so the plain
# gate exits non-zero regardless of whether THIS specific bug is fixed. This script isolates the
# actual regression the two rows are about: an empty/mistyped CORPUS path must REFUSE (non-zero
# exit), never silently print PASS=0 FAIL=0 and exit 0 -- independent of whatever the real corpus
# currently contains.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EMPTY="$(mktemp -d)"
trap 'rm -rf "$EMPTY"' EXIT

fail=0
# ⛔⭐ `rc != 0` IS NOT A DISCRIMINATOR -- IT ACCEPTS ANY NON-ZERO, INCLUDING ONES THIS FILE IS NOT ABOUT (hq_B
# 2026-09-13, measured, row pascal-gates-report-a-one-runner-refusal-as-an-unpopulated-master). ⭐ THE PROOF, because
# asserting blindness is not measuring it: with the `RUNGS_EXAMINED -eq 0` refusal -- the exact thing this file exists
# to guard -- DELETED OUTRIGHT from both gates on this tree, the old body printed "✅ GATE OK" and exited 0. It was
# satisfied by rc=1, an ORDINARY RED: the absent rungs booked one FAIL and the gate failed its own `[ $FAIL -eq 0 ]`,
# non-zero for a reason that has nothing to do with refusing. A gate that passes over the deletion of the thing it
# guards is not weak, it is blind. ⛔ A FIRST ATTEMPT AT THIS PROOF RAN THE STRIPPED COPIES OUT OF A SCRATCH DIRECTORY
# AND WAS CONTAMINATED -- they refused rc=2 on the stale-binary preflight ("artifact not built") before reaching any
# arm, so it demonstrated a real blindness by an accidental mechanism and would have been quoted for the wrong one.
# The measurement above is the in-tree one. ⭐ It is the cto's control_f shape from the same evening: a NAME asserting
# a role the measurement contradicts. ARM 1 now asserts WHICH refusal fired, by message; ARM 2 is the positive control
# that gives ARM 1 its power -- the same message must be ABSENT on the real, populated corpus, or ARM 1 is matching
# something that fires unconditionally, which is a way to be green about nothing.
MARK='0 rungs entries examined'
for mode in m3 m4; do
    out="$(CORPUS="$EMPTY" timeout -k 5 600 bash "$HERE/test_gate_pascal_$mode.sh" 2>&1)"
    rc=$?
    if [ $rc -eq 0 ]; then
        echo "⛔ REGRESSION ARM 1: test_gate_pascal_$mode.sh exited 0 on an EMPTY corpus (should refuse non-zero)" >&2
        echo "$out" >&2
        fail=1
    elif ! grep -qF "$MARK" <<<"$out"; then
        echo "⛔ REGRESSION ARM 1: test_gate_pascal_$mode.sh refused an EMPTY corpus (rc=$rc) but NOT with the empty-rungs refusal" >&2
        echo "   expected its message to contain: $MARK" >&2
        echo "   ⛔ a non-zero exit for some OTHER reason is exactly the blindness this arm exists to stop -- read the output:" >&2
        echo "$out" | sed 's/^/     /' >&2
        fail=1
    fi
    # ARM 2 (positive control): the empty-corpus message must NOT appear against the REAL corpus. Without this, ARM 1
    # passes on a gate that prints it unconditionally, which is the state this file was in until today.
    real="$(timeout -k 5 600 bash "$HERE/test_gate_pascal_$mode.sh" 2>&1)"
    if grep -qF "$MARK" <<<"$real"; then
        echo "⛔ REGRESSION ARM 2 (positive control): test_gate_pascal_$mode.sh prints the EMPTY-rungs refusal against the REAL, populated corpus" >&2
        echo "   -- so ARM 1 proves nothing: the message fires whatever CORPUS points at. Populated rungs:" >&2
        ls -l "${S4E_HOME:-$(cd "$HERE/../.." && pwd)}/corpus/tests/pascal/ALL.pas" >&2
        fail=1
    fi
done

if [ $fail -eq 0 ]; then
    echo "✅ GATE OK: both test_gate_pascal_m3.sh and test_gate_pascal_m4.sh refuse an empty CORPUS with the EMPTY-RUNGS message, and do NOT print it against the real populated corpus"
fi
exit $fail
