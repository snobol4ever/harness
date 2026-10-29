#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_icn_scrip_does_not_preprocess.sh -- ICON'S PREPROCESSOR RUNS ON THE FLY, ONE STAGE, AS ARIZONA'S DOES (Lon 2026-10-14, in-chat to
# hq_icon, verbatim: "Keep the Arizona Icon's pre-processing behavior if that is done on-the-fly and not done in two stages. Which is it?";
# ceo CEO-1702 amends RULES.md FACT RULE SCRIP DOES NOT PREPROCESS for Icon; this file's name is kept so the blocking set and the row
# icon-gate-scrip-does-not-preprocess-...-ceo-1663 keep their handle). Arizona's lexer pulls every character through the preprocessor
# (icont common/yylex.h nextchar() -> common/ipp.c ppch(), one line at a time): no expanded copy of the program exists, and a directive
# is acted on when the lexer reaches it, so diagnostics come out in SOURCE ORDER. A two-stage front end expands the whole source first
# and reports every directive error before the lexer has read line 1 -- that is the observable this gate grades, against the live oracle.
# The CEO-1366 arms this file carried (no ipp in icon_lex.c, scrip -E refuses, a $define is a parse error) are WITHDRAWN by CEO-1702.
#
# FOUR ARMS, every expectation read from icont/iconx at run time, none typed here:
#   1 SOURCE ORDER: a syntax error on line 2 before a $error on line 4. icont's first diagnostic names line 2; SCRIP's first must name
#     the same line, in mode 3 and at mode 4's compile. MEASURED RED on the two-stage tree (SCRIP 9d80e90bf-era icon_lex.c, icn_lex_init
#     running icn_pp_text over the whole source): SCRIP's first line named line 4 and the syntax error was never reached.
#   2 THE MIRROR: the $error on line 3 before a syntax error on line 4 -- both name line 3 first; a cure that swallowed directive errors fails it.
#   3 DIRECTIVES STILL WORK: $define/$ifdef/$else/$endif/$undef witness, SCRIP's stdout == iconx's, both modes.
#   4 scrip -E STAYS icont -E: the same witness's -E text equals icont -E's (#line lines and blank lines aside, as the pre-step tool gate reads them).
# Exit 0 = all four; 1 = an arm fails; 2 = cannot measure.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; G="$(basename "${BASH_SOURCE[0]}" .sh)"
. "$HERE/lib_oracle_flags.sh"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
ICONT="$(icont_bin)"; [ -x "$ICONT" ] || { echo "⛔ GATE REFUSE(2) [$G]: no icont at $ICONT -- reached by absolute path"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0
firstline() { grep -m1 -oiE '(^| )line [0-9]+' "$1" | grep -oE '[0-9]+'; }
printf 'procedure main();\n  write(1 +);\n  write(2);\n$error boom\nend\n' > "$T/o1.icn"
printf 'procedure main();\n  write(2);\n$error boom\n  write(1 +);\nend\n' > "$T/o2.icn"
for w in o1 o2; do
    ( cd "$T" && timeout -k 5 20 "$ICONT" -s -o "$w.ox" "$w.icn" < /dev/null > /dev/null 2> "$w.icont.err" ); orc=$?
    want="$(firstline "$T/$w.icont.err")"
    [ "$orc" -ne 0 ] && [ -n "$want" ] || { echo "⛔ GATE REFUSE(2) [$G]: icont accepted $w.icn or named no line (rc=$orc) -- the witness no longer measures"; exit 2; }
    ( cd "$T" && timeout -k 5 20 "$SCRIP" "$w.icn" < /dev/null > /dev/null 2> "$w.m3.err" ); m3rc=$?
    ( cd "$T" && timeout -k 5 20 "$SCRIP" --compile --out="$w.s" "$w.icn" < /dev/null > /dev/null 2> "$w.m4.err" ); m4rc=$?
    for m in m3 m4; do
        rc=$m3rc; [ "$m" = m4 ] && rc=$m4rc
        got="$(firstline "$T/$w.$m.err")"
        if [ "$rc" -ne 0 ] && [ "$got" = "$want" ]; then echo "  PASS $w $m: the first diagnostic names line $got, as icont's does"
        else RC=1; echo "  FAIL $w $m: rc=$rc, first diagnostic names line ${got:-none} where icont's names line $want -- $(head -1 "$T/$w.$m.err" | cut -c1-120)"; fi
    done
done
printf '$define N 3\n$ifdef N\n$define M "on"\n$else\n$define M "off"\n$endif\n$undef N\n$ifndef N\n$define K 7\n$endif\nprocedure main();\n  write(M, " ", K);\nend\n' > "$T/d.icn"
( cd "$T" && timeout -k 5 20 "$ICONT" -s -o d.ox d.icn < /dev/null > /dev/null 2>&1 && timeout -k 5 20 ./d.ox < /dev/null > d.ref 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: the oracle would not run the directive witness"; exit 2; }
( cd "$T" && timeout -k 5 20 "$SCRIP" d.icn < /dev/null > d.m3 2>&1 ); m3rc=$?
( cd "$T" && timeout -k 5 20 "$SCRIP" --compile --out=d.s d.icn < /dev/null > /dev/null 2>&1 && gcc -no-pie d.s -Wl,-rpath,"$ROOT/out" -L"$ROOT/out" -lscrip_rt -lm -lpthread -o d.bin 2>/dev/null && timeout -k 5 20 ./d.bin < /dev/null > d.m4 2>&1 ); m4rc=$?
[ "$m3rc" -eq 0 ] && cmp -s "$T/d.m3" "$T/d.ref" && echo "  PASS directives in mode 3 == iconx ($(cat "$T/d.ref"))" || { RC=1; echo "  FAIL directives in mode 3: rc=$m3rc, got '$(head -c 60 "$T/d.m3")' want '$(cat "$T/d.ref")'"; }
[ "$m4rc" -eq 0 ] && cmp -s "$T/d.m4" "$T/d.ref" && echo "  PASS directives in mode 4 == iconx" || { RC=1; echo "  FAIL directives in mode 4: rc=$m4rc, got '$(head -c 60 "$T/d.m4" 2>/dev/null)' want '$(cat "$T/d.ref")'"; }
text() { grep -v '^#line ' "$1" | grep -v '^[[:space:]]*$'; }
( cd "$T" && timeout -k 5 20 "$SCRIP" -E d.icn < /dev/null > e.scrip 2> /dev/null ); erc=$?
( cd "$T" && timeout -k 5 20 "$ICONT" -E d.icn < /dev/null > e.icont 2> /dev/null )
[ "$erc" -eq 0 ] && cmp -s <(text "$T/e.scrip") <(text "$T/e.icont") && echo "  PASS scrip -E == icont -E" || { RC=1; echo "  FAIL scrip -E (rc=$erc) differs from icont -E: $(diff <(text "$T/e.scrip") <(text "$T/e.icont") | grep -m1 '^[<>]' | cut -c1-100)"; }
[ "$RC" = 0 ] && echo "GATE PASS(0) [$G]: Icon's preprocessor runs on the fly, in source order, as Arizona's does" || echo "⛔ GATE FAIL(1) [$G]: Icon's preprocessor is not on the fly"
exit $RC
