#!/usr/bin/env bash
# test_smoke_snocone_parse_g.sh — GOAL-SNOCONE-LANG-SPACE LS-4.g gate
#
# Builds and runs test_snocone_parse_g, which verifies that the new
# Bison-based Snocone parser handles the LS-4.g addition: do/while,
# do/until, and for loop control structures.
#
# Lowering shapes verified:
#
#   do { S } while (C)  ->  Ltop ; <S> ; C:S(Ltop) ; Lend
#   do { S } until (C)  ->  Ltop ; <S> ; C:F(Ltop) ; Lend
#   for (I; C; T) S     ->  <I> ; Ltop ; C:F(Lend) ; <S> ; <T> ; :(Ltop) ; Lend
#
# Note: do/while and do/until require a brace block body (no bare stmt).
# This is a grammar disambiguation choice — see snocone_parse.y do_body
# non-terminal for rationale.
#
# Side-channel test — the LS-4.g parser is not yet wired into scrip's
# production driver path (that happens at LS-4.j).
#
# AUTHORS: Lon Jones Cherryholmes · Claude Sonnet
# Commit identity: LCherryholmes / lcherryh@yahoo.com  (RULES.md)

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$(cd "$HERE/../../SCRIP" && pwd)"
TEST="$SCRIP/test/parser/snocone/test_snocone_parse_g.c"
SRCDIR="$SCRIP/src/parsers/snocone"
BIN="/tmp/test_snocone_parse_g"

cc -Wall -o "$BIN" \
    "$TEST" \
    "$SRCDIR/snocone_parse.tab.c" \
    "$SRCDIR/snocone_lex.c" \
    -I "$SRCDIR" \
    -I "$SCRIP/src/parsers/snobol4" \
    -I "$SCRIP/src"

"$BIN"
