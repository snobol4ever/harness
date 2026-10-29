#!/usr/bin/env bash
# test_gate_icn_an_external_value_answers_type_image_copy_identity_and_sort_as_iconx.sh -- AN ICON EXTERNAL VALUE (a block a loaded C
# function makes with alcexternal) ANSWERS type(), image(), copy(), === AND sort() AS ICONX DOES, IN BOTH MODES (hq_icon 2026-09-27,
# crawl work under CEO-1336: Arizona general/extlvals; Lon granted the one new counter, g_agg_external_ser, in-chat 19:1x).
#
# iconx's rexternal.r and ralc.r are the contract: alcexternal rounds the block to whole words and numbers it from ONE serial shared by
# every external; type() is the block's extlname or "external"; image() is its extlimage or <name>_<id>(<data words>); copy() is its
# extlcopy or the value itself; === is block identity; sort() collates externals after records (order 12), by the library's extlcmp
# when both share a function list and it has one, else by type name and then id. SCRIP had alcexternal as a stub that raised 216. The
# witness calls the distribution's own libcfunc.so (extxmin: a minimal external; extxstr: name and image callbacks; extxreal: name,
# image, cmp and copy callbacks) through loadfunc on an absolute path, so no FPATH and no linked io.icn is involved; expectations come
# from a live iconx run. On the tree before the cure the first call dies with error 216 (red).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
G=test_gate_icn_an_external_value_answers_type_image_copy_identity_and_sort_as_iconx
S="$HERE/../../SCRIP/scrip"; O="$HERE/../../SCRIP/out"
[ -x "$S" ] || { echo "⛔ GATE REFUSE(2) [$G]: scrip not built"; exit 2; }
IC=/home/resources/icon-master/bin/icont; LIB=/home/resources/icon-master/bin/libcfunc.so
[ -x "$IC" ] || { echo "⛔ GATE REFUSE(2) [$G]: icont not found at $IC -- the oracle is required"; exit 2; }
[ -f "$LIB" ] || { echo "⛔ GATE REFUSE(2) [$G]: the distribution's libcfunc.so is not at $LIB -- the witness calls it"; exit 2; }
T="$(mktemp -d "${TMPDIR:-/tmp}/extl_gate.XXXXXX")" || { echo "⛔ GATE REFUSE(2) [$G]: mktemp failed"; exit 2; }
trap 'rm -rf "$T"' EXIT
cat > "$T/w.icn" <<WITNESS
record pt(x, y)
procedure main()
   local mn, xs, xr, v1, v2, s1, s2, r1, r2, r3, l, x;
   mn := loadfunc("$LIB", "extxmin");
   xs := loadfunc("$LIB", "extxstr");
   xr := loadfunc("$LIB", "extxreal");
   v1 := mn(); v2 := mn(); s1 := xs("bite"); s2 := xs("tadpole");
   r1 := xr(2.5); r2 := xr(1.5); r3 := copy(r1);
   every x := v1 | v2 | copy(v1) | s1 | s2 | r1 | r2 | r3 do write(type(x), " ", image(x));
   write(if v1 === copy(v1) then "copy is identical" else "copy differs");
   write(if r1 === r3 then "rcopy is identical" else "rcopy differs");
   write(if v1 === v2 then "v1 is v2" else "v1 is not v2");
   l := [r1, s2, pt(1, 2), v2, s1, r2, v1, r3, "str", 3];
   every write("sorted ", image(!sort(l)));
end
WITNESS
( cd "$T" && "$IC" -s -o w.ox w.icn >/dev/null 2>&1 && ./w.ox > oracle.txt 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: the oracle did not run the witness"; exit 2; }
grep -q '^xreal xreal_[0-9]*(2.5)$' "$T/oracle.txt" || { echo "⛔ GATE REFUSE(2) [$G]: the oracle's external lines are not the ones this gate measures:"; head -3 "$T/oracle.txt"; exit 2; }
( cd "$T" && "$S" w.icn < /dev/null > m3.txt 2>&1 )
( cd "$T" && "$S" --compile --out=w.s w.icn < /dev/null >/dev/null 2>&1 ) && gcc -no-pie -o "$T/w.x" "$T/w.s" -Wl,-rpath,"$O" -L"$O" -lscrip_rt -lm -lpthread 2>/dev/null \
    || { echo "⛔ GATE REFUSE(2) [$G]: m4 did not build the witness"; exit 2; }
( cd "$T" && ./w.x < /dev/null > m4.txt 2>&1 )
red=0
cmp -s "$T/oracle.txt" "$T/m3.txt" || { echo "  m3 differs from iconx:"; diff "$T/oracle.txt" "$T/m3.txt" | head -8; red=1; }
cmp -s "$T/oracle.txt" "$T/m4.txt" || { echo "  m4 differs from iconx:"; diff "$T/oracle.txt" "$T/m4.txt" | head -8; red=1; }
[ "$red" -eq 0 ] && { echo "✅ GATE PASS [$G]: $(wc -l < "$T/oracle.txt") lines -- an external value answers type, image, copy, === and sort as iconx, m3 and m4"; exit 0; }
echo "⛔ GATE FAIL [$G]: an external value does not answer as iconx"; exit 1
