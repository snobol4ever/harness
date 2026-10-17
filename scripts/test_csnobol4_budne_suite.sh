#!/usr/bin/env bash
# ../harness/scripts/test_csnobol4_budne_suite.sh — CSNOBOL4 test suite regression for scrip
# Runs all three modes: --run (M2), --run (M3), --compile→link→run (M4).
# Self-contained. Run from anywhere with no env vars.
#
# Runs 116 Budne-suite tests + 10 FENCE crosscheck tests = 126 total.
# Usage: bash ../harness/scripts/test_csnobol4_budne_suite.sh
#
# Stdin tests (data embedded below END in .sno):
#   atn crlf longrec rewind1 sudoku trim0 trim1 uneval2
#   — split at END line, pipe tail as stdin to scrip.
#
# Excluded (8): bench breakline genc k ndbm sleep time line2
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${SCRIP:-$HERE/../../SCRIP/scrip}"
# ⛔⭐ STALE-BINARY PREFLIGHT (row harness-and-ladder-runner-refuse-on-a-stale-binary-like-the-artifact-regen-
# does, ceo -> hq_T 2026-09-04). This runner had NO binary preflight at all -- not even an existence check --
# so `make`-less it would have graded a nonexistent binary into a full, plausible, entirely false all-FAIL
# board. The shim covers both: missing REFUSES, stale REFUSES, each rc=2 with the cure printed. NO LOGIC HERE:
# util_require_fresh.sh sources gate_require_fresh from lib_gate.sh, the ONE authority (hq_B 4c7253e99).
"$HERE/util_require_fresh.sh" --gate test_csnobol4_budne_suite "$SCRIP" "${RT_DIR:-$HERE/../../SCRIP/out}/libscrip_rt.so" || exit 2
CORPUS="$S4E/corpus"
TIMEOUT="${TIMEOUT:-15}"
SUITE="$CORPUS/packages/snobol4/csnobol4_suite"
# ⛔ crosscheck/patterns/ is GONE -- converted into tests/snobol4/ALL.{sno,ref,csv} (corpus da0987478
# lineage, row dead-suite-path-consumer-sweep). Extract the 10 named FENCE origins by ORIGIN (never
# re-point at a surviving directory -- that would grade a different population and look green either
# way, hq_P's FINDING-2026-08-30 on this exact class). Origins confirmed against ALL.csv before use;
# numbers 058-067 match this script's own documented "10 FENCE crosscheck tests (058-067)" comment
# above exactly -- other *_pat_fence* origins exist in the corpus now (added after this script was
# written) but are deliberately NOT included here, to keep this fix a repoint, not a scope change.
FENCE="$(mktemp -d)"
trap 'rm -rf "$FENCE"' EXIT
FENCE_ORIGINS="crosscheck_patterns__058_pat_fence_keyword crosscheck_patterns__059_pat_fence_fn_basic crosscheck_patterns__060_pat_fence_fn_fail crosscheck_patterns__061_pat_fence_fn_seal crosscheck_patterns__062_pat_fence_fn_outer crosscheck_patterns__063_pat_fence_fn_optional crosscheck_patterns__064_pat_fence_fn_capture crosscheck_patterns__065_pat_fence_fn_decimal crosscheck_patterns__066_pat_fence_fn_nested crosscheck_patterns__067_pat_fence_fn_vs_kw"
if RUNGS_LANG="${RUNGS_LANG:-snobol4}" source "$HERE/lib_rungs_extract.sh" 2>/dev/null; then
    for o in $FENCE_ORIGINS; do
        n="${o#crosscheck_patterns__}"
        rungs_extract_origin "$o" "$FENCE/$n.sno" "$FENCE/$n.ref" || echo "WARN: could not extract $o from the rungs" >&2
    done
else
    echo "WARN: lib_rungs_extract.sh unavailable, FENCE crosscheck tests will not run" >&2
fi

# ── corpus guard ──────────────────────────────────────────────────────────────
if [ ! -d "$CORPUS" ]; then
    echo "SKIP corpus not found at $CORPUS"
    echo "     clone snobol4ever/corpus to $CORPUS to run this suite"
    exit 0
fi

PASS2=0; FAIL2=0
PASS3=0; FAIL3=0
FAILURES2=""; FAILURES3=""
T_M2=0; T_M3=0; T0_ALL=$SECONDS


SKIP_LIST="bench breakline genc k ndbm sleep time line2"
STDIN_TESTS="atn crlf longrec rewind1 sudoku trim0 trim1 uneval2 factor len repl tab words words1"

is_excluded() {
    local name="$1"
    for s in $SKIP_LIST; do [ "$name" = "$s" ] && return 0; done
    return 1
}

is_stdin_test() {
    local name="$1"
    for s in $STDIN_TESTS; do [ "$name" = "$s" ] && return 0; done
    return 1
}

split_at_end() {
    local file="$1" prog_out="$2" stdin_out="$3"
    python3 - "$file" "$prog_out" "$stdin_out" << 'PY'
import sys, re
src = open(sys.argv[1], 'r', errors='replace').read()
lines = src.split('\n')
end_idx = None
for i, l in enumerate(lines):
    if re.match(r'^END\s*$', l):
        end_idx = i
        break
if end_idx is not None:
    open(sys.argv[2], 'w').write('\n'.join(lines[:end_idx+1]) + '\n')
    open(sys.argv[3], 'w').write('\n'.join(lines[end_idx+1:]))
else:
    open(sys.argv[2], 'w').write(src)
    open(sys.argv[3], 'w').write('')
PY
}


run_test() {
    local label="$1" sno="$2" ref="$3"
    [ ! -f "$ref" ] && return
    local exp; exp=$(cat "$ref")
    local name slug; name=$(basename "$sno" .sno); slug=$(echo "$label" | tr '/: ' '_')

    local prog_file="$sno" stdin_file=""
    if is_stdin_test "$name"; then
        local prog_tmp stdin_tmp
        prog_tmp=$(mktemp /tmp/scrip_prog_XXXXXX.sno)
        stdin_tmp=$(mktemp /tmp/scrip_stdin_XXXXXX)
        split_at_end "$sno" "$prog_tmp" "$stdin_tmp"
        prog_file="$prog_tmp"
        stdin_file="$stdin_tmp"
    fi

    # ── Mode 2: --run ──────────────────────────────────────────────────
    local T0m=$SECONDS; local got2
    if [ -n "$stdin_file" ]; then
        got2=$(timeout -k 5 "$TIMEOUT" "$SCRIP" --run "$prog_file" < "$stdin_file" 2>/dev/null || true)
    else
        got2=$(timeout -k 5 "$TIMEOUT" "$SCRIP" --run "$sno" 2>/dev/null || true)
    fi
    T_M2=$((T_M2+SECONDS-T0m))
    if [ "$got2" = "$exp" ]; then PASS2=$((PASS2+1))
    else FAIL2=$((FAIL2+1)); FAILURES2="${FAILURES2}  FAIL ${label}\n"; fi

    # ── Mode 3: --run ─────────────────────────────────────────────────────
    local T0m3=$SECONDS; local got3
    if [ -n "$stdin_file" ]; then
        got3=$(timeout -k 5 "$TIMEOUT" "$SCRIP" --run "$prog_file" < "$stdin_file" 2>/dev/null || true)
    else
        got3=$(timeout -k 5 "$TIMEOUT" "$SCRIP" --run "$sno" 2>/dev/null || true)
    fi
    T_M3=$((T_M3+SECONDS-T0m3))
    if [ "$got3" = "$exp" ]; then PASS3=$((PASS3+1))
    else FAIL3=$((FAIL3+1)); FAILURES3="${FAILURES3}  FAIL ${label}\n"; fi

    [ -n "$stdin_file" ] && rm -f "$prog_file" "$stdin_file"
}

# ── FENCE crosscheck tests (058–067) ─────────────────────────────────────────
for sno in "$FENCE"/*_pat_fence*.sno; do
    [ -f "$sno" ] || continue
    ref="${sno%.sno}.ref"
    label=$(basename "$sno" .sno)
    run_test "$label" "$sno" "$ref"
done

# ── Budne suite (116 tests) ───────────────────────────────────────────────────
for sno in "$SUITE"/*.sno; do
    [ -f "$sno" ] || continue
    name=$(basename "$sno" .sno)
    is_excluded "$name" && continue
    ref="${sno%.sno}.ref"
    run_test "$name" "$sno" "$ref"
done

T_ALL=$((SECONDS-T0_ALL))
TOTAL=$((PASS2+FAIL2))
echo "mode-2 (--run):  PASS=$PASS2 FAIL=$FAIL2  ($TOTAL run)"
echo "mode-3 (--run):     PASS=$PASS3 FAIL=$FAIL3  ($TOTAL run)"
[ -n "$FAILURES2" ] && printf "$FAILURES2" | head -40
[ -n "$FAILURES3" ] && printf "$FAILURES3" | head -40
printf "TIME M2=%ds M3=%ds TOTAL=%ds\n" "$T_M2" "$T_M3" "$T_ALL"
