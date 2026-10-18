#!/bin/bash
# Icon large integers, RUNG 1: the shapes rung 0 deliberately did not cover. Row
# icon-bignum-rung-1-division-remainder-literals-conversion-and-negation.
#
# Measured 2026-09-06 against iconx, on the tree where rung 0 is already green:
#   2^100 / 2^90   iconx 1024                                   SCRIP 1
#   2^100 % 7      iconx 2                                      SCRIP 0
#   2^100 / 3      iconx 422550200076076467165567735125         SCRIP 3074457345618258602
#   12345678901234567890 + 1                                    ⛔ THE LEXER, NOT THE RUNTIME: iconx
#                  prints 12345678901234567891, SCRIP prints 9.223372037e+18 -- an integer literal too
#                  wide for int64 becomes a REAL at parse time, so NO runtime cure can reach it and a
#                  witness built on a large literal tests the lexer rather than the arithmetic.
#   integer("1267650600228229401496703205376")  iconx echoes it; SCRIP clamps to INT64_MAX
#   -(2^100)       iconx -1267650600228229401496703205376; SCRIP -9223372036854775807 (unary minus has
#                  no large-integer arm)
#
# ⭐ TWO ARMS ARE ALREADY GREEN AND ARE KEPT AS CONTROLS, not removed: real(2^100) and 2^100 - 2^100.
# An arm that is green before the cure proves nothing about the cure DIRECTION, which is exactly why
# they are labelled controls here rather than counted as witnesses -- they exist to catch a rung-1 cure
# that breaks what rung 0 already got right.
# ⛔ REFUSES rc=2 unless all 16 runs (8 witnesses x 2 modes) are graded, and rc=2 if the oracle is absent.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; cd "$ROOT" || exit 2
ICONT=/home/resources/icon-master/bin/icont; ICONX=/home/resources/icon-master/bin/iconx
[ -x ./scrip ] && [ -f out/libscrip_rt.so ] || { echo "⛔ GATE REFUSES (rc=2): scrip/runtime not built at $ROOT"; exit 2; }
[ -x "$ICONT" ] && [ -x "$ICONX" ] || { echo "⛔ GATE REFUSES (rc=2): Icon oracle missing at $ICONT / $ICONX"; exit 2; }
d=$(mktemp -d) || exit 2; trap 'rm -rf "$d"' EXIT
w() { printf 'procedure main()\n  %s\nend\n' "$2" > "$d/$1.icn"; }
w div_big_big   'write(2^100 / 2^90);'
w mod_big_small 'write(2^100 % 7);'
w div_big_small 'write(2^100 / 3);'
w big_literal   'write(12345678901234567890 + 1);'
w integer_of    'write(integer("1267650600228229401496703205376"));'
w negate        'write(-(2^100));'
w real_control  'write(real(2^100));'
w zero_control  'write(2^100 - 2^100);'
graded=0; bad=0
for t in div_big_big mod_big_small div_big_small big_literal integer_of negate real_control zero_control; do
    "$ICONT" -s -o "$d/$t.ora" "$d/$t.icn" >/dev/null 2>&1 || { echo "⛔ GATE REFUSES (rc=2): icont rejected $t -- cannot measure"; exit 2; }
    want=$(timeout -k 5 20 "$ICONX" "$d/$t.ora" </dev/null 2>/dev/null); wrc=$?
    [ "$wrc" != 124 ] || { echo "⛔ GATE REFUSES (rc=2): the ORACLE timed out on $t -- cannot measure"; exit 2; }
    o=$(timeout -k 5 20 ./scrip "$d/$t.icn" </dev/null 2>/dev/null); r=$?; graded=$((graded+1))
    if [ "$o" != "$want" ] || [ "$r" != "$wrc" ]; then
        echo "  ⛔ RED m3 $t: rc=$r out=[$(printf '%s' "$o" | tr '\n' '|' | cut -c1-46)] -- iconx rc=$wrc out=[$(printf '%s' "$want" | tr '\n' '|' | cut -c1-46)]"; bad=1
    fi
    if timeout -k 5 120 ./scrip --compile -o "$d/$t.s" "$d/$t.icn" </dev/null >/dev/null 2>&1 \
       && gcc -m64 -no-pie "$d/$t.s" -o "$d/$t.m4" -L./out -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread 2>/dev/null; then
        o=$(timeout -k 5 20 "$d/$t.m4" </dev/null 2>/dev/null); r=$?; graded=$((graded+1))
        if [ "$o" != "$want" ] || [ "$r" != "$wrc" ]; then
            echo "  ⛔ RED m4 $t: rc=$r out=[$(printf '%s' "$o" | tr '\n' '|' | cut -c1-46)] -- iconx rc=$wrc out=[$(printf '%s' "$want" | tr '\n' '|' | cut -c1-46)]"; bad=1
        fi
    else
        graded=$((graded+1)); echo "  ⛔ RED m4 $t: does not compile/link"; bad=1
    fi
done
[ "$graded" = 16 ] || { echo "⛔ GATE REFUSES (rc=2): graded $graded of the 16 required runs"; exit 2; }
[ "$bad" = 0 ] || { echo "⛔ GATE RED [icn_bignum_rung1]: division, remainder, large literals, integer() or negation still lose large integers"; exit 1; }
echo "✅ GATE OK [icn_bignum_rung1]: division, remainder, large literals, integer() and negation all carry large integers -- BOTH modes"
