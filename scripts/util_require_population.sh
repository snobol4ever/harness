#!/usr/bin/env bash
# util_require_population.sh -- THE ONE-LINE POPULATION-FLOOR PREFLIGHT, callable from ANY language.
#
# ⛔ THIS FILE CONTAINS NO FLOOR LOGIC AND MUST NEVER GROW ANY. It is a CALLING CONVENTION over
# gate_floor() in lib_gate.sh -- source it, call it, translate its exit code. Mirrors
# util_require_fresh.sh's shape exactly (same flag parsing, same three-exit-code contract), because
# it is the same lesson applied to a different verdict-shaped defect (row every-board-wrapper-
# refuses-on-a-zero-population-instead-of-passing-vacuously, hq_T 2026-09-04).
#
# THE DEFECT THIS EXISTS TO KILL: a wrapper's verdict is a comparison against 0 over a count it never
# proved non-zero -- an upstream refusal (contention, an unbuilt oracle, an empty glob after a family
# was consolidated into a suite pair) leaves an empty or truncated result file behind, and "no
# failures" reads identically to "nothing graded". WITNESSED TWICE IN ONE HOUR, INDEPENDENTLY, IN ONE
# FILE (test_snobol4_gimpel_suite.sh): the concurrent-board registry declined, correctly, and the
# wrapper turned that refusal into a green board.
#
# USAGE (all callers, any language):
#     util_require_population.sh [--gate <name>] <count> <floor> <label...>
# <count> and <floor> are integers; <label> (the rest of argv, joined with spaces) names what was
# counted AND should carry the upstream context (total/unscored/upstream rc) so the refusal is
# actionable, not just "zero" -- see gate_floor()'s own message shape in lib_gate.sh.
# --gate <name> names the CALLER in the refusal text; without it the refusal says
# "util_require_population", which is the shim, not the instrument that refused.
#
# EXIT: 0 count >= floor · 2 REFUSED (count < floor, cause named). ⛔ NEVER 1: this cannot say
# "measured and bad", only "measured enough to have an opinion" or "could not" (lib_gate.sh's three
# exit codes) -- the CALLER's own comparison, run only after this passes, is what may say 1.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_gate=""
while [ $# -gt 0 ]; do
    case "$1" in
        --gate) shift; _gate="${1:-}";;
        --gate=*) _gate="${1#--gate=}";;
        --) shift; break;;
        -*) echo "⛔ REFUSED-TO-GRADE rc=2: unknown flag '$1'" >&2
            echo "   implemented flags: --gate <name>" >&2; exit 2;;
        *) break;;
    esac; shift
done
GATE_NAME="${_gate:-${GATE_NAME:-util_require_population}}"; export GATE_NAME
if [ $# -lt 2 ]; then
    echo "⛔ REFUSED-TO-GRADE rc=2 [$GATE_NAME]: usage: util_require_population.sh [--gate name] <count> <floor> <label...>" >&2
    exit 2
fi
case "$1" in *[!0-9]*|"") echo "⛔ REFUSED-TO-GRADE rc=2 [$GATE_NAME]: <count> must be a non-negative integer, got '$1'" >&2; exit 2;; esac
case "$2" in *[!0-9]*|"") echo "⛔ REFUSED-TO-GRADE rc=2 [$GATE_NAME]: <floor> must be a non-negative integer, got '$2'" >&2; exit 2;; esac
_count="$1"; _floor="$2"; shift 2
_label="${*:-rows}"
if ! . "$HERE/lib_gate.sh" 2>/dev/null || ! command -v gate_floor >/dev/null 2>&1; then
    echo "⛔ REFUSED-TO-GRADE rc=2 [$GATE_NAME]: lib_gate.sh unavailable or missing gate_floor -- cannot establish what is about to be graded" >&2
    exit 2
fi
gate_floor "$_count" "$_floor" "$_label"
