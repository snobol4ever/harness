#!/usr/bin/env bash
# lib_progress.sh -- the shell face of THE PROGRESS DATABASE APPEND. ONE writer: util_progress_append.py (its
# docstring is the contract; the table is /home/resources/progress/results.tsv, the rule is progress/README.md,
# CEO-319 / CEO-331: every suite run by any session appends its per-program rows in the sitting it rewrites its
# SCORE.md cell). Source this beside lib_gate.sh; every function returns the writer's rc (0 written or
# S4E_PROGRESS_OFF, 2 refused loudly) and NEVER swallows it -- the caller decides whether a run that could not
# record is a landing verdict (it is not).
#
#   progress_append <class> <suite> <lang> <program> <mode> <outcome> [secs] [note]
#   progress_append_rows_tsv <file>                       # class suite lang program mode outcome [secs [note]] per line
#   progress_append_results_tsv <suite> <lang> <file>     # scorecard_snobol4.sh results.tsv (suite program m3 m4 t3 t4 note)
#   progress_append_triangulation <lang> <file>           # bench_triangulate_* TSV (kernel engine a1 a2 ratio verdict ...)
#   progress_context                                      # prints scrip= corpus= measurer= db= off= -- what a row would carry
#   t0="$(progress_clock)"; ...run...; s="$(progress_secs_since "$t0")"   # the program's own wall seconds, for the row's secs field
#
# Control arms: S4E_PROGRESS_DB=<path> (gates point it at a scratch file), S4E_PROGRESS_OFF=1 (says so on stderr).
_PROGRESS_PY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_progress_append.py"
# ⛔ A GRADED RUN'S TIMEOUT IS "$TIMEOUT_RETRY", NEVER A BARE timeout (ceo CEO-1335; the coo 2026-10-09): util_timeout_retry.sh takes
# timeout's own argv, and a timeout while the 1-minute load exceeds the cores re-runs the command once -- the reading measured the
# scheduler. Its stamp lands in S4E_TIMEOUT_STAMP (one file per runner process) and the writer attaches it to the row it names;
# a runner names the unit it is grading with S4E_TIMEOUT_KEY at the head of its loop.
export TIMEOUT_RETRY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_timeout_retry.sh"
export S4E_TIMEOUT_STAMP="${S4E_TIMEOUT_STAMP:-${TMPDIR:-/tmp}/s4e-timeout-stamp.$$}"
_progress_run() {
    [ -f "$_PROGRESS_PY" ] || { echo "⛔ PROGRESS APPEND REFUSES(2): writer missing at $_PROGRESS_PY" >&2; return 2; }
    python3 "$_PROGRESS_PY" "$@"
}
# progress_config_of_env -- the configuration this process's runs exercise: the GC axis set in its own environment, read through
# util_progress_append.gc_axis_env (the ONE definition), else `shipped`. THE WRITER GUESSES NOTHING (CEO-812 on the record), so a
# runner that sets no axis per child says so itself: PROGRESS_CONFIG="$(progress_config_of_env)" once, and every progress_append
# below declares it. Without it a board's rows read `undeclared` -- measured: the coo's Arizona board of 2026-10-01T19:04Z wrote 238
# undeclared rows after the lane had declared `shipped`, and test_gate_progress_configuration_declarations_do_not_regress read red.
progress_config_of_env() {
    python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import util_progress_append as p; a = p.gc_axis_env(); print(",".join("%s=%s" % kv for kv in a.items()) if a else "shipped")' "$(dirname "$_PROGRESS_PY")"
}
progress_append() {
    [ $# -ge 6 ] || { echo "⛔ PROGRESS APPEND REFUSES(2): progress_append needs class suite lang program mode outcome [secs] [note], got $# arg(s)" >&2; return 2; }
    _progress_run append --class "$1" --suite "$2" --lang "$3" --program "$4" --mode "$5" --outcome "$6" --secs "${7:-0}" --note "${8:-}" ${PROGRESS_CONFIG:+--config "$PROGRESS_CONFIG"}
}
progress_append_rows_tsv() { _progress_run rows-tsv "$1"; }
progress_append_results_tsv() { _progress_run results-tsv --suite "$1" --lang "$2" "$3"; }
progress_append_triangulation() { _progress_run triangulation --lang "$1" "$2"; }
progress_context() { _progress_run context; }
# ⭐ THE PROGRAM'S OWN SECONDS (ceo CEO-1676 row (c); ARCH-SUITE-PARTITIONS.md section 4 (c)): the secs column read 0 for nearly every
# suite (snobol4-rungs 0 of 4028 rows, swi 0 of 5870), so no partition could be sized by time. A runner reads progress_clock before a
# program's run in a mode and progress_secs_since after it, and passes that as the row's secs; a row that ran nothing keeps 0.
# $EPOCHREALTIME: no fork per program (its decimal mark follows the locale, so a comma is read as a point).
progress_clock() { local t="${EPOCHREALTIME:-$(date +%s.%N)}"; printf '%s' "${t/,/.}"; }
progress_secs_since() { awk -v a="$1" -v b="$(progress_clock)" 'BEGIN { d = b - a; if (d < 0) d = 0; printf "%.3f", d }'; }
# progress_row_secs <mode> -- the secs a runner's own row helper writes: ROW_S3 / ROW_S4, which the runner resets to 0 at the head of each
# program and sets from progress_clock around each mode's run, so a row written before (or instead of) a run -- UNGRADED, OUTSIDE -- reads 0.
progress_row_secs() { case "$1" in m3) printf '%s' "${ROW_S3:-0}";; m4) printf '%s' "${ROW_S4:-0}";; *) printf 0;; esac; }
# progress_secs_sum <secs>... -- one row's seconds made of parts (a mode-4 row: the compile shared before the modes plus its own runs).
progress_secs_sum() { awk 'BEGIN { s = 0; for (i = 1; i < ARGC; i++) s += ARGV[i]; printf "%.3f", s }' "$@"; }
