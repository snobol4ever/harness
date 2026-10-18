#!/usr/bin/env bash
# test_gate_snocone_beauty_suite_reads_every_test_in_both_modes_with_no_xfail.sh -- THE SNOCONE BEAUTY SUITE, GRADED EVERY BUILD
#
# LON 2026-09-23 15:4x CDT, in-chat to the ceo, verbatim: "Get snocone beauty test suite working first." (row snocone-the-beauty-
# test-suite-reads-twenty-of-twenty-in-both-modes-with-no-xfail-marker-lons-first, CEO-1212). THE SUITE is the banner-block container
# corpus/tests/snocone/beauty_modules.sc + .ref: the Snocone beauty subsystem tests of SC-19..SC-22 (test_Gen .. test_tree), each a
# driver over the bootstrap runtime it names. This gate runs it through the harness in BOTH modes and is GREEN only when every test
# passes in m3 AND m4 and neither file carries an XFAIL banner (an xfail counts as a fail, RULES.md FACT RULE; the Snocone lane bans it).
#
# ⛔ WHY THIS FILE REPLACES TWO RUNNERS. It is test_beauty_snocone_all_modes.sh renamed and rewritten; its sibling
# test_beauty_snocone_subsystems.sh was deleted in the same commit. Both read corpus/snocone/demo/snobol4/beauty/test, a directory the
# 2026-08-29 corpus re-grid removed, so from that day the suite was graded by NOTHING: the first skipped every subsystem (and later
# refused), the second skipped every name it was given. The tests were folded into the container; one runner over the container is
# the whole grader, and a single named test is `corpus_suite_harness.py extract <container> <ref> test_<name> <out>` and run.
# ⛔ WHY A test_gate_ NAME: only a test_gate_*.sh is in util_gate_wiring.py's population, so only a gate is held by the wiring floor.
# A suite that went ungraded for three weeks because its runner pointed at a dead path is precisely what the floor exists to stop.
#
# FAIL-ONCE, MEASURED 2026-09-23 by hq_snocone on ONE binary through the zd-planner killswitches: SCRIP_ZD_REPL_FREE=0 reds test_Qize
# and test_case, SCRIP_ZD_OBACK=0 reds test_strings and test_trace, SCRIP_ZD_MATCHDIAMOND=0 reds test_trace -- each a SIGSEGV or a
# wrong answer in both modes. RE-MEASURED 2026-10-09 by hq_snocone (SCRIP ddd1d8bd7, the old container and the rungs view alike):
# OBACK=0 and MATCHDIAMOND=0 no longer red any test; REPL_FREE=0 still reds test_Qize and test_case (m3 18/20, m4 18/20), so
# `SCRIP_ZD_REPL_FREE=0 bash $0` must print RED. It grades output against the refs, never rc alone.
# THE KILLSWITCH IS DELETED (hq_zetas 2026-10-17, the spine flip, under the cto's review: ZETA HAS NO MODES, and CEO-1680
# allows no seam in SCRIP for a test): every killswitch named here is gone and the
# fail-once readings above stand as history.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
M="$S4E/corpus/tests/snocone"
[ -x "$ROOT/scrip" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $ROOT/scrip -- run make"; exit 2; }
{ [ -f "$M/ALL.sc" ] && [ -f "$M/ALL.ref" ] && [ -f "$M/ALL.csv" ]; } || { echo "⛔ GATE REFUSE(2) [$G]: the Snocone rungs (ALL.sc, ALL.ref, ALL.csv) are missing under $M"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
# ⛔ THE SUITE IS A VIEW OVER THE RUNGS (row snocone-the-beauty-suite-folds-into-sncm-..., hq_snocone 2026-10-09): the twenty tests were
# absorbed into corpus/tests/snocone/ALL.* with origin beauty_modules__test_<name> and the loose container deleted, so the gate extracts
# the family from the rungs (corpus_suite_harness.py extract-family, the one authority) and grades that. It grades OUTSIDE the shared
# corpus (coo 2026-09-27, ceo CEO-1306): the rungs are a Snocone board the one-runner guard admits for hq_snocone alone, and a gate is an
# invariant check any seat runs, never a lane's board (CEO-1232). The tests inline their code (no -INCLUDE), so the extract stands alone.
S="$T/beauty_modules.sc"; R="$T/beauty_modules.ref"
python3 "$HERE/corpus_suite_harness.py" extract-family "$M/ALL.sc" "$M/ALL.ref" "$M/ALL.csv" beauty_modules "$S" "$R" >/dev/null 2>&1 || { echo "⛔ GATE REFUSE(2) [$G]: could not extract family beauty_modules from the rungs"; exit 2; }
out=$(cd "$ROOT" && S4E_PROGRESS_DB="$T/progress.tsv" timeout -k 5 1200 python3 "$HERE/corpus_suite_harness.py" run "$T/$(basename "$S")" "$T/$(basename "$R")" --lang snocone --modes m3,m4 2>&1); rc=$?
line=$(printf '%s\n' "$out" | grep '^SUITE_BOARD family=beauty_modules' | tail -1)
[ -n "$line" ] || { printf '%s\n' "$out" | tail -5; echo "⛔ GATE REFUSE(2) [$G]: the harness printed no SUITE_BOARD line (rc=$rc) -- nothing was graded"; exit 2; }
field() { printf '%s' "$line" | grep -oE " $1=[0-9]+" | cut -d= -f2; }
t=$(field total); p3=$(field m3_pass); p4=$(field m4_pass)
[ "${t:-0}" -gt 0 ] || { echo "⛔ GATE REFUSE(2) [$G]: the container graded zero tests -- a board over nothing is not a pass"; exit 2; }
x=$(cat "$S" "$R" | grep -cE '^/\*-+ [0-9]+ .*XFAIL')
if [ "$p3" = "$t" ] && [ "$p4" = "$t" ] && [ "$x" = 0 ]; then
    echo "GATE PASS [$G]: the Snocone beauty suite reads m3 $p3/$t and m4 $p4/$t with no XFAIL banner"; RC=0
else
    printf '%s\n' "$out" | grep -E '^  (FAIL|CRASH|HANG|XFAIL|XPASS|UNPROVEN)' | head -20
    echo "GATE FAIL(1) [$G]: m3 $p3/$t, m4 $p4/$t, XFAIL banners $x -- every test must pass in both modes and no banner may say XFAIL"; RC=1
fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY) corpus=$(git -C "$S4E/corpus" rev-parse --short HEAD 2>/dev/null)$(git -C "$S4E/corpus" diff --quiet 2>/dev/null || echo -DIRTY)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
