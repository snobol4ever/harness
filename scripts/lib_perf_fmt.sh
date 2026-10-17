#!/usr/bin/env bash
# lib_perf_fmt.sh -- ⭐ THE ONE AUTHORITY for PRINTING a benchmark multiple.
#
# THE RULE IT IMPLEMENTS (Lon, 2026-08-23 s266; authority .github/RULES.md § FACT RULES):
#   THE UNIT IS `x`, A MULTIPLE, ON THE FASTER AXIS.  multiple = reference / ours.
#   2.00x is twice the reference's speed, 0.50x is half.  THE NUMBER IS THE DIRECTION.
#   ⛔ FASTER and SLOWER are NOT UNITS and never attach to a multiple: "0.666 slower" is
#      self-contradictory, because *slower* has its own multiple (1.5x as slow), so the
#      phrase names two answers at once.  "2x slower" is the same disease from the other
#      side -- it means 0.50x and reads as the bigger number.
#   ✅ PERCENTAGES may take the English word, and only percentages: 10% faster = 1.10x,
#      10% slower = 0.90x.  perf_pct below is the one that is allowed to say it.
#   ⭐ COLOUR WHERE THE MEDIUM SUPPORTS IT (Lon, same session): below 1.00x RED, at or
#      above 1.00x GREEN.  Colour is a SECOND channel, never the only one -- every
#      function here prints a number that is still correct with the colour stripped,
#      because it will be: pipes, logs, CI capture and `less` all lose it.
#
# ⛔ WHY THIS IS A FILE AND NOT A CONVENTION.  Six harnesses printed their own ratios and
# three of them printed them in opposite directions -- that is how GOAL-HQ-PERFORM's RUNG
# P-0 table came to run two divisors down one column.  A rule that lives only in markdown
# is re-derived by every script author.  Callers that cannot load this file must REFUSE,
# not fall back to a private format -- same law as lib_oracle_flags.sh.
#
#=====================================================================================================
# ⛔⭐ THE DARK-CELL LAW (CEO-676, dark-is-worse-than-red CEO-582 arriving in the benchmark harness;
# hq_P 2026-09-13).  A BENCHMARK ARM THAT CANNOT MEASURE ITS SUBJECT REFUSES, NAMING THE SUBJECT.
# It never emits a blank cell, and a grid refuses to publish a column it could not fill.
#
# THE THREE SHAPES THIS FILE USED TO PRODUCE, ALL MEASURED IN THIS TREE, ALL NOW REFUSED:
#   (1) BLANK -- `if (o + 0 == 0) { print "n/a" }`.  A tidy two-letter cell that reads as a
#       measurement which came back empty, when the truth is that no measurement happened.
#   (2) FABRICATED -- a sub-floor reading printed as 0 became "0.000x" for deriv-vs-gprolog
#       (bench_prolog_vanroy.sh:78 records it).  WORSE than blank: it is a NUMBER, it sorts,
#       it colours RED, and it will be quoted.  awk's `o + 0` also silently turns any
#       non-numeric string into 0, so a cell holding "ERROR" rendered as a multiple.
#   (3) INVISIBLE -- callers guard with `[ -n "$rf" ] && [ -n "$r3" ] && perf_row ...`, so a
#       missing operand DELETES THE ROW.  A grid with a row missing looks complete; nobody
#       greps for a row that was never printed.  perf_row_or_refuse is the cure for that one.
# ⭐ A caller that already knows its subject is below the instrument should say so in its own
# words (bench_icon_kernels.sh prints "<1 tick") -- that is a MEASUREMENT, not a dark cell, and
# it is exactly why the refusal names the subject rather than guessing on the caller's behalf.
#
# ⛔⭐ AND A VERDICT WITHOUT ITS LOAD IS NOT A VERDICT (CEO-697 one layer deeper, hq_P 2026-09-13).
# The ruling says a COST without the load it ran under is not a cost.  Measured on this box: two
# runs of IDENTICAL angle-2 code differ by up to 2.15x, and gnu's `cal` column moved 1,352,177 ->
# 742,684 iterations/s (1.82x) between two runs of unchanged code.  Two van Roy gates PASS on a
# busy box and FAIL on an idle one, because a budget-driven harness picks its iteration count from
# how fast the box is.  A pass/fail that silently tracks machine load is the one disguise nobody
# audits, because a green gate is never investigated.  So the load stamp lives HERE, in the
# printer, and not in a caller's good intentions: perf_grid_begin welds it to the shared-axes line
# every grid must already print, so a grid cannot open without stating the load it ran under.
#=====================================================================================================
#
# USAGE
#   . "$(dirname "$0")/lib_perf_fmt.sh"
#   perf_mult <reference_cost> <our_cost> [subject]  -> "1.628x" (green) / "0.734x" (red)
#                                                       or REFUSED (rc=2, subject named on stderr)
#   perf_pct  <before_cost>    <after_cost> [subject] -> "24.3% faster" / "8.0% slower"
#   perf_row  <label> <ref> <ours>                   -> one aligned, coloured table row
#   perf_row_or_refuse <label> <ref> <ours>          -> same, but a missing operand PRINTS a
#                                                       refusing row instead of vanishing
#   perf_load_stamp                                  -> "load 1.71 on 16 cores (0.11/core)"
#   perf_grid_begin <axis-line>                      -> the shared-axes line WITH the load stamp
#   perf_grid_end                                    -> rc=2 if any cell in this grid refused
#   perf_dark_cell <subject> <why>                   -> bump the dark count from a caller that
#                                                       prints its own grid; names it on stderr
#   PERF_COLOR=0 forces plain; PERF_COLOR=1 forces colour even when not a tty.
#   PERF_DARK_CELLS counts refusals since the last perf_grid_begin.  Read it, do not set it.
perf_color_on() {
    case "${PERF_COLOR:-auto}" in 0|no|off) return 1 ;; 1|yes|on) return 0 ;; esac
    [ -t 1 ] || return 1                       # not a terminal: a pipe or a log, so plain
    [ "${TERM:-dumb}" != dumb ] || return 1
    return 0
}
#-----------------------------------------------------------------------------------------------------
# perf_is_cost VALUE -- is this a usable COST?  A cost is a positive real.  ⛔ This is the guard that
# stops awk's `v + 0` from silently turning "ERROR", "" or "n/a" into 0 and then into a multiple.
# Zero is NOT a usable cost: a zero denominator is not an infinitely fast program, it is a program
# the instrument could not see, and the caller must say which of those it means.
perf_is_cost() {
    case "$1" in ''|*[!0-9.eE+-]*) return 1 ;; esac
    awk -v v="$1" 'BEGIN{ exit !(v + 0 > 0 && v ~ /^[+]?[0-9]*[.]?[0-9]+([eE][+-]?[0-9]+)?$/) }'
}
#-----------------------------------------------------------------------------------------------------
# perf_refuse SUBJECT WHY -- the ONE way this file reports an unmeasurable subject.  Prints a loud,
# non-blank, non-numeric token on stdout so the cell cannot be read as a measurement, names the
# subject and the reason on stderr, counts itself, and returns 2.
perf_refuse() {
    PERF_DARK_CELLS=$(( ${PERF_DARK_CELLS:-0} + 1 ))
    printf 'REFUSED'
    printf '⛔ perf: REFUSED to print a multiple for %s -- %s (a dark cell is worse than a red one: CEO-676)\n' \
           "${1:-<unnamed subject>}" "${2:-unmeasurable operand}" >&2
    return 2
}
#-----------------------------------------------------------------------------------------------------
# perf_dark_cell SUBJECT WHY -- for a caller that formats its OWN grid (the three Prolog angle harnesses
# print aligned work/overhead tables of their own, not perf_row rows) and needs a hand-printed dark cell
# to reach perf_grid_end.  Prints NOTHING on stdout -- the caller is mid-row and owns its own column
# text -- bumps the count IN THE CALLER'S SHELL, and names the subject on stderr like every other refusal.
# ⛔ WHY THIS EXISTS RATHER THAN `PERF_DARK_CELLS=$((...+1))` AT EACH SITE, AND IT IS ARM E's LESSON ONE
#   LEVEL OUT: angle 1 landed printing literal "DARK" cells and closing with `perf_grid_end || true`, so
#   its whole-grid verdict was structurally unable to fire -- the counter it reads was never touched by
#   the cells it exists to count, and the `|| true` discarded even that.  A guard satisfied by the broken
#   shape is what this lane keeps paying for.  One named function is also what a gate can census for.
# ⭐ WHAT IS NOT A DARK CELL, per THE DARK-CELL LAW above: a subject the caller KNOWS is below its
#   instrument and says so in its own words ("<1 tick", "TICK-FLOOR(0)") is a MEASUREMENT -- the reader
#   is told the truth and no number is fabricated.  Do not bump for those; bump when the cell could not
#   measure its subject at all (no run, no bracket reading, a build that failed, a generator that refused).
perf_dark_cell() {
    PERF_DARK_CELLS=$(( ${PERF_DARK_CELLS:-0} + 1 ))
    printf '⛔ perf: dark cell for %s -- %s (a dark cell is worse than a red one: CEO-676)\n' \
           "${1:-<unnamed subject>}" "${2:-could not measure its subject}" >&2
    return 0
}
#-----------------------------------------------------------------------------------------------------
# perf_stamp_suffix / perf_stamp_once_for_rows -- CEO-743: EVERY WALL-CLOCK NUMBER RECORDS THE LOAD AT
# MEASUREMENT, IN THE SAME LINE AS THE NUMBER.  ⛔ The ruling is explicit that this belongs in this file
# "so it cannot be forgotten, rather than in a procedure that must be remembered", and the census that
# earned it is the reason: EIGHT benchmark scripts -- bench_icon_classic_set.sh, bench_icon_kernels.sh,
# bench_ir_slope.sh, bench_two_number_ir.sh, bench_prolog_vanroy.sh, bench_pascal_fixed_iter.sh,
# test_bench_pascal_timed.sh, bench_startup_touch_ab.sh -- print multiples through perf_row/perf_mult and
# never call perf_grid_begin, so the stamp this file already had reached NONE of them.
# ⭐ THE MEASUREMENT THAT MAKES IT A LAW AND NOT A COURTESY: one unchanged binary read 0.549x at load 6.96
# and 0.384x at load 29.84 -- the ratio moved by 30% of itself, so load does NOT cancel out of a multiple,
# and the SIGN of the error is not knowable from inside the measurement.  Two such readings are identical
# on paper and 30% apart in fact, and the only thing that separates them is a figure neither one printed.
# WHERE THE STAMP GOES, AND WHY IT IS NOT SIMPLY "ON EVERY LINE": the FACT RULE says a grid names its axis
# ONCE in the header and its rows carry BARE multiples, so stamping every row would break the grid it is
# trying to make honest.  So: a standalone perf_mult/perf_pct carries the stamp itself; inside a grid the
# header carries it once; and a grid built WITHOUT perf_grid_begin -- all eight scripts above -- gets it
# emitted once before its first row, which is the seam that would otherwise keep them loadless forever.
perf_stamp_suffix() {
    [ "${PERF_STAMP_OFF:-0}" = "1" ] && return 0
    [ "${PERF_GRID_OPEN:-0}" = "1" ] && return 0
    printf '   · %s' "$(perf_load_stamp)"
}
perf_stamp_once_for_rows() {
    [ "${PERF_GRID_OPEN:-0}" = "1" ] && return 0
    [ "${PERF_ROWS_STAMPED:-0}" = "1" ] && return 0
    PERF_ROWS_STAMPED=1
    printf '  measured at %s · %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$(perf_load_stamp)"
}
#-----------------------------------------------------------------------------------------------------
# perf_mult REF OURS [SUBJECT] -- the multiple, coloured, with its unit.  Nothing else.
# ⛔ REFUSES rather than printing "n/a" or a fabricated "0.000x"; see THE DARK-CELL LAW above.
perf_mult() {
    [ $# -ge 2 ] || { echo "perf_mult: need <reference_cost> <our_cost> [subject]" >&2; return 2; }
    local subj="${3:-reference=$1 ours=$2}"
    perf_is_cost "$1" || { perf_refuse "$subj" "reference cost is not a positive number: '$1'"; return 2; }
    perf_is_cost "$2" || { perf_refuse "$subj" "our cost is not a positive number: '$2'"; return 2; }
    local out
    out="$(awk -v r="$1" -v o="$2" -v c="$(perf_color_on && echo 1 || echo 0)" 'BEGIN{
        m = r / o
        s = sprintf("%.3fx", m)
        if (c) { print (m >= 1.0 ? "\033[92m" : "\033[31m") s "\033[0m" } else { print s }
    }')"
    printf '%s%s\n' "$out" "$(perf_stamp_suffix)"
}
#-----------------------------------------------------------------------------------------------------
# perf_pct BEFORE AFTER [SUBJECT] -- a DELTA, and a delta is the one form allowed to say the word.
# BEFORE/AFTER are COSTS (lower is better), so after < before is faster.
perf_pct() {
    [ $# -ge 2 ] || { echo "perf_pct: need <before_cost> <after_cost> [subject]" >&2; return 2; }
    local subj="${3:-before=$1 after=$2}"
    perf_is_cost "$1" || { perf_refuse "$subj" "before cost is not a positive number: '$1'"; return 2; }
    perf_is_cost "$2" || { perf_refuse "$subj" "after cost is not a positive number: '$2'"; return 2; }
    local out
    out="$(awk -v b="$1" -v a="$2" -v c="$(perf_color_on && echo 1 || echo 0)" 'BEGIN{
        m = b / a; p = (m - 1) * 100
        s = (p >= 0) ? sprintf("%.1f%% faster", p) : sprintf("%.1f%% slower", -p)
        if (c) { print (p >= 0 ? "\033[92m" : "\033[31m") s "\033[0m" } else { print s }
    }')"
    printf '%s%s\n' "$out" "$(perf_stamp_suffix)"
}
#-----------------------------------------------------------------------------------------------------
# perf_row LABEL REF OURS -- one row of a grid.  ⛔ The grid's own header still has to name
# the axis ONCE ("x vs <reference>") and carry its SHARED-AXES line; this only formats.
# ⭐ The label is TRUNCATED to its field, never wrapped: a row that wraps turns a grid into prose,
# and Lon's ruling on the suite banner was that an unreadable grid is not a grid (2026-09-13).
# ⛔ THE SUBSHELL SEAM, AND IT MADE perf_grid_end INERT ON THE ONLY PATH THAT MATTERS (hq_P 2026-09-13).
# This function used to call perf_mult inside the printf's own $( ), so perf_refuse's
# PERF_DARK_CELLS bump happened in a SUBSHELL and never reached the parent: every refusal arriving
# through perf_row was invisible to perf_grid_end, which then closed rc=0 on a grid with a hole in it.
# ⭐ The two gate arms that should have caught it BOTH PASSED -- arm C refused a grid whose dark cell
# came from a DIRECT perf_mult call (parent shell, counter survives) and arm D proved the row prints
# REFUSED -- and nothing composed them. A seam between two passing guards is where a mechanism leaks.
# So the multiple is captured FIRST, its rc read in THIS shell, and the count bumped here.
perf_row() {
    local lbl="$1" mult rc
    [ "${#lbl}" -le 34 ] || lbl="${lbl:0:31}..."
    perf_stamp_once_for_rows
    mult="$(PERF_STAMP_OFF=1 perf_mult "$2" "$3" "$1")"; rc=$?
    [ "$rc" -eq 0 ] || PERF_DARK_CELLS=$(( ${PERF_DARK_CELLS:-0} + 1 ))
    printf '  %-34s %14s %14s   %s\n' "$lbl" "$2" "$3" "$mult"
}
#-----------------------------------------------------------------------------------------------------
# perf_row_or_refuse LABEL REF OURS -- perf_row for callers that today write
#     [ -n "$ref" ] && [ -n "$ours" ] && perf_row "$k" "$ref" "$ours"
# and so DELETE the row when an operand is missing.  A deleted row is shape (3) of the dark cell: the
# grid looks complete because nobody greps for a row that was never printed.  This prints the row.
perf_row_or_refuse() { perf_row "$1" "${2:-<none>}" "${3:-<none>}"; }
#-----------------------------------------------------------------------------------------------------
# perf_load_stamp -- the load this measurement ran under.  ⛔ Not decoration: on this 16-core box two
# runs of identical code differ by up to 2.15x, so a rate without this line is not a reading.
perf_load_stamp() {
    local la cores
    la="$(awk '{print $1}' /proc/loadavg 2>/dev/null)" || la=""
    cores="$(getconf _NPROCESSORS_ONLN 2>/dev/null)" || cores=""
    [ -n "$la" ] && [ -n "$cores" ] || { printf 'load UNKNOWN (⛔ no /proc/loadavg -- treat every rate below as ungraded)'; return 0; }
    awk -v l="$la" -v c="$cores" 'BEGIN{ printf "load %s on %s cores (%.2f/core)", l, c, l/c }'
}
#-----------------------------------------------------------------------------------------------------
# perf_load_guard -- THE LOAD GUARD a timing criterion names on a refusal (ceo CEO-1574, 2026-10-08, the coo's row
# instruments-the-sweep-keeps-a-row-whose-finish-line-refused-on-a-load-guard-instead-of-retiring-it-ceo-1562). A timing-shaped
# refusal -- angles that DISAGREE, a harness that printed no row or no time twin because the kernel ran past its budget -- taken
# while the box is busy is not a measurement of the program (a multiple is not load-invariant, CEO-743), and the zero-base sweep
# retired fourteen live performance rows on exactly that between 10-07 20:16 and 10-08 19:17. Prints one phrase and returns 0 when
# the 1-minute load per core is at or above BENCH_LOAD_GUARD_PER_CORE (default 0.5: on this 16-core box the fleet's builds and the
# coo's fan-out/4 board read 1.2-2.4/core, a quiet box under 0.3); the phrase carries the words "load-guard" the sweep keys on
# (.github/scripts/util_queue_zero_base.py LOAD GUARD). Returns 1 with a plain load stamp when the box is quiet, so the same
# refusal on a quiet box is what it says it is -- the kernel's own, a cannot-measure the sweep retires. A bar's refuse_timing
# wraps it; the precondition refusals (no binary, no oracle, an unknown kernel, a wrong answer) never do.
perf_load_guard() {
    local la cores thr
    la="$(awk '{print $1}' /proc/loadavg 2>/dev/null)" || la=""
    cores="$(getconf _NPROCESSORS_ONLN 2>/dev/null)" || cores=""
    thr="${BENCH_LOAD_GUARD_PER_CORE:-0.5}"
    [ -n "$la" ] && [ -n "$cores" ] || { printf 'load UNKNOWN (no /proc/loadavg)'; return 1; }
    awk -v l="$la" -v c="$cores" -v t="$thr" 'BEGIN{ r = l / c; if (r >= t) { printf "load-guard: load %s on %s cores (%.2f/core) at or above the %s/core guard -- a timing refusal under load is not a measurement (CEO-743)", l, c, r, t; exit 0 } printf "load %s on %s cores (%.2f/core), under the %s/core guard", l, c, r, t; exit 1 }'
}
#-----------------------------------------------------------------------------------------------------
# perf_build_stamp [LIB] -- the build a reading was taken on, RT_OPT beside RT_DIAG, READ BACK and never assumed (ceo CEO-1390,
# 2026-10-01: every bar line and grid header names RT_DIAG beside RT_OPT -- a LABEL, not a configuration; the bars keep grading
# the shipped library). RT_OPT is the RT_OPT this run was handed, else the checkout's own `make buildinfo`. RT_DIAG is read
# from the library's bytes: an RT_DIAG=1 build carries the collector's [ZGC-WALK] telemetry string, and -DRT_DIAG=0 compiles
# it out (measured on both builds of one tree, 2026-10-01). A library that cannot be read stamps RT_DIAG=UNKNOWN, never a guess.
perf_build_stamp() {
    local root lib opt diag
    root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../SCRIP" && pwd)"
    lib="${1:-$root/out/libscrip_rt.so}"
    opt="${RT_OPT:-$(make -s -C "$root" buildinfo 2>/dev/null | sed -n 's/^RT_OPT *: *//p' | sed 's/ *$//')}"
    if [ -r "$lib" ]; then if grep -q -a 'ZGC-WALK' "$lib"; then diag=1; else diag=0; fi; else diag=UNKNOWN; fi
    printf 'RT_OPT=%s RT_DIAG=%s' "${opt:-UNKNOWN}" "$diag"
}
#-----------------------------------------------------------------------------------------------------
# perf_grid_begin AXIS-LINE -- open a grid.  Emits the shared-axes line the FACT RULE requires ONCE,
# with the load stamp welded to it, and resets the dark-cell counter.
perf_grid_begin() {
    PERF_DARK_CELLS=0; PERF_GRID_OPEN=1; PERF_ROWS_STAMPED=1
    printf '  %s\n  measured at %s · %s\n' "${1:-x vs reference (basis and RT_OPT unstated -- ⛔ name them)}" \
           "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$(perf_load_stamp)"
}
#-----------------------------------------------------------------------------------------------------
# perf_grid_end -- close a grid.  ⛔ A GRID REFUSES TO PUBLISH A COLUMN IT COULD NOT FILL: if any cell
# refused, say how many and return 2 so the caller's `set -e` or its own verdict line carries it out.
perf_grid_end() {
    PERF_GRID_OPEN=0; PERF_ROWS_STAMPED=0
    [ "${PERF_DARK_CELLS:-0}" -eq 0 ] && return 0
    printf '  ⛔ GRID REFUSES: %s cell(s) could not measure their subject (named on stderr above); this grid is INCOMPLETE and must not be quoted as a reading\n' \
           "$PERF_DARK_CELLS"
    return 2
}
