#!/usr/bin/env bash
# lib_ir_measure.sh -- ⭐ THE ONE AUTHORITY for TAKING a callgrind Ir reading.
#
# THE RULE IT IMPLEMENTS (hq_P 2026-09-10, on hq_U's ask that this shape become the rule for EVERY Ir
# cell and not just the one that caught it; FINDING-2026-09-10-hq_P-both-icon-modes-segv-under-valgrind-
# in-gc-zeta-frame-while-running-clean-natively.md):
#
#   ⛔⭐ AN Ir READING FROM A RUN THAT DIED IS NOT A MEASUREMENT, AND IT MUST NOT LOOK LIKE ONE.
#   callgrind counts instructions whatever the client does, so a program that SEGVs, parse-errors or
#   is killed by a timeout still hands back a perfectly well-formed PROGRAM TOTALS -- the instruction
#   count of its dying path.  It is the same shape as every honest cell on the board and nothing in
#   the output says otherwise.  ⭐ A CRASH THAT ANNOUNCES ITSELF AS A NUMBER IS STRICTLY WORSE THAN
#   ONE THAT ANNOUNCES ITSELF AS A HOLE (hq_U, 2026-09-10).
#
# ⛔ AND THE REASON IS *NOT* NON-DETERMINISM -- that argument is weaker than it looks and this file
# would be wrong to rest on it.  MEASURED hq_P 2026-09-10 with a C program that sums 200,000 ints and
# then writes through a null pointer: three crashed runs under a FIXED argv+env read 2,157,204 Ir
# THREE TIMES, byte-identical.  A crashed reading can be perfectly reproducible.  The Icon
# concat_table case that opened this row DID disagree run to run (330,078,095 vs 330,079,909), but
# that is a property of THAT program -- its fault point moves with heap and GC state -- not of dead
# runs in general.  ⭐ THE REAL ARGUMENT IS SIMPLER AND ALWAYS HOLDS: the number counts a path that
# did not do the work, so it does not answer the question the column asks.  Reproducing it exactly
# only makes it a reliable answer to the wrong question.
#
# ⛔ THREE OUTCOMES, NEVER TWO.  "not measured" and "measured and thrown away" are different facts and
# a board that prints one `NA` for both has destroyed the difference.  The first cut of the Icon
# kernel harness printed a bare NA for a SIGSEGV and no warning at all, because the status was carried
# out of the measuring function in a global that could not survive the command substitution calling it.
# ⭐ SO THE STATUS RIDES IN THE VALUE, never in a global and never in a return code that a `$( )` eats.
#
# USAGE
#   . "$(dirname "$0")/lib_ir_measure.sh"        # a caller that cannot load this REFUSES, never
#                                                #   falls back to a private extraction (lib_perf_fmt law)
#   v="$(ir_measure ./prog arg ...)"             # runs it under callgrind; NEVER dies, NEVER unset
#   ir_is_number "$v" && use "$v"                # the only sanctioned way to ask "may I grade this?"
#   ir_cell "$v"                                 # -> "2157204" | "REFUSED(rc=139)" | "NOT-MEASURED(valgrind-absent)"
#   ir_reason "$v"                               # -> the one-line why, for stderr; empty for a good reading
#
#   IR_TMO       seconds for the whole callgrind run (default 600 -- callgrind is ~50x native)
#   IR_OUT       optional path to keep the callgrind.out file at; default is a temp that is removed
#   IR_PROG_OUT  optional path to keep the CLIENT's stdout at   \  ⛔ USE THESE, never a `>` on the call:
#   IR_PROG_ERR  optional path to keep the CLIENT's stderr at   /  the reading is this function's OWN stdout,
#                so `v="$(ir_measure ./p > run.out)"` sends the READING into run.out and comes back empty.
#   VALGRIND     the valgrind binary to run (default: valgrind on PATH). An instrument's no-valgrind arm points it at a path that
#                does not exist and must read NOMEASURE:valgrind-absent through THIS function, never a private probe of its own.
#   IR_VG_FLAGS  extra valgrind flags, word-split (e.g. --smc-check=all-non-file for runtime-emitted blobs).
#                ⛔ It exists so a caller with a special need still comes through here instead of running its
#                own callgrind -- a private call site is exactly what this file was written to end.
#
# THE VALUE GRAMMAR (stdout of ir_measure, one line, always exactly one of):
#   <digits>                 a clean reading: the client exited 0 and PROGRAM TOTALS parsed
#   RC:<n>                   the client RAN AND DIED with status n (139 = SIGSEGV, 124 = timeout kill)
#   NOMEASURE:<reason>       the INSTRUMENT could not read: valgrind-absent, annotate-absent, no-totals
ir_have_valgrind() { command -v "${VALGRIND:-valgrind}" >/dev/null 2>&1 && command -v callgrind_annotate >/dev/null 2>&1; }
# ir_measure ARGV... -- the whole rule, in one function.  Writes exactly one line to stdout and returns 0.
ir_measure() {
    [ $# -ge 1 ] || { echo "NOMEASURE:no-argv"; return 0; }
    command -v "${VALGRIND:-valgrind}" >/dev/null 2>&1 || { echo "NOMEASURE:valgrind-absent"; return 0; }
    command -v callgrind_annotate >/dev/null 2>&1 || { echo "NOMEASURE:annotate-absent"; return 0; }
    local d cg rc ir
    d="$(mktemp -d "${TMPDIR:-/tmp}/irm.XXXXXX")" || { echo "NOMEASURE:no-workdir"; return 0; }
    cg="${IR_OUT:-$d/cg.out}"
    timeout -k 5 "${IR_TMO:-600}" "${VALGRIND:-valgrind}" --tool=callgrind ${IR_VG_FLAGS:-} --callgrind-out-file="$cg" "$@" >"${IR_PROG_OUT:-$d/prog.out}" 2>"${IR_PROG_ERR:-$d/vg.log}"
    rc=$?
    if [ "$rc" -ne 0 ]; then rm -rf "$d"; echo "RC:$rc"; return 0; fi
    ir="$(ir_reading 0 "$cg")"
    [ -n "${IR_OUT:-}" ] || rm -rf "$d"
    echo "$ir"
}
# ir_reading RC CG -- the reading of a callgrind run the CALLER made and watched itself (a background run under an RSS watchdog, which
#   ir_measure's foreground timeout cannot be): RC is the client's exit status as the caller's own `wait` returned it, CG the
#   --callgrind-out-file. One line in the grammar above, the same one ir_measure prints after its own run -- ir_measure calls this --
#   so a watched run and a plain one can never be read two ways (the coo 2026-10-01, util_parser_phase_profile.sh, named by ARM 2 of
#   test_gate_ir_reading_voids_a_dead_run.sh for dropping the status its `wait` returned).
ir_reading() {
    local rc="${1:-}" cg="${2:-}" ir
    case "$rc" in ''|*[!0-9]*) echo "NOMEASURE:no-status"; return 0 ;; esac
    [ "$rc" -eq 0 ] || { echo "RC:$rc"; return 0; }
    command -v callgrind_annotate >/dev/null 2>&1 || { echo "NOMEASURE:annotate-absent"; return 0; }
    ir="$(callgrind_annotate "$cg" 2>/dev/null | awk '/PROGRAM TOTALS/{gsub(/,/,"",$1); print $1; exit}')"
    case "$ir" in ''|*[!0-9]*) echo "NOMEASURE:no-totals" ;; *) echo "$ir" ;; esac
}
# ir_is_number VALUE -- rc 0 only for a reading a caller may grade, ratio or ratchet against.
ir_is_number() { case "${1:-}" in ''|*[!0-9]*) return 1 ;; *) return 0 ;; esac; }
# ir_cell VALUE -- the DISPLAY form.  A dead run and an unmeasured one print differently, on purpose.
ir_cell() {
    case "${1:-}" in
        RC:*)        echo "REFUSED(rc=${1#RC:})" ;;
        NOMEASURE:*) echo "NOT-MEASURED(${1#NOMEASURE:})" ;;
        ''|*[!0-9]*) echo "NOT-MEASURED(bad-value)" ;;
        *)           echo "$1" ;;
    esac
}
# ir_reason VALUE -- the sentence that goes beside the cell so a reader is never left to guess.  Empty on a good reading.
ir_reason() {
    case "${1:-}" in
        RC:124)      echo "the run was KILLED by the IR_TMO timeout -- callgrind still printed a total, but a count of a partial run is not a measurement, so it is voided" ;;
        RC:*)        echo "the run exited rc=${1#RC:} -- callgrind still printed a total, but a count from a process that died counts a path that never did the work, so it is voided, not recorded" ;;
        NOMEASURE:*) echo "the instrument could not read at all (${1#NOMEASURE:}) -- this cell is EMPTY BECAUSE IT WAS NOT MEASURED, which is a different fact from a voided one" ;;
        ''|*[!0-9]*) echo "the measuring call returned something that is not a reading -- treat as UNPROVEN" ;;
        *)           echo "" ;;
    esac
}
