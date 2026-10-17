#!/usr/bin/env bash
# run_parser_sync_monitor.sh — GOAL-PARSER-SC-TRANSPILE.md SCT-7.
#
# LON'S METHOD (2026-09-24, verbatim: "You transpile to *.sno, then run the *.sno with IPC sync-step monitor to
# compare SCRIP to SPITBOL. But first you get the transpiled program working is SPITBOL."), end to end:
#   1. transpile the bootstrap runtime chain + parser_<lang>.sc to ONE portable .sno with `scrip --transpile`
#      (the switch takes every file and merges them; --dump-sno, which this script used to call, no longer exists);
#   2. run that .sno on SPITBOL FIRST with the sample on stdin -- if the oracle refuses or errors, STOP: the fault is
#      the transpiler's or the parser's, and a monitor run against a failing oracle measures nothing (rc 4);
#   3. then drive ../harness/scripts/monitor_run.sh <.sno> --oracle --input <sample>: SPITBOL and SCRIP mode 3 in lock-step on the
#      SAME .sno, the first divergence being the SCRIP defect.
#
# The transpiler is the new piece; the monitor harness was built earlier
# (see ../harness/scripts/test_monitor_2way_spitbol_vs_sm.sh and friends).  This
# script is the glue that ties them together for the parser-transpile
# rung sequence.
#
# Usage:
#   bash ../harness/scripts/run_parser_sync_monitor.sh <lang> <sample-input>
#
# Examples:
#   bash ../harness/scripts/run_parser_sync_monitor.sh snobol4  corpus/tests/snobol4/parser/atom_id.sno
#   bash ../harness/scripts/run_parser_sync_monitor.sh rebus    corpus/tests/rebus/parser_paren.reb
#   bash ../harness/scripts/run_parser_sync_monitor.sh snocone  corpus/tests/snocone/test_capture_call.sc
#   bash ../harness/scripts/run_parser_sync_monitor.sh icon     corpus/tests/icon/parser/fail_stmt.icn
#   bash ../harness/scripts/run_parser_sync_monitor.sh raku     corpus/tests/raku/parser/str_chars.raku
#   bash ../harness/scripts/run_parser_sync_monitor.sh prolog   corpus/tests/prolog/rung01_hello_hello.pl
#
# Exit codes:
#   0 — both runtimes agreed throughout (monitor_run.sh's verdict)
#   1 — divergence detected (monitor prints last-agree + first-disagree)
#   2 — transpile failed, or the monitor could not measure
#   3 — usage error
#   4 — step 2 not done: SPITBOL itself does not parse the sample through the transpiled .sno
set -uo pipefail

PLANG=${1:?Usage: run_parser_sync_monitor.sh <lang> <sample-input>}
SAMPLE=${2:?Usage: run_parser_sync_monitor.sh <lang> <sample-input>}

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../../SCRIP" && pwd)"

PARSER_SC="$REPO_ROOT/bootstrap/parser_${PLANG}.sc"
if [[ ! -f "$PARSER_SC" ]]; then
    # Try alternative layout
    PARSER_SC="$REPO_ROOT/bootstrap/parser_${PLANG}.sc"
fi
if [[ ! -f "$PARSER_SC" ]]; then
    echo "run_parser_sync_monitor: cannot find parser_${PLANG}.sc" >&2
    exit 3
fi
if [[ ! -f "$SAMPLE" ]]; then
    echo "run_parser_sync_monitor: cannot find sample input '$SAMPLE'" >&2
    exit 3
fi

SCRIP="${SCRIP:-$REPO_ROOT/scrip}"
if [[ ! -x "$SCRIP" ]]; then
    echo "run_parser_sync_monitor: scrip not built at $SCRIP" >&2
    exit 2
fi

SNO_OUT="/tmp/parser_${PLANG}.sno"

# SCT-1c-2: dump the full Snocone runtime prelude alongside parser_<lang>.sc so
# the resulting .sno is self-contained.  Order mirrors run_scrip_parser.sh exactly
# (which mirrors the beauty.sno -INCLUDE chain).
# PIVOT (2026-05-17, Claude Sonnet 4.6): include gen.sc and language-specific helpers
# alongside the parser so all six languages transpile cleanly.  Helpers will be
# eliminated in a later cleanup session (SCT-4/5/6); for now they are included.
CORPUS_SCRIP="$REPO_ROOT/bootstrap"   # the runtime moved here from the retired corpus/SCRIP/ (s267 REPO BOUNDARY)
RUNTIME=(
    "$CORPUS_SCRIP/global.sc"
    "$CORPUS_SCRIP/case.sc"
    "$CORPUS_SCRIP/assign.sc"
    "$CORPUS_SCRIP/match.sc"
    "$CORPUS_SCRIP/counter.sc"
    "$CORPUS_SCRIP/stack.sc"
    "$CORPUS_SCRIP/tree.sc"
    "$CORPUS_SCRIP/ShiftReduce.sc"
    "$CORPUS_SCRIP/tdump.sc"
    "$CORPUS_SCRIP/gen.sc"
    "$CORPUS_SCRIP/qize.sc"
    "$CORPUS_SCRIP/semantic.sc"
    "$CORPUS_SCRIP/omega.sc"
    "$CORPUS_SCRIP/trace.sc"
)
for f in "${RUNTIME[@]}"; do
    if [[ ! -f "$f" ]]; then
        echo "run_parser_sync_monitor: missing runtime file '$f'" >&2
        exit 2
    fi
done

# Load language-specific helpers if they exist (icon_helpers.sc, raku_helpers.sc).
# These are loaded between runtime and parser, matching run_scrip_parser.sh behaviour.
HELPERS=()
HELPER_FILE="$CORPUS_SCRIP/${PLANG}_helpers.sc"
if [[ -f "$HELPER_FILE" ]]; then
    HELPERS=("$HELPER_FILE")
    echo "[run_parser_sync_monitor] including helpers: $HELPER_FILE"
fi

echo "[run_parser_sync_monitor] transpiling runtime + $PARSER_SC -> $SNO_OUT"
if ! "$SCRIP" --transpile "${RUNTIME[@]}" "${HELPERS[@]}" "$PARSER_SC" > "$SNO_OUT"; then
    echo "run_parser_sync_monitor: --transpile failed for $PARSER_SC" >&2
    exit 2
fi

# Sanity: did we emit any TT_xxx placeholders? Warn but don't abort —
# the monitor will tell us if those tags actually affect execution.
PLACEHOLDERS=$(grep -c "?TT_\|BOTH-QUOTES" "$SNO_OUT" || true)
if [[ "$PLACEHOLDERS" -gt 0 ]]; then
    echo "[run_parser_sync_monitor] WARNING: $PLACEHOLDERS unhandled-tag placeholder(s) in transpiled output"
    grep -n "?TT_\|BOTH-QUOTES" "$SNO_OUT" | head -5
fi

# Quick line-length sanity (SPITBOL Manual Ch.14 line 9022: 1024-char cap;
# emitter splits at ~900 to leave headroom).  Hard-fail if exceeded — that
# means a long quoted string had no safe split point.
OVERLEN=$(awk 'length>1024' "$SNO_OUT" | wc -l)
if [[ "$OVERLEN" -gt 0 ]]; then
    echo "[run_parser_sync_monitor] WARNING: $OVERLEN line(s) exceed SPITBOL's 1024-char limit"
fi

# STEP 2 -- the oracle first. SPITBOL exits 0 even on an ERROR, so its TEXT is read, never its rc.
SBL="${SBL:-/home/resources/x64/bin/sbl}"
# The oracle runs at the sizes bootstrap/parser_<lang>.oracle_args declares (ceo CEO-1353, RULES.md clause 8 (g)(3)), never typed here.
. "$HERE/lib_declared_arena.sh" || { echo "run_parser_sync_monitor: cannot load lib_declared_arena.sh" >&2; exit 2; }
OARGS="$(declared_oracle_args_beside "$PARSER_SC")" || exit 2
ORACLE_OUT="$(timeout -k 5 60 "$SBL" -bf $OARGS "$SNO_OUT" < "$SAMPLE" 2>&1)"
if printf '%s\n' "$ORACLE_OUT" | grep -qE '^Parse Error\.?$|ERROR [0-9]+ --'; then
    echo "[run_parser_sync_monitor] STEP 2 NOT DONE: SPITBOL itself does not parse $SAMPLE through $SNO_OUT:"
    printf '%s\n' "$ORACLE_OUT" | grep -v '^$' | head -5 | sed 's/^/    /'
    echo "  fix the transpile (src/lower/tree_to_sno.c) or, by a few characters, the parser -- then monitor"
    exit 4
fi
echo "[run_parser_sync_monitor] step 2: SPITBOL parses the sample ($(printf '%s\n' "$ORACLE_OUT" | grep -vc '^$') output lines)"
# STEP 3 -- the IPC sync-step monitor through its one sanctioned entry point (CEO-1186).
echo "[run_parser_sync_monitor] step 3: monitor_run.sh $SNO_OUT --oracle --input $SAMPLE"
exec bash "$HERE/monitor_run.sh" "$SNO_OUT" --oracle --input "$SAMPLE"
