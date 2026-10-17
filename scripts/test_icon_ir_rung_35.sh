#!/usr/bin/env bash
# test_icon_ir_rung_35.sh — rung35: block bodies + str/str table — IC-7
# Gate: PASS=7 FAIL=0 XFAIL=0
# Authors: LCherryholmes · Claude Sonnet 4.6   DATE: 2026-04-16
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${SCRIP:-$HERE/../../SCRIP/scrip}"
CORPUS="${CORPUS:-$S4E/corpus/tests/icon}"
PASS=0; FAIL=0; XFAIL=0

if [ ! -x "$SCRIP" ];  then echo "SKIP scrip not found at $SCRIP";  exit 0; fi
if [ ! -d "$CORPUS" ]; then echo "SKIP corpus not found at $CORPUS"; exit 0; fi

run() {
    local base="$CORPUS/$1"
    [ -f "${base}.xfail" ] && { echo "  XFAIL $1"; XFAIL=$((XFAIL+1)); return; }
    [ -f "${base}.ref" ] || { echo "  SKIP  $1 (no .ref)"; return; }
    local stdin_f="${base}.stdin"; [ -f "$stdin_f" ] || stdin_f="$(dirname "$base")/config/$(basename "$base").stdin"
    local got want
    if [ -f "$stdin_f" ]; then
        got=$(timeout -k 5 8 "$SCRIP" --run "${base}.icn" < "$stdin_f"  2>/dev/null) || true
    else
        got=$(timeout -k 5 8 "$SCRIP" --run "${base}.icn" < /dev/null   2>/dev/null) || true
    fi
    want=$(cat "${base}.ref")
    if [ "$got" = "$want" ]; then
        echo "  PASS $1"; PASS=$((PASS+1))
    else
        echo "  FAIL $1"
        echo "    want: $(echo "$want" | tr '\n' '|')"
        echo "    got:  $(echo "$got"  | tr '\n' '|')"
        FAIL=$((FAIL+1))
    fi
}

echo "=== rung35: block bodies + table str/str ==="
run rung35_block_body_every_do_block
run rung35_block_body_if_block
run rung35_block_body_if_else_block
run rung35_block_body_nested_block
run rung35_block_body_while_do_block
run rung35_table_str_str_default_int_key
run rung35_table_str_str_table_read

echo ""
echo "PASS=$PASS FAIL=$FAIL XFAIL=$XFAIL"
# ⛔⭐ ZERO-GRADED IS A REFUSAL, NOT A PASS (hq_B 2026-08-30, row graders-denominator-audit-six-families).
# MEASURED: every witness this script names lost its per-entry .expected file when the family was
# consolidated, so run() took its `[ -f ... ] || { echo SKIP; return; }` arm for ALL of them, PASS and
# FAIL both stayed 0, and `[ "$FAIL" -eq 0 ]` reported GREEN having graded nothing. That is WORSE than an
# unmatched glob: this script names its witnesses, DETECTS that each is missing, prints SKIP, and counts
# it as neither -- skip-as-success, which RULES.md calls the same defect with better manners.
# ⭐ The denominator was written at the top of this file the whole time (the `# Gate: PASS=n` header) and
# nothing ever compared against it. A declared expectation that no code reads is a comment, not a gate.
# ⛔ THE CONTENT IS NOT LOST AND THIS IS NOT RE-POINTED ON PURPOSE: test_icon_all_rungs.sh /
# test_icon_rung_suite.sh / test_icon_x64_all_rungs.sh already grade these families as SUITE pairs
# (measured: `SUITE rung30_builtins_misc: pass=5`, and so on for 31-35, 33 entries in total). So this
# script is REDUNDANT, not a coverage hole -- unlike the Prolog twins, where no rungs board over ALL.pl
# existed and the same shape hid 143 real gradings. Re-pointing this at the absorbed data would duplicate
# the aggregate; refusing is the honest state, and whether to retire it outright is a corpus-layout call.
if [ $((PASS+FAIL+XFAIL)) -eq 0 ]; then
    echo "REFUSE (rc=2): graded ZERO witnesses -- every named witness lacks its .ref (consolidated away). Coverage lives in test_icon_all_rungs.sh as SUITE pairs AND, since 2026-08-30, in board_icon_rungs.sh, which grades the whole 534-entry ALL.icn set and prints its own denominator -- so a family that stops being graded is now caught at the SET level, which is the guarantee the family-by-family graders never gave. This script is redundant, not a hole. Cannot measure, not a pass."
    exit 2
fi
[ "$FAIL" -eq 0 ]
