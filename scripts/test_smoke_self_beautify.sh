#!/usr/bin/env bash
# test/smoke/test_self_beautify.sh
#
# Milestone 0 validation: beauty_full_bin self-beautifies beauty.sno
# and the output matches the CSNOBOL4 oracle.
#
# Usage: ./test_self_beautify.sh [path/to/beauty_full_bin]
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)

set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
BEAUTY="$S4E/corpus/demos/snobol4/beauty/beauty.sno"
INC="$S4E/corpus/include"
BIN="${1:-/tmp/beauty_full_bin}"

echo "=== Milestone 0: self-beautify smoke test ==="
echo "Binary: $BIN"

# ⛔⛔ THIS SCRIPT USED TO REPORT rc=1 (FAIL) FOR EVERY CANNOT-MEASURE STATE, AND POINTED AT A REMEDY THAT
# DOES NOT EXIST. "run build_beauty.sh first" — there is no build_beauty.sh anywhere in ../harness/scripts/, so the one
# instruction it gave could not be followed, and a reader saw a FAIL for a test that had never run. Under
# RULES.md THE INSTRUMENT LAWS clause 2, measured-and-clean and never-ran may not share an output: every
# cannot-measure arm below now REFUSES with rc=2 and says what is actually missing, and rc=1 is reserved for a
# real measured mismatch. (A THIRD shape of the night's silent-success family — not skip-as-pass but
# skip-as-FAIL, which is worse, because it spends someone's debugging time on a program that never started.)
if [[ ! -x "$BIN" ]]; then
    echo "Binary absent — building it (this is what the missing build_beauty.sh was supposed to do)."
    SCRIP_BIN="${SCRIP:-$REPO/SCRIP/scrip}"; RTDIR="${RT_DIR:-$REPO/SCRIP/out}"
    [[ -x "$SCRIP_BIN" ]] || { echo "REFUSING rc=2: no scrip at $SCRIP_BIN — cannot build the beauty binary, so this test never ran. Not a FAIL." >&2; exit 2; }
    TMPS="$(mktemp -d)/beauty.s"
    trap 'rm -rf "${TMPS%/*}"' EXIT INT TERM
    ( cd "$INC" && timeout -k 5 300 "$SCRIP_BIN" --compile "$BEAUTY" --out="$TMPS" < /dev/null ) 2>/dev/null || { echo "REFUSING rc=2: scrip could not COMPILE $BEAUTY — a compiler defect to chase on its own, not a self-beautify result." >&2; exit 2; }
    gcc -no-pie "$TMPS" -L"$RTDIR" -lscrip_rt -lm -Wl,-rpath,"$RTDIR" -o "$BIN" 2>/dev/null || { echo "REFUSING rc=2: could not link the beauty binary against $RTDIR — this test never ran." >&2; exit 2; }
    echo "Built: $BIN"
fi

# 1. Oracle
echo -n "Running CSNOBOL4 oracle ... "
# ⛔ "FAIL: oracle crashed" WAS A WRONG DIAGNOSIS, NOT MERELY A WRONG EXIT CODE. `snobol4` (CSNOBOL4) is not
# installed in this environment at all, so the old arm blamed a crash for an absence and sent the reader hunting
# a defect in a program that never started. ⚠️ DELIBERATELY NOT SWITCHED to sbl: this test asserts agreement
# with CSNOBOL4 specifically, and silently substituting a different oracle would change WHAT IS ASSERTED while
# leaving the name intact — the same class of defect this file is being repaired for. Needs a ruling on which
# oracle beauty grades against; until then it refuses honestly rather than quietly measuring something else.
if ! command -v snobol4 >/dev/null 2>&1; then
    echo "REFUSING rc=2: the CSNOBOL4 oracle (snobol4) is NOT INSTALLED here — this test never ran. Not a crash, not a FAIL. Needs a ruling on whether beauty grades against CSNOBOL4 or sbl (see this file's comment)." >&2
    exit 2
fi
if snobol4 -f -P256k -I "$INC" "$BEAUTY" < "$BEAUTY" > /tmp/beauty_oracle.sno 2>/dev/null; then
    ORACLE_LINES=$(wc -l < /tmp/beauty_oracle.sno)
    echo "OK ($ORACLE_LINES lines)"
else
    echo "FAIL: oracle is installed but produced no output"
    exit 1
fi

# 2. Compiled binary
echo -n "Running compiled binary ... "
if timeout -k 5 30 "$BIN" < "$BEAUTY" > /tmp/beauty_compiled.sno 2>/tmp/beauty_stderr.txt; then
    COMPILED_LINES=$(wc -l < /tmp/beauty_compiled.sno)
    echo "OK ($COMPILED_LINES lines)"
else
    RC=$?
    echo "FAIL (rc=$RC)"
    head -5 /tmp/beauty_stderr.txt
    head -5 /tmp/beauty_compiled.sno
    exit 1
fi

# 3. Diff
echo -n "Diffing oracle vs compiled ... "
if diff /tmp/beauty_oracle.sno /tmp/beauty_compiled.sno > /tmp/beauty_diff.txt 2>&1; then
    echo "EMPTY DIFF"
    echo ""
    echo "============================================"
    echo "MILESTONE 0 ACHIEVED — self-beautification matches oracle."
    exit 0
else
    DIFF_LINES=$(wc -l < /tmp/beauty_diff.txt)
    echo "DIFF ($DIFF_LINES lines)"
    echo ""
    head -40 /tmp/beauty_diff.txt
    echo ""
    echo "============================================"
    echo "MILESTONE 0 NOT YET ACHIEVED."
    exit 1
fi
