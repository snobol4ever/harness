#!/usr/bin/env bash
# ../harness/scripts/test_icon_mode4_rung.sh — ICN-G-1: Icon mode-4 (--compile --target=x86) rung gate.
# Self-contained. Run from anywhere with no env vars.
# Usage: bash ../harness/scripts/test_icon_mode4_rung.sh [--rung RUNG] [--scrip PATH] [--corpus PATH] [--keep]
#
# For each Icon program with a matching .ref file, runs the FULL mode-4
# native pipeline — scrip --compile --target=x86 file.icn > file.s ; as file.s ;
# gcc -no-pie file.o -L out -lscrip_rt -Wl,-rpath,out -lm — then executes the
# binary and diffs its stdout against scrip --run (the mode-2 oracle).
# Reports PASS/FAIL/SKIP in PASS=N FAIL=M format and never aborts the harness:
# emit / assemble / link / run failures are caught and counted as FAIL, not fatal.
#
# This gate exists so EMITTER (template) rungs can be honestly verified: a
# template that emits an empty string or stub jumps produces a binary whose
# output diverges from --run and is counted FAIL (HQ Invariant 0). Mode-2
# (test_icon_all_rungs.sh) cannot measure mode-4 generator/template progress.
#
# Gate threshold (per GOAL-ICON-BB ICN-G-1): the harness must exist and run
# without crashing; mode-4 PASS >= 1 is required before any emitter rung is
# marked complete. The default seed set is the smallest generator programs.
#
# Authors: LCherryholmes · Jeffrey Cooper M.D. · Claude Sonnet
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP:-$ROOT/scrip}"
RT_SO="${RT_SO:-$ROOT/out/libscrip_rt.so}"
CORPUS="${CORPUS:-$S4E/corpus/tests/icon}"
RUNG=""
KEEP=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --rung)   RUNG="$2";   shift 2 ;;
        --scrip)  SCRIP="$2";  shift 2 ;;
        --corpus) CORPUS="$2"; shift 2 ;;
        --keep)   KEEP=1;      shift   ;;
        *) echo "Usage: $0 [--rung RUNG] [--scrip PATH] [--corpus PATH] [--keep]" >&2; exit 1 ;;
    esac
done

if [ ! -x "$SCRIP" ]; then
    echo "SKIP scrip binary not found at $SCRIP — run ../harness/scripts/build_scrip.sh" >&2
    exit 0
fi
if [ ! -f "$RT_SO" ]; then
    echo "SKIP libscrip_rt.so not found at $RT_SO — run: make libscrip_rt" >&2
    exit 0
fi
if [ ! -d "$CORPUS" ]; then
    echo "SKIP corpus not found at $CORPUS" >&2
    echo "     clone snobol4ever/corpus to $S4E/corpus to run this suite" >&2
    exit 0
fi

OUTDIR="$(dirname "$RT_SO")"
WORK="$(mktemp -d)"
if [ "$KEEP" -eq 0 ]; then trap 'rm -rf "$WORK"' EXIT; else echo "WORK=$WORK (kept)"; fi

PASS=0; FAIL=0; SKIP=0

run_one() {
    local icn="$1"
    local tmo="${2:-8}"
    local exp="${icn%.icn}.ref"
    [ -f "$exp" ] || return 0
    # a container (corpus_suite_harness.py's `#---- <seq> <name>` banners) is the harness's to grade, never this
    # per-file loop -- it was out of reach while loose programs carried a .expected; since CEO-1222 both are .ref
    grep -qE '^#-{3,} [0-9]+ [^[:space:]]' "$icn" && return 0
    local base="${icn%.icn}"
    local name
    name=$(basename "$icn" .icn)
    if [ -f "${base}.xfail" ]; then
        echo "SKIP $name (xfail)"
        SKIP=$((SKIP+1))
        return 0
    fi
    local stdin_file="${base}.stdin"; [ -f "$stdin_file" ] || stdin_file="$(dirname "$base")/config/$(basename "$base").stdin"
    local s="$WORK/$name.s" o="$WORK/$name.o" bin="$WORK/${name}_bin"

    if ! timeout -k 5 "$tmo" "$SCRIP" --compile --target=x86 "$icn" < /dev/null > "$s" 2>/dev/null; then
        echo "FAIL $name (emit)"; FAIL=$((FAIL+1)); return 0
    fi
    if ! as "$s" -o "$o" 2>/dev/null; then
        echo "FAIL $name (assemble)"; FAIL=$((FAIL+1)); return 0
    fi
    if ! gcc -no-pie "$o" -L"$OUTDIR" -lscrip_rt -Wl,-rpath,"$OUTDIR" -lm -o "$bin" 2>/dev/null; then
        echo "FAIL $name (link)"; FAIL=$((FAIL+1)); return 0
    fi

    local got want
    if [ -f "$stdin_file" ]; then
        got=$(timeout -k 5 "$tmo" "$bin" < "$stdin_file" 2>/dev/null) || true
        want=$(timeout -k 5 "$tmo" "$SCRIP" --run "$icn" < "$stdin_file" 2>/dev/null) || true
    else
        got=$(timeout -k 5 "$tmo" "$bin" < /dev/null 2>/dev/null) || true
        want=$(timeout -k 5 "$tmo" "$SCRIP" --run "$icn" < /dev/null 2>/dev/null) || true
    fi

    if [ "$got" = "$want" ]; then
        echo "PASS $name"
        PASS=$((PASS+1))
    else
        echo "FAIL $name (output)"
        echo "  interp: $(echo "$want" | tr '\n' '|')"
        echo "  mode4:  $(echo "$got"  | tr '\n' '|')"
        FAIL=$((FAIL+1))
    fi
}

if [ -n "$RUNG" ]; then
    for icn in "$CORPUS"/${RUNG}_*.icn; do
        [ -f "$icn" ] || continue
        run_one "$icn" 8
    done
else
    # Default seed set: smallest generator programs (rung01 paper examples +
    # the canonical every-loop cases). Expand as templates land.
    for icn in "$CORPUS"/rung01_paper_to5.icn \
               "$CORPUS"/rung01_paper_lt.icn \
               "$CORPUS"/rung01_paper_mult.icn \
               "$CORPUS"/rung01_paper_to_by.icn \
               "$CORPUS"/rung01_paper_compound.icn; do
        [ -f "$icn" ] || continue
        run_one "$icn" 8
    done
fi

echo "--- Icon --compile/x86: PASS=$PASS FAIL=$FAIL SKIP=$SKIP TOTAL=$((PASS+FAIL+SKIP)) ---"
# ⛔⭐ ZERO-TOTAL IS ANNOUNCED, NOT SILENT (hq_B 2026-08-30, row graders-denominator-audit-six-families).
# MEASURED: with no --rung, the default seed set below is a HARDCODED list of five rung01_paper_*.icn
# files, and all five were consolidated away -- each `[ -f "$icn" ] || continue` skipped, TOTAL landed
# at 0, and the script printed a tidy summary and exited 0. All five are present in tests/icon/ALL.csv
# by `origin`, so the programs were renamed, not deleted.
# ⛔ THE exit 0 BELOW IS DELIBERATE AND IS LEFT ALONE: the ICN-G-1 contract states it, and that contract
# is not this row's to overturn. But that reason was written for a run that GRADES and does not pass --
# "informational, not a build break" -- and it does not cover a run that graded NOTHING because its
# inputs moved. Those are different states and only one of them was argued for. So the exit code is
# untouched and the silence is not: a zero total now says so, loudly, on stderr.
if [ $((PASS+FAIL+SKIP)) -eq 0 ]; then
    echo "⛔ GRADED ZERO PROGRAMS -- not a pass, and not what the ICN-G-1 exit-0 contract was argued for." >&2
    echo "   With no --rung, the default seed set is a hardcoded rung01_paper_* list whose files were" >&2
    echo "   consolidated away; all five survive in corpus/tests/icon/ALL.csv under the 'origin' column." >&2
    echo "   Pass --rung <name>, or re-point the seed set at the flat ALL.* set. rc is left at 0 by the" >&2
    echo "   ICN-G-1 contract only -- read this line, not the exit code." >&2
fi
# ICN-G-1 contract: the gate must run to completion (rc 0 here) so it can be
# wired into Session Setup before any rung passes. Emitter rungs assert PASS>=1
# separately. Until then, a non-passing run is informational, not a build break.
exit 0
