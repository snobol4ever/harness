#!/usr/bin/env bash
export S4E_ONE_RUNNER_FIXTURE="gate arm ${0##*/}: a runner invoked as an instrument fixture, not a board (R-523)"
# ../harness/scripts/test_gate_scorecard_suite_aware.sh -- row scorecard-probes-misc-suite-awareness, re-cut by CIO-43 (2026-11-10).
# scorecard_snobol4.sh's probes_misc row globs `$CORPUS/probe -name *.sno -not -path */bb/*` for loose witnesses; a probe family that
# was converted to the suite format left that root, and since 2026-08-29 every converted family is a family of the master
# (tests/snobol4/ALL.sno, its index ALL.csv). `run_one`'s own SUITE-FILE GUARD refuses to grade a suite .sno whole (it is a container,
# not a program), so widening the glob is not a fix -- the scorecard needs the ENTRY count, read from the master by family (the master
# fold, MASTER_FOLD in the scorecard). Measured live 2026-08-27 (seat15,
# .github/FINDING-2026-08-27-seat15-probe-conformance-already-shrank-probes-misc-fuzz-stays-blocked.md): a converted family cost 92
# witnesses, silently, uncorrected.
# This gate CONSTRUCTS that condition hermetically: a scratch corpus (its own git repo, so the harness reads it as a fixture and not
# the shared population, with a scratch progress table) holding ONE loose probe witness (the sanity anchor) and a five-entry master:
# three entries of family probe_gatefam (probes_misc's), one of probe_bbgate (bb_probes's, never probes_misc's) and one of
# probe_loose_gate (never under probes_misc's roots), all green. It asserts probes_misc's denominator and pass counts are exactly the
# loose file plus the three probe_gatefam entries: N=4 M3ok=4 M4ok=4. N=1 is the fold missing; N=5 or 6 is the partition leaking.
# TWO-PART PROOF (RULES.md): RED (N=1) against the scorecard of harness ffb49ba8, whose fold read a probe folder the master replaced;
# GREEN (N=4) after the master fold -- both halves run by hand on the landing of CIO-43's row.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SC="$(cd "$HERE/../../SCRIP" && pwd)"
SCORECARD="${SCORECARD:-$HERE/scorecard_snobol4.sh}"
[ -f "$SCORECARD" ] || { echo "⛔ GATE CANNOT RUN: no scorecard at $SCORECARD"; exit 2; }
[ -x "$SC/scrip" ] || { echo "⛔ GATE CANNOT RUN: scrip not built at $SC/scrip"; exit 2; }
[ -f "$HERE/corpus_suite_harness.py" ] || { echo "⛔ GATE CANNOT RUN: corpus_suite_harness.py missing at $HERE"; exit 2; }
[ -f "$HERE/util_suite_partition.py" ] || { echo "⛔ GATE CANNOT RUN: util_suite_partition.py missing at $HERE"; exit 2; }

GATE_WORK="$(mktemp -d)"
trap 'rm -rf "$GATE_WORK"' EXIT
ROOT="$GATE_WORK/root"
T4="$ROOT/corpus/tests/snobol4"
mkdir -p "$ROOT/corpus/probe/gateloose" "$T4"
git init -q "$ROOT/corpus" || { echo "⛔ GATE CANNOT RUN: git init of the scratch corpus failed"; exit 2; }
export S4E_PROGRESS_DB="$GATE_WORK/progress.tsv"

# ---- the sanity anchor: one real loose witness, findable regardless of the fold ----
printf ' OUTPUT = "GATE_LOOSE_OK"\nEND\n' > "$ROOT/corpus/probe/gateloose/one.sno"
printf 'GATE_LOOSE_OK\n' > "$ROOT/corpus/probe/gateloose/one.ref"

# ---- the scratch master: written by the harness's own Entry/write_suite (never a second suite-grammar writer), its index carrying
# the live master's header, and its partition built by util_suite_partition.py (the harness's --partition reads it) ----
python3 -I - "$HERE" "$T4" <<'PY' || { echo "⛔ GATE CANNOT RUN: the scratch master could not be written"; exit 2; }
import sys, os, csv
sys.path.insert(0, sys.argv[1]); import corpus_suite_harness as h
T = sys.argv[2]
hdr = ["rank", "entry", "origin", "family", "kind", "xfail", "n_lines", "heap_kb", "stack_kb", "compile_args", "run_args"]
fx = [("gatefam_e1", "probe_gatefam"), ("gatefam_e2", "probe_gatefam"), ("gatefam_e3", "probe_gatefam"),
      ("gatebb_e1", "probe_bbgate"), ("gateloose_e1", "probe_loose_gate")]
h.write_suite([h.Entry("block", 1, n, [" OUTPUT = '%s'" % n.upper(), "END"], [n.upper()]) for n, _ in fx],
              os.path.join(T, "ALL.sno"), os.path.join(T, "ALL.ref"))
with open(os.path.join(T, "ALL.csv"), "w", newline="") as f:
    w = csv.writer(f); w.writerow(hdr)
    for k, (n, fam) in enumerate(fx, 1):
        w.writerow([k, n, fam + "__" + n, fam, "block", 0, 2, "", "", "", ""])
PY
python3 "$HERE/util_suite_partition.py" build "$T4/ALL.csv" >/dev/null 2>&1 || { echo "⛔ GATE CANNOT RUN: util_suite_partition.py build refused the scratch master"; exit 2; }

out="$GATE_WORK/results"
S4E_HOME="$ROOT" timeout -k 5 180 bash "$SCORECARD" run --suites probes_misc --out "$out" --force >"$GATE_WORK/run.log" 2>&1
report="$(S4E_HOME="$ROOT" bash "$SCORECARD" report "$out" 2>&1)"
row="$(grep -E '^probes_misc ' <<<"$report" | head -1)"

if [ -z "$row" ]; then
  echo "⛔ GATE CANNOT RUN: no probes_misc row in the report at all -- the scratch fixture or invocation is broken, not the mechanism under test."
  echo "--- run.log ---"; tail -40 "$GATE_WORK/run.log"
  echo "--- noise.log ---"; tail -20 "$out/noise.log" 2>/dev/null
  echo "--- report ---"; printf '%s\n' "$report"
  exit 2
fi

# columns: SUITE W N M3ok M4ok m3% m4% SCORE UNSCR ...
set -- $row
n="$3" m3ok="$4" m4ok="$5"

if [ "${n:-0}" -eq 4 ] && [ "${m3ok:-0}" -eq 4 ] && [ "${m4ok:-0}" -eq 4 ]; then
  echo "✅ GATE OK [test_gate_scorecard_suite_aware]: probes_misc counted 4 witnesses (1 loose + 3 master entries of probe_gatefam), all PASS both modes; the bb and loose families stayed out."
  exit 0
fi

echo "⛔ GATE FAIL [test_gate_scorecard_suite_aware]: probes_misc's denominator/pass-counts are not the loose witness plus its master family."
echo "   Expected N=4 M3ok=4 M4ok=4 (1 loose witness + the 3 entries of the master family probe_gatefam)."
echo "   Got:      N=${n:-?} M3ok=${m3ok:-?} M4ok=${m4ok:-?}"
if [ "${n:-0}" -eq 1 ]; then
  echo "   N=1 means the master's family is exactly as invisible as the converted conformance family's real 92 witnesses were"
  echo "   (seat15's FINDING) -- probes_misc is still only seeing the loose leftover."
elif [ "${n:-0}" -gt 4 ]; then
  echo "   N>4 means a family outside probes_misc's partition (probe_bb*, probe_loose_*) leaked into its denominator."
fi
echo "--- probes_misc row ---"
printf '%s\n' "$row"
echo "--- run.log tail ---"
tail -20 "$GATE_WORK/run.log"
echo "--- noise.log tail ---"
tail -10 "$out/noise.log" 2>/dev/null
exit 1
