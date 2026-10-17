#!/usr/bin/env bash
# test_icon_ir_rung_36.sh — rung36: JCON integration suite (75 tests) — IC-7
# Tests marked .xfail are known-unimplemented features (co-expressions, large integers,
# &error trapping, etc.) — they count as XFAIL, not FAIL.
# ⛔ 2026-08-29 (seat07, row tests-consolidate-icon): 32 of the 75 were converted into a suite pair
# (rung36_all.icn/.ref, see corpus's tests/icon/KEEP.md ## rung36) and their loose .icn/.expected
# files no longer exist. Per FINDING-2026-08-29-hq_P-converting-a-family-silently-disarms-its-
# per-family-glob-script.md: a converted family's entries MUST be delegated to the harness, never
# left to fall through this script's own [ -f ... ] checks as a silent SKIP (SKIP is not checked by
# the final `[ "$FAIL" -eq 0 ]`, so 32 silently-skipped tests would still read as a clean pass). The
# remaining 43 (29 still-red .xfail witnesses + 14 newly-found-red, see KEEP.md) stay loose and are
# still tested individually below, unchanged — only the now-converted 32 moved to delegation.
# Authors: LCherryholmes · Claude Sonnet 4.6   DATE: 2026-04-16
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${SCRIP:-$HERE/../../SCRIP/scrip}"
# ⛔ ABSOLUTE, because run() now invokes scrip from the PROGRAM'S OWN directory (see below) and a relative
# path would resolve against that instead of against this script.
case "$SCRIP" in /*) : ;; *) SCRIP="$(cd "$(dirname "$SCRIP")" && pwd)/$(basename "$SCRIP")";; esac
CORPUS="${CORPUS:-$S4E/corpus/tests/icon}"
PASS=0; FAIL=0; XFAIL=0

# ⛔ THESE WERE `exit 0` — SKIP-AS-SUCCESS, on the two conditions that make this script measure NOTHING.
# An unbuilt scrip or a moved corpus made it print one SKIP line and report success, which is the precise
# defect lib_gate.sh's three exit codes exist to kill ("I checked and it is clean" and "I could not check"
# must never be the same exit code). rc=2 = UNPROVEN, and it is not a pass.
if [ ! -x "$SCRIP" ];  then echo "⛔ REFUSES rc=2: scrip not built at $SCRIP — this is NOT a pass; nothing was examined."; exit 2; fi
if [ ! -d "$CORPUS" ]; then echo "⛔ REFUSES rc=2: corpus not found at $CORPUS — the layout moved; do not read a smaller total as a pass."; exit 2; fi

run() {
    local base="$CORPUS/$1"
    [ -f "${base}.xfail" ] && { echo "  XFAIL $1"; XFAIL=$((XFAIL+1)); return; }
    [ -f "${base}.ref" ] || { echo "  SKIP  $1 (no .ref)"; return; }
    local stdin_f="${base}.stdin"; [ -f "$stdin_f" ] || stdin_f="$(dirname "$base")/config/$(basename "$base").stdin"
    local got want
    # ⛔⭐ A CORPUS PROGRAM RUNS IN ITS OWN DIRECTORY (seat06, 2026-08-29; same cure corpus_suite_harness.py
    # already carries as 022f3a00). This ran scrip from whatever cwd it inherited, so any program that opens a
    # companion by RELATIVE name could not find it. MEASURED on rung36_jcon_fncs1: from an unrelated cwd its
    # output differs from .expected by 147 lines and the run reads FAIL, with the cause visible in the first
    # divergent line — `F := open("fncs1.dat") ----> none` instead of `file(fncs1.dat)`; from the corpus
    # directory the diff is ZERO and it PASSES. ⭐ That single false FAIL is the whole of the long-standing
    # discrepancy between this script (FAIL=9) and the aggregate board (FAIL=8), which delegates to the harness
    # and therefore already cd'd. Two numbers for one tree, one of them wrong, and the cause was the cwd.
    local _pdir _pfile; _pdir="$(dirname "${base}.icn")"; _pfile="$(basename "${base}.icn")"
    if [ -f "$stdin_f" ]; then
        got=$(cd "$_pdir" && timeout -k 5 30 "$SCRIP" --run "$_pfile" < "$stdin_f"  2>/dev/null) || true
    else
        got=$(cd "$_pdir" && timeout -k 5 30 "$SCRIP" --run "$_pfile" < /dev/null   2>/dev/null) || true
    fi
    want=$(cat "${base}.ref")
    if [ "$got" = "$want" ]; then
        echo "  PASS $1"; PASS=$((PASS+1))
    else
        echo "  FAIL $1"
        echo "    want: $(echo "$want" | head -3 | tr '\n' '|')"
        echo "    got:  $(echo "$got"  | head -3 | tr '\n' '|')"
        FAIL=$((FAIL+1))
    fi
}

# ⛔⭐ A NAME THAT MOVED INTO THE RUNGS IS ASSERTED HERE, NEVER SILENTLY SKIPPED (hq_V, 2026-09-11).
# run() above prints "SKIP (no .ref)" and returns SUCCESS when a file is gone, so absorbing a loose
# rung36 witness into ALL.icn and deleting its pair -- the correct, routine end of a conversion -- takes this
# script one witness smaller with no message and no failing exit code. That is the same false-green shape
# test_icon_ir_rung_34's REFUSAL was written to kill. moved() states where the coverage went and PROVES it is
# there: the entry must be present in ALL.csv under the origin named, or this gate REFUSES rc=2 rather than
# reporting a smaller green board. It deliberately adds nothing to PASS -- the IcnRungs board grades that entry
# now, in both modes, and counting it here too would double-count one program across two instruments.
moved() {
    local name="$1" origin="$2"
    if [ -f "$CORPUS/${name}.icn" ]; then
        echo "⛔ REFUSES rc=2: $name is loose again at $CORPUS/${name}.icn while this line says it moved to the rungs -- one program cannot be graded in two places; restore the run line or finish the absorption"; exit 2
    fi
    grep -q ",${origin}," "$CORPUS/ALL.csv" || { echo "⛔ REFUSES rc=2: $name was absorbed as origin $origin but no such origin is in $CORPUS/ALL.csv -- the coverage is in NEITHER place; this is not a pass"; exit 2; }
    echo "  MOVED $name -> ALL.icn origin $origin (graded m3+m4 by the IcnRungs board, not counted twice here)"
}

echo "=== rung36: JCON integration suite (43 still-loose entries, individually diagnosed) ==="
run rung36_jcon_args
run rung36_jcon_btrees
run rung36_jcon_case
run rung36_jcon_checkfpx
run rung36_jcon_ck
run rung36_jcon_collate
run rung36_jcon_cxprimes
run rung36_jcon_endetab
run rung36_jcon_errkwds
run rung36_jcon_errors
run rung36_jcon_evalx
run rung36_jcon_every
run rung36_jcon_fncs
run rung36_jcon_fncs1
run rung36_jcon_geddump
run rung36_jcon_gener
moved rung36_jcon_genqueen rung36_jcon_genqueen
run rung36_jcon_image
run rung36_jcon_io
run rung36_jcon_iobig
run rung36_jcon_kwds
run rung36_jcon_large
run rung36_jcon_level
run rung36_jcon_lgint
run rung36_jcon_misc
run rung36_jcon_nargs
moved rung36_jcon_others rung36_jcon_others
run rung36_jcon_prefix
run rung36_jcon_prepro
run rung36_jcon_profsum
run rung36_jcon_proto
run rung36_jcon_radix
run rung36_jcon_recent
run rung36_jcon_recogn
run rung36_jcon_scan
run rung36_jcon_scan1
run rung36_jcon_scan2
run rung36_jcon_sets
run rung36_jcon_sorting
run rung36_jcon_struct
run rung36_jcon_subjpos
run rung36_jcon_toby
run rung36_jcon_var

echo ""
echo "=== rung36: converted suite delegation (32 entries in rung36_all.icn/.ref) ==="
SUITE_SNO="$CORPUS/rung36_all.icn"
SUITE_REF="$CORPUS/rung36_all.ref"
if [ ! -f "$SUITE_SNO" ] || [ ! -f "$SUITE_REF" ]; then
    echo "REFUSE (rc=2): rung36_all suite not found under $CORPUS -- cannot measure the 32 converted entries, not a pass"
    exit 2
fi
board=$(python3 "$HERE/corpus_suite_harness.py" run "$SUITE_SNO" "$SUITE_REF" --lang icon --modes m3,m4 2>&1 | grep '^SUITE_BOARD') || true
if [ -z "$board" ]; then
    echo "REFUSE (rc=2): rung36_all harness produced no SUITE_BOARD line -- cannot measure, not a pass"
    exit 2
fi
echo "  $board"
for mode in m3 m4; do
    p=$(echo "$board" | grep -oP "${mode}_pass=\K[0-9]+")
    f=$(echo "$board" | grep -oP "${mode}_fail=\K[0-9]+")
    c=$(echo "$board" | grep -oP "${mode}_crash=\K[0-9]+")
    h=$(echo "$board" | grep -oP "${mode}_hang=\K[0-9]+")
    u=$(echo "$board" | grep -oP "${mode}_unproven=\K[0-9]+")
    PASS=$((PASS+p))
    FAIL=$((FAIL+f+c+h+u))
done

echo ""
echo "PASS=$PASS FAIL=$FAIL XFAIL=$XFAIL TOTAL=$((PASS+FAIL+XFAIL))"
[ "$FAIL" -eq 0 ]
