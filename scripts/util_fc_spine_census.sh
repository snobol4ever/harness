#!/usr/bin/env bash
# util_fc_spine_census.sh — RUNG ZB-FC (ARCH-ZETA §13): count FORTH-cell pushes per kind across the corpus
# under SCRIP_ZETA_PORT=6.  A LEDGER COUNTER, NOT A GATE (the .s-regen philosophy: never enforce sameness —
# the number is supposed to GROW as ZB-FC-3/ZB-ACT-3 land).  Method: compile every crosscheck .sno with
# --compile under PORT=6, attribute each "sub rsp, 16" to the IR_MATCH_* comment block it appears under.
# ⛔⛔ THIS METHOD CANNOT CURRENTLY MEASURE ANYTHING, REGARDLESS OF POPULATION (found seat14 2026-09-04,
# row dead-suite-path-consumer-sweep, FINDING-2026-09-04-seat14-fc-spine-census-comment-scan-is-permanently-
# blind-since-fix-8a.md): `x86("comment", ...)` (src/templates/x86/x86_asm.h:1567) is `return std::string()`
# UNCONDITIONALLY — GOAL-BB-FIXUP.md's FIX-8a terse-comment rung made this a deliberate, ratified, gated
# no-op for BOTH media (RULES.md "x86(\"comment\") is medium-complete" — complete because it does nothing
# in either medium, not because it prints the comment correctly in both). So "# IR_MATCH_*" never appears
# in `--compile` output at all, for any input — 0 FC CELLS is not evidence ZB-FC-3/ZB-ACT-3 haven't landed;
# it is evidence this instrument's premise (grep the .s for a comment) died when FIX-8a landed, upstream of
# and unrelated to the corpus-path fossil this row cured. A real census needs a different signal — e.g.
# instrumenting zls_fc_cell() (src/ir/zeta_storage.c) directly, or a --dump-ir pass — not .s comment-text.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
set -u
SCRIP="${SCRIP:-$S4E/SCRIP/scrip}"
# ⛔ CORPUS IS EXTRACTED, NOT A FIXED TREE (row dead-suite-path-consumer-sweep): corpus/crosscheck/ is
# gone -- the corpus-suites-consolidation converted it into the rungs suite's crosscheck_* families
# (31 of them). An explicit CORPUS override still runs the old loose-directory path unchanged, for
# anyone testing against a hand-built tree.
if [ -z "${CORPUS:-}" ]; then
    WORKDIR=$(mktemp -d)
    trap 'rm -rf "$WORKDIR"' EXIT
    CORPUS="$WORKDIR/crosscheck_src"
    RUNGS_LANG="${RUNGS_LANG:-snobol4}" . "$(dirname "${BASH_SOURCE[0]}")/lib_rungs_extract.sh"
    rungs_extract_origin_prefix crosscheck_ "$CORPUS" || { echo "GATE UNPROVEN(2) [util_fc_spine_census]: could not extract the crosscheck_* families from the rungs suite"; exit 2; }
fi
[ -d "$CORPUS" ] || { echo "no corpus dir found"; exit 1; }
declare -A CELLS; TOTAL=0; PROGS=0
for f in $(find "$CORPUS" -name "*.sno" | sort); do
    [ -f "$f" ] || continue
    s=$(SCRIP_ZETA_PORT=6 timeout -k 5 8 "$SCRIP" --compile --target=x86 "$f" < /dev/null 2>/dev/null) || continue
    PROGS=$((PROGS+1))
    kind=""
    while IFS= read -r line; do
        case "$line" in
            *"# IR_MATCH_"*) kind="${line##*# }" ;;
            *"sub rsp, 16"*) [ -n "$kind" ] && { CELLS[$kind]=$(( ${CELLS[$kind]:-0} + 1 )); TOTAL=$((TOTAL+1)); } ;;
        esac
    done <<< "$s"
done
FC_SET=" IR_MATCH_ALT_NARY IR_MATCH_SPAN IR_MATCH_TAB IR_MATCH_RTAB IR_MATCH_BREAK IR_MATCH_BREAKX IR_MATCH_BAL IR_MATCH_REM "
echo "=== FORTH SPINE CENSUS (PORT=6, $PROGS programs compiled) ==="
FC=0; ZL=0
for k in $(echo "${!CELLS[@]}" | tr ' ' '\n' | sort); do
    case "$FC_SET" in *" $k "*) tag="fc cell"; FC=$((FC+${CELLS[$k]})) ;; *) tag="zls2/other rsp push (s11 class, NOT an fc cell)"; ZL=$((ZL+${CELLS[$k]})) ;; esac
    printf "  %-24s %5d  %s\n" "$k" "${CELLS[$k]}" "$tag"
done
echo "  FC CELLS: $FC   ·   other rsp pushes: $ZL   ·   total rsp pushes: $TOTAL"
