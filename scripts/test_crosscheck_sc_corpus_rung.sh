#!/usr/bin/env bash
# run_sc_corpus_rung.sh — SC corpus ladder driver (--compile --target=x86 pipeline)
#
# Compiles each .sc in a given directory via scrip --compile --target=x86, assembles
# with gcc/as, links against out/libscrip_rt.so, runs, diffs vs .ref oracle.
#
# Usage:
#   bash test/crosscheck/run_sc_corpus_rung.sh <dir> [dir2 ...]
#
# Examples:
#   bash test/crosscheck/run_sc_corpus_rung.sh $CORPUS/crosscheck/snocone
#   bash test/crosscheck/run_sc_corpus_rung.sh \
#       $CORPUS/crosscheck/snocone \
#       $CORPUS/snocone/corpus
#
# Environment overrides:
#   SCRIP_CC        — path to scrip binary     (default: ./scrip)
#   STOP_ON_FAIL — 1 to stop at first fail  (default: 0)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TINY="$(cd "$SCRIPT_DIR/../../SCRIP" && pwd)"
SCRIP_CC="${SCRIP_CC:-$TINY/scrip}"
RT_OUT="$TINY/out"
STOP_ON_FAIL="${STOP_ON_FAIL:-0}"

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[0;33m'; RESET='\033[0m'
PASS=0; FAIL=0; SKIP=0

if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <sc-corpus-dir> [dir2 ...]"
    exit 1
fi

# ⛔ missing prerequisite is a refusal (rc=2), never a silent FAIL/SKIP — see test_corpus_snobol4.sh.
if [[ ! -x "$SCRIP_CC" ]]; then
    echo "⛔ REFUSED TO GRADE: scrip not found at $SCRIP_CC"
    exit 2
fi

if [[ ! -f "$RT_OUT/libscrip_rt.so" ]]; then
    echo "⛔ REFUSED TO GRADE: out/libscrip_rt.so not found at $RT_OUT — build scrip first"
    exit 2
fi

WORK=$(mktemp -d); trap "rm -rf $WORK" EXIT

# ── Per-test binary cache ──────────────────────────────────────────────────────
# Key: md5 of (.sc content + scrip binary mtime + libscrip_rt.so mtime). On cache
# hit: skip scrip, gcc assemble, and link entirely — just run the cached binary.
# Cuts warm-run cost from ~220ms/test to ~10ms/test (run only).
_stamp=$(stat -c '%Y' "$SCRIP_CC" "$RT_OUT/libscrip_rt.so" 2>/dev/null | md5sum | cut -c1-16)
BIN_CACHE_DIR="$TINY/out/rt_cache/bins"
mkdir -p "$BIN_CACHE_DIR"

run_test() {
    local sc="$1"
    local base; base=$(basename "$sc" .sc)
    local dir;  dir=$(dirname "$sc")
    local ref="$dir/$base.ref"
    local input="$dir/$base.input"   # optional stdin

    [[ ! -f "$ref" ]] && { echo -e "${YELLOW}SKIP${RESET} $base (no .ref)"; SKIP=$((SKIP+1)); return 0; }

    # .xfail — emitter gap queued for backend session; skip gracefully
    local xfail="$dir/$base.xfail"
    if [[ -f "$xfail" ]]; then
        local reason; reason=$(cat "$xfail")
        echo -e "${YELLOW}XFAIL${RESET} $base  [$reason]"
        SKIP=$((SKIP+1)); return 0
    fi

    # Binary cache: key = md5(sc_content + runtime_stamp)
    local _sc_md5; _sc_md5=$(md5sum "$sc" 2>/dev/null | cut -c1-16)
    local _cache_key="${_sc_md5}_${_stamp}"
    local _cached_bin="$BIN_CACHE_DIR/${_cache_key}"
    local bin

    if [[ -x "$_cached_bin" ]]; then
        bin="$_cached_bin"
    else
        local s_file="$WORK/${base}.s"
        local o_file="$WORK/${base}.o"
        bin="$WORK/${base}_bin"

        # scrip --compile --target=x86 (timeout guards against hangs on unimplemented constructs)
        if ! timeout -k 5 15 "$SCRIP_CC" --compile --target=x86 "$sc" --out="$s_file" 2>"$WORK/${base}.scrip_err"; then
            echo -e "${RED}FAIL${RESET} $base  [scrip error/timeout]"
            cat "$WORK/${base}.scrip_err" | head -3
            FAIL=$((FAIL+1))
            [[ "$STOP_ON_FAIL" == "1" ]] && exit 1
            return 0
        fi

        # assemble (GAS .intel_syntax noprefix output — via gcc driver, NOT nasm)
        if ! gcc -c "$s_file" -o "$o_file" 2>"$WORK/${base}.gcc_err"; then
            echo -e "${RED}FAIL${RESET} $base  [assemble error]"
            head -5 "$WORK/${base}.gcc_err"
            FAIL=$((FAIL+1))
            [[ "$STOP_ON_FAIL" == "1" ]] && exit 1
            return 0
        fi

        # link against the shared unified runtime
        # ⛔ -no-pie required: SCRIP mode-4 codegen embeds absolute (non-PIC) addresses — the same
        # convention every other m4 link site in ../harness/scripts/ already follows (see e.g. board_sno_apps.sh,
        # bench_pt0_3way.sh). Without it, a PIE build can pick up a DT_TEXTREL relocation into .text
        # that the loader mis-applies under ASLR, producing a silent-empty-output SIGSEGV unrelated to
        # program correctness (found via B03_for_continue, confirmed independent of that codegen path).
        if ! gcc -no-pie "$o_file" -L"$RT_OUT" -lscrip_rt -lm -Wl,-rpath,"$RT_OUT" -o "$bin" 2>"$WORK/${base}.link_err"; then
            echo -e "${RED}FAIL${RESET} $base  [link error]"
            head -3 "$WORK/${base}.link_err"
            FAIL=$((FAIL+1))
            [[ "$STOP_ON_FAIL" == "1" ]] && exit 1
            return 0
        fi

        # Promote to cache (atomic via temp+move)
        cp "$bin" "${_cached_bin}.tmp" && mv "${_cached_bin}.tmp" "$_cached_bin" || true
    fi

    # run
    local got exp
    if [[ -f "$input" ]]; then
        got=$(timeout -k 5 10 "$bin" < "$input" 2>/dev/null) || true
    else
        got=$(timeout -k 5 10 "$bin" 2>/dev/null) || true
    fi
    exp=$(cat "$ref")

    if [[ "$got" == "$exp" ]]; then
        echo -e "${GREEN}PASS${RESET} $base"
        PASS=$((PASS+1))
    else
        echo -e "${RED}FAIL${RESET} $base"
        echo "  expected: $(echo "$exp" | head -3)"
        echo "  got:      $(echo "$got" | head -3)"
        FAIL=$((FAIL+1))
        [[ "$STOP_ON_FAIL" == "1" ]] && exit 1
    fi
}

for dir in "$@"; do
    for sc in "$dir"/*.sc; do
        [[ -f "$sc" ]] || continue
        run_test "$sc"
    done
done

echo "============================================"
echo "Results: ${GREEN}${PASS} passed${RESET}, ${RED}${FAIL} failed${RESET}, ${YELLOW}${SKIP} skipped${RESET}"
[[ $FAIL -eq 0 ]] && echo -e "${GREEN}ALL PASS${RESET}" || echo -e "${RED}FAILURES${RESET}"
