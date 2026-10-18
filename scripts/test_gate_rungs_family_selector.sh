#!/usr/bin/env bash
# test_gate_rungs_family_selector.sh — the executable DONE-WHEN for row
# `master-builder-delete-absorbed-family-selector` (ceo mint 2026-08-30).
#
# WHAT IT PROVES, and why each arm exists (hq_P's measurement at mint time): --delete-absorbed is
# all-or-nothing per LANGUAGE while FLEET-16 splits one language's consolidation across seats --
# icon has 208 verified-deletable families of which 153 are parser_* under a live seat lock, so the
# one authorized delete command would wipe another seat's working set and nobody could safely run
# it. `--family <prefix>` / `--only fam,fam` scope deletion to a named subset of the SAME-INVOCATION
# verified list.
#   A. POSITIVE, SCOPED — `--family <prefix>` deletes ONLY the matching subset; a verified family
#      outside the prefix survives on disk, untouched (not merely unverified — verified but out of
#      scope this run).
#   B. NEGATIVE — a prefix matching zero verified families REFUSES rc=2 and deletes nothing. A
#      typo'd prefix must never silently no-op while --delete-absorbed still exits 0.
#   C. UNCHANGED — plain `--delete-absorbed` with no selector still deletes every verified family,
#      byte-for-byte the same behaviour as before this row (checked against the SAME scratch
#      scenario A used, not a separate one, so A and C are directly comparable).
#   D. `--only fam,fam` (the exact-name alternative to a prefix) selects precisely the named set.
#
# ⛔ EVERY ARM RUNS ON A SCRATCH COPY, never the live rungs. Reads corpus/tests/snobol4 for its
# base tree shape only; writes exclusively under mktemp -d.
#
# Usage: bash ../harness/scripts/test_gate_rungs_family_selector.sh [--informational]
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT"
GATE_NAME="rungs-family-selector"
GATE_STRICT=1
. "$HERE/lib_gate.sh"
gate_parse_args "$@"

BUILDER="$ROOT/../harness/scripts/util_build_rungs_suite.py"
LIVE="$ROOT/../corpus/tests/snobol4"
gate_require "$BUILDER" "the rungs builder"
gate_require "$LIVE/ALL.sno" "the live snobol4 rungs"

FAILS=0
# ⛔⭐ COUNT THE ASSERTIONS, so the verdict line's denominator is the population it actually graded. This
# gate printed "GATE PASS(0) ... (examined 0)" while the lines above it showed a dozen ✓ checks: GATE_EXAMINED
# was never set, and gate_verdict has no way to know. A zero denominator beside a real population is the same
# reading error as a zero denominator beside an empty one -- and the second is the vacuous green this project
# keeps paying for, so the two must not print alike (hq_T 2026-09-05, beside the SCORE gate floors).
CHECKS=0
good() { echo "  ✓ $*"; CHECKS=$((CHECKS + 1)); }
bad()  { echo "  ✗ $*"; CHECKS=$((CHECKS + 1)); FAILS=$((FAILS + 1)); }

W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
# mkscratch: a FULLY SYNTHETIC scratch snobol4 tree (no live-tree copy -- copying the real 1726-
# entry rungs alongside only 2 fresh pairs trips the (correct, unrelated) collapse-refusal guard,
# since pairs*K < rungs_entries reads as a would-be collapse). Two never-before-absorbed families
# under distinct prefixes -- "selfam_" (to be selected), "otherfam_" (to prove it survives
# untouched) -- built as BLOCK-kind entries via the harness's own Entry/write_suite (the same writer
# the system uses, so the fixture cannot be wrong about the suite grammar; block kind uses an
# explicit banner rather than a line kind's terse trailing-tag convention).
mkscratch() {
    rm -rf "$1"; mkdir -p "$1/corpus/tests/snobol4"
    python3 - "$1/corpus/tests/snobol4" <<'PY'
import sys, os
sys.path.insert(0, os.path.join(os.getcwd(), "scripts"))
import corpus_suite_harness as h
T = sys.argv[1]
e1 = h.Entry("block", 1, "selfam_x", ["OUTPUT = 'sel-x'", "END"], ["sel-x"])
h.write_suite([e1], os.path.join(T, "selfam_probe.sno"), os.path.join(T, "selfam_probe.ref"))
e2 = h.Entry("block", 1, "otherfam_y", ["OUTPUT = 'other-y'", "END"], ["other-y"])
h.write_suite([e2], os.path.join(T, "otherfam_probe.sno"), os.path.join(T, "otherfam_probe.ref"))
PY
}

echo "== A. POSITIVE, SCOPED: --family selfam deletes only the matching family"
mkscratch "$W/a"
S4E_HOME="$W/a" python3 "$BUILDER" --lang snobol4 >/dev/null 2>"$W/a.absorb.err"
out="$(S4E_HOME="$W/a" python3 "$BUILDER" --lang snobol4 --delete-absorbed --family selfam 2>&1)"; rc=$?
if [ "$rc" -eq 0 ]; then good "exit 0"; else bad "expected rc=0, got rc=$rc: $out"; fi
if [ ! -f "$W/a/corpus/tests/snobol4/selfam_probe.sno" ] && [ ! -f "$W/a/corpus/tests/snobol4/selfam_probe.ref" ]; then
    good "selfam_probe.sno/.ref deleted (the selected family)"
else bad "selfam_probe.sno/.ref still on disk — the selector did not delete its match"; fi
if [ -f "$W/a/corpus/tests/snobol4/otherfam_probe.sno" ] && [ -f "$W/a/corpus/tests/snobol4/otherfam_probe.ref" ]; then
    good "otherfam_probe.sno/.ref SURVIVES (verified but out of scope, not deleted)"
else bad "⛔ otherfam_probe.sno/.ref was deleted — the selector leaked past its own prefix"; fi
if printf '%s' "$out" | grep -q 'SELECTED by'; then good "reported SELECTED-by-selector count distinctly from the full verified count"
else bad "did not report a distinct SELECTED count — the scoping is invisible to the reader"; fi

echo "== B. NEGATIVE: a prefix matching zero verified families REFUSES rc=2 and deletes nothing"
mkscratch "$W/b"
S4E_HOME="$W/b" python3 "$BUILDER" --lang snobol4 >/dev/null 2>"$W/b.absorb.err"
before_sel="$(md5sum "$W/b/corpus/tests/snobol4/selfam_probe.sno" | cut -d' ' -f1)"
before_oth="$(md5sum "$W/b/corpus/tests/snobol4/otherfam_probe.sno" | cut -d' ' -f1)"
out="$(S4E_HOME="$W/b" python3 "$BUILDER" --lang snobol4 --delete-absorbed --family nonexistent_prefix_zzz 2>&1)"; rc=$?
if [ "$rc" -eq 2 ]; then good "refused rc=2"; else bad "expected rc=2, got rc=$rc: $out"; fi
if [ -f "$W/b/corpus/tests/snobol4/selfam_probe.sno" ] && [ -f "$W/b/corpus/tests/snobol4/otherfam_probe.sno" ]; then
    good "both synthetic families still on disk (nothing deleted on refusal)"
else bad "⛔ a file was deleted despite the rc=2 refusal"; fi
after_sel="$(md5sum "$W/b/corpus/tests/snobol4/selfam_probe.sno" | cut -d' ' -f1)"
if [ "$before_sel" = "$after_sel" ] && [ "$before_oth" = "$(md5sum "$W/b/corpus/tests/snobol4/otherfam_probe.sno" | cut -d' ' -f1)" ]; then
    good "byte-identical before/after the refusal"
else bad "⛔ content changed during a refusal"; fi

echo "== C. UNCHANGED: plain --delete-absorbed (no selector) still deletes every verified family"
mkscratch "$W/c"
S4E_HOME="$W/c" python3 "$BUILDER" --lang snobol4 >/dev/null 2>"$W/c.absorb.err"
out="$(S4E_HOME="$W/c" python3 "$BUILDER" --lang snobol4 --delete-absorbed 2>&1)"; rc=$?
if [ "$rc" -eq 0 ]; then good "exit 0"; else bad "expected rc=0, got rc=$rc: $out"; fi
if [ ! -f "$W/c/corpus/tests/snobol4/selfam_probe.sno" ] && [ ! -f "$W/c/corpus/tests/snobol4/otherfam_probe.sno" ]; then
    good "BOTH synthetic families deleted — unscoped behaviour unchanged from before this row"
else bad "⛔ plain --delete-absorbed left a verified family behind — this row must not change the unscoped path"; fi
if printf '%s' "$out" | grep -q 'SELECTED by'; then bad "⛔ unscoped run printed a SELECTED-by line — selector reporting must stay silent when no selector is given"
else good "no SELECTED-by line printed (matches pre-row output shape exactly)"; fi

echo "== D. --only fam,fam selects the exact named set"
mkscratch "$W/d"
S4E_HOME="$W/d" python3 "$BUILDER" --lang snobol4 >/dev/null 2>"$W/d.absorb.err"
out="$(S4E_HOME="$W/d" python3 "$BUILDER" --lang snobol4 --delete-absorbed --only selfam_probe,doesnotexist_probe 2>&1)"; rc=$?
if [ "$rc" -eq 0 ]; then good "exit 0 (at least one named family matched)"; else bad "expected rc=0, got rc=$rc: $out"; fi
if [ ! -f "$W/d/corpus/tests/snobol4/selfam_probe.sno" ]; then good "selfam_probe deleted (named, matched)"
else bad "selfam_probe survived despite being named in --only"; fi
if [ -f "$W/d/corpus/tests/snobol4/otherfam_probe.sno" ]; then good "otherfam_probe survives (not named)"
else bad "⛔ otherfam_probe deleted despite not being named in --only"; fi

GATE_EXAMINED="$CHECKS assertions"
gate_verdict "$FAILS" "failed assertion(s)"
