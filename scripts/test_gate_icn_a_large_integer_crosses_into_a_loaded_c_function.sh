#!/usr/bin/env bash
# test_gate_icn_a_large_integer_crosses_into_a_loaded_c_function.sh -- A LARGE INTEGER PASSED TO A loadfunc'd C FUNCTION ARRIVES AS
# ICONX'S OWN LARGE-INTEGER BLOCK, AND ONE RETURNED COMES BACK AS AN ICON INTEGER, IN BOTH MODES (hq_icon 2026-09-27, crawl work under
# CEO-1270/CEO-1336: Arizona general/cfuncs, whose lgconv(10^30) died "error 101: integer expected" with the library in reach).
#
# The C calling convention of the Arizona distribution (ipl/cfuncs/icall.h) hands a function iconx descriptors: an integer too large
# for a word is D_Lrgint, its v-word a struct b_bignum {title, blksize, msd, lsd, int sign, 32-bit digits most significant first}.
# SCRIP's marshaller had no arm for its own DT_BIG, so the argument crossed as &null and ArgInteger raised 101. The cure builds the
# iconx block from SCRIP's limbs going in (rt_big_icnx_block), rebuilds a SCRIP integer from one coming out (rt_big_from_icnx_block),
# and lets cnv_str and cnv_real read it, as iconx's conversions do. The witness calls the distribution's own libcfunc.so (lgconv, which
# walks the block's digits; pack with "rb", which reads it through ArgReal; unpack of one, which reads it through ArgString and fails
# 205 with its decimal string) through loadfunc on an absolute path, so no FPATH and no linked io.icn is involved;
# expectations come from a live iconx run. On the tree before the cure the lgconv lines differ (red).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
G=test_gate_icn_a_large_integer_crosses_into_a_loaded_c_function
S="$HERE/../../SCRIP/scrip"; O="$HERE/../../SCRIP/out"
[ -x "$S" ] || { echo "⛔ GATE REFUSE(2) [$G]: scrip not built"; exit 2; }
IC=/home/resources/icon-master/bin/icont; LIB=/home/resources/icon-master/bin/libcfunc.so
[ -x "$IC" ] || { echo "⛔ GATE REFUSE(2) [$G]: icont not found at $IC -- the oracle is required"; exit 2; }
[ -f "$LIB" ] || { echo "⛔ GATE REFUSE(2) [$G]: the distribution's libcfunc.so is not at $LIB -- the witness calls it"; exit 2; }
T="$(mktemp -d "${TMPDIR:-/tmp}/lrgint_gate.XXXXXX")" || { echo "⛔ GATE REFUSE(2) [$G]: mktemp failed"; exit 2; }
trap 'rm -rf "$T"' EXIT
cat > "$T/w.icn" <<EOF
procedure main()
   local lg, pk, up, x;
   lg := loadfunc("$LIB", "lgconv");
   pk := loadfunc("$LIB", "pack");
   up := loadfunc("$LIB", "unpack");
   every x := 10 ^ 30 | -(2 ^ 100) | 2 ^ 64 | 2 ^ 63 - 1 | -(2 ^ 63) | 12345 do
      write(image(x), " -> ", lg(x) | "[failed]");
   write(up("abcdefgh", "b") | "[failed]");
   write(image(pk(2 ^ 70, "rb", 8)) | "[failed]");
   write(up(pk(-(10 ^ 30), "rb", 8), "rb") | "[failed]");
   &error := 1;
   write(up(2 ^ 70) | (&errornumber || " " || image(&errorvalue)));
end
EOF
( cd "$T" && "$IC" -s -o w.ox w.icn >/dev/null 2>&1 && ./w.ox > oracle.txt 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: the oracle did not run the witness"; exit 2; }
grep -q '^integer(~10^30) -> 1000000000000000000000000000000$' "$T/oracle.txt" || { echo "⛔ GATE REFUSE(2) [$G]: the oracle's lgconv line is not the one this gate measures:"; head -3 "$T/oracle.txt"; exit 2; }
( cd "$T" && "$S" w.icn < /dev/null > m3.txt 2>&1 )
( cd "$T" && "$S" --compile --out=w.s w.icn < /dev/null >/dev/null 2>&1 ) && gcc -no-pie -o "$T/w.x" "$T/w.s" -Wl,-rpath,"$O" -L"$O" -lscrip_rt -lm -lpthread 2>/dev/null \
    || { echo "⛔ GATE REFUSE(2) [$G]: m4 did not build the witness"; exit 2; }
( cd "$T" && ./w.x < /dev/null > m4.txt 2>&1 )
red=0
cmp -s "$T/oracle.txt" "$T/m3.txt" || { echo "  m3 differs from iconx:"; diff "$T/oracle.txt" "$T/m3.txt" | head -8; red=1; }
cmp -s "$T/oracle.txt" "$T/m4.txt" || { echo "  m4 differs from iconx:"; diff "$T/oracle.txt" "$T/m4.txt" | head -8; red=1; }
[ "$red" -eq 0 ] && { echo "✅ GATE PASS [$G]: $(wc -l < "$T/oracle.txt") lines -- a large integer crosses into and out of a loaded C function as iconx's block, m3 and m4"; exit 0; }
echo "⛔ GATE FAIL [$G]: a large integer does not cross the external-function boundary as iconx's block"; exit 1
