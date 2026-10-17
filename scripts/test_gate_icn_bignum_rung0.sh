#!/bin/bash
# Icon large-integer arithmetic, RUNG 0: a fixed integer that OVERFLOWS must promote to a large
# integer rather than wrap in silence. Row icon-bignum-large-integer-arithmetic-ported-from-iconx-rlrgint
# (CEO-318, Lon: "the bignum is just a port of iconx"), ladder rung 39, arizona bignum class.
#
# Measured 2026-09-06 against iconx: `write(2^100)` prints 1267650600228229401496703205376 and SCRIP
# printed 0 -- a WRAP, not a refusal, so every downstream number was quietly wrong. `3^40 * 3^40` printed
# 4389419161382147137 where the oracle prints a 39-digit value.
#
# ⛔ RUNG 0 IS DELIBERATELY NOT THE WHOLE PORT, and the boundary is stated so nobody reads a green here as
# bignum-complete: this rung covers PROMOTION on overflow for + - * ^, decimal rendering, size and
# comparison, and DEMOTION when a result fits again. Rung 1 owns division and remainder (Knuth D), large
# integer LITERALS (the lexer wraps a 20-digit constant today), radix conversion, &random and real
# conversion. Each has its own witnesses cut from iconx; none of them is graded here.
#
# ⭐ THE CONTROL ARMS ARE THE POINT, as with every arithmetic cure: a value that still FITS must print
# exactly as it does today and must not acquire a large-integer spelling. 2^62, plain sums and negative
# products are graded on every run, so a promotion that fires too eagerly is caught here rather than on
# a board. Expectations come from a LIVE iconx run, never hardcoded.
# ⛔ REFUSES rc=2 unless all 18 runs (9 witnesses x 2 modes) are graded, and rc=2 if the oracle is absent.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"; cd "$ROOT" || exit 2
ICONT=/home/resources/icon-master/bin/icont; ICONX=/home/resources/icon-master/bin/iconx
[ -x ./scrip ] && [ -f out/libscrip_rt.so ] || { echo "⛔ GATE REFUSES (rc=2): scrip/runtime not built at $ROOT"; exit 2; }
[ -x "$ICONT" ] && [ -x "$ICONX" ] || { echo "⛔ GATE REFUSES (rc=2): Icon oracle missing at $ICONT / $ICONX -- not on PATH, so command -v answers a narrower question"; exit 2; }
d=$(mktemp -d) || exit 2; trap 'rm -rf "$d"' EXIT
w() { printf 'procedure main()\n  %s\nend\n' "$2" > "$d/$1.icn"; }
w pow2_100     'write(2^100);'
w pow2_64      'write(2^64);'
w neg_base     'write((-2)^100);'
w mul_promote  'write(3^40 * 3^40);'
w add_promote  'write(2^62 + 2^62 + 2^62);'
w compare      'write(2^100 > 2^99);'
w size_of_str  'write(*string(2^100));'
w fits_control 'write(2^62);'
w small_control 'write(2 + 3, " ", -5 * 3, " ", 7 % 3);'
graded=0; bad=0
for t in pow2_100 pow2_64 neg_base mul_promote add_promote compare size_of_str fits_control small_control; do
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
[ "$graded" = 18 ] || { echo "⛔ GATE REFUSES (rc=2): graded $graded of the 18 required runs"; exit 2; }
[ "$bad" = 0 ] || { echo "⛔ GATE RED [icn_bignum_rung0]: an overflowing integer still wraps instead of promoting"; exit 1; }
echo "✅ GATE OK [icn_bignum_rung0]: + - * ^ promote on overflow, render in decimal, compare and demote -- and every value that still fits is unchanged, BOTH modes"
