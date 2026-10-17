#!/usr/bin/env bash
# test_smoke_snocone_parse_f.sh — GOAL-SNOCONE-LANG-SPACE LS-4.f gate
#
# Builds and runs test_snocone_parse_f, which verifies that the new
# Bison-based Snocone parser handles the LS-4.f addition: control flow
# `if`/`else`/`while` parses and lowers to a flat SPITBOL-style statement
# sequence with :F/:(uncond) goto fields and synthetic labels.
#
# Lowering shapes verified:
#
#   if (C) S          -> cond:F(Lend) ; <S> ; Lend
#   if (C) S1 else S2 -> cond:F(Lelse); <S1>; :(Lend); Lelse; <S2>; Lend
#   while (C) S       -> Ltop; cond:F(Lend); <S>; :(Ltop); Lend
#
# Pascal/Algol balanced grammar (matched_stmt / unmatched_stmt) keeps
# the dangling-else unambiguous and Bison conflict-free.
#
# Side-channel test — the LS-4.f parser is not yet wired into scrip's
# production driver path (that happens at LS-4.j).
#
# AUTHORS: Lon Jones Cherryholmes · Claude Sonnet
# Commit identity: LCherryholmes / lcherryh@yahoo.com  (RULES.md)

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$(cd "$HERE/../../SCRIP" && pwd)"
TEST="$SCRIP/test/parser/snocone/test_snocone_parse_f.c"
SRCDIR="$SCRIP/src/parsers/snocone"
BIN="/tmp/test_snocone_parse_f"

cc -Wall -o "$BIN" \
    "$TEST" \
    "$SRCDIR/snocone_parse.tab.c" \
    "$SRCDIR/snocone_lex.c" \
    -I "$SRCDIR" \
    -I "$SCRIP/src/parsers/snobol4" \
    -I "$SCRIP/src"

"$BIN"
