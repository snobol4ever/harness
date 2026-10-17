#!/usr/bin/env bash
# util_require_fresh.sh -- THE ONE-LINE STALE-BINARY PREFLIGHT, callable from ANY language.
#
# ⛔ THIS FILE CONTAINS NO STALENESS LOGIC AND MUST NEVER GROW ANY. It is a CALLING CONVENTION over
# gate_require_fresh() in lib_gate.sh (hq_B, SCRIP 4c7253e99) -- source it, call it, translate its exit
# code. Every rule about WHAT counts as stale lives in that one function.
#
# ⛔⭐ WHY A SHIM AND NOT A REIMPLEMENTATION -- this is the whole point of the row (harness-and-ladder-
# runner-refuse-on-a-stale-binary-like-the-artifact-regen-does, ceo -> hq_T 2026-09-04). The staleness
# idea ALREADY existed twice in this repo: gate_require_fresh (lib_gate.sh) and assert_binary_current
# (lib_build_currency.sh). ceo cured the commit-time defect in the second (3d12ca54, "IT IS NOT A
# SUPERSET, IT IS WRONG") and the fix never reached the first, so the identical defect regenerated there
# and had to be cured a SECOND time nine days later (4c7253e99). ⭐ THE LESSON THE ROW ENCODES: the cost
# of a copy is not the duplicated lines, it is that a cure applied to one copy STRENGTHENS EVERYONE'S
# BELIEF THE CLASS IS DEAD while the other copy keeps the bug. corpus_suite_harness.py is Python and
# cannot `source` a bash function -- which is exactly the pressure that produces copy number three. This
# file is the answer to that pressure: Python shells out to the SAME function every bash caller runs.
#
# USAGE (all callers, any language):
#     util_require_fresh.sh [--gate <name>] [--no-behaviour] [<artifact> ...]
# ⛔⭐ THE BUILD-BEHAVIOUR PROBE (gate_require_built_from) RUNS BY DEFAULT, AFTER the mtime check. IT IS A SECOND
# QUESTION, NOT A STRONGER VERSION OF THE FIRST: the mtime check proves the binary is NEWER THAN the sources, the
# probe proves the emitted code HAS NOT MOVED under a tree that has not moved. hq_P's 2026-09-09 build PASSED the
# first and FAILS the second (FINDING-2026-09-09-hq_P: three builds on one commit, two different compilers, two
# SCORE rows published from the bad one). ⭐ DEFAULT-ON HERE RATHER THAN AT 144 CALL SITES because this shim is the
# one choke point every runner already goes through -- and because the class it catches is invisible to the caller
# by construction, so a probe you must remember to ask for is a probe that is off exactly when it is needed.
# MEASURED BEFORE DEFAULTING IT ON, and this is the load-bearing measurement: emission is a PURE FUNCTION OF THE
# TREE -- a 155-object rebuild of an unchanged tree reproduced the signature byte for byte, so a green tree cannot
# be turned red by rebuilding it. MEASURED COST +0.21s on an 0.87s preflight (1.07-1.10 vs 0.85-0.89, three runs each). --no-behaviour opts out; SCRIP_ALLOW_STALE=1 overrides
# it loudly and stops SCORE.md being written, the same declared-override the stale check already uses.
# With no artifacts it checks the two the whole fleet grades: $SCRIP (default <root>/scrip) and
# $RT_DIR/libscrip_rt.so (default <root>/out) -- the .so because a stale runtime is the FALSE-GREEN half
# of this class (row stale-binary-preflight-also-covers-out-libscrip-rt-so, DONE): a 13:37 .so against a
# 14:16 src read `exec_stmt` as still exported when source had already deleted it.
# --gate <name> names the CALLER in the refusal text; without it the refusal says "util_require_fresh",
# which is the shim, not the instrument that refused -- an unactionable verdict of the kind gate_stamp
# already exists to prevent.
#
# ENV (both live in gate_require_fresh, the one authority -- this shim only passes them through):
#   SCRIP_STALE_PROBE_SRC=<file>  ONE extra "newest source" candidate, for fail-once proofs against a SCRATCH file
#                                 (the ceo's DONE-WHEN contract). It can only TIGHTEN the verdict, never loosen it.
#   SCRIP_ALLOW_STALE=1           the deliberate stale run: a stale artifact PASSES with a loud banner on BOTH streams,
#                                 and gate_score_row refuses to write SCORE.md for the rest of that run. A MISSING
#                                 artifact is never overridable -- nothing ran, so nothing was "deliberately" graded.
# EXIT: 0 every named artifact exists and is newer than every tracked src/+Makefile file · 2 REFUSED
# (missing or stale, cause + cure printed). ⛔ NEVER 1: this cannot say "measured and bad", only
# "measured and current" or "I could not establish what you are about to grade" (lib_gate.sh's three
# exit codes). A missing artifact REFUSES here rather than passing-by-skip -- gate_require_fresh itself
# `continue`s past a nonexistent binary because its production caller checks existence one line earlier,
# and a shim whose callers may not is the wrong place to inherit that assumption.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
_gate=""
_behaviour=1
while [ $# -gt 0 ]; do
    case "$1" in
        --gate) shift; _gate="${1:-}";;
        --gate=*) _gate="${1#--gate=}";;
        --behaviour|--behavior) _behaviour=1;;
        --no-behaviour|--no-behavior) _behaviour=0;;
        --) shift; break;;
        -*) echo "⛔ REFUSED-TO-GRADE rc=2: unknown flag '$1'" >&2
            echo "   implemented flags: --gate <name> | --behaviour | --no-behaviour" >&2; exit 2;;
        *) break;;
    esac; shift
done
GATE_NAME="${_gate:-${GATE_NAME:-util_require_fresh}}"; export GATE_NAME
if [ $# -gt 0 ]; then ARTS=("$@"); else ARTS=("${SCRIP:-$ROOT/scrip}" "${RT_DIR:-$ROOT/out}/libscrip_rt.so"); fi
if ! . "$HERE/lib_gate.sh" 2>/dev/null || ! command -v gate_require_fresh >/dev/null 2>&1; then
    echo "⛔ REFUSED-TO-GRADE rc=2 [$GATE_NAME]: lib_gate.sh unavailable or missing gate_require_fresh -- cannot establish what is about to be graded" >&2
    exit 2
fi
for _a in "${ARTS[@]}"; do
    [ -e "$_a" ] && continue
    echo "⛔ REFUSED-TO-GRADE rc=2 [$GATE_NAME]: artifact not built: $_a" >&2
    echo "   cure: cd $ROOT && make        (RULES.md:118 -- an incremental make, pristine only when a refusal keeps firing)" >&2
    exit 2
done
gate_require_fresh "$ROOT" src "${ARTS[@]}"
# ⛔ REACHED ONLY WHEN THE MTIME CHECK PASSED -- gate_require_fresh exits 2 itself on stale, so this is the
# "and it is also the binary this tree describes" half, never a substitute for it.
if [ "$_behaviour" = 1 ]; then
    gate_require_built_from "$ROOT" "${SCRIP:-$ROOT/scrip}" || exit 2
fi
