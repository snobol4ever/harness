#!/usr/bin/env bash
export S4E_ONE_RUNNER_FIXTURE="gate arm ${0##*/}: a runner invoked as an instrument fixture, not a board (CEO-523)"
# ../harness/scripts/test_gate_probe_suite_grading_path.sh -- DONE-WHEN for row probe-suite-grading-path.
# Before this row: there was NO working path to grade a probe/-sourced suite file
# (corpus-suite-family-list-should-autodiscover's autodiscovery was crosscheck/-scoped only, and
# scorecard_snobol4.sh's probes_misc ran a suite file whole -- a category error per
# corpus_suite_harness.py's own top-of-file warning: it fails two ways that both LOOK like real
# defects). TWO-PART PROOF (RULES.md): a real probe/ suite family must actually grade entry-by-entry
# on the SNOBOL4 board (POSITIVE), and probes_misc must REFUSE (rc=2, named reason) on a suite file
# it cannot enumerate rather than silently mis-grade it (NEGATIVE). REFUSES rc=2 when it cannot
# measure -- never skip-as-success.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
CORPUS="$S4E/corpus"
SUITES="$CORPUS/tests/snobol4"
HARNESS="$HERE/corpus_suite_harness.py"
[ -x "$HERE/../../SCRIP/scrip" ] || { echo "⛔ GATE CANNOT RUN: scrip not built at $HERE/../../SCRIP/scrip"; exit 2; }
[ -f "$HARNESS" ] || { echo "⛔ GATE CANNOT RUN: corpus_suite_harness.py missing at $HARNESS"; exit 2; }
fail=0

# ---- POSITIVE: at least one probe/ suite family exists and grades clean, entry-by-entry ----
mapfile -t families < <(find "$SUITES/probe" -name '*.sno' 2>/dev/null | sort)
if [ "${#families[@]}" -eq 0 ]; then
    echo "⛔ NOT DONE: zero suite families under $SUITES/probe -- nothing to demonstrate the grading path on."
    fail=1
else
    s_sno="${families[0]}"; s_ref="${s_sno%.sno}.ref"; fam="$(basename "$s_sno" .sno)"
    if [ ! -f "$s_ref" ]; then
        echo "⛔ NOT DONE: $s_sno has no sibling .ref"
        fail=1
    else
        board="$(python3 "$HARNESS" run "$s_sno" "$s_ref" --modes m3,m4 2>&1 | grep '^SUITE_BOARD ')"
        if [ -z "$board" ]; then
            echo "⛔ NOT DONE: corpus_suite_harness.py produced no SUITE_BOARD line for $fam"
            fail=1
        elif echo "$board" | grep -qE 'm[34]_(fail|crash|hang|unproven|skip)=[1-9]'; then
            echo "⛔ NOT DONE: probe/$fam graded with failures: $board"
            fail=1
        else
            total="$(echo "$board" | grep -oE 'total=[0-9]+' | cut -d= -f2)"
            if [ "${total:-0}" -eq 0 ]; then
                echo "⛔ NOT DONE: probe/$fam has zero entries: $board"
                fail=1
            else
                echo "✅ POSITIVE: probe/$fam grades entry-by-entry on the SNOBOL4 board, clean: $board"
            fi
        fi
    fi
fi

# ---- NEGATIVE: probes_misc REFUSES (rc=2, named reason) on a suite file it cannot enumerate ----
SCRATCH="$(mktemp -d)"; trap 'rm -rf "$SCRATCH"' EXIT
mkdir -p "$SCRATCH/probe"
printf ' OUTPUT = "GATE_PROBE_A";* zzz_gate_e1\n' > "$SCRATCH/probe/zzz_gate_suite.sno"
out="$(CORPUS="$SCRATCH" timeout -k 5 60 bash "$HERE/scorecard_snobol4.sh" run --suites probes_misc --out "$SCRATCH/out" --force 2>&1)"
rc=$?
if [ "$rc" -eq 2 ] && grep -q "suite-format file" <<<"$out" && grep -q "zzz_gate_suite.sno" <<<"$out"; then
    echo "✅ NEGATIVE: probes_misc refused (rc=2), naming the unenumerable suite file."
else
    echo "⛔ NOT DONE: probes_misc did not refuse correctly (rc=$rc):"
    echo "$out"
    fail=1
fi

[ "$fail" -eq 0 ] && echo "✅ GATE OK: probe-suite-grading-path -- both directions proven."
exit $fail
