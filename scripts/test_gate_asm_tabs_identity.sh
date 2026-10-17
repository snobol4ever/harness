#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_asm_tabs_identity.sh — TAB-COLUMN REFACTOR GATE (GOAL-RBP-EARN, Lon directive s62b).
# The TAB record format is a REPRESENTATION change, never an OUTPUT change: the .s bytes the sink
# writes must be IDENTICAL with SCRIP_ASM_TABS=1 (records carry TAB-delimited fields) and
# SCRIP_ASM_TABS=0 (legacy space-delimited producers).  A producer missed by the refactor emits a
# record with no TAB, lands on the legacy parse path, and — if that parse disagrees by one byte —
# shows up here as a DIFF.  Same discipline as the JOIN rung: md5 across the demo corpus, 22/22.
# Usage: bash ../harness/scripts/test_gate_asm_tabs_identity.sh [corpus_dir]
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
set -u
SCRIP=${SCRIP:-$S4E/SCRIP/scrip}
DIR=${1:-$S4E/corpus/demos}
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
pass=0; fail=0; skip=0; failed=""
# ⭐ V2-5 GATE HONESTY: examining nothing must exit UNPROVEN(2), never read as a pass.
. "$(dirname "$0")/lib_gate.sh"
gate_require_exec "${SCRIP:-${SCRIP_BIN:-$(dirname "$0")/../../SCRIP/scrip}}" "the scrip compiler"
gate_require "${RT_DIR:-$(dirname "$0")/../../SCRIP/out}/libscrip_rt.so" "the runtime shared object out/libscrip_rt.so"
for f in "$DIR"/*.sno; do
    [ -e "$f" ] || continue
    b=$(basename "$f" .sno)
    SCRIP_ASM_TABS=0 timeout -k 5 60 "$SCRIP" --compile "$f" > "$WORK/$b.off.s" 2>"$WORK/$b.off.err" < /dev/null
    rc0=$?
    SCRIP_ASM_TABS=1 timeout -k 5 60 "$SCRIP" --compile "$f" > "$WORK/$b.on.s"  2>"$WORK/$b.on.err"  < /dev/null
    rc1=$?
    if [ $rc0 -ne 0 ] || [ $rc1 -ne 0 ]; then
        if [ $rc0 -eq $rc1 ]; then skip=$((skip+1)); continue; fi
        fail=$((fail+1)); failed="$failed $b(rc $rc0/$rc1)"; continue
    fi
    m0=$(md5sum < "$WORK/$b.off.s" | cut -d' ' -f1)
    m1=$(md5sum < "$WORK/$b.on.s"  | cut -d' ' -f1)
    if [ "$m0" = "$m1" ]; then pass=$((pass+1)); else
        fail=$((fail+1)); failed="$failed $b"
        diff "$WORK/$b.off.s" "$WORK/$b.on.s" | head -12 > "$WORK/$b.diff"
        echo "--- DIFF $b (off vs on) ---"; cat "$WORK/$b.diff"
    fi
done
echo "ASM-TABS IDENTITY: PASS=$pass FAIL=$fail SKIP=$skip  (dir=$DIR)"
[ -n "$failed" ] && echo "FAILED:$failed"
[ $fail -eq 0 ] && { echo "GATE GREEN"; exit 0; }
echo "GATE RED"; exit 1
