#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib_one_runner.sh" && one_runner_guard "${0##*/}" "${S4E_CORPUS:-${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}/corpus}/packages/prolog/logtalk_iso" || exit 2
# test_prolog_logtalk_suite.sh — THE LOGTALK ISO/IEC 13211-1 CONFORMANCE BOARD
# (row prolog-logtalk-iso-3268-conformance-cases-have-no-runner, hq_R 2026-09-12; Lon 2026-09-11: "Let's
# get those Prolog programs graded.").
#
# WHAT IT GRADES. corpus/packages/prolog/logtalk_iso — 192 tests.lgt holding 3617 conformance cases across
# 97 built-in predicates, 54 arithmetic functions, 12 control constructs, 11 syntax groups, 7 directives,
# the logical update view, unbounded integers and Unicode. Roughly 7x the INRIA suite, Apache-2.0, and the
# suite SWI-Prolog, JIProlog and Tau Prolog self-check with. Before this runner: 0 of 3617 graded, which
# made it the largest single gap on the board.
#
# ⛔⭐ THE ROW NAME SAYS 3268 AND THE POPULATION IS 3617. The row was minted off a census of `test/2` heads
# alone; the suite also uses lgtunit's three legacy spellings — succeeds/1 162, throws/2 134, fails/1 53 —
# which are the same three expectations written differently (succeeds == true, fails == false,
# throws(Name,Ball) == the ball). ⭐ A PARSER THAT HANDLES ONLY test/2 GRADES 90% OF THIS SUITE AND REPORTS
# 100% OF IT, and that is the defect class this row exists to stop, so the legacy three are normalised into
# the same expectation vocabulary rather than given a second grading path.
#
# ⛔⭐ WHAT THE CRITERION IS, AND WHY IT IS NOT AN ORACLE DIFF. Every case carries its OWN expectation,
# lifted from ISO/IEC 13211-1 and citing the standard's section numbers in the comment above it. This
# runner therefore grades scrip against THE STANDARD AS THE STANDARD STATES IT, not against gprolog's or
# swipl's opinion of it — a stronger instrument than any oracle diff this repo owns, and the reason this
# row decides whether "100% of the industry-standard language" can be said about Prolog at all.
#
# ⛔ THE IDENTITY IS THE DELIVERABLE, NOT THE PERCENTAGE (ARCH-PROGRAM-LEDGER):
#     PASS + FAIL + OUTSIDE + UNGRADABLE + UNGRADED + DEFERRED == the population globbed
# and it is ASSERTED IN CODE — if it does not reconcile the run REFUSES rather than publishing numbers with
# an invisible remainder. A case this runner cannot set up, cannot express, or is told to skip by its own
# `condition(...)` option is UNGRADED **and named with its reason**: never dropped, never a pass. UNKNOWN
# is not ZERO.
#
# Usage: bash ../harness/scripts/test_prolog_logtalk_suite.sh [--modes m3|m3,m4] [--name-reds] [--jobs N]
set -uo pipefail
GATE_NAME=test_prolog_logtalk_suite
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export TIMEOUT_RETRY="${TIMEOUT_RETRY:-$HERE/util_timeout_retry.sh}"   # a graded run's timeout (CEO-1335): a timeout under load is retried once, util_timeout_retry.sh
ROOT="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
SUITE="${S4E_CORPUS:-$ROOT/corpus}/packages/prolog/logtalk_iso"
SCRIP="$HERE/../../SCRIP/scrip"
MODES="${LOGTALK_MODES:-m3,m4}"
JOBS="${LOGTALK_JOBS:-}"
NAME_REDS=""
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
while [ $# -gt 0 ]; do
    case "$1" in
        --modes) MODES="$2"; shift 2 ;;
        --jobs) JOBS="$2"; shift 2 ;;
        --name-reds) NAME_REDS="--name-reds"; shift ;;
        *) refuse "unknown argument '$1' -- this runner has no silent fall-through" ;;
    esac
done
# ⛔ THE FAN-OUT CEILING (ceo CEO-1333; the ceo's word to the coo 2026-10-01 12:1x CDT, a Logtalk pass at 12 jobs put load1 at 18 on a
# shared box): the default width is lib_fanout.sh's fanout_width, max(2, min(4, cores - demand)), read at launch; a --jobs or LOGTALK_JOBS above
# it is CLAMPED and the clamp is printed, never silent -- the shape run_blocking_set.sh gives --shards. This runner defaulted to 12.
. "$HERE/lib_fanout.sh" || refuse "../harness/scripts/lib_fanout.sh is missing -- the fan-out ceiling has no instrument"
_fw=$(fanout_width)
case "$JOBS" in
    '') JOBS=$_fw ;;
    *[!0-9]*|0) refuse "--jobs takes a count of 1 or more (got '$JOBS')" ;;
    *) if [ "$JOBS" -gt "$_fw" ]; then echo "fanout: --jobs $JOBS clamped to $_fw at CPU demand $(fanout_demand) ($(fanout_source)) on $(fanout_cores) cores (CEO-1333/1394: max(2, min(4, cores - demand)), never load1)"; JOBS=$_fw; fi ;;
esac

[ -d "$SUITE" ] || refuse "no vendored suite at $SUITE -- a suite that is absent is not a suite that is failing"
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first; a missing binary prints a full, plausible, entirely false board"
# ⛔⭐ STALE-BINARY PREFLIGHT. The line above proves a binary EXISTS; this one proves it is the binary this
# tree describes. NO LOGIC HERE: util_require_fresh.sh sources gate_require_fresh from lib_gate.sh, the ONE
# authority — never a second copy of the staleness rule.
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "${RT_DIR:-$HERE/../../SCRIP/out}/libscrip_rt.so" || exit 2
. "$HERE/lib_gate.sh"
. "$HERE/lib_inventory.sh"

# ⛔⭐⭐ THE HARNESS PREFLIGHT, AND IT IS THE MOST IMPORTANT LINE IN THIS FILE. 1141 of the 3617 cases call
# an lgtunit framework predicate, so lib_logtalk_lgtunit.pl (the plain-Prolog shim that re-implements them)
# is prepended to EVERY generated case program. If the shim itself does not compile and run under this
# binary, every case comes back refused — and the board that prints is complete, plausible and entirely
# about the harness. ⭐ So the harness proves itself on a two-line witness BEFORE any case is graded, and
# says so out loud, because "the instrument was broken" must never be a thing the reader has to infer from
# a suspiciously round number.
_pf="$(mktemp -d "${TMPDIR:-/tmp}/lgt_preflight.XXXXXX")"
{ cat "$HERE/lib_logtalk_lgtunit.pl"
  echo "'\$p' :- lgt_h(lgt_set_text_output('')), write(ok), lgt_h(lgt_text_output_assertion(ok, A)), A."
  echo ":- ( catch('\$p', E, (write(user_output, '@PRE ball '), writeq(user_output, E))) -> write(user_output, '@PRE ok') ; write(user_output, '@PRE fail') ), nl(user_output)."
} > "$_pf/preflight.pl"
_pfout="$(cd "$_pf" && "$TIMEOUT_RETRY" 30 "$SCRIP" "$_pf/preflight.pl" </dev/null 2>&1)"; _pfrc=$?
rm -rf "$_pf"
case "$_pfout" in
    *"@PRE ok"*) echo "HARNESS PREFLIGHT ok: lib_logtalk_lgtunit.pl compiles and round-trips a captured write under this binary" ;;
    *) refuse "the lgtunit shim does not run under this binary (rc=$_pfrc): ${_pfout:-<no output>}
    Every case program embeds this shim, so grading now would publish a complete, plausible board that measures the harness and not the language." ;;
esac

# ⭐ THE DECLARED HEAP AND STACK (Lon 2026-09-23 18:3x; CEO-1167, CEO-1225; wired by the coo on CEO-1229, the SWI runner's pattern):
# ALL.csv's heap_kb and stack_kb are read ONCE through lib_declared_arena.sh (the one reader; a refused cell refuses the board) and the
# validated table goes to the grader, which runs each case in both modes at its own declaration (util_logtalk_grade.py decl_env).
# Line 2 hands the guard the same suite this runner grades -- S4E_CORPUS, else S4E_HOME's corpus, exactly as SUITE above.
. "$HERE/lib_declared_arena.sh" || refuse "lib_declared_arena.sh unloadable -- the one reader of a declared heap and stack"
_decl="$(mktemp "${TMPDIR:-/tmp}/lgt_decl.XXXXXX")"
declared_memory_begin "$SUITE/ALL.csv" "$_decl" || { rm -f "$_decl"; refuse "a declared-memory cell in $SUITE/ALL.csv is refused (named above) -- fix the cell; this board does not grade around it"; }
_out="$(mktemp "${TMPDIR:-/tmp}/lgt_board.XXXXXX")"
trap 'rm -f ${_decl:+"$_decl"} ${_out:+"$_out"}' EXIT; trap 'rm -f ${_decl:+"$_decl"} ${_out:+"$_out"}; exit 143' TERM; trap 'rm -f ${_decl:+"$_decl"} ${_out:+"$_out"}; exit 130' INT
# ⭐ THE ROUND ROBIN'S SEAM (ceo CEO-1802/1805/1806; Lon 2026-10-17, in-chat to the coo: "Get LogTalk working now that you have batches."): under
# S4E_CHUNK the part's cases (group:case, as ALL.csv and PARTITION.tsv name them) are graded in the partition's order, LOGTALK_RR_BATCH (25) names
# per grader call, both modes each call, and each call's rows are appended as it ends. Between two calls a waiting request or a spent S4E_RR_BUDGET
# stops the part (RR_YIELD; the loop resumes it at the next name). No suite row is written from a part: util_score_row.py from-progress assembles it.
. "$HERE/lib_rr.sh" && rr_load "$SUITE" || refuse "the round-robin selection S4E_CHUNK=${S4E_CHUNK:-} is refused (named above)"
if rr_selected; then
    . "$HERE/lib_progress.sh" || refuse "lib_progress.sh is missing -- a part's rows would go nowhere"
    mapfile -t _sel < <(rr_entries | awk '!s[$0]++')   # a repeated name is one entry: --only grades every instance of it
    _only="$(mktemp "${TMPDIR:-/tmp}/lgt_only.XXXXXX")"; _b="${LOGTALK_RR_BATCH:-25}"; _i=0; _graded=0
    while [ "$_i" -lt "${#_sel[@]}" ]; do
        { rr_yield "${_sel[$_i]}" || rr_over_budget "${_sel[$_i]}"; } && break
        printf '%s\n' "${_sel[@]:$_i:$_b}" > "$_only"
        python3 "$HERE/util_logtalk_grade.py" --suite "$SUITE" --scrip "$SCRIP" --modes "$MODES" --jobs "$JOBS" --decl "$_decl" --only "$_only" $NAME_REDS > "$_out" 2>&1
        _rc=$?
        grep -E '^(LOGTALK_ISO_BOARD|ONLY:)' "$_out"
        [ "$_rc" -eq 0 ] || { tail -20 "$_out"; rm -f "$_only"; exit "$_rc"; }
        _prows="$(grep -m1 '^PROGRESS_ROWS_TSV ' "$_out" | awk '{print $2}')"
        if [ -n "${_prows:-}" ] && [ -s "$_prows" ]; then progress_append_rows_tsv "$_prows" > /dev/null || echo "⚠ progress rows NOT recorded"; fi
        _i=$((_i + _b)); _graded=$(( _i < ${#_sel[@]} ? _i : ${#_sel[@]} ))
    done
    rm -f "$_only"
    echo "graded $_graded of ${#_sel[@]} name(s) of the part"
    rr_end logtalk; exit 0
fi
python3 "$HERE/util_logtalk_grade.py" --suite "$SUITE" --scrip "$SCRIP" --modes "$MODES" --jobs "$JOBS" --decl "$_decl" $NAME_REDS | tee "$_out"
# ⛔ PIPESTATUS[0], NEVER $? -- the pipeline ends in `tee`, so $? reports the pager and a python that died
# reads as a clean run (CLAUDE.md, measured live on this box).
_rc=${PIPESTATUS[0]}
[ "$_rc" -eq 0 ] || { rm -f "$_out" "$_decl"; exit "$_rc"; }

_shell="$(grep -m1 '^BOARD_FOR_SHELL ' "$_out" || true)"
[ -n "$_shell" ] || { echo "⚠ SCORE.md NOT UPDATED [$GATE_NAME]: the run printed no BOARD_FOR_SHELL line, so there is no measurement to record"; rm -f "$_out" "$_decl"; exit 1; }
set -- $_shell
_pop="$2"; _both="$3"; _m3p="$4"; _m3f="$5"; _m4p="${6:-}"; _m4f="${7:-}"
# ⭐ THE EXCLUDED CASES (EXCLUDED_CASES.tsv beside the suite, Lon 2026-10-05, ceo CEO-1519/1520) ride the shell line as a named trailing
# field, never a position, and reach the row as --excluded so the grid shows Excl beside PASS over the population (shipped = both).
_excl="$(printf '%s\n' "$_shell" | grep -o 'excluded=[0-9]*' | cut -d= -f2)"
[ -n "$_excl" ] || refuse "the grader's BOARD_FOR_SHELL line carries no excluded= field -- the Excl column would be a guess"
# ⛔⭐ POPULATION FLOOR (row every-board-wrapper-refuses-on-a-zero-population-instead-of-passing-
# vacuously, hq_T 2026-09-04; gap named by coo, test_gate_board_population_floor.sh ARM 6, 2026-09-21).
# util_logtalk_grade.py only refuses on an empty population when --group is passed; this runner never
# passes --group, so a suite directory that came back empty (a vendoring accident, a bad --suite path)
# would otherwise print "population=0, identity 0 == 0 ✓" and read as a clean board.
"$HERE/util_require_population.sh" --gate "$GATE_NAME" "$_pop" 1 "logtalk_iso cases graded (BOARD_FOR_SHELL population)" || { rm -f "$_out" "$_decl"; exit 2; }

# ⛔⭐ ONE ROW PER CASE PER MODE (CEO-331), appended from what the grader just wrote. NON-FATAL BY DESIGN,
# exactly like gate_score_row: a runner that gets red-ed by its own bookkeeping is a runner people stop
# calling. ⛔ WITHOUT THIS THE SUITE READS AS **MISSING** TO util_progress_flips --coverage even while the
# board is green, so a flip the progress table cannot see is a flip nobody is paid for (coo, 2026-09-12).
if [ -f "$HERE/lib_progress.sh" ]; then
    . "$HERE/lib_progress.sh"
    _prows="$(grep -m1 '^PROGRESS_ROWS_TSV ' "$_out" | awk '{print $2}')"
    if [ -n "${_prows:-}" ] && [ -s "$_prows" ]; then progress_append_rows_tsv "$_prows" || echo "  (progress append failed -- the board stands)"; fi
fi

# ⛔⭐ THE PACKAGE INVENTORY IS A FILE CENSUS AND THE BOARD ABOVE IS A CASE CENSUS -- two populations, and
# conflating them is how a package reports 100% of the wrong thing. shipped counts .lgt files (400: 192
# tests.lgt plus the vendor's 192 driver objects, 6 alternative entry objects and 10 encoded data
# fixtures, each named in UNGRADABLE.tsv); the board counts the 3617 CASES inside the 192. Both are
# printed, and the board line says which number is which.
INV_PACKAGE=logtalk_iso; INV_DIR="$SUITE"; INV_EXT=".lgt"
_iv="$(inventory_line 192 0)"; _ivrc=$?
[ "$_ivrc" -eq 0 ] && echo "$_iv"
[ "$_ivrc" -eq 0 ] || echo "⚠ the package inventory refused (rc=$_ivrc) -- the case board above stands on its own measurement; the FILE census does not"

_board="$(grep -m1 '^LOGTALK_ISO_BOARD ' "$_out" || true)"
_ident="$(grep -m1 ' identity ' "$_out" | sed 's/^ *//' || true)"
_txt="logtalk_iso (ISO/IEC 13211-1, the suite's own per-case expectations) $_both/$_pop by the AND PER CASE — a case passes when it passes in EVERY mode graded (CEO-372), which is NOT either per-mode count: $_m3p/$_pop m3"
[ -n "$_m4p" ] && _txt="$_txt · $_m4p/$_pop m4 are equal counts over sets that differ"
_txt="$_txt — every case graded against the standard as the standard states it, not an oracle diff; $_ident"
# ⛔⭐ THE SUITE ROW STATES THE **AND PER CASE**, PASSED EXPLICITLY, AND THE KEY IS LOWERCASE `logtalk`.
# Three things went wrong here on the first pass and all three are the same mistake -- letting a helper
# infer what only this runner knows (coo, 2026-09-12): (1) the key was written LOGTALK and SUITES.tsv's is
# `logtalk`; (2) no --suite-pass/--suite-total was given, so util_score_row tried to read a fraction out of
# the prose and REFUSED, leaving SCORE.md rewritten and SUITES.tsv untouched -- the adrift-cell split state
# the handoff instrument warns on; (3) even had it read one, the per-mode fraction is the WRONG NUMBER when
# the modes differ. m3 and m4 both say 1218 over sets that are not the same. CEO-372's answer is the AND per
# case, and only this runner can compute it, so only this runner may state it.
_sc="$HERE/util_score_row.py"
# A DENOMINATOR MOVE IS STAMPED THROUGH S4E_CRITERION_CHANGED='<YYYY-MM-DD>:<reason>' (the test_corpus_snobol4.sh convention, CEO-785): the
# writer refuses a moved denominator without it, and this runner had no way to pass it (hq_prolog 2026-09-25, when CEO-1235 (a) moved 3600 -> 3528).
python3 "$_sc" write --lang prolog --column vendor --text "$_txt${_iv:+ · $_iv (\`$GATE_NAME.sh\`)}" \
    --measurer "${S4E_SEAT:-}" --modes "$MODES" --suite logtalk --suite-pass "$_both" --suite-total "$_pop" --excluded "$_excl" \
    ${S4E_CRITERION_CHANGED:+--criterion-changed "$S4E_CRITERION_CHANGED"} \
    || echo "⚠ SCORE.md NOT UPDATED [$GATE_NAME] -- the board above stands on its own measurement; the leaderboard row does not"
rm -f "$_out" "$_decl"
exit 0
