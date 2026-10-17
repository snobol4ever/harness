#!/usr/bin/env bash
# run_scrip_parser.sh — run a SCRIP parser_<lang>.sc driver against a source file.
# Load order mirrors beauty.sno -INCLUDE chain exactly (beauty.sno is the source of truth).
# Usage: run_scrip_parser.sh <lang> [source_file]
#   lang: snobol4 | snocone | icon | prolog | raku | rebus | pascal
#   source_file: path to source file; omit to read stdin
# AUTHORS: Lon Jones Cherryholmes · Claude Sonnet 4.6  DATE: 2026-05-12
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${SCRIP:-$HERE/../../SCRIP/scrip}"
SD="${SD:-$S4E/SCRIP/bootstrap}"

LANG="${1:-snobol4}"
SRC="${2:-}"

if [ ! -f "$SCRIP" ]; then echo "REFUSE scrip not found: $SCRIP" >&2; exit 2; fi
if [ ! -d "$SD" ];   then echo "REFUSE SCRIP/bootstrap not found: $SD" >&2; exit 2; fi

# Shared runtime — beauty.sno INCLUDE order:
#   global, case, assign, match, counter, stack, tree, ShiftReduce,
#   TDump, Gen, Qize, semantic, omega, trace
# SL-2 (2026-05-17): qize.sc is re-included.  The "Append-through-function-parameter"
# theory recorded earlier was a misdiagnosis — the actual bug was a use-after-free
# in snocone_parse.y's sc_finalize_if_else_pst, triggered by any function with
# three or more chained `else if` clauses (qize.sc's Qize fits that shape).
# Fixed by giving each `if_head` its own heap-allocated IfHead snapshot instead of
# sharing a single ScParseState slot that nested ifs clobbered.
RUNTIME=(
    "$SD/global.sc"
    "$SD/case.sc"
    "$SD/assign.sc"
    "$SD/match.sc"
    "$SD/counter.sc"
    "$SD/stack.sc"
    "$SD/tree.sc"
    "$SD/ShiftReduce.sc"
    "$SD/tdump.sc"
    "$SD/gen.sc"
    "$SD/qize.sc"
    "$SD/semantic.sc"
    "$SD/omega.sc"
    "$SD/trace.sc"
)

# PST-RB-5e (2026-05-17): lower.sc and lower_driver.sc were deleted from the parser source tree (now SCRIP/bootstrap)
# and will be re-translated from lower.c when that file stabilizes.  The PST-era
# parsers (snobol4, snocone, icon, prolog, raku, rebus) now emit pure AST via TDump
# and need no SCRIP-side lowering pass.
LOWER=()

DRIVER="$SD/parser_${LANG}.sc"
if [ ! -f "$DRIVER" ]; then echo "REFUSE no driver: $DRIVER" >&2; exit 2; fi

# Load language-specific helpers (defined outside parser file per PST rules)
HELPERS=()
if [ -f "$SD/${LANG}_helpers.sc" ]; then
    HELPERS=("$SD/${LANG}_helpers.sc")
fi

# hq_snocone 2026-09-27: scrip takes the FIRST positional as the program and the rest as ITS argv, so the chain must be
# ONE file -- passed separately, every source printed nothing and exited 0 (the census and the five-arm runner already
# concatenate; this instrument did not). A missing binary or driver is COULD-NOT-MEASURE, rc=2, never a SKIP that exits 0.
# The chain runs at the heap and stack bootstrap/parser_<lang>.heap and .stack declare (ceo CEO-1353, RULES.md clause 8 (g)(4): a
# runner passes the unit's declaration and types no size of its own), read by lib_declared_arena.sh -- an undeclared chain is refused.
. "$HERE/lib_declared_arena.sh" || { echo "REFUSE cannot load lib_declared_arena.sh" >&2; exit 2; }
SW="$(declared_switches_beside "$DRIVER")" || exit 2
[ -n "$SW" ] || { echo "REFUSE $DRIVER declares no heap or stack (bootstrap/parser_${LANG}.heap, .stack)" >&2; exit 2; }
ONE="$(mktemp "${TMPDIR:-/tmp}/run_scrip_parser.${LANG}.XXXXXX.sc")"
trap 'rm -f "$ONE"' EXIT
cat "${RUNTIME[@]}" "${LOWER[@]}" "${HELPERS[@]}" "$DRIVER" > "$ONE"
if [ -n "$SRC" ]; then
    timeout -k 5 30 "$SCRIP" --run $SW "$ONE" < "$SRC"
else
    timeout -k 5 30 "$SCRIP" --run $SW "$ONE"
fi
