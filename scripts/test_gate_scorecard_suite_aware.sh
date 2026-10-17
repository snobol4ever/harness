#!/usr/bin/env bash
export S4E_ONE_RUNNER_FIXTURE="gate arm ${0##*/}: a runner invoked as an instrument fixture, not a board (CEO-523)"
# ../harness/scripts/test_gate_scorecard_suite_aware.sh -- row scorecard-probes-misc-suite-awareness.
# scorecard_snobol4.sh's probes_misc row globs `$CORPUS/probe -name *.sno -not -path */bb/*` -- a converted
# probe family (probe/<family> loose files -> tests/snobol4/probe/<family>.{sno,ref}, corpus-suites-consolidation's
# probe-consolidate-* rows) moves OUT of that root into a sibling root the glob never reaches. `run_one`'s own
# SUITE-FILE GUARD also refuses to grade a suite .sno whole (it is a container, not a program), so simply widening
# the glob is not a fix either -- it needs its ENTRY count. Measured live 2026-08-27 (seat15,
# .github/FINDING-2026-08-27-seat15-probe-conformance-already-shrank-probes-misc-fuzz-stays-blocked.md):
# `probe-consolidate-conformance` had already landed and cost 92 witnesses, silently, uncorrected.
# This gate CONSTRUCTS that exact condition hermetically -- a scratch corpus with ONE loose probe witness
# (findable today, the sanity anchor) plus ONE converted suite family of 3 entries sitting where real
# conversions land (tests/snobol4/probe/), all green -- and asserts probes_misc's reported denominator and
# pass counts include the suite's entries, not just the loose file. TWO-PART PROOF (RULES.md): run this against
# the unfixed script first and confirm it goes RED (N=1, the 3 entries invisible) before curing
# scorecard_snobol4.sh, then confirm GREEN after (N=4, P3=P4=4) -- both halves were run by hand while writing
# this gate; only the property check itself is committed, same shape as
# test_gate_crosscheck_family_list_autodiscovers.sh's sibling gate for the crosscheck/ side of this fan-out.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SC="$(cd "$HERE/../../SCRIP" && pwd)"
SCORECARD="${SCORECARD:-$HERE/scorecard_snobol4.sh}"
[ -f "$SCORECARD" ] || { echo "⛔ GATE CANNOT RUN: no scorecard at $SCORECARD"; exit 2; }
[ -x "$SC/scrip" ] || { echo "⛔ GATE CANNOT RUN: scrip not built at $SC/scrip"; exit 2; }
[ -f "$HERE/corpus_suite_harness.py" ] || { echo "⛔ GATE CANNOT RUN: corpus_suite_harness.py missing at $HERE"; exit 2; }

GATE_WORK="$(mktemp -d)"
trap 'rm -rf "$GATE_WORK"' EXIT
ROOT="$GATE_WORK/root"
mkdir -p "$ROOT/corpus/probe/gateloose" "$ROOT/corpus/tests/snobol4/probe"

# ---- the sanity anchor: one real loose witness, findable today regardless of the fix ----
printf ' OUTPUT = "GATE_LOOSE_OK"\nEND\n' > "$ROOT/corpus/probe/gateloose/one.sno"
printf 'GATE_LOOSE_OK\n' > "$ROOT/corpus/probe/gateloose/one.ref"

# ---- the converted family: 3 entries, format-A one-line join (verified against a real committed suite
# file's own join shape -- corpus/tests/snobol4/tests/snobol4/probe_loose/dv.sno -- before being baked in here: END is written
# flush at column 1 in the source, which the harness's own column-1 "labeled" heuristic then joins with NO
# pad space, i.e. `;END`, not `; END`) ----
printf ' OUTPUT = "GATE_ENTRY_1";END;* gatefam_e1\n OUTPUT = "GATE_ENTRY_2";END;* gatefam_e2\n OUTPUT = "GATE_ENTRY_3";END;* gatefam_e3\n' \
  > "$ROOT/corpus/tests/snobol4/probe/gatefam.sno"
printf 'GATE_ENTRY_1\nGATE_ENTRY_2\nGATE_ENTRY_3\n' > "$ROOT/corpus/tests/snobol4/probe/gatefam.ref"

out="$GATE_WORK/results"
S4E_HOME="$ROOT" timeout -k 5 120 bash "$SCORECARD" run --suites probes_misc --out "$out" --force >"$GATE_WORK/run.log" 2>&1
report="$(S4E_HOME="$ROOT" bash "$SCORECARD" report "$out" 2>&1)"
row="$(grep -E '^probes_misc ' <<<"$report" | head -1)"

if [ -z "$row" ]; then
  echo "⛔ GATE CANNOT RUN: no probes_misc row in the report at all -- the scratch fixture or invocation is broken, not the mechanism under test."
  echo "--- run.log ---"; tail -40 "$GATE_WORK/run.log"
  echo "--- report ---"; printf '%s\n' "$report"
  exit 2
fi

# columns: SUITE W N M3ok M4ok m3% m4% SCORE UNSCR ...
set -- $row
n="$3" m3ok="$4" m4ok="$5"

if [ "${n:-0}" -eq 4 ] && [ "${m3ok:-0}" -eq 4 ] && [ "${m4ok:-0}" -eq 4 ]; then
  echo "✅ GATE OK: probes_misc counted 4 witnesses (1 loose + 3 suite-derived entries), all PASS both modes -- the converted family is NOT invisible."
  exit 0
fi

echo "⛔ NOT DONE: probes_misc's denominator/pass-counts do not include the converted suite family's entries."
echo "   Expected N=4 M3ok=4 M4ok=4 (1 loose witness + 3 entries from tests/snobol4/probe/gatefam.sno)."
echo "   Got:      N=${n:-?} M3ok=${m3ok:-?} M4ok=${m4ok:-?}"
if [ "${n:-0}" -eq 1 ]; then
  echo "   N=1 means the fixture's 3-entry converted family is exactly as invisible as tests/snobol4/probe_loose/conformance's real"
  echo "   92 witnesses were (seat15's FINDING) -- probes_misc is still only seeing the loose leftover."
fi
echo "--- probes_misc row ---"
printf '%s\n' "$row"
echo "--- run.log tail ---"
tail -20 "$GATE_WORK/run.log"
exit 1
