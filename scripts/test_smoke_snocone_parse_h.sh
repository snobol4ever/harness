#!/usr/bin/env bash
# test_smoke_snocone_parse_h.sh — GOAL-SNOCONE-LANG-SPACE LS-4.h gate
#
# Builds and runs test_snocone_parse_h, which verifies the LS-4.h
# grammar additions: function/return/freturn/nreturn.
#
# Lowering shapes verified:
#
#   function NAME(args) { body }
#       DEFINE('NAME(args)')   (bare-expr AST_FNC)
#       :(NAME_end)            (skip-the-body uncond goto)
#       NAME    <body>         (body stmts; entry-point label)
#       NAME_end               (label pad)
#
#   return E ;                 ->   <fn> = E :(RETURN)   (assignment+goto)
#   return ;                   ->   :(RETURN)
#   freturn ;                  ->   :(FRETURN)
#   nreturn ;                  ->   :(NRETURN)
#
# Side-channel test — the LS-4.h parser is not yet wired into scrip's
# production driver path (that happens at LS-4.j).
#
# AUTHORS: Lon Jones Cherryholmes · Claude Sonnet
# Commit identity: LCherryholmes / lcherryh@yahoo.com  (RULES.md)

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$(cd "$HERE/../../SCRIP" && pwd)"
TEST="$SCRIP/test/parser/snocone/test_snocone_parse_h.c"
SRCDIR="$SCRIP/src/parsers/snocone"
BIN="/tmp/test_snocone_parse_h"

cc -Wall -o "$BIN" \
    "$TEST" \
    "$SRCDIR/snocone_parse.tab.c" \
    "$SRCDIR/snocone_lex.c" \
    -I "$SRCDIR" \
    -I "$SCRIP/src/parsers/snobol4" \
    -I "$SCRIP/src"

"$BIN"
