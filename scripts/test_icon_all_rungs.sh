#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib_one_runner.sh" && one_runner_guard "${0##*/}" "$(one_runner_population_of "$@")" || exit 2
# ../harness/scripts/test_icon_all_rungs.sh — Icon rung ladder runner under scrip --run.
# Self-contained. Run from anywhere with no env vars.
# Usage: bash ../harness/scripts/test_icon_all_rungs.sh [--rung RUNG] [--scrip PATH] [--corpus PATH]
#
# Runs rung01–rung36 (or a specific rung) of the Icon corpus against
# scrip --run and reports PASS/FAIL/XFAIL vs .ref files.
# Files with a matching .xfail marker are skipped as known-unimplemented (XFAIL).
# All rungs use timeout 8s. rung36_jcon_subjpos quarantined via .xfail (infinite
# loop in --run subject/&pos path, hangs to timeout; see GOAL-ICON-BB). No
# legitimate rung36 program exceeds 8s (timing audit 2026-05-26).
#
# Replaces test_icon_all_rungs.sh (deleted, was --run-based and gated on
# the now-amputated Icon AST walker). The reference path for Icon is --run.
#
# SUITE-FORMAT DELEGATION (tests-consolidate-icon, 2026-08-28): a family converted by
# corpus_suite_harness.py loses its loose rungNN_*.icn files and becomes one <family>.icn+.ref
# pair (discriminator: a .ref sibling AND section banners in the source). Left in the raw per-file glob
# it would either vanish silently (empty-glob false-green) or, since a suite file's name still
# matches the glob, get misread as MISSING (this script counts a missing .ref as MISSING and
# fails the gate on it -- see the MISSING branch below). Converted families are routed into
# SUITE_FILES instead and folded into the same PASS/FAIL totals via `corpus_suite_harness.py run`
# after the per-file loops. This script runs under `set -e`, unlike its interp/run/compile twin
# test_icon_rung_suite.sh, so every command in that block is explicitly guarded (`|| true`) --
# a real FAIL inside a converted family is an expected, must-not-abort-the-script outcome here.
# ⚠️ Known gap, not fixed here: rung36's per-category tally (r36_tally, below) reads individual
# per-file names and would go blind for any rung36 entries folded into a suite -- not a concern
# today (rung36 is not a converted family), but worth remembering if it ever becomes one.
#
# Authors: LCherryholmes · Claude Sonnet 4.6 · Claude Opus 4.7 · Claude Sonnet 5
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export TIMEOUT_RETRY="${TIMEOUT_RETRY:-$HERE/util_timeout_retry.sh}"   # a graded run's timeout (CEO-1335): a timeout under load is retried once, util_timeout_retry.sh
. "$HERE/lib_icn_rundir.sh"   # THE ONE AUTHORITY for a witness's stdin/argv/fixtures/env contract -- see that file's header
SCRIP="${SCRIP:-$HERE/../../SCRIP/scrip}"
CORPUS="${CORPUS:-$S4E/corpus/tests/icon}"
RUNG=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --rung)   RUNG="$2";   shift 2 ;;
        --scrip)  SCRIP="$2";  shift 2 ;;
        --corpus) CORPUS="$2"; shift 2 ;;
        *) echo "Usage: $0 [--rung RUNG] [--scrip PATH] [--corpus PATH]" >&2; exit 1 ;;
    esac
done

if [ ! -x "$SCRIP" ]; then
    echo "SKIP scrip binary not found at $SCRIP" >&2
    exit 0
fi
if [ ! -d "$CORPUS" ]; then
    echo "SKIP corpus not found at $CORPUS" >&2
    echo "     clone snobol4ever/corpus to $S4E/corpus to run this suite" >&2
    exit 0
fi

PASS=0; FAIL=0; XFAIL=0; XPASS=0; BADEXIT=0; MISSING=0; INVALID=0
ICN_SCRATCH=$(mktemp -d)
trap 'rm -rf "$ICN_SCRATCH"' EXIT
declare -a SUITE_FILES=()
# converted-family discriminator (see header note): a .ref sibling AND corpus_suite_harness.py's section banners
# (`#---- <seq> <name>`) in the source. The sibling alone decided while loose programs carried a .expected; since
# CEO-1222 every loose expected output is a .ref as well, so the source's own shape is what tells a container.
is_suite_file() { [ -f "${1%.icn}.ref" ] && grep -qE '^#-{3,} [0-9]+ [^[:space:]]' "$1"; }

# rung36 per-category tally (sidecar map at corpus/rung36_categories.txt)
declare -A R36_CAT_P R36_CAT_F R36_CAT_X R36_CAT_XP
R36_MAP_FILE="$CORPUS/rung36_categories.txt"
declare -A R36_NAME_TO_CAT
if [ -f "$R36_MAP_FILE" ]; then
    while IFS=$'\t' read -r r36_name r36_cat; do
        case "$r36_name" in ''|'#'*) continue ;; esac
        R36_NAME_TO_CAT["$r36_name"]="$r36_cat"
        R36_CAT_P["$r36_cat"]=${R36_CAT_P["$r36_cat"]:-0}
        R36_CAT_F["$r36_cat"]=${R36_CAT_F["$r36_cat"]:-0}
        R36_CAT_X["$r36_cat"]=${R36_CAT_X["$r36_cat"]:-0}
        R36_CAT_XP["$r36_cat"]=${R36_CAT_XP["$r36_cat"]:-0}
    done < "$R36_MAP_FILE"
fi

r36_tally() {
    local name="$1" status="$2"
    case "$name" in
        rung36_jcon_*)
            local stem="${name#rung36_jcon_}"
            local cat="${R36_NAME_TO_CAT[$stem]:-uncategorized}"
            case "$status" in
                PASS)    R36_CAT_P["$cat"]=$((${R36_CAT_P["$cat"]:-0}+1)) ;;
                FAIL)    R36_CAT_F["$cat"]=$((${R36_CAT_F["$cat"]:-0}+1)) ;;
                BADEXIT) R36_CAT_F["$cat"]=$((${R36_CAT_F["$cat"]:-0}+1)) ;;
                XFAIL) R36_CAT_X["$cat"]=$((${R36_CAT_X["$cat"]:-0}+1)) ;;
                XPASS) R36_CAT_XP["$cat"]=$((${R36_CAT_XP["$cat"]:-0}+1)) ;;
            esac
            ;;
    esac
}

run_one() {
    local icn="$1"
    local tmo="${2:-8}"
    local exp="${icn%.icn}.ref"
    local base="${icn%.icn}"
    local name
    name=$(basename "$icn" .icn)
    if [ ! -f "$exp" ]; then
        # a pairless file the ORACLE refuses is not a board member (lib_icn_rundir.sh icn_oracle_refuses); one it compiles owes a ref
        if icn_oracle_refuses "$icn"; then echo "INVALID $name (no .ref, and icont refuses the source: not a board member)"; INVALID=$((INVALID+1)); return 0; fi
        echo "MISSING $name (no .ref oracle)"
        MISSING=$((MISSING+1))
        return 0
    fi
    # ⭐ XPASS DETECTION (seat15, xpass-promotion-xfail-hygiene, 2026-08-29): an .xfail marker records a
    # PAST verdict, not a licence to stop checking it. This used to `return` here without ever running the
    # program, so a fix landing upstream could NEVER be detected -- the instrument had ZERO capacity to
    # ever say XPASS (the never-say-YES defect RULES.md's TWO-PART PROOF law names), identically to the
    # gap fixed the same day in this file's twin, test_icon_rung_suite.sh. Now it always runs; is_xfail
    # only reinterprets the verdict below, it never skips measuring it.
    local is_xfail=0
    [ -f "${base}.xfail" ] && is_xfail=1
    local stdin_file; stdin_file="$(icn_rundir_stdin "$icn")"
    local tdir tfn
    # ⛔⭐ RUN FROM A SCRATCH CWD, NOT FROM THE CORPUS (hq_B 2026-08-30, hq_C's cure (1) on the tmp3
    # recurrence). Icon tests legitimately do file I/O against RELATIVE paths -- rung36_jcon_io.icn opens
    # tmp1/tmp2 "w" and rung36_jcon_iobig.icn testio()s tmp3/tmp4 -- and with cwd set to the corpus dir
    # those writes land in the SOURCE TREE. tmp3 was committed by accident, ceo deleted it, and the next
    # run of THIS SCRIPT put it straight back as an untracked file, which handoff_status.sh reads as a
    # dirty corpus. ⭐ Fixing the cwd fixes every scratch-writing test at once, present and future, and
    # needs no per-test knowledge -- unlike deleting the file (the writer survives) or ignoring the name
    # (the symptom is silenced while a test still writes into the source tree).
    # ⛔ The program is passed ABSOLUTE so nothing depends on cwd to FIND it; only what it WRITES moves.
    tdir="$ICN_SCRATCH"; tfn="$icn"
    # ⭐⛔ THE RUN-DIRECTORY CONTRACT (hq_P, CEO-532). A witness that declares NAME.argv / NAME.fixtures/ /
    # NAME.env is a program whose ANSWER DEPENDS ON ITS ENVIRONMENT, so it gets a fresh directory holding
    # exactly its declared fixtures -- never the shared scratch, whose contents are whatever ran before it.
    # ⛔ A malformed declaration REFUSES(2) for the whole board instead of degrading to "no contract": a
    # witness silently graded starved is precisely the false green this contract exists to end, and it
    # prints the same orderly, stable, non-empty output either way.
    # ⛔ `if cmd; then` AND NEVER `cmd; [ $? -eq 2 ] && …` -- this file runs under `set -e`, where a `&&`
    # list whose test is FALSE returns 1 and kills the whole board. Written the second way it did exactly
    # that: rung36_jcon_io and everything after it vanished from the board with NO message and NO summary
    # line, which reads as a shorter suite rather than as an aborted one.
    local -a rd_argv=() rd_env=()
    local rd_rc
    # ⭐ THE DECLARED HEAP AND STACK (CEO-1353): icn_rundir_sizes fills rd_sw with -d<kb>k -s<kb>k for the SCRIP command line.
    local -a rd_sw=(); rd_rc=0; if icn_rundir_sizes "$icn" rd_sw; then :; else rd_rc=$?; fi
    if [ "$rd_rc" -eq 2 ]; then echo "⛔ REFUSE(2) $name: malformed NAME.heap or NAME.stack declaration (the reader said why above)" >&2; exit 2; fi
    if [ "$rd_rc" -eq 1 ]; then echo "    $name: declares no heap and stack beside it -- runs at the shipped default, NAMED (CEO-1353)" >&2; fi
    if icn_rundir_declares "$icn"; then
        rd_rc=0; icn_rundir_argv "$icn" rd_argv || rd_rc=$?
        if [ "$rd_rc" -eq 2 ]; then echo "⛔ REFUSE(2) $name: malformed argv declaration" >&2; exit 2; fi
        rd_rc=0; icn_rundir_env "$icn" rd_env || rd_rc=$?
        if [ "$rd_rc" -eq 2 ]; then echo "⛔ REFUSE(2) $name: malformed env declaration" >&2; exit 2; fi
        tdir="$(icn_rundir_make "$icn" "$ICN_SCRATCH")" || { echo "⛔ REFUSE(2) $name: could not stage the declared fixtures" >&2; exit 2; }
    fi
    local got want rc=0 want_rc=0
    # ⛔ EXIT STATUS IS PART OF THE ANSWER (hq_P s272). This runner used to end both arms with `|| true`,
    # discarding rc entirely and grading stdout alone -- so a program that printed the right answer and then
    # ABORTED counted PASS. That false-green is worth exactly 75 programs on this suite and is why this board
    # read 244 while test_icon_rung_suite.sh (which enforces rc) read 169 on the SAME tree, SAME 293 files,
    # SAME 30 XFAIL -- two boards that looked directly comparable and were not.
    # ⭐ Graded against the ORACLE, not against 0: real iconx exits 0 for a main that FAILS (the normal end of
    # `every`), but a few programs legitimately exit nonzero, so a `<base>.exitcode` sidecar names the expected
    # code where it is not 0. Wrong-rc lands in its OWN bucket, never silently inside FAIL.
    # ⛔ `--` separates OUR flags from the PROGRAM's argv; without it a declared argument is read as a
    # second source file (CLAUDE.md § Build and run). ${rd_argv[@]+"${rd_argv[@]}"} is the empty-safe form
    # -- a bare "${rd_argv[@]}" is an unbound-variable error under `set -u` when nothing is declared.
    got=$( (cd "$tdir" && "$TIMEOUT_RETRY" "$tmo" env ${rd_env[@]+"${rd_env[@]}"} "$SCRIP" --run ${rd_sw[@]+"${rd_sw[@]}"} "$tfn" -- ${rd_argv[@]+"${rd_argv[@]}"}) < "$stdin_file" 2>/dev/null) || rc=$?
    [ -f "${base}.exitcode" ] && want_rc=$(tr -dc '0-9' < "${base}.exitcode")
    want=$(cat "$exp")
    if [ "$is_xfail" = 1 ]; then
        if [ "$got" = "$want" ] && [ "$rc" = "$want_rc" ]; then
            echo "XPASS $name (marked XFAIL but now genuinely passes -- STALE MARKER, promote it: rm ${base}.xfail)"
            XPASS=$((XPASS+1))
            r36_tally "$name" XPASS
        else
            echo "XFAIL $name"
            XFAIL=$((XFAIL+1))
            r36_tally "$name" XFAIL
        fi
        return 0
    fi
    if [ "$got" = "$want" ] && [ "$rc" != "$want_rc" ]; then
        echo "BADEXIT $name (stdout correct, exit $rc, expected $want_rc)"
        BADEXIT=$((BADEXIT+1))
        r36_tally "$name" BADEXIT
    elif [ "$got" = "$want" ]; then
        echo "PASS $name"
        PASS=$((PASS+1))
        r36_tally "$name" PASS
    else
        echo "FAIL $name"
        echo "  want: $(echo "$want" | tr '\n' '|')"
        echo "  got:  $(echo "$got"  | tr '\n' '|')"
        FAIL=$((FAIL+1))
        r36_tally "$name" FAIL
    fi
}

if [ -n "$RUNG" ]; then
    for icn in "$CORPUS"/${RUNG}_*.icn "$CORPUS"/${RUNG}.icn; do
        [ -f "$icn" ] || continue
        if is_suite_file "$icn"; then SUITE_FILES+=("$icn"); continue; fi
        run_one "$icn"
    done
else
    for icn in "$CORPUS"/rung0[1-9]_*.icn \
               "$CORPUS"/rung1[0-9]_*.icn \
               "$CORPUS"/rung2[0-9]_*.icn \
               "$CORPUS"/rung3[0-5]_*.icn; do
        [ -f "$icn" ] || continue
        if is_suite_file "$icn"; then SUITE_FILES+=("$icn"); continue; fi
        run_one "$icn" 8
    done
    for icn in "$CORPUS"/rung36_*.icn; do
        [ -f "$icn" ] || continue
        if is_suite_file "$icn"; then SUITE_FILES+=("$icn"); continue; fi
        run_one "$icn" 8
    done
    for icn in "$CORPUS"/rung37_*.icn; do
        [ -f "$icn" ] || continue
        if is_suite_file "$icn"; then SUITE_FILES+=("$icn"); continue; fi
        run_one "$icn" 8
    done
fi

# suite-format families (see header note): fold each converted family's m3 board into the same
# PASS/FAIL totals a loose-file run_one would have contributed. Every command here is explicitly
# guarded against this script's `set -e` -- a real FAIL inside the harness call must not abort.
for icn in "${SUITE_FILES[@]}"; do
    sfname=$(basename "$icn" .icn)
    board=$(python3 "$HERE/corpus_suite_harness.py" run "$icn" "${icn%.icn}.ref" --lang icon --modes m3 2>&1 | grep '^SUITE_BOARD') || true
    spass=$(echo "$board" | grep -oP 'm3_pass=\K[0-9]+') || true
    if [ -z "$spass" ]; then
        echo "SUITE-RUN-ERROR $sfname (harness produced no SUITE_BOARD line)"
        FAIL=$((FAIL+1))
        continue
    fi
    sfail=$(echo "$board" | grep -oP 'm3_fail=\K[0-9]+') || true
    scrash=$(echo "$board" | grep -oP 'm3_crash=\K[0-9]+') || true
    shang=$(echo "$board" | grep -oP 'm3_hang=\K[0-9]+') || true
    sunproven=$(echo "$board" | grep -oP 'm3_unproven=\K[0-9]+') || true
    sxfail=$(echo "$board" | grep -oP 'm3_xfail=\K[0-9]+') || true
    sxpass=$(echo "$board" | grep -oP 'm3_xpass=\K[0-9]+') || true
    # XPASS (a witness marked XFAIL that actually passed -- stale marker) is surfaced as loudly as
    # FAIL, through its own top-line bucket rather than folded anonymously into FAIL -- FAIL means
    # "broken", XPASS means "already fixed, paperwork owed" (xpass-promotion-xfail-hygiene, matched
    # to the identical change in test_icon_rung_suite.sh the same day). Inert today: no Icon family
    # is suite-converted yet, so SUITE_FILES is empty in practice.
    sbad=$((sfail+scrash+shang+sunproven))
    echo "SUITE $sfname: pass=$spass xfail=$sxfail bad=$sbad xpass=$sxpass"
    PASS=$((PASS+spass)); FAIL=$((FAIL+sbad)); XFAIL=$((XFAIL+sxfail)); XPASS=$((XPASS+sxpass))
done

echo "--- rung36 by category ---"
{
    for cat in "${!R36_CAT_P[@]}" "${!R36_CAT_F[@]}" "${!R36_CAT_X[@]}" "${!R36_CAT_XP[@]}"; do echo "$cat"; done
} | sort -u | while read -r cat; do
    [ -z "$cat" ] && continue
    p=${R36_CAT_P[$cat]:-0}
    f=${R36_CAT_F[$cat]:-0}
    x=${R36_CAT_X[$cat]:-0}
    xp=${R36_CAT_XP[$cat]:-0}
    total=$((p+f+x+xp))
    line=$(printf "  rung36_%-12s  total=%2d  PASS=%2d  FAIL=%2d  XFAIL=%2d" "$cat" "$total" "$p" "$f" "$x")
    [ "$xp" -gt 0 ] && line="$line  XPASS=$xp"
    echo "$line"
done

# XPASS only appears when nonzero (same convention as BADEXIT) -- it is the rare, good-news case;
# printing "XPASS=0" on every green board forever would just be noise on top of noise.
summary_line="--- Icon --run: PASS=$PASS FAIL=$FAIL BADEXIT=$BADEXIT XFAIL=$XFAIL"
[ "$XPASS" -gt 0 ] && summary_line="$summary_line XPASS=$XPASS"
summary_line="$summary_line MISSING=$MISSING INVALID=$INVALID TOTAL=$((PASS+FAIL+BADEXIT+XFAIL+XPASS)) ---"
echo "$summary_line"
if [ "$BADEXIT" -gt 0 ]; then
    echo "--- BADEXIT = stdout matched .ref but the process exit status did not. Before hq_P s272 these"
    echo "--- counted as PASS (rc was discarded), which is why this board previously read PASS=$((PASS+BADEXIT))."
    echo "--- This is NOT a regression: it is the same tree, graded on exit status for the first time."
fi
if [ "$MISSING" -gt 0 ]; then
    echo "--- MISSING = a .icn with no .ref oracle at all -- previously invisible (counted in nothing,"
    echo "--- board stayed green). Give it an oracle or an .xfail marker; see FINDING/mail"
    echo "--- ruling-xfail-stays-loose-and-your-2-files-are-a-runner-defect."
fi
[ "$FAIL" -eq 0 ] && [ "$BADEXIT" -eq 0 ] && [ "$MISSING" -eq 0 ]
