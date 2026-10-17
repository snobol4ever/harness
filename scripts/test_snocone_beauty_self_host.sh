#!/usr/bin/env bash
# test_snocone_beauty_self_host.sh — SB-6 self-host one-shot reproducer.
#
# Runs the assembled Snocone beauty driver (beauty.sc + 16 .sc lib files)
# under scrip on a SNOBOL4 input, optionally diffs against the SPITBOL oracle.
# Default input is beauty.sno itself (the SB-6 self-host case).
#
# This script is the single source of truth for "how do I reproduce SB-6"
# so future sessions don't have to reconstruct the lib chain from scratch.
#
# Usage:
#   bash ../harness/scripts/test_snocone_beauty_self_host.sh [OPTIONS]
#
# Options:
#   --input FILE       SNOBOL4 source to beautify
#                      (default: corpus/demos/snobol4/beauty/beauty.sno)
#   --mode MODE        scrip mode: --run | --run | --run
#                      (default: --run)
#   --timeout N        seconds for scrip run (default: 30)
#   --diff             also run SPITBOL oracle and diff (default: off)
#   --quiet            print only the summary line, suppress diff body
#   --keep             keep /tmp/sb6_scr.{out,err} and /tmp/sb6_spl.out for inspection
#                      (default behavior — so the existing files survive between runs)
#   --corpus PATH      corpus root (default: /home/claude/corpus)
#   --oracle PATH      sbl binary path (default: /home/claude/x64/bin/sbl)
#   --scrip  PATH      scrip binary path (default: $ROOT/scrip)
#
# Exit codes:
#   0  scrip ran (and oracle matched if --diff was given)
#   1  scrip non-zero exit, or oracle diff non-empty under --diff
#   2  setup error (missing binary/lib/input)
#
# Output (stdout):
#   - Always one summary line:
#       lines=N stderr=M parse_err=P internal_err=I rc=R
#   - With --diff: a second line:
#       diff: empty | <N differing hunks>
#   - Without --quiet and with --diff: the full diff body after the summary
#
# Files written (always preserved for inspection):
#   /tmp/sb6_scr.out   scrip stdout
#   /tmp/sb6_scr.err   scrip stderr
#   /tmp/sb6_spl.out   oracle stdout (only if --diff)
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
S4A="${S4E_ASSETS:-$([ -d "$S4E/x64" ] && echo "$S4E" || echo /home/resources)}"   # D-17b: ASSET root -- oracles/vendor trees live at the HQ root on this machine (Lon: seats carry ONLY .github/SCRIP/corpus); a root owning its own x64 (HQ, or a full standalone clone-set) is self-contained.

set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"

INPUT=""
MODE="--run"
TIMEOUT=30
DO_DIFF=0
QUIET=0
CORPUS="${CORPUS:-$S4E/corpus}"
ORACLE="${ORACLE:-$S4A/x64/bin/sbl}"
SCRIP="${SCRIP:-$ROOT/scrip}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --input)   INPUT="$2";   shift 2 ;;
        --mode)    MODE="$2";    shift 2 ;;
        --timeout) TIMEOUT="$2"; shift 2 ;;
        --diff)    DO_DIFF=1;    shift   ;;
        --quiet)   QUIET=1;      shift   ;;
        --keep)    shift   ;;  # accepted for clarity, default behavior anyway
        --corpus)  CORPUS="$2";  shift 2 ;;
        --oracle)  ORACLE="$2";  shift 2 ;;
        --scrip)   SCRIP="$2";   shift 2 ;;
        -h|--help) sed -n '2,40p' "$0"; exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
done

# --- Resolve paths ----------------------------------------------------------
SC_DIR="$CORPUS/library"
SNO_DIR="$CORPUS/demos/snobol4/beauty"
[[ -z "$INPUT" ]] && INPUT="$SNO_DIR/beauty.sno"

[[ -x "$SCRIP"   ]] || { echo "FAIL scrip not found: $SCRIP"     >&2; exit 2; }
[[ -d "$SC_DIR"  ]] || { echo "FAIL .sc dir not found: $SC_DIR"  >&2; exit 2; }
[[ -f "$INPUT"   ]] || { echo "FAIL input not found: $INPUT"     >&2; exit 2; }

# --- Lib chain --------------------------------------------------------------
# Order matches goal-file architecture (Step 1, --run with .sno-equivalent
# .sc files). This is the canonical 16-file ordering established in SB-4b.
# Last positional arg is beauty.sc itself (the main program).
LIB_FILES=(
    global.sc trace.sc stack.sc tree.sc counter.sc match.sc assign.sc
    semantic.sc omega.sc case.sc Gen.sc Qize.sc TDump.sc XDump.sc
    ShiftReduce.sc ReadWrite.sc
)
LIBS=()
for f in "${LIB_FILES[@]}"; do
    p="$SC_DIR/$f"
    [[ -f "$p" ]] || { echo "FAIL lib not found: $p" >&2; exit 2; }
    LIBS+=("$p")
done
# ⛔ THE SNOCONE DRIVER LIVES IN THE SNOCONE TREE, NOT BESIDE ITS SNOBOL4 TWIN (repointed
# 2026-09-16 by hq_snocone -- this line said demos/snobol4/beauty/beauty.sc and REFUSED rc=2
# with "FAIL driver not found", so this suite had not run since beauty.sc moved. The .sno twin
# and the INPUT above are still correctly under demos/snobol4/beauty; only the .sc moved.
DRIVER="$CORPUS/demos/snocone/beauty/beauty.sc"
[[ -f "$DRIVER" ]] || { echo "FAIL driver not found: $DRIVER" >&2; exit 2; }

# --- Run scrip --------------------------------------------------------------
SCR_OUT=/tmp/sb6_scr.out
SCR_ERR=/tmp/sb6_scr.err
SPL_OUT=/tmp/sb6_spl.out

set +e
timeout -k 5 "$TIMEOUT" "$SCRIP" "$MODE" "${LIBS[@]}" "$DRIVER" \
    < "$INPUT" > "$SCR_OUT" 2> "$SCR_ERR"
SCRIP_RC=$?
set -e

# --- Summary ----------------------------------------------------------------
LINES=$(wc -l < "$SCR_OUT")
STDERR_LINES=$(wc -l < "$SCR_ERR")
PARSE_ERR=$(grep -c 'Parse Error'    "$SCR_OUT" || true)
INTERNAL_ERR=$(grep -c 'Internal Error' "$SCR_OUT" || true)
echo "lines=$LINES stderr=$STDERR_LINES parse_err=$PARSE_ERR internal_err=$INTERNAL_ERR rc=$SCRIP_RC"

# --- Optional oracle diff ---------------------------------------------------
if [[ "$DO_DIFF" -eq 1 ]]; then
    if [[ ! -x "$ORACLE" ]]; then
        echo "diff: SKIP oracle not found: $ORACLE"
        exit 0
    fi
    bash "$HERE/util_run_beauty_oracle.sh" \
        --input  "$INPUT" \
        --corpus "$CORPUS" \
        --oracle "$ORACLE" \
        --output "$SPL_OUT" 2>/dev/null || {
        echo "diff: SKIP oracle run failed"
        exit 0
    }

    if diff -q "$SCR_OUT" "$SPL_OUT" >/dev/null 2>&1; then
        echo "diff: empty"
        exit 0
    fi

    set +e
    HUNKS=$(diff "$SCR_OUT" "$SPL_OUT" | grep -c '^[0-9]')
    echo "diff: $HUNKS hunks (scrip < / oracle >)"
    if [[ "$QUIET" -eq 0 ]]; then
        diff "$SCR_OUT" "$SPL_OUT" | head -80
    fi
    exit 1
fi

# ⛔ A RUN THAT PRODUCED NOTHING IS NOT A PASS (hq_snocone 2026-09-16). This verdict was
# `rc==0 && exit 0` alone, so the suite reported GREEN on lines=0 -- and it had been doing so
# because the lib chain is passed as BARE POSITIONALS at the scrip invocation above, and scrip
# takes the FIRST positional as the source and the rest as program args. Only global.sc ever
# ran; beauty.sc never executed; rc was 0 because global.sc exits cleanly. Load the same chain
# by concatenation instead and beauty SIGSEGVs (rc=139), which is the real state this green hid.
# The empty-output arm below is what makes that visible instead of silent.
if [[ "$LINES" -eq 0 ]]; then
    echo "FAIL beauty produced NO OUTPUT (lines=0) -- a run that emitted nothing is not a pass." >&2
    echo "     scrip rc=$SCRIP_RC. The lib chain above is passed as bare positionals; scrip loads" >&2
    echo "     only the FIRST and treats the rest as program args, so beauty.sc never runs. A .sc" >&2
    echo "     program cannot load a chain at all today: -L is collected for every language but" >&2
    echo "     expanded into -INCLUDE only on the SNOBOL4 path (src/driver/scrip.c:1218), while the" >&2
    echo "     Snocone branch calls snocone_compile() and never reads n_preload." >&2
    exit 1
fi
[[ "$SCRIP_RC" -eq 0 ]] && exit 0 || exit 1
