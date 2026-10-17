#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib_one_runner.sh" && one_runner_guard "${0##*/}" "$(one_runner_population_of "$@")" || exit 2
# ../harness/scripts/test_prolog_rung_suite.sh — Prolog rung ladder runner.
# Self-contained. Run from anywhere with no env vars.
# Usage: bash ../harness/scripts/test_prolog_rung_suite.sh [--rung RUNG] [--mode MODE] [--scrip PATH] [--corpus PATH]
#
# GOAL-PROLOG-BB mandates running ALL modes on every gate run (see GOAL "Testing discipline").
# With no --mode (or --mode all, the DEFAULT) the corpus runs in BOTH modes (modes 1 and 2 are deleted; `run` is an alias of interp):
#   interp  (mode 3, --run)             — HARD GATE (this script's exit status)
#   compile (mode 4, --compile x86)     — emit→assemble→link→exec via run_prolog_via_x86_backend.sh — TRACKED
# A mode whose probe prints the Stack-Machine-eXcision banner is reported REFUSED and its per-file loop is skipped.
# ⛔ A PASS NEEDS stdout == .ref AND rc == 0 (hq_B 2026-09-02, row prolog-rung-suite-reds-rowed-by-class). On the post-cut tree
# the driver REFUSES every construct above the landed ladder rung with rc=2 and EMPTY stdout, so a witness whose expected output is
# empty (the three rung15_abolish_* files — their swipl output IS empty) graded PASS on a refusal: 3 of 3 greens were vacuous.
# stderr is kept (ERRF) and a driver refusal names its class on the RED line, `REFUSED-LADDER rung N -- <construct>` (the text of
# lower_prolog.c pl_refuse()), so `grep -oE 'REFUSED-LADDER rung [0-9]+' | sort | uniq -c` IS the classification by ladder rung.
# Failed once / passed once on SCRIP c182977e: before, interp PASS=3 (all vacuous); after, PASS=0 FAIL=15 both modes with every
# RED named and rung-classed; a scratch --corpus holding only hello world grades PASS=1 in both modes.
#
# SUITE-FORMAT DELEGATION (tests-consolidate-prolog, 2026-08-27): a family converted by
# corpus_suite_harness.py loses its loose rungNN[_slug]/*.pl directory and becomes one
# <family>.pl+.ref pair. Globbing loose files directly would silently lose that family the
# moment its loose originals are removed (empty-glob false-green — the exact bug this same
# task found and fixed in 7 other per-rung scripts). collect_files() also gathers converted
# families into SUITE_FILES; run_corpus() delegates those to `corpus_suite_harness.py run`
# in the mode being graded -- m3 for interp/run, m4 for compile. The two modes are one machine in two media
# (Lon 2026-09-23), so every family is graded in both.
#
# Authors: LCherryholmes · Claude Sonnet 4.6 · Claude Opus 4.7 · Claude Sonnet
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export TIMEOUT_RETRY="${TIMEOUT_RETRY:-$HERE/util_timeout_retry.sh}"   # a graded run's timeout (CEO-1335): a timeout under load is retried once, util_timeout_retry.sh
SCRIP="${SCRIP:-$HERE/../../SCRIP/scrip}"
CORPUS="${CORPUS:-$S4E/corpus/tests/prolog}"
RUNG=""
MODE="all"                              # DEFAULT: run all three modes
SMX_SIG='\[SMX\]'                       # both refuse banners begin with "[SMX]"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --rung)   RUNG="$2";   shift 2 ;;
        --mode)   MODE="$2";   shift 2 ;;
        --scrip)  SCRIP="$2";  shift 2 ;;
        --corpus) CORPUS="$2"; shift 2 ;;
        *) echo "Usage: $0 [--rung RUNG] [--mode all|interp|run|compile] [--scrip PATH] [--corpus PATH]" >&2; exit 1 ;;
    esac
done

# ⛔ WAS `exit 0` ("SKIP") until 2026-09-04, on BOTH this arm and the corpus arm below: a box with no
# compiler built, or no corpus cloned, reported SUCCESS to every caller reading $? -- every gate, every
# board, and handoff_status.sh. That is the ABSENT-ORACLE FALSE-GREEN class (RULES.md: a test that cannot
# measure REFUSES rc=2, never skip-as-success), and its sibling test_icon_rung_suite.sh was cured of the
# identical pair of arms earlier -- the cure never crossed to this copy, which is this row's whole theme.
if [ ! -x "$SCRIP" ]; then
    echo "⛔ REFUSED TO GRADE rc=2: no scrip binary at $SCRIP" >&2
    exit 2
fi
# ⛔⭐ STALE-BINARY PREFLIGHT (row harness-and-ladder-runner-refuse-on-a-stale-binary-like-the-artifact-regen-
# does, ceo -> hq_T 2026-09-04). Existence is not currency: a binary that IS there can still predate the tree
# whose SHA the board stamps on the verdict. NO LOGIC HERE -- util_require_fresh.sh sources gate_require_fresh
# from lib_gate.sh, the ONE authority (hq_B 4c7253e99), never a second copy.
"$HERE/util_require_fresh.sh" --gate test_prolog_rung_suite "$SCRIP" "${RT_DIR:-$HERE/../../SCRIP/out}/libscrip_rt.so" || exit 2
if [ ! -d "$CORPUS" ]; then
    echo "⛔ REFUSED TO GRADE rc=2: no corpus at $CORPUS" >&2
    echo "     clone snobol4ever/corpus to $S4E/corpus to run this suite" >&2
    exit 0
fi

# run a single program in a given mode, echoing its stdout
# A loose program runs at the heap and stack it declares beside itself, read by lib_declared_arena.sh (ceo CEO-1353, RULES.md clause 8 (g));
# m4's switches are carried by run_prolog_via_x86_backend.sh, which reads the same sidecars. A sidecar the reader refuses is rc 2 here.
. "$HERE/lib_declared_arena.sh" || { echo "REFUSE(2): cannot load lib_declared_arena.sh" >&2; exit 2; }
run_prog() {
    local mode="$1" pl="$2" tmo="$3" sw
    sw="$(declared_switches_beside "$pl" 2>"$ERRF")" || return 2
    case "$mode" in
        interp)  "$TIMEOUT_RETRY" "$tmo" "$SCRIP" --run $sw "$pl" < /dev/null 2>"$ERRF" ;;
        run)     "$TIMEOUT_RETRY" "$tmo" "$SCRIP" --run $sw "$pl" < /dev/null 2>"$ERRF" ;;
        compile) "$TIMEOUT_RETRY" "$tmo" bash "$HERE/run_prolog_via_x86_backend.sh" "$pl" < /dev/null 2>"$ERRF" ;;
        *) echo "bad mode $mode" >&2; exit 1 ;;
    esac
}

# return 0 if MODE is currently Stack-Machine-eXcised (probe with a trivial program).
# Capture output first, THEN grep: under `set -o pipefail` the aborting scrip (rc 134) would
# otherwise dominate the pipeline status and mask the match.
mode_is_refused() {
    local mode="$1" out
    case "$mode" in
        interp)  return 1 ;;                              # the reference path is never refused
        run)     out=$("$SCRIP" --run "$PROBE" </dev/null 2>&1 || true) ;;
        compile) out=$("$SCRIP" --compile --target=x86 "$PROBE" </dev/null 2>&1 || true) ;;
    esac
    printf '%s' "$out" | grep -qE "$SMX_SIG"
}

# collect the corpus file list into the FILES array (loose) and SUITE_FILES (converted families).
# Discriminator for a converted family .pl: its .ref sibling carries the harness's banner lines (CEO-1222: every expected
# output is a .ref, so a plain .ref beside a loose witness no longer means "converted family" -- the banners do, as in
# the Icon runners' twin cure). A .ref with no banner line is a loose witness's expected output.
# (the OLD dual-extension individual files, e.g. rung05/29/30's per-entry .pl, always carry BOTH —
# that is what tells a suite family apart from those, since both use the .pl extension).
pl_ref_banners() { grep -cE '^[^A-Za-z0-9]*-{10,}[[:space:]]+[0-9]+[[:space:]]+[A-Za-z0-9_]' "$1"; }
collect_files() {
    FILES=()
    SUITE_FILES=()
    if [ -n "$RUNG" ]; then
        for pl in "$CORPUS"/${RUNG}_*.pl; do [ -f "$pl" ] && FILES+=("$pl"); done
        for pl in "$CORPUS"/${RUNG}.pl "$CORPUS"/${RUNG}_*.pl; do
            [ -f "$pl" ] || continue
            [ -f "${pl%.pl}.ref" ] || continue
            [ "$(pl_ref_banners "${pl%.pl}.ref")" -gt 0 ] || continue
            SUITE_FILES+=("$pl")
        done
    else
        for pl in "$CORPUS"/rung0[1-9]_*.pl \
                  "$CORPUS"/rung1[0-9]_*.pl \
                  "$CORPUS"/rung2[0-9]_*.pl \
                  "$CORPUS"/rung3[0-9]_*.pl \
                  "$CORPUS"/rung4[0-9]_*.pl \
                  "$CORPUS"/rung5[0-9]_*.pl \
                  "$CORPUS"/rung6[0-9]_*.pl \
                  "$CORPUS"/rung7[0-9]_*.pl \
                  "$CORPUS"/rung8[0-9]_*.pl; do
            [ -f "$pl" ] && FILES+=("$pl")
        done
        for pl in "$CORPUS"/rung[0-9][0-9]*.pl; do
            [ -f "$pl" ] || continue
            [ -f "${pl%.pl}.ref" ] || continue
            [ "$(pl_ref_banners "${pl%.pl}.ref")" -gt 0 ] || continue
            SUITE_FILES+=("$pl")
        done
    fi
}

# run the whole corpus in one mode; sets MODE_FAIL=1 on any FAIL
run_corpus() {
    local mode="$1"
    local PASS=0 FAIL=0 XFAIL=0 REFUSED=0
    # ⛔ MODE_FAIL's SIBLING, DELIBERATELY NOT `local` FOR THE SAME REASON (row every-board-wrapper-
    # refuses-on-a-zero-population-instead-of-passing-vacuously, hq_T 2026-09-04): a FILE matched by
    # collect_files but missing a usable .ref hits `[ -f "$exp" ] || continue` below
    # with NO counter incremented at all -- unlike Icon's twin, which counts this as MISSING and sets
    # MODE_FAIL=1. If every collected FILE lacks an oracle, PASS=FAIL=XFAIL=0, MODE_FAIL stays its
    # initialized 0, and HARD_FAIL reads exactly like a clean board -- the collect_files-level floor
    # this row already added cannot see this, because collect_files never asked "does it have an
    # oracle", only "does the .pl exist". MODE_TOTAL is the caller's only way to tell "graded and
    # clean" from "found files, graded none of them".
    MODE_FAIL=0; MODE_TOTAL=0
    if mode_is_refused "$mode"; then
        local pend=0 f
        for f in "${FILES[@]}"; do [ -f "${f%.pl}.ref" ] && pend=$((pend+1)); done
        echo "--- Prolog ($mode): REFUSED (Stack Machine refused) — $pend files pending regrow ---"
        return 0
    fi
    local pl base name exp got want _isref
    for pl in "${FILES[@]}"; do
        # ⛔⭐ .ref-AWARE, AND IT IS A DENOMINATOR FIX, NOT A FEATURE (hq_P 2026-08-29, row tests-consolidate-prolog; cures the class seat16 filed as
        # "GATE-3 is .ref-blind").  A single-entry suite conversion renames <stem>.expected -> <stem>.ref and prepends ONE banner line.  This arm looked
        # only for .expected, so every converted file SILENTLY LEFT THE DENOMINATOR: converting 13 files dropped `Prolog (compile): TOTAL` from 30 to 17
        # with FAIL unchanged at 13 -- a board that shrinks instead of reddening, which is the exact false-green shape RULES.md names.  Measured, not
        # theorised: I caused it in this session and caught it with a stash-and-rerun control arm.
        # ⛔ DELIBERATELY NARROW -- a .ref is accepted here ONLY when it is a SINGLE-ENTRY suite (exactly one banner line).  A MULTI-entry family .ref
        # holds several programs' outputs plus their banners and belongs to corpus_suite_harness.py, which the interp arm already delegates to and which
        # this arm explicitly does not get (see the header note).  Reading one of those as a single pin would compare one program's output against the
        # whole family's -- a guaranteed, and confusingly plausible, FAIL.
        # a plain .ref (no banner) is this witness's whole expected output; a SINGLE-banner .ref is a one-entry suite read
        # as a single pin past its banner; a multi-banner .ref is a container and belongs to the harness, never to this arm.
        exp="${pl%.pl}.ref"; _isref=0
        if [ -f "$exp" ]; then
            case "$(pl_ref_banners "$exp")" in 0) ;; 1) _isref=1 ;; *) continue ;; esac
        fi
        [ -f "$exp" ] || continue
        base="${pl%.pl}"
        name=$(basename "$pl" .pl)
        if [ -f "${base}.xfail" ]; then
            [ "$VERBOSE" = 1 ] && echo "XFAIL $name"
            XFAIL=$((XFAIL+1)); continue
        fi
        got=$(run_prog "$mode" "$pl" 8); rc=$?
        # the driver's own refusal text names the first construct above the landed rung and the rung that lands it; in compile
        # mode the backend runner echoes scrip's stderr to stdout, so both streams are read.
        ladder=$( { printf '%s\n' "$got"; cat "$ERRF"; } | grep -m1 -oE 'prolog: .* is not on the ladder yet -- rung [0-9]+' | sed 's/^prolog: //')
        # Per-file refuse: mode-4 is now PARTIALLY live (PLG-9a hello tier emits+runs); a shape
        # the flat tier does not yet cover refuses with the [SMX] banner. Per the testing discipline
        # that is REFUSED (pending regrow), NOT a FAIL — identical to test_smoke_prolog.sh.
        if printf '%s' "$got" | grep -qE "$SMX_SIG"; then
            echo "RED $mode $name: REFUSED (Stack Machine banner)"
            REFUSED=$((REFUSED+1)); continue
        fi
        if [ "$_isref" = 1 ]; then want=$(tail -n +2 "$exp"); else want=$(cat "$exp"); fi
        if [ "$got" = "$want" ] && [ "$rc" -eq 0 ]; then
            [ "$VERBOSE" = 1 ] && echo "PASS $name"
            PASS=$((PASS+1))
        else
            # ⛔ instrument laws clause 5 (anchor on identity, never position): name every red by default,
            # not only under VERBOSE=1 -- a count the board cannot name cannot be rowed. rc is read BEFORE
            # any `|| true`/pipefail swallowing, so a crash/timeout is distinguished from a clean-exit wrong
            # answer without changing what is graded (PASS/FAIL bucketing below is untouched).
            if   [ -n "$ladder" ];   then reason="REFUSED-LADDER rung ${ladder##*rung } -- ${ladder%% is not on the ladder yet*} (rc=$rc)"
            elif [ "$rc" -ge 128 ]; then reason="CRASH rc=$rc (signal $((rc-128)))"
            elif [ "$rc" -eq 124 ]; then reason="TIMEOUT"
            elif [ "$rc" -ne 0 ] && [ "$got" = "$want" ]; then reason="EXIT rc=$rc with matching stdout (a nonzero exit is never a PASS)"
            elif [ "$rc" -ne 0 ];   then reason="CRASH rc=$rc"
            else reason="output mismatch"; fi
            echo "RED $mode $name: $reason"
            if [ "$VERBOSE" = 1 ]; then
                echo "  want: $(echo "$want" | tr '\n' '|')"
                echo "  got:  $(echo "$got"  | tr '\n' '|')"
            fi
            FAIL=$((FAIL+1)); MODE_FAIL=1
        fi
    done
    # suite-format families (see header note): delegated to the harness in this mode, one family at a
    # time, folding its per-entry board into these same totals.
    local hm=m3; [ "$mode" = compile ] && hm=m4
    {
        local sf sfname raw board spass sfail scrash shang sunproven sbad eline etag erest ename edetail
        for sf in "${SUITE_FILES[@]}"; do
            sfname=$(basename "$sf" .pl)
            # SUITE_LIST_ALL=1 + full (unfiltered) capture: the harness already prints one line per
            # non-PASS entry ("  TAG <mode> name: detail", cmd_run's own `fails` listing) -- it was being
            # thrown away by piping straight into `grep '^SUITE_BOARD'`. Reformat each into this
            # script's own RED shape instead of re-deriving per-entry identity a second way.
            raw=$(SUITE_LIST_ALL=1 python3 "$HERE/corpus_suite_harness.py" run "$sf" "${sf%.pl}.ref" --lang prolog --modes "$hm" 2>&1)
            board=$(printf '%s\n' "$raw" | grep '^SUITE_BOARD')
            spass=$(echo "$board" | grep -oP "${hm}_pass=\\K[0-9]+")
            if [ -z "$spass" ]; then
                echo "RED $mode $sfname: SUITE-RUN-ERROR (harness produced no SUITE_BOARD line)"
                FAIL=$((FAIL+1)); MODE_FAIL=1
                continue
            fi
            sfail=$(echo "$board" | grep -oP "${hm}_fail=\\K[0-9]+")
            scrash=$(echo "$board" | grep -oP "${hm}_crash=\\K[0-9]+")
            shang=$(echo "$board" | grep -oP "${hm}_hang=\\K[0-9]+")
            sunproven=$(echo "$board" | grep -oP "${hm}_unproven=\\K[0-9]+")
            sbad=$((sfail+scrash+shang+sunproven))
            while IFS= read -r eline; do
                [ -n "$eline" ] || continue
                etag="${eline%% $hm *}"; etag="${etag#  }"
                erest="${eline#* $hm }"
                ename="${erest%%:*}"
                edetail="${erest#*: }"
                echo "RED $mode $sfname/$ename: $etag ($edetail)"
            done < <(printf '%s\n' "$raw" | grep -E '^  [A-Z]')
            [ "$VERBOSE" = 1 ] && echo "SUITE $sfname: pass=$spass bad=$sbad"
            PASS=$((PASS+spass)); FAIL=$((FAIL+sbad))
            [ "$sbad" -gt 0 ] && MODE_FAIL=1
        done
    }
    MODE_TOTAL=$((PASS+FAIL+XFAIL+REFUSED))
    if [ "$REFUSED" -gt 0 ]; then
        echo "--- Prolog ($mode): PASS=$PASS FAIL=$FAIL XFAIL=$XFAIL REFUSED=$REFUSED TOTAL=$MODE_TOTAL ---"
    else
        echo "--- Prolog ($mode): PASS=$PASS FAIL=$FAIL XFAIL=$XFAIL TOTAL=$MODE_TOTAL ---"
    fi
}

PROBE="$(mktemp /tmp/plprobe_XXXXXX.pl)"
ERRF="$(mktemp /tmp/plerr_XXXXXX.txt)"           # stderr of the last run_prog call; a driver ladder refusal is read from here
printf ':- initialization(main).\nmain :- write(ok), nl.\n' > "$PROBE"
trap 'rm -f "$PROBE" "$ERRF"' EXIT

collect_files
# ⛔⭐ POPULATION FLOOR (row every-board-wrapper-refuses-on-a-zero-population-instead-of-passing-
# vacuously, hq_T 2026-09-04): run_corpus() only sets MODE_FAIL on a FILE it iterates -- if
# collect_files's globs matched nothing (a --rung typo, or a family fully consolidated into a suite
# pair with the loose originals removed), the loop body never runs, MODE_FAIL stays its initialized 0,
# and HARD_FAIL below reads exactly like a clean board. This is the Icon twin's identical fix.
"$HERE/util_require_population.sh" --gate test_prolog_rung_suite "$((${#FILES[@]}+${#SUITE_FILES[@]}))" 1 "collected .pl/.ref witnesses (RUNG=${RUNG:-<all>})" || exit 2
# verbose per-file output only for single-mode runs; the all-modes sweep prints summaries only
VERBOSE=1; [ "$MODE" = "all" ] && VERBOSE=0

HARD_FAIL=0
case "$MODE" in
    all)
        # MODE COUNT CORRECTED (s160): the loop ran `interp run compile` and reported "x3 modes",
        # but run_prog's `interp` and `run` arms are the IDENTICAL command ($SCRIP --run) — SCRIP has
        # exactly TWO modes since 1 and 2 were deleted (REPO-SCRIP.md), so the third arm measured the
        # same path twice and every "164/164 x3" in the goal-file history was really x2.  `run` is
        # still accepted as an explicit alias below; it is only dropped from the sweep.
        for m in interp compile; do
            run_corpus "$m"
            # ⛔⭐ POPULATION FLOOR, ONE LEVEL DEEPER THAN collect_files (row every-board-wrapper-
            # refuses-on-a-zero-population-instead-of-passing-vacuously, hq_T 2026-09-04): interp is
            # the HARD GATE (see header), so its own MODE_TOTAL -- not just "did collect_files find a
            # .pl file" -- must be non-zero before MODE_FAIL is trusted. A RUNG whose matched files
            # ALL lack an oracle (see run_corpus's `[ -f "$exp" ] || continue`) reaches here with
            # MODE_FAIL=0 and MODE_TOTAL=0 -- refuse before HARD_FAIL can read that as clean.
            [ "$m" = interp ] && { "$HERE/util_require_population.sh" --gate test_prolog_rung_suite "$MODE_TOTAL" 1 "interp-mode graded rows (RUNG=${RUNG:-<all>})" || exit 2; }
            [ "$m" = interp ] && [ "$MODE_FAIL" -ne 0 ] && HARD_FAIL=1
        done
        ;;
    interp|run|compile)
        run_corpus "$MODE"
        [ "$MODE" = interp ] && { "$HERE/util_require_population.sh" --gate test_prolog_rung_suite "$MODE_TOTAL" 1 "interp-mode graded rows (RUNG=${RUNG:-<all>})" || exit 2; }
        [ "$MODE" = interp ] && [ "$MODE_FAIL" -ne 0 ] && HARD_FAIL=1
        ;;
    *) echo "bad mode $MODE" >&2; exit 1 ;;
esac

[ "$HARD_FAIL" -eq 0 ]
