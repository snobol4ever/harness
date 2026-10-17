#!/usr/bin/env bash
# test_gate_parser_raku_sc_nest8_witness.sh -- THE WITNESS: bootstrap/parser_raku.sc compiled to a mode-4 binary dies in emitted
# code (SIGSEGV, pc 3, inside a match_assign_cond box) on ../harness/scripts/fixtures/parser_sc/raku_nest8.raku -- eight nested while loops
# with `next if` guards -- while seven nested loops parse; the same file parses in the C parser (ceo 2026-09-30, CEO-1374).
# RED while the defect stands: rc 1 when the binary dies (rc >= 128) or prints no tree; rc 0 when it prints a tree; rc 2 when
# the grammar cannot be built.  The build is util_parser_sc_grade.sh's (chain + parser, transpile, compile, link).
set -u
here=$(cd "$(dirname "$0")" && pwd); W=$(cd "$here/../../SCRIP" && pwd)
OUT="${OUT:-/tmp/si_parser_sc_witness_$(id -u)}"; mkdir -p "$OUT" || exit 2
LIST="$OUT/nest8.list"; echo "$W/scripts/fixtures/parser_sc/raku_nest8.raku" > "$LIST"
printf '%s\n' "== $W/scripts/fixtures/parser_sc/raku_nest8.raku" > "$OUT/empty.dump"
CHUNK=1 SHOW=0 bash "$here/util_parser_sc_grade.sh" raku "$LIST" "$OUT/empty.dump" "$OUT" > "$OUT/grade.txt" 2>&1; g=$?
[ "$g" -eq 2 ] && { echo "GATE REFUSE(2) [parser_raku_sc_nest8_witness]: $(head -1 "$OUT/grade.txt" | cut -c1-200)"; exit 2; }
if grep -q 'run_rc=1[2-9][0-9]' "$OUT/grade.txt" || ! grep -q '(TT_STMT' "$OUT/raku.sc.dump" 2>/dev/null; then
    echo "GATE RED(1) [parser_raku_sc_nest8_witness]: the compiled grammar dies or prints no tree on raku_nest8.raku -- $(head -1 "$OUT/grade.txt" | cut -c1-160)"; exit 1
fi
echo "GATE PASS(0) [parser_raku_sc_nest8_witness]: the compiled grammar prints a tree for raku_nest8.raku"; exit 0
