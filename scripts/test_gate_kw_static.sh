#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_kw_static.sh — KW-STATIC gate (GOAL-SNOBOL4-100 D-3, rungs KW-1..KW-4)
#
# Runs corpus/probe/kw/ in BOTH modes against the live-oracle .ref files.
# KW-1 (census) minted the witnesses; the gate reads 0/4 at census time and
# must read 4/4 before KW-4 is done.  Record: FINDING-2026-08-19-s146.
#
# Usage:  bash ../harness/scripts/test_gate_kw_static.sh [--mode 3|4|both] [--verbose]
# Exit:   0 = every witness PASS in every selected mode; 1 = at least one DIFF.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
set -uo pipefail
SCRIP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../SCRIP" && pwd)"
# ⭐ RE-POINTED (ceo s283h, probe total-conversion): corpus/probe/kw is GONE. The 13 non-stdin witnesses
# live in the kw SUITE (tests/snobol4/probe/kw.{sno,ref}) and are materialized here via the harness's
# `extract` verb (test_arbno_witnesses.sh's established idiom); the 2 stdin-bearing witnesses
# (kw_trim_effect, kw_trim_lazy_seed -- .dat companions) stay LOOSE in tests/snobol4/probe_loose/kw
# per hq_C's permanent stdin ruling and are copied in beside them, so this gate's witness population
# is UNCHANGED (15) and the .dat-stdin arm below still exercises what it always did.
KW_ASSEMBLED="$(mktemp -d)"
RUNGS_LANG="${RUNGS_LANG:-snobol4}" . "$(dirname "${BASH_SOURCE[0]}")/lib_rungs_extract.sh"   # zero-subfolders cutover: the kw suite lives IN the rungs; loose stdin pair is flat-prefixed
rungs_extract_family probe_kw "$KW_ASSEMBLED" || true
for f in "$S4E/corpus/tests/snobol4/"probe_loose_kw_*; do
    [ -f "$f" ] || continue
    b="$(basename "$f")"; cp "$f" "$KW_ASSEMBLED/${b#probe_loose_kw_}"
done
PROBE_DIR="${KW_PROBE_DIR:-$KW_ASSEMBLED}"
SCRIP_BIN="${SCRIP_BIN:-$SCRIP_DIR/scrip}"
MODE="both"; VERBOSE=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode) MODE="$2"; shift 2 ;;
        --verbose|-v) VERBOSE=1; shift ;;
        --armed) shift ;;   # KW-4: accepted and ignored -- there is only one arm now
        --with-b1) WITH_B1=1; shift ;;
        --legacy) echo "GATE BLOCKED: --legacy is gone -- KW-4 deleted the SCRIP_KW_STATIC=0 arm"; exit 2 ;;
        *) echo "unknown option: $1"; exit 2 ;;
    esac
done
[[ -x "$SCRIP_BIN" ]] || { echo "GATE BLOCKED: no scrip binary at $SCRIP_BIN (run make -j8 scrip)"; exit 2; }
[[ -d "$PROBE_DIR" ]] || { echo "GATE BLOCKED: no probe dir at $PROBE_DIR (clone corpus)"; exit 2; }
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK" "$KW_ASSEMBLED"' EXIT
pass=0; fail=0; failed_names=()
# a witness may ship a .dat beside it -- that file is its stdin (kw_trim_effect needs one to
# show that &TRIM actually trims).  Absent, stdin is /dev/null.
stdin_for() { local d="${1%.sno}.dat"; [[ -f "$d" ]] && echo "$d" || echo /dev/null; }
run_mode3() { timeout -k 5 30 "$SCRIP_BIN" --run "$1" < "$(stdin_for "$1")" > "$2" 2>&1; }
run_mode4() {
    local sno="$1" out="$2" s="$WORK/m4.s" exe="$WORK/m4.bin"
    timeout -k 5 30 "$SCRIP_BIN" --compile "$sno" < /dev/null > "$s" 2>/dev/null || return 1
    gcc -no-pie -o "$exe" "$s" -L"$SCRIP_DIR/out" -lscrip_rt -lm > /dev/null 2>&1 || return 1
    LD_LIBRARY_PATH="$SCRIP_DIR/out" timeout -k 5 30 "$exe" < "$(stdin_for "$sno")" > "$out" 2>&1
}
for ref in "$PROBE_DIR"/*.ref; do
    [[ -e "$ref" ]] || { echo "GATE BLOCKED: no .ref files in $PROBE_DIR"; exit 2; }
    base="$(basename "$ref" .ref)"; sno="$PROBE_DIR/$base.sno"
    # kw_unset_datatype is NOT a KW-STATIC row and never was: it is identical on both
    # killswitch arms, so scoring it would credit this gate with a result arming does not
    # control.  It was CLOSED at s161 -- DATATYPE of an unset variable answers STRING, not
    # NULL (SNOBOL4 has no null datatype; the null string is a string) -- so it is no
    # longer the open B1 handoff it was minted as.  It runs unconditionally as a STANDING
    # PIN after the scored loop, beside kw_pattern_family and for the same reason.
    if [[ "$base" == "kw_unset_datatype" ]]; then continue; fi
    # kw_pattern_family is likewise NOT a KW-STATIC row.  It pins the s147 CN-2
    # regression (&ARB/&BAL/&REM/&FAIL/&FENCE/&ABORT/&SUCCEED raising error 342 on
    # READ instead of yielding their primitive patterns, manual Ch.16 p.187-188) and
    # PASSES ON BOTH KILLSWITCH ARMS, because that fix lives outside the killswitch.
    # A row identical on both arms measures nothing about ARMING, so scoring it here
    # would inflate the legacy arm with a result the killswitch does not control --
    # the same reasoning that excludes kw_unset_datatype just above, in the opposite
    # direction.  It is run unconditionally as a STANDING PIN after the scored loop.
    if [[ "$base" == "kw_pattern_family" ]]; then continue; fi
    [[ -f "$sno" ]] || { echo "SKIP  $base (no .sno beside .ref)"; continue; }
    for m in 3 4; do
        [[ "$MODE" == "both" || "$MODE" == "$m" ]] || continue
        out="$WORK/$base.m$m"
        if [[ "$m" == 3 ]]; then run_mode3 "$sno" "$out"; else run_mode4 "$sno" "$out"; fi
        if diff -q "$ref" "$out" > /dev/null 2>&1; then
            pass=$((pass+1)); [[ $VERBOSE -eq 1 ]] && echo "PASS  $base m$m"
        else
            fail=$((fail+1)); failed_names+=("$base m$m")
            echo "DIFF  $base m$m"
            [[ $VERBOSE -eq 1 ]] && diff "$ref" "$out" | head -20
        fi
    done
done
echo "-----------------------------------------------------------------------"
pin_bad=0
pin_row() {   # $1 = witness base, $2 = what a break MEANS (the reader should not have to go find out)
    local pin_ref="$PROBE_DIR/$1.ref" pin_sno="$PROBE_DIR/$1.sno"
    [[ -f "$pin_ref" && -f "$pin_sno" ]] || return 0
    for m in 3 4; do
        [[ "$MODE" == "both" || "$MODE" == "$m" ]] || continue
        local pout="$WORK/$1.pin.m$m"
        if [[ "$m" == 3 ]]; then run_mode3 "$pin_sno" "$pout"; else run_mode4 "$pin_sno" "$pout"; fi
        if diff -q "$pin_ref" "$pout" > /dev/null 2>&1; then echo "PIN   $1 m$m  OK (arm-independent)"
        else pin_bad=1; echo "PIN   $1 m$m  BROKEN — $2"; fi
    done
}
pin_row kw_pattern_family "the primitive-pattern keyword family regressed again (s147 class: &ARB..&SUCCEED must read as PATTERN, manual Ch.16 p.187-188)"
pin_row kw_unset_datatype "DATATYPE of an unset variable stopped answering STRING (s161 class: SNOBOL4 has no null datatype -- the null string IS a string, manual p.24 and the DATATYPE entry p.213)"
echo "-----------------------------------------------------------------------"
echo "KW-STATIC GATE: $pass PASS / $((pass+fail)) total   (mode=$MODE, single arm -- KW-4 deleted the killswitch)"
# KW-4 (this session) DELETED the SCRIP_KW_STATIC killswitch, so there is no arm to select and no
# legacy expectations to print.  The rows below ARE the contract; a red here is a regression, never
# "the other arm".  Keeping the old two-branch epilogue would have printed an arm label for a switch
# the binary no longer reads -- the vacuous-gate class RULES.md names.
echo "  ONE ARM — GRADE IT.  Expected: ALL ROWS GREEN, no routed reds left."
echo "  kw_protected_write went green at KW-5 (kwb_error converts 208/209 to statement failure when"
echo "  &ERRLIMIT is non-zero, Ch.16); kw_bare_shadow at s161 (DATATYPE of an unset variable is STRING,"
echo "  not NULL -- it was mis-routed as B1); kw_trim_lazy_seed is KW-5b (block initials seeded at"
echo "  program start, so a program that touches no keyword still gets the oracle's &TRIM=1)."
if [[ $pin_bad -ne 0 ]]; then
    echo "STANDING PIN BROKEN — kw_pattern_family; this is a CORRECTNESS regression independent of the KW-STATIC score above."
    exit 1
fi
if [[ $fail -gt 0 ]]; then
    echo "FAILING: ${failed_names[*]}"
    echo "GATE RED — see FINDING-2026-08-19-s146-KW1-census-keyword-truth-table.md"
    exit 1
fi
echo "GATE GREEN"
exit 0
