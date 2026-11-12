#!/usr/bin/env bash
export S4E_ONE_RUNNER_FIXTURE="gate arm ${0##*/}: a runner invoked as an instrument fixture, not a board (R-523)"
# ../harness/scripts/test_gate_probe_suite_grading_path.sh -- DONE-WHEN for row probe-suite-grading-path.
# Before this row: there was NO working path to grade a probe/-sourced suite file
# (corpus-suite-family-list-should-autodiscover's autodiscovery was crosscheck/-scoped only, and
# scorecard_snobol4.sh's probes_misc ran a suite file whole -- a category error per
# corpus_suite_harness.py's own top-of-file warning: it fails two ways that both LOOK like real
# defects). TWO-PART PROOF (RULES.md): a real probe suite family must actually grade entry-by-entry
# on the SNOBOL4 board (POSITIVE), and the scorecard must REFUSE (rc=2, named reason) on a suite file
# it cannot enumerate rather than silently mis-grade it (NEGATIVE). REFUSES rc=2 when it cannot
# measure -- never skip-as-success.
# ⭐ RE-CUT 2026-11-10 (CIO-43, officer_03): the probe suite folder is gone; every probe family is a family of
# the snobol4 master. THE POSITIVE ARM TAKES ITS FAMILY THROUGH THE HARNESS READER AND OPENS NO MASTER FILE
# ITSELF: the family column comes from the harness's own index reader (_fmt2_read_csv, the reader format 2
# keeps), and the entries are graded by `run` over the master's ALL.sno ALL.ref command line with an entry
# partition -- the harness follows that command line into ONE-LINERS.sno, ONE-LINERS.out and MULTI-LINERS.md at the regroup
# (fmt2_dir_of), which a find, cat, grep or test -f here would not. The family is the first probe_* family by
# name with 2 to 8 entries: more than one entry proves entry-by-entry grading, and at most eight is a seat's
# own test, admitted for every seat (R-1893). The NEGATIVE arm plants its suite file in bb_probes's loose
# root, because probes_misc's loose root is retired (CIO-43).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
CORPUS="$S4E/corpus"
SUITES="$CORPUS/tests/snobol4"
HARNESS="$HERE/corpus_suite_harness.py"
[ -x "$HERE/../../SCRIP/scrip" ] || { echo "⛔ GATE CANNOT RUN: scrip not built at $HERE/../../SCRIP/scrip"; exit 2; }
[ -f "$HARNESS" ] || { echo "⛔ GATE CANNOT RUN: corpus_suite_harness.py missing at $HARNESS"; exit 2; }
fail=0

# ---- POSITIVE: a probe family of the master grades clean, entry-by-entry ----
pick="$(python3 -I -c 'import sys, collections
sys.path.insert(0, sys.argv[1]); import corpus_suite_harness as h
_, rows = h._fmt2_read_csv(sys.argv[2]); fam = collections.OrderedDict()
for r in rows: fam.setdefault(r["family"], []).append(r["entry"])
ok = sorted(f for f, e in fam.items() if f.startswith("probe_") and 2 <= len(e) <= 8)
if ok: print(ok[0], ",".join("entry:" + e for e in fam[ok[0]]))' "$HERE" "$SUITES" 2>/dev/null)"
[ -n "$pick" ] || { echo "⛔ GATE CANNOT RUN: the harness index reader names no probe_* family of 2 to 8 entries in $SUITES -- nothing to demonstrate the grading path on"; exit 2; }
fam="${pick%% *}"; parts="${pick#* }"
board="$(python3 "$HARNESS" run "$SUITES/ALL.sno" "$SUITES/ALL.ref" --lang snobol4 --modes m3,m4 --partition "$parts" 2>&1 | grep '^SUITE_BOARD ')"
if [ -z "$board" ]; then
    echo "⛔ GATE CANNOT RUN: corpus_suite_harness.py produced no SUITE_BOARD line for the master family $fam"
    exit 2
elif echo "$board" | grep -qE 'm[34]_(fail|crash|hang|unproven|skip)=[1-9]'; then
    echo "⛔ NOT DONE: the master family $fam graded with failures: $board"
    fail=1
else
    total="$(echo "$board" | grep -oE ' total=[0-9]+' | cut -d= -f2)"
    if [ "${total:-0}" -lt 2 ]; then
        echo "⛔ NOT DONE: the master family $fam graded ${total:-0} entries, not entry-by-entry: $board"
        fail=1
    else
        echo "✅ POSITIVE: the master family $fam grades entry-by-entry on the SNOBOL4 board, clean: $board"
    fi
fi

# ---- NEGATIVE: the scorecard (bb_probes) REFUSES (rc=2, named reason) on a suite file it cannot enumerate ----
SCRATCH="$(mktemp -d)"; trap 'rm -rf "$SCRATCH"' EXIT
mkdir -p "$SCRATCH/library/probe_reference/bb"
printf ' OUTPUT = "GATE_PROBE_A";* zzz_gate_e1\n' > "$SCRATCH/library/probe_reference/bb/zzz_gate_suite.sno"
out="$(CORPUS="$SCRATCH" timeout -k 5 60 bash "$HERE/scorecard_snobol4.sh" run --suites bb_probes --out "$SCRATCH/out" --force 2>&1)"
rc=$?
if [ "$rc" -eq 2 ] && grep -q "suite-format file" <<<"$out" && grep -q "zzz_gate_suite.sno" <<<"$out"; then
    echo "✅ NEGATIVE: bb_probes refused (rc=2), naming the unenumerable suite file."
else
    echo "⛔ NOT DONE: bb_probes did not refuse correctly (rc=$rc):"
    echo "$out"
    fail=1
fi

[ "$fail" -eq 0 ] && echo "✅ GATE OK: probe-suite-grading-path -- both directions proven."
exit $fail
