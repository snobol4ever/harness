#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib_one_runner.sh" && one_runner_guard "${0##*/}" "${WIRTH76_SUITE:=${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}/corpus/packages/pascal/wirth1976}" || exit 2
# test_pascal_wirth76_suite.sh -- THE Wirth76 SUITE ROW: Niklaus Wirth's Algorithms + Data Structures = Programs (1976), each program
# transcribed to ISO 7185 with its driver (corpus/packages/pascal/wirth1976/, hq_pascal's row), graded in both SCRIP modes against
# refs cut from fpc -Miso. Lon 2026-10-09 17:0x CDT, in-chat to the ceo, verbatim: "Have drivers created for the Wirth 1976 and make it
# an official test suite." (CEO-1580; the coo's row instruments-the-wirth76-suite-row-...). The shape of test_pascal_fpc_suite.sh, without
# the fpc_tests history: every <name>.pas is a whole program, <name>.ref its oracle output, <name>.in its stdin when present, ALL.wantrc
# fpc's own exit status where it is not 0, ALL.timeout.tsv a declared run timeout with its reason, ALL.csv each unit's heap_kb/stack_kb.
# A .pas with no .ref is UNGRADED (REF_NOT_CUT), never dropped. The row is THE AND PER PROGRAM (ceo-372): green in both modes.
set -u
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib_flag_gate.sh" 2>/dev/null || { echo "⛔ REFUSED-TO-GRADE: lib_flag_gate.sh unloadable"; exit 2; }
. "$HERE/lib_inventory.sh" 2>/dev/null || { echo "⛔ REFUSED-TO-GRADE: lib_inventory.sh unloadable"; exit 2; }
. "$HERE/lib_progress.sh" 2>/dev/null || { echo "⛔ REFUSED-TO-GRADE: lib_progress.sh unloadable"; exit 2; }
[ $# -eq 0 ] || flaggate_reject "$1" "(none -- set WIRTH76_SUITE_RUN_TIMEOUT via environment instead)"
SCRIP="${HERE}/../../SCRIP/scrip"
RT_SO="${HERE}/../../SCRIP/out/libscrip_rt.so"
SUITE="${WIRTH76_SUITE:-$S4E/corpus/packages/pascal/wirth1976}"
KEY="${WIRTH76_SUITE_KEY:-wirth76}"
WANTRC="$SUITE/ALL.wantrc"
RUN_TIMEOUT="${WIRTH76_SUITE_RUN_TIMEOUT:-10}"
[ -d "$SUITE" ] || { echo "⛔ REFUSED-TO-GRADE: $SUITE missing (the package is hq_pascal's row: pascal-wirth-1976-...-ceo-1580)"; exit 2; }
[ -x "$SCRIP" ] || { echo "⛔ REFUSED-TO-GRADE: scrip not built"; exit 2; }
"$HERE/util_require_fresh.sh" --gate test_pascal_wirth76_suite "$SCRIP" "${RT_DIR:-$HERE/../../SCRIP/out}/libscrip_rt.so" || exit 2
[ -f "$RT_SO" ] || { echo "⛔ REFUSED-TO-GRADE: $RT_SO missing (m4 link needs it)"; exit 2; }
TIMEOUT_TSV="$SUITE/ALL.timeout.tsv"; declare -A TMO_OF=()
if [ -f "$TIMEOUT_TSV" ]; then
    while IFS=$'\t' read -r _tn _ts _tr; do case "$_tn" in ''|'#'*) continue;; esac
        [ -f "$SUITE/$_tn.pas" ] || { echo "⛔ REFUSED-TO-GRADE: ALL.timeout.tsv names $_tn, which is not in $SUITE"; exit 2; }
        case "$_ts" in ''|*[!0-9]*) echo "⛔ REFUSED-TO-GRADE: ALL.timeout.tsv gives $_tn the non-numeric timeout '$_ts'"; exit 2;; esac
        TMO_OF[$_tn]="$_ts"; echo "-- declared run timeout: $_tn ${_ts}s ($_tr)"; done < "$TIMEOUT_TSV"
fi
TMP="$(mktemp -d /tmp/wirth76_suite_XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
. "$HERE/lib_declared_arena.sh" || { echo "⛔ REFUSED-TO-GRADE: lib_declared_arena.sh unloadable -- the one reader of a declared heap and stack"; exit 2; }
DECL="$TMP/declared_memory.tsv"
declared_memory_begin "$SUITE/ALL.csv" "$DECL" || { echo "⛔ REFUSED-TO-GRADE: a declared-memory cell in $SUITE/ALL.csv is refused (named above) -- fix the cell; this board does not grade around it"; exit 2; }
cd "$TMP"
mapfile -t PROGS < <(cd "$SUITE" && ls *.pas 2>/dev/null | sed 's/\.pas$//' | sort)
TOTAL=${#PROGS[@]}
"$HERE/util_require_population.sh" --gate test_pascal_wirth76_suite "$TOTAL" 1 "Wirth 1976 programs" || exit 2
M3_PASS=0; M3_FAIL=0; M4_PASS=0; M4_FAIL=0; BOTH_PASS=0; NOREF=0
M3_FAIL_NAMES=(); M4_FAIL_NAMES=(); NOREF_NAMES=()
PROG_ROWS="$TMP/progress.tsv"; : >"$PROG_ROWS"
echo "=== Wirth76 suite grade ($TOTAL programs, $SUITE) ==="
for name in "${PROGS[@]}"; do
    export S4E_TIMEOUT_KEY="$name"
    pas="$SUITE/$name.pas"; ref="$SUITE/$name.ref"
    inp="$SUITE/$name.in"; [ -f "$inp" ] || inp=/dev/null
    if [ ! -f "$ref" ]; then
        NOREF=$((NOREF+1)); NOREF_NAMES+=("$name")
        for m in m3 m4; do printf 'package\t%s\tpascal\t%s\t%s\tUNGRADED\t0\tno-ref-cut\n' "$KEY" "$name" "$m" >>"$PROG_ROWS"; done
        continue
    fi
    exp="$(cat "$ref")"
    T_RUN="${TMO_OF[$name]:-$RUN_TIMEOUT}"
    wantrc=$(awk -F'\t' -v n="$name" '$1==n{print $2; exit}' "$WANTRC" 2>/dev/null); [ -n "$wantrc" ] || wantrc=0
    m3ok=0; _t0="$(progress_clock)"
    m3out=$(cd "$TMP" && run_at_declared_table "$DECL" "$name" -- "$TIMEOUT_RETRY" "$T_RUN" "$SCRIP" --run "$pas" < "$inp" 2>/dev/null); m3rc=$?
    S3="$(progress_secs_since "$_t0")"   # each mode's own wall for its row (CEO-1676 (c)); m4's takes its compile and link
    if [ "$m3out" = "$exp" ] && [ "$m3rc" = "$wantrc" ]; then
        M3_PASS=$((M3_PASS+1)); m3ok=1; printf 'package\t%s\tpascal\t%s\tm3\tPASS\t%s\t\n' "$KEY" "$name" "$S3" >>"$PROG_ROWS"
    else
        M3_FAIL=$((M3_FAIL+1)); M3_FAIL_NAMES+=("$name")
        if [ "$m3out" = "$exp" ]; then _d3="exit-code-differs(got=$m3rc want=$wantrc)"; else _d3="output-differs-from-ref"; fi
        [ "$m3rc" = 124 ] && _d3="timeout-at-${T_RUN}s"
        printf 'package\t%s\tpascal\t%s\tm3\tFAIL\t%s\t%s\n' "$KEY" "$name" "$S3" "$_d3" >>"$PROG_ROWS"
    fi
    m4bin="$TMP/${name}.bin"; m4s="$TMP/${name}.s"; _t0="$(progress_clock)"
    if "$TIMEOUT_RETRY" "$T_RUN" "$SCRIP" --compile "$pas" -o "$m4s" < /dev/null 2>/dev/null \
        && gcc -no-pie "$m4s" -L "${HERE}/../../SCRIP/out" -lscrip_rt -Wl,-rpath,"${HERE}/../../SCRIP/out" -o "$m4bin" 2>/dev/null; then
        m4out=$(cd "$TMP" && run_at_declared_table "$DECL" "$name" -- "$TIMEOUT_RETRY" "$T_RUN" "$m4bin" < "$inp" 2>/dev/null); m4rc=$?
        S4="$(progress_secs_since "$_t0")"
        if [ "$m4out" = "$exp" ] && [ "$m4rc" = "$wantrc" ]; then
            M4_PASS=$((M4_PASS+1)); [ "$m3ok" -eq 1 ] && BOTH_PASS=$((BOTH_PASS+1))
            printf 'package\t%s\tpascal\t%s\tm4\tPASS\t%s\t\n' "$KEY" "$name" "$S4" >>"$PROG_ROWS"
        else
            M4_FAIL=$((M4_FAIL+1)); M4_FAIL_NAMES+=("$name")
            if [ "$m4out" = "$exp" ]; then _d4="exit-code-differs(got=$m4rc want=$wantrc)"; else _d4="output-differs-from-ref"; fi
            [ "$m4rc" = 124 ] && _d4="timeout-at-${T_RUN}s"
            printf 'package\t%s\tpascal\t%s\tm4\tFAIL\t%s\t%s\n' "$KEY" "$name" "$S4" "$_d4" >>"$PROG_ROWS"
        fi
    else
        S4="$(progress_secs_since "$_t0")"
        M4_FAIL=$((M4_FAIL+1)); M4_FAIL_NAMES+=("$name (build/link failed)")
        printf 'package\t%s\tpascal\t%s\tm4\tFAIL\t%s\tbuild-or-link-failed\n' "$KEY" "$name" "$S4" >>"$PROG_ROWS"
    fi
done
echo ""
[ "$NOREF" -gt 0 ] && echo "-- programs with no .ref cut yet (UNGRADED, REF_NOT_CUT): $NOREF -- ${NOREF_NAMES[*]}"
[ "$M3_FAIL" -gt 0 ] && echo "-- m3 FAIL ($M3_FAIL): ${M3_FAIL_NAMES[*]}"
[ "$M4_FAIL" -gt 0 ] && echo "-- m4 FAIL ($M4_FAIL): ${M4_FAIL_NAMES[*]}"
echo ""
echo "WIRTH76_SUITE_BOARD total=$TOTAL both_pass=$BOTH_PASS m3_pass=$M3_PASS m3_fail=$M3_FAIL m4_pass=$M4_PASS m4_fail=$M4_FAIL ungraded=$NOREF"
INV_PACKAGE="$KEY"; INV_DIR="$SUITE"; INV_EXT=".pas"
INV_LINE="$(inventory_line "$((TOTAL - NOREF))" 0)"
if [ -n "$INV_LINE" ]; then echo "$INV_LINE"; else echo "⚠ inventory refused (above) -- the board line still stands; the inventory does not" >&2; fi
if [ -s "$PROG_ROWS" ]; then
    progress_append_rows_tsv "$PROG_ROWS" || echo "⚠ PROGRESS DB NOT UPDATED -- the score write below cannot cross-check and will refuse (reason above)" >&2
fi
python3 "$HERE/util_score_row.py" write --lang pascal --column vendor --suite "$KEY" --suite-key "$KEY" --modes m3,m4 \
    ${S4E_CRITERION_CHANGED:+--criterion-changed "$S4E_CRITERION_CHANGED"} \
    --suite-pass "$BOTH_PASS" --suite-total "$TOTAL" \
    --measurer "${S4E_SEAT:-}" --text "Wirth76 both-modes $BOTH_PASS/$TOTAL · m3 $M3_PASS/$TOTAL · m4 $M4_PASS/$TOTAL (m3_fail=$M3_FAIL m4_fail=$M4_FAIL ungraded=$NOREF${INV_LINE:+ · $INV_LINE (\`test_pascal_wirth76_suite.sh\`)})" \
    || echo "⚠ SCORE.md NOT UPDATED -- record this row by hand (the REFUSED line above says why)"
[ "$M3_FAIL" -eq 0 ] && [ "$M4_FAIL" -eq 0 ] && [ "$NOREF" -eq 0 ]
