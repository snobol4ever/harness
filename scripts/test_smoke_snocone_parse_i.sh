#!/usr/bin/env bash
# test_smoke_snocone_parse_i.sh — GOAL-SNOCONE-LANG-SPACE LS-4.i gate
#
# Builds and runs test_snocone_parse_i, which verifies the LS-4.i
# grammar additions: goto/label (LS-4.i.1), break/continue (LS-4.i.2),
# switch/case/default (LS-4.i.3), alt-eval (LS-4.i.4), struct (LS-4.i.5).
#
# Currently exercises LS-4.i.1: goto LABEL; and LABEL: stmt prefix.
#
# Lowering shapes verified:
#
#   goto NAME ;        ->   :(NAME)        (bare goto-uncond stmt)
#   NAME : stmt        ->   NAME           (label pad)
#                          <stmts of stmt>
#
# Side-channel test — the LS-4.i parser is not yet wired into scrip's
# production driver path (that happens at LS-4.j).
#
# AUTHORS: Lon Jones Cherryholmes · Claude Sonnet
# Commit identity: LCherryholmes / lcherryh@yahoo.com  (RULES.md)

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$(cd "$HERE/../../SCRIP" && pwd)"
TEST="$SCRIP/test/parser/snocone/test_snocone_parse_i.c"
SRCDIR="$SCRIP/src/parsers/snocone"
BIN="/tmp/test_snocone_parse_i"

cc -Wall -o "$BIN" \
    "$TEST" \
    "$SRCDIR/snocone_parse.tab.c" \
    "$SRCDIR/snocone_lex.c" \
    -I "$SRCDIR" \
    -I "$SCRIP/src/parsers/snobol4" \
    -I "$SCRIP/src"

"$BIN"
