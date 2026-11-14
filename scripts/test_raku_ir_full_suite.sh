#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib_one_runner.sh" && one_runner_guard "${0##*/}" || exit 2
# ../harness/scripts/test_raku_ir_full_suite.sh — Raku rungs-suite run sweep, both modes, via corpus_suite_harness.py.
# Re-pointed off the retired test/raku rung tree (row test-raku-ir-full-suite-skips-rc-0-when-its-population-
# directory-is-absent): the old TRACK-4 population never existed under the one-flat-suite corpus reorg, so this
# always printed "SKIP ... rc=0" -- a never-ran reading as green (the archived ruling record R-20, FINDING-2026-08-30-hq_B).
# Population is the rungs pair corpus/tests/raku/ALL.raku + ALL.ref. An absent population REFUSES rc=2 -- it
# is never silently skipped.
# ⛔ --modes m3,m4 EXPLICITLY: --lang raku alone defaults the harness to the ast dump instrument. Every entry is graded in
# both modes -- there is no modes column (Lon 2026-09-23, R-1218/1230).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib_paths.sh"   # S4E_SCRIP, S4E_CORPUS, S4E_HARNESS, S4E_GITHUB: the absolute model, each its sibling until its one-disk checkout stands (row harness-corpus-and-harness-live-once-on-disk-one-seat-owns-them)
S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
SNO="$S4E_CORPUS/tests/raku/ALL.raku"
REF="$S4E_CORPUS/tests/raku/ALL.ref"

if { [ ! -f "$SNO" ] || [ ! -f "$REF" ]; } && [ ! -f "$(dirname "$SNO")/MULTI-LINERS.md" ] && [ ! -f "$(dirname "$SNO")/ONE-LINERS.raku" ]; then   # format 2 is read under the same line (CIO-24 f)
    echo "⛔ REFUSING (rc=2): raku rungs suite population absent -- expected $SNO + $REF" >&2
    exit 2
fi

if out=$(python3 "$HERE/corpus_suite_harness.py" run "$SNO" "$REF" --lang raku --modes m3,m4 2>&1); then rc=0; else rc=$?; fi
echo "$out"
run=$(printf '%s\n' "$out" | grep '^SUITE_BOARD ' || true)
m3p=$(printf '%s\n' "$run" | grep -oE 'm3_pass=[0-9]+' | head -1 | cut -d= -f2 || true)
m3f=$(printf '%s\n' "$run" | grep -oE 'm3_fail=[0-9]+' | head -1 | cut -d= -f2 || true)
m4p=$(printf '%s\n' "$run" | grep -oE 'm4_pass=[0-9]+' | head -1 | cut -d= -f2 || true)
m4f=$(printf '%s\n' "$run" | grep -oE 'm4_fail=[0-9]+' | head -1 | cut -d= -f2 || true)
pass=$(( ${m3p:-0} + ${m4p:-0} ))
fail=$(( ${m3f:-0} + ${m4f:-0} ))
echo "PASS=${pass} FAIL=${fail}"
exit "$rc"
