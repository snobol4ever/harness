#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib_one_runner.sh" && one_runner_guard "${0##*/}" "$(one_runner_population_of "$@")" || exit 2
# ../harness/scripts/test_icon_rung_suite.sh — Icon rung ladder runner, ALL THREE MODES (GOAL-ICON-BB discipline).
# Self-contained. Run from anywhere with no env vars.
# Usage: bash ../harness/scripts/test_icon_rung_suite.sh [--rung RUNG] [--mode MODE] [--scrip PATH] [--corpus PATH]
#
# GOAL-ICON-BB mandates running ALL modes on every gate run (the "ALWAYS TEST ALL THREE MODES" policy,
# adopted from GOAL-PROLOG-BB's session-sync three-mode stepping). With no --mode (or --mode all, the
# DEFAULT) every corpus program is run through all three engine paths against its .ref:
#   interp  (Mode 2, --run)                 — reference oracle — HARD GATE (PASS must be >= previous).
#   run     (Mode 3, --run, stackless native)  — TRACKED. A shape with no native template REFUSES LOUD
#                                                 with the [SMX] banner -> counted REFUSED (NOT a FAIL).
#   compile (Mode 4, --compile --target=x86)   — emit .s -> as -> link out/libscrip_rt.so -> exec.
#                                                 TRACKED, same [SMX] -> REFUSED rule.
# A mode-3/4 run whose stderr carries the [SMX] refuse banner is reported REFUSED (expected mid-Ground
# -Zero, NOT FAIL) and auto-resumes counting toward PASS the moment that box family gets a native template.
# This is the Icon twin of test_prolog_rung_suite.sh; the [SMX]->REFUSED mechanism is identical.
# Pass --mode interp|run|compile to run a single mode. This is the THREE-MODE source of truth for the Icon
# rung ladder (test_icon_all_rungs.sh remains the mode-2-only category-tally view).
#
# SUITE-FORMAT DELEGATION (tests-consolidate-icon, 2026-08-28): a family converted by
# corpus_suite_harness.py loses its loose rungNN_*.icn files and becomes one <family>.icn+.ref pair.
# Globbing loose files directly would silently lose that family the moment its loose originals are
# removed (empty-glob false-green -- the same class test_prolog_rung_suite.sh fixed for Prolog).
# collect_files() also gathers converted families into SUITE_FILES (discriminator: a .ref sibling AND
# section banners in the source -- since CEO-1222 a loose file's expected output is a .ref too); run_corpus() delegates those to
# `corpus_suite_harness.py run` for EVERY mode, unlike the Prolog twin which withholds compile --
# Icon's m4 is proven live (tests-consolidate-icon ledger, seat01 2026-08-28: verified round-trip
# before adding the LANG_CONFIGS entry), so there is no untested-grading caveat to withhold it for.
# ⛔ A suite file's name still matches the raw rungNN_*.icn glob (e.g. rung04_string.icn matches
# rung0[1-9]_*.icn) -- collect_files() MUST route it to SUITE_FILES, never FILES: unlike Prolog's
# per-file loop (which just `continue`s past a missing .expected), THIS script's FILES loop counts
# a missing .ref as MISSING and trips MODE_FAIL -- leaving a suite file in FILES would self-
# inflict a false failure, not merely skip silently.
#
# Authors: LCherryholmes · Jeffrey Cooper M.D. · Claude Opus 4.8 · Claude Sonnet 5
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export TIMEOUT_RETRY="${TIMEOUT_RETRY:-$HERE/util_timeout_retry.sh}"   # a graded run's timeout (CEO-1335): a timeout under load is retried once, util_timeout_retry.sh
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
. "$HERE/lib_icn_rundir.sh" || { echo "⛔ REFUSES rc=2: cannot load lib_icn_rundir.sh" >&2; exit 2; }
SCRIP="${SCRIP:-$ROOT/scrip}"
RT_SO="${RT_SO:-$ROOT/out/libscrip_rt.so}"
CORPUS="${CORPUS:-$S4E/corpus/tests/icon}"
RUNG=""
MODE="all"                              # DEFAULT: run all three modes
SMX_SIG='\[SMX\]'                       # the loud-refuse banner — same token Prolog uses

while [[ $# -gt 0 ]]; do
    case "$1" in
        --rung)   RUNG="$2";   shift 2 ;;
        --mode)   MODE="$2";   shift 2 ;;
        --scrip)  SCRIP="$2";  shift 2 ;;
        --corpus) CORPUS="$2"; shift 2 ;;
        *) echo "Usage: $0 [--rung RUNG] [--mode all|interp|run|compile] [--scrip PATH] [--corpus PATH]" >&2; exit 1 ;;
    esac
done

# ⛔⛔⛔ s272 hq_C (CEO audit correction 2) — A MISSING PREREQUISITE IS A REFUSAL (rc=2), NEVER A GREEN EXIT.
# These two arms printed SKIP and exited 0, so a box with no compiler built, or no corpus cloned, reported
# SUCCESS to every caller that reads $? — which is every gate, every board, and handoff_status.sh. That is the
# ABSENT-ORACLE FALSE-GREEN class, and it is the exact twin of the `make test` no-recipe trap: a check that
# ran nothing and said nothing was wrong. ⭐ rc=2 means REFUSED-TO-GRADE and is distinct from rc=1 FAILED:
# a caller can tell 'I could not measure' from 'I measured and it is broken'. Silence could say neither.
if [ ! -x "$SCRIP" ]; then
    echo "⛔ REFUSED TO GRADE: no scrip binary at $SCRIP — run ../harness/scripts/build_scrip.sh" >&2
    exit 2
fi
# ⛔⭐ STALE-BINARY PREFLIGHT (row harness-and-ladder-runner-refuse-on-a-stale-binary-like-the-artifact-regen-
# does, ceo -> hq_T 2026-09-04). Existence is not currency: a binary that IS there can still predate the tree
# whose SHA the board stamps on the verdict. NO LOGIC HERE -- util_require_fresh.sh sources gate_require_fresh
# from lib_gate.sh, the ONE authority (hq_B 4c7253e99), never a second copy.
"$HERE/util_require_fresh.sh" --gate test_icon_rung_suite "$SCRIP" "${RT_DIR:-$HERE/../../SCRIP/out}/libscrip_rt.so" || exit 2
if [ ! -d "$CORPUS" ]; then
    echo "⛔ REFUSED TO GRADE: no corpus at $CORPUS" >&2
    echo "   clone snobol4ever/corpus to $S4E/corpus to run this suite" >&2
    exit 2
fi

OUTDIR="$(dirname "$RT_SO")"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# run a single program in a given mode, echoing its stdout; stderr captured separately to /tmp banner probe.
# For compile: emit .s -> assemble -> link libscrip_rt.so -> run. Any toolchain failure yields empty stdout
# (so a non-[SMX] toolchain failure shows up as a FAIL, exactly as silent-wrong would — honest).
# ⛔ THE RUN-DIRECTORY CONTRACT (lib_icn_rundir.sh, the m3 twin's own): run_contract sets RP_TDIR/RP_ARGV/RP_ENV for one witness
# in THIS shell, so a malformed declaration refuses the whole board -- run_prog runs inside $( ), where an exit only ends the
# subshell. This runner fed stdin but no argv, fixtures or env and ran from the caller's cwd, so rung36_jcon_io and
# rung36_jcon_recent read red in all three modes for the harness's reasons, not SCRIP's.
declare -a RP_ARGV=() RP_ENV=() RP_SW=(); RP_TDIR=""
run_contract() {
    local icn="$1" name rd_rc; name=$(basename "$icn" .icn)
    RP_ARGV=(); RP_ENV=(); RP_TDIR="$WORK/cwd"; mkdir -p "$RP_TDIR"
    # ⭐ THE DECLARED HEAP AND STACK (CEO-1353): icn_rundir_sizes fills RP_SW with -d<kb>k -s<kb>k for both SCRIP command lines.
    RP_SW=(); rd_rc=0; if icn_rundir_sizes "$icn" RP_SW; then :; else rd_rc=$?; fi
    if [ "$rd_rc" -eq 2 ]; then echo "⛔ REFUSE(2) $name: malformed NAME.heap or NAME.stack declaration (the reader said why above)" >&2; exit 2; fi
    if [ "$rd_rc" -eq 1 ]; then echo "    $name: declares no heap and stack beside it -- runs at the shipped default, NAMED (CEO-1353)" >&2; fi
    icn_rundir_declares "$icn" || return 0
    rd_rc=0; icn_rundir_argv "$icn" RP_ARGV || rd_rc=$?
    if [ "$rd_rc" -eq 2 ]; then echo "⛔ REFUSE(2) $name: malformed argv declaration" >&2; exit 2; fi
    rd_rc=0; icn_rundir_env "$icn" RP_ENV || rd_rc=$?
    if [ "$rd_rc" -eq 2 ]; then echo "⛔ REFUSE(2) $name: malformed env declaration" >&2; exit 2; fi
    RP_TDIR="$(icn_rundir_make "$icn" "$WORK")" || { echo "⛔ REFUSE(2) $name: could not stage the declared fixtures" >&2; exit 2; }
}
run_prog() {
    local mode="$1" icn="$2" tmo="$3" errf="$4"
    local name s o bin
    name=$(basename "$icn" .icn)
    local IN; IN="$(icn_rundir_stdin "$icn")"
    case "$mode" in
        interp)  (cd "$RP_TDIR" && "$TIMEOUT_RETRY" "$tmo" env ${RP_ENV[@]+"${RP_ENV[@]}"} "$SCRIP" --run ${RP_SW[@]+"${RP_SW[@]}"} "$icn" -- ${RP_ARGV[@]+"${RP_ARGV[@]}"}) < "$IN" 2>"$errf" ;;
        run)     (cd "$RP_TDIR" && "$TIMEOUT_RETRY" "$tmo" env ${RP_ENV[@]+"${RP_ENV[@]}"} "$SCRIP" --run ${RP_SW[@]+"${RP_SW[@]}"} "$icn" -- ${RP_ARGV[@]+"${RP_ARGV[@]}"}) < "$IN" 2>"$errf" ;;
        compile)
            s="$WORK/$name.s"; o="$WORK/$name.o"; mkdir -p "$WORK/bin"; bin="$WORK/bin/$name"
            if ! "$TIMEOUT_RETRY" "$tmo" "$SCRIP" --compile --target=x86 "$icn" < /dev/null > "$s" 2>"$errf"; then
                return 1   # emit failed; a loud [SMX] banner in errf still wins (REFUSED) in run_corpus
            fi
            # a loud [SMX] refuse prints to stderr and emits no usable .s — surface the banner, no asm step
            if grep -qE "$SMX_SIG" "$errf"; then return 0; fi
            if ! as "$s" -o "$o" 2>>"$errf"; then return 1; fi
            if ! gcc -no-pie "$o" -L"$OUTDIR" -lscrip_rt -Wl,-rpath,"$OUTDIR" -lm -o "$bin" 2>>"$errf"; then return 1; fi
            (cd "$RP_TDIR" && PATH="$WORK/bin:$PATH" "$TIMEOUT_RETRY" "$tmo" env ${RP_ENV[@]+"${RP_ENV[@]}"} "$name" ${RP_SW[@]+"${RP_SW[@]}"} ${RP_SW[@]+--} ${RP_ARGV[@]+"${RP_ARGV[@]}"}) < "$IN" 2>>"$errf"
            ;;
        *) echo "bad mode $mode" >&2; exit 1 ;;
    esac
}

declare -a FILES
declare -a SUITE_FILES
# converted-family discriminator (see header note): a .ref sibling AND corpus_suite_harness.py's section banners
# (`#---- <seq> <name>`) in the source. The sibling alone decided while loose programs carried a .expected; since
# CEO-1222 every loose expected output is a .ref as well, so the source's own shape is what tells a container.
is_suite_file() { [ -f "${1%.icn}.ref" ] && grep -qE '^#-{3,} [0-9]+ [^[:space:]]' "$1"; }
collect_files() {
    FILES=()
    SUITE_FILES=()
    local f
    if [ -n "$RUNG" ]; then
        for f in "$CORPUS"/${RUNG}_*.icn "$CORPUS"/${RUNG}.icn; do
            [ -f "$f" ] || continue
            if is_suite_file "$f"; then SUITE_FILES+=("$f"); else FILES+=("$f"); fi
        done
    else
        for f in "$CORPUS"/rung0[1-9]_*.icn \
                 "$CORPUS"/rung1[0-9]_*.icn \
                 "$CORPUS"/rung2[0-9]_*.icn \
                 "$CORPUS"/rung3[0-5]_*.icn \
                 "$CORPUS"/rung3[6-9]_*.icn; do
            [ -f "$f" ] || continue
            if is_suite_file "$f"; then SUITE_FILES+=("$f"); else FILES+=("$f"); fi
        done
    fi
}

# run the whole collected set in one mode; sets MODE_FAIL=1 on any FAIL
run_corpus() {
    local mode="$1"
    local PASS=0 FAIL=0 XFAIL=0 XPASS=0 REFUSED=0 BADEXIT=0 MISSING=0 INVALID=0
    MODE_FAIL=0
    local icn base name exp got want errf rc want_rc is_xfail
    errf="$WORK/err.txt"
    for icn in "${FILES[@]}"; do
        exp="${icn%.icn}.ref"
        base="${icn%.icn}"
        name=$(basename "$icn" .icn)
        if [ ! -f "$exp" ]; then
            # a pairless file the ORACLE refuses is not a board member (lib_icn_rundir.sh icn_oracle_refuses); one it compiles owes a ref
            if icn_oracle_refuses "$icn"; then [ "$VERBOSE" = 1 ] && echo "INVALID $name (no .ref, and icont refuses the source)"; INVALID=$((INVALID+1)); continue; fi
            [ "$VERBOSE" = 1 ] && echo "MISSING $name (no .ref oracle)"
            MISSING=$((MISSING+1)); MODE_FAIL=1; continue
        fi
        # ⭐ XPASS DETECTION (seat15, xpass-promotion-xfail-hygiene, 2026-08-29): an .xfail marker records a
        # PAST verdict, not a licence to stop checking it. This used to `continue` here without ever running
        # the program, so a fix landing upstream could NEVER be detected -- the instrument had ZERO capacity
        # to ever say XPASS, the exact never-say-YES defect RULES.md's TWO-PART PROOF law names. Now it runs
        # unconditionally and only reinterprets the verdict below: a marked-xfail entry that genuinely passes
        # is XPASS (stale marker, promote it), never silently re-absorbed as XFAIL.
        is_xfail=0
        [ -f "${base}.xfail" ] && is_xfail=1
        : > "$errf"
        run_contract "$icn"
        got=$(run_prog "$mode" "$icn" 8 "$errf"); rc=$?
        # loud-refuse -> REFUSED (expected mid-Ground-Zero, NOT a FAIL). interp never refuses.
        if [ "$mode" != interp ] && grep -qE "$SMX_SIG" "$errf"; then
            if [ "$is_xfail" = 1 ]; then
                [ "$VERBOSE" = 1 ] && echo "XFAIL $name (REFUSED -- unmeasured this mode)"
                XFAIL=$((XFAIL+1)); continue
            fi
            [ "$VERBOSE" = 1 ] && echo "REFUSED $name"
            REFUSED=$((REFUSED+1)); continue
        fi
        # SUITE-HONESTY (GOAL-ICON-BB 2026-06-03): a nonzero exit without the [SMX] banner is a FAIL in
        # EVERY mode (m2 included), even when stdout happens to match .ref — kills the vacuous pass
        # where an aborting program with empty stdout matched an empty .ref (rung36_jcon_proto).
        # ⭐ GRADED AGAINST THE ORACLE, NOT AGAINST 0 (ported from test_icon_all_rungs.sh f5dd74af — item 2
        # of task icon-regression-232-to-169): a `<base>.exitcode` sidecar names the expected code where it
        # is not 0. Wrong-rc-but-right-stdout lands in its own BADEXIT bucket, never silently inside FAIL
        # and never silently inside PASS — symmetric with all_rungs so the two instruments cannot diverge
        # on this axis again. No program in the corpus needs a sidecar today (find turns up zero); this
        # closes the missing capability, it is not a reaction to an observed false result.
        want_rc=0
        [ -f "${base}.exitcode" ] && want_rc=$(tr -dc '0-9' < "${base}.exitcode")
        want=$(cat "$exp")
        if [ "$rc" -ne "$want_rc" ]; then
            if [ "$is_xfail" = 1 ]; then
                [ "$VERBOSE" = 1 ] && echo "XFAIL $name (rc=$rc, expected $want_rc -- still red)"
                XFAIL=$((XFAIL+1)); continue
            fi
            if [ "$got" = "$want" ]; then
                [ "$VERBOSE" = 1 ] && echo "BADEXIT $name (stdout correct, exit $rc, expected $want_rc)"
                BADEXIT=$((BADEXIT+1)); MODE_FAIL=1
            else
                [ "$VERBOSE" = 1 ] && echo "FAIL $name (rc=$rc, expected $want_rc)"
                FAIL=$((FAIL+1)); MODE_FAIL=1
            fi
            continue
        fi
        if [ "$got" = "$want" ]; then
            if [ "$is_xfail" = 1 ]; then
                echo "XPASS $name (marked XFAIL but now genuinely passes -- STALE MARKER, promote it: rm ${base}.xfail)"
                XPASS=$((XPASS+1)); MODE_FAIL=1
            else
                [ "$VERBOSE" = 1 ] && echo "PASS $name"
                PASS=$((PASS+1))
            fi
        else
            if [ "$is_xfail" = 1 ]; then
                [ "$VERBOSE" = 1 ] && echo "XFAIL $name"
                XFAIL=$((XFAIL+1))
            else
                if [ "$VERBOSE" = 1 ]; then
                    echo "FAIL $name"
                    echo "  want: $(echo "$want" | tr '\n' '|')"
                    echo "  got:  $(echo "$got"  | tr '\n' '|')"
                fi
                FAIL=$((FAIL+1)); MODE_FAIL=1
            fi
        fi
    done
    # suite-format families (see header note): fold each converted family's board into these same
    # totals -- m3 for interp/run, m4 for compile (both proven live for Icon, so unlike the Prolog
    # twin no mode is withheld here).
    local hmode; case "$mode" in interp|run) hmode=m3 ;; compile) hmode=m4 ;; esac
    local sf sfname board spass sfail scrash shang sunproven sxfail sxpass sbad
    for sf in "${SUITE_FILES[@]}"; do
        sfname=$(basename "$sf" .icn)
        board=$(python3 "$HERE/corpus_suite_harness.py" run "$sf" "${sf%.icn}.ref" --lang icon --modes "$hmode" 2>&1 | grep '^SUITE_BOARD')
        spass=$(echo "$board" | grep -oP "${hmode}_pass=\K[0-9]+")
        if [ -z "$spass" ]; then
            echo "SUITE-RUN-ERROR $sfname ($mode) (harness produced no SUITE_BOARD line)" >&2
            FAIL=$((FAIL+1)); MODE_FAIL=1
            continue
        fi
        sfail=$(echo "$board" | grep -oP "${hmode}_fail=\K[0-9]+")
        scrash=$(echo "$board" | grep -oP "${hmode}_crash=\K[0-9]+")
        shang=$(echo "$board" | grep -oP "${hmode}_hang=\K[0-9]+")
        sunproven=$(echo "$board" | grep -oP "${hmode}_unproven=\K[0-9]+")
        sxfail=$(echo "$board" | grep -oP "${hmode}_xfail=\K[0-9]+")
        sxpass=$(echo "$board" | grep -oP "${hmode}_xpass=\K[0-9]+")
        # XPASS (a witness marked XFAIL that actually passed -- stale marker) is surfaced as loudly
        # as FAIL and trips MODE_FAIL the same way, but through its OWN top-line bucket rather than
        # folded anonymously into FAIL -- FAIL means "broken", XPASS means "already fixed, paperwork
        # owed", and collapsing the two into one number is the named A-SIGNAL-REACHABLE-BY-TWO-CAUSES
        # defect (RULES.md) wearing this file's own costume. Kept consistent with the loose-file path's
        # XPASS bucket below even though no Icon family is suite-converted yet (SUITE_FILES is empty
        # today, so this is currently inert, not a behavior change) -- see xpass-promotion-xfail-hygiene.
        sbad=$((sfail+scrash+shang+sunproven))
        [ "$VERBOSE" = 1 ] && echo "SUITE $sfname ($mode): pass=$spass xfail=$sxfail bad=$sbad xpass=$sxpass"
        PASS=$((PASS+spass)); FAIL=$((FAIL+sbad)); XFAIL=$((XFAIL+sxfail)); XPASS=$((XPASS+sxpass))
        { [ "$sbad" -gt 0 ] || [ "$sxpass" -gt 0 ]; } && MODE_FAIL=1
    done
    # ⭐ Byte-identical to the pre-BADEXIT summary whenever BADEXIT=0 (true for the whole corpus today) —
    # the field is inserted only when it has something to say, same convention this file already used for
    # REFUSED, so no board number or downstream grep changes until a sidecar file actually exists.
    local total=$((PASS+FAIL+XFAIL+XPASS)) line="PASS=$PASS FAIL=$FAIL"
    if [ "$BADEXIT" -gt 0 ]; then line="$line BADEXIT=$BADEXIT"; total=$((total+BADEXIT)); fi
    line="$line XFAIL=$XFAIL"
    # XPASS only appears when nonzero (same convention as BADEXIT/REFUSED/MISSING) -- it is the good-news,
    # rare case, and printing "XPASS=0" on every green board forever would just be noise on top of noise.
    if [ "$XPASS" -gt 0 ]; then line="$line XPASS=$XPASS"; fi
    if [ "$REFUSED" -gt 0 ]; then line="$line REFUSED=$REFUSED"; total=$((total+REFUSED)); fi
    if [ "$MISSING" -gt 0 ]; then line="$line MISSING=$MISSING"; fi
    if [ "$INVALID" -gt 0 ]; then line="$line INVALID=$INVALID"; fi
    echo "--- Icon ($mode): $line TOTAL=$total ---"
}

collect_files
# ⛔⭐ POPULATION FLOOR (row every-board-wrapper-refuses-on-a-zero-population-instead-of-passing-
# vacuously, hq_T 2026-09-04): run_corpus() only sets MODE_FAIL on a FILE it iterates -- if
# collect_files's globs matched nothing (a --rung typo, or a family fully consolidated into a suite
# pair with the loose originals removed and SUITE_FILES's own discriminator missing it), the loop body
# never runs, MODE_FAIL stays its initialized 0, and HARD_FAIL below reads exactly like a clean board.
"$HERE/util_require_population.sh" --gate test_icon_rung_suite "$((${#FILES[@]}+${#SUITE_FILES[@]}))" 1 "collected .icn/.ref witnesses (RUNG=${RUNG:-<all>})" || exit 2
# verbose per-file output only for single-mode runs; the all-modes sweep prints summaries only
VERBOSE=1; [ "$MODE" = "all" ] && VERBOSE=0

HARD_FAIL=0
case "$MODE" in
    all)
        for m in interp run compile; do
            run_corpus "$m"
            [ "$m" = interp ] && [ "$MODE_FAIL" -ne 0 ] && HARD_FAIL=1
        done
        ;;
    interp|run|compile)
        run_corpus "$MODE"
        [ "$MODE" = interp ] && [ "$MODE_FAIL" -ne 0 ] && HARD_FAIL=1
        ;;
    *) echo "bad mode $MODE" >&2; exit 1 ;;
esac

[ "$HARD_FAIL" -eq 0 ]
