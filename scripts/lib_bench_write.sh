#!/usr/bin/env bash
# lib_bench_write.sh -- ONE CONVENTION FOR WHEN A BENCH RUNNER PUBLISHES ITS SUITE ROW (ceo CEO-1302 (a), 2026-09-27, on the coo's ask of
# COO-197: six of the seven bench runners wrote only under --write and Pascal's wrote unconditionally, so whether a pass published its
# row depended on which runner it was).
#
# THE RULE, the ceo's: every bench runner publishes its row BY DEFAULT on a WHOLE-POPULATION pass, and a FILTERED OR SUBSET pass NEVER
# writes (the FACT RULE of 2026-09-03: any suite run rewrites its row). WHO may write is not decided here: util_score_row.py admits the
# seat MODE's LANES: line names for the language and refuses every other, so a default write by the wrong seat is refused there, loudly.
#
# bench_row_writes <published population dir> <this pass's population dir> <subset words> <no-write flag>
#   prints "1 <why>" when the pass publishes, "0 <why>" when it does not:
#     --no-write was given                           -> 0 (an explicit opt-out: a dry look at the table)
#     the pass named kernels (a subset)              -> 0 (a filtered or subset pass never writes)
#     the pass graded a different population dir     -> 0 (a fixture, a scratch tree or another checkout is not the published row)
#     otherwise                                      -> 1 (the whole published population)
#   A population directory that does not resolve is not the published one: it reads 0, never 1.
bench_row_writes() {
    local def="$1" pop="$2" subset="${3:-}" nowrite="${4:-0}" d p
    [ "$nowrite" = 1 ] && { echo "0 --no-write was given"; return 0; }
    subset="$(printf '%s' "$subset" | xargs 2>/dev/null)"
    [ -n "$subset" ] && { echo "0 a subset pass (${subset}) -- a filtered or subset pass never writes (CEO-1302 (a))"; return 0; }
    d="$(cd "$def" 2>/dev/null && pwd -P)"; p="$(cd "$pop" 2>/dev/null && pwd -P)"
    [ -n "$d" ] && [ -n "$p" ] && [ "$d" = "$p" ] || { echo "0 this pass graded $pop, not the published population $def"; return 0; }
    echo "1 the whole published population $def (CEO-1302 (a): a whole-population pass publishes by default)"
}
