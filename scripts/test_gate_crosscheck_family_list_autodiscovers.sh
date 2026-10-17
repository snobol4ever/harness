#!/usr/bin/env bash
export S4E_ONE_RUNNER_FIXTURE="gate arm ${0##*/}: a runner invoked as an instrument fixture, not a board (CEO-523)"
# ../harness/scripts/test_gate_crosscheck_family_list_autodiscovers.sh -- row corpus-suite-family-list-should-autodiscover.
# test_corpus_snobol4.sh's suite-family list is a hardcoded `for family in ...` literal (SCRIP 1d38f034,
# hq_P s277): a suite .sno/.ref pair that lands on disk but is never added to that list is INVISIBLE to the
# board -- not FAIL, not MISSING, simply never iterated -- which is exactly how 98 entries (19 whole families)
# silently left the SNOBOL4 board on 2026-08-27 while the gate still printed "GATE OK ... MISSING=0".
# This gate CONSTRUCTS that exact condition hermetically (a probe suite pair certain not to be in the
# runner's current list, in an otherwise-empty scratch corpus so every hardcoded name/demo path resolves to
# nothing -- MISSING, not FAIL, and irrelevant to the signal below) and asserts the runner does NOT silently
# ignore the probe: either its printed totals grade it (auto-discovery landed), or its output explicitly
# names it as unregistered/undiscovered (a loud consistency check landed instead). Either cure is acceptable;
# silence is not.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER="${RUNNER:-$HERE/test_corpus_snobol4.sh}"
[ -f "$RUNNER" ] || { echo "⛔ GATE CANNOT RUN: no runner at $RUNNER"; exit 2; }
[ -x "$HERE/../../SCRIP/scrip" ] || { echo "⛔ GATE CANNOT RUN: scrip not built at $HERE/../../SCRIP/scrip"; exit 2; }

FAMILIES="$(grep -oP '(?<=for family in )[^;]+' "$RUNNER" | head -1)"
[ -n "$FAMILIES" ] && { for _n in $FAMILIES; do [ "$(basename "$_n")" = "zzz_gate_probe" ] && { echo "⛔ GATE CANNOT RUN: probe name collided with a real family"; exit 2; }; done; }

GATE_WORK="$(mktemp -d)"
trap 'rm -rf "$GATE_WORK"' EXIT
ROOT="$GATE_WORK/root"
PROBE="zzz_gate_probe_$$"
mkdir -p "$ROOT/corpus/demos/snobol4" "$ROOT/corpus/tests/snobol4/beauty_suite" "$ROOT/corpus/crosscheck" \
         "$ROOT/corpus/include" "$ROOT/corpus/tests/snobol4/crosscheck"
printf ' OUTPUT = "GATE_PROBE_OK";END;* %s\n' "$PROBE" > "$ROOT/corpus/tests/snobol4/crosscheck/${PROBE}.sno"
printf 'GATE_PROBE_OK\n' > "$ROOT/corpus/tests/snobol4/crosscheck/${PROBE}.ref"

out="$(S4E_HOME="$ROOT" timeout -k 5 60 bash "$RUNNER" 2>&1)"

mentions_probe=0
grep -q "$PROBE" <<<"$out" && mentions_probe=1
pass3="$(grep -oP 'mode-3 \(--run\):\s*PASS=\K[0-9]+' <<<"$out")"

if [ "$mentions_probe" -eq 1 ]; then
    echo "✅ GATE OK: the runner's output names the unregistered probe family ($PROBE) instead of silently omitting it"
    exit 0
fi
if [ -n "${pass3:-}" ] && [ "$pass3" -ge 1 ]; then
    echo "✅ GATE OK: the unregistered probe family was graded anyway (PASS3=$pass3) -- auto-discovery is live"
    exit 0
fi
echo "⛔ NOT DONE: probe family '$PROBE' existed on disk (valid one-line suite pair, would PASS if graded) but"
echo "   the runner's output neither names it nor counts it toward PASS3 -- it is silently invisible, exactly"
echo "   the hand-maintained-list omission bug from SCRIP 1d38f034. The durable fix (discover crosscheck/tests"
echo "   suite pairs by globbing the filesystem instead of naming them in a literal list, or at minimum a loud"
echo "   consistency check naming any on-disk pair absent from the list) has not landed yet."
echo "--- runner output (mode-3/mode-4 summary lines) ---"
grep -E '^mode-[34]|MISSING' <<<"$out"
exit 1
