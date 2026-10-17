#!/usr/bin/env bash
# test_smoke_snocone_parse_a.sh — GOAL-SNOCONE-LANG-SPACE LS-4.a gate
#
# Builds and runs test_snocone_parse_a, which verifies that the new
# Bison-based Snocone parser (snocone_parse.y, snocone_parse.tab.c) produces the
# expected IR shape for atoms + arithmetic + parens + assignment +
# `;`-terminated statements.
#
# Gate: 35/35 PASS, exits 0.
#
# This is a side-channel test — the LS-4.a parser is not yet wired into
# scrip's production driver path (that happens at LS-4.j).  Until then,
# the new parser is exercised through this standalone test against the
# IR helpers and the FSM lexer.
#
# AUTHORS: Lon Jones Cherryholmes · Claude Sonnet
# Commit identity: LCherryholmes / lcherryh@yahoo.com  (RULES.md)

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$(cd "$HERE/../../SCRIP" && pwd)"
TEST="$SCRIP/test/parser/snocone/test_snocone_parse_a.c"
SRCDIR="$SCRIP/src/parsers/snocone"
BIN="/tmp/test_snocone_parse_a"

cc -Wall -o "$BIN" \
    "$TEST" \
    "$SRCDIR/snocone_parse.tab.c" \
    "$SRCDIR/snocone_lex.c" \
    -I "$SRCDIR" \
    -I "$SCRIP/src/parsers/snobol4" \
    -I "$SCRIP/src"

"$BIN"
