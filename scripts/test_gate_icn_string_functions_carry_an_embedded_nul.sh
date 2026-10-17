#!/usr/bin/env bash
# test_gate_icn_string_functions_carry_an_embedded_nul.sh -- hq_icon, 2026-09-24, MODE DECTET.
#
# WHAT WAS THERE. NUL is a valid string element and a length is carried, never measured (RULES.md). Swept against iconx,
# three places still measured: the scanning upto/many/any boxes built their compile-time cset bitmap by walking the
# literal to its first NUL (bs_cset_words) and any() tested membership with the unmeasured rt_icn_cset_member, so a cset
# with a NUL member lost it -- `s ? tab(upto('\x00'))` FAILED where iconx answers "ab"; and left/right/center took their
# pad with `if (fs && *fs) ... strlen(fs)`, so a "\x00" pad read as empty and padded with blanks.
#
# WHAT IS HERE. The emit cases hand the literal's true length (its lowerer-attached length operand) to the three boxes in
# op_ival; the bitmap is built over it, the data is emitted with its length, and any() calls rt_icn_cset_member_n with it.
# The pad is measured with icn_true_len, the helper its subject already used.
#
# ARM. Two witnesses -- a sweep of twenty string functions over a NUL-carrying string, and the scanning cset boxes with NUL
# members -- graded against the LIVE oracle (icont/iconx 9.5.25a) in both media, byte for byte. A witness the oracle does
# not run refuses the gate rather than passing it.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
. "$HERE/lib_oracle_flags.sh"
ICONT="$(icont_bin)" || { echo "⛔ GATE REFUSE(2) [$G]: the Icon oracle is missing"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/w1.icn" <<'EOF'
procedure main()
   local s, t, c;
   s := "ab\x00cd\x00" || "ef";
   write(*s, " ", image(s));
   write(image(reverse(s)));
   write(image(repl(s, 2)));
   write(image(map(s, "\x00", "_")));
   write(image(trim(s || "  ")));
   write(image(left(s, 10, "\x00")), " ", image(right(s, 10)), " ", image(center(s, 12, "*")));
   write(image(s[3]), " ", image(s[2:5]), " ", image(s[-1]));
   write(*string(s), " ", image(string(s)));
   c := cset(s);
   write(*c, " ", image(c));
   write(image(s ? tab(upto('\x00'))));
   write(image(s ? { tab(many('ab')) || "|" || tab(0) }));
   every writes(upto('\x00', s), " "); write();
   write(image(s == ("ab\x00cd\x00ef")) | "not equal");
   write(image(s << "ab\x00cd\x01") | "not less");
   t := table(); t[s] := 1; t["ab"] := 2;
   write(t[s], " ", *t);
   write(image(detab("a\x00\tb")));
   write(image(s || s), " ", *(s || s));
   write(image(ord(s[3])), " ", image(char(0)));
end
EOF
cat > "$T/w2.icn" <<'EOF'
procedure main()
   local s, x;
   s := "ab\x00cd\x00" || "ef";
   write(image(s ? tab(upto('\x00'))) | "upto fails");
   write(image(s ? { tab(3); tab(many('\x00c')) }) | "many fails");
   write(image(s ? { tab(3); tab(any('\x00')) }) | "any fails");
   write(image(s ? { tab(3); tab(any('x\x00')) }) | "any2 fails");
   s ? every x := upto('d\x00') do writes(x, " ");
   write();
   write(image(s ? tab(upto('e'))) | "upto-e fails");
   write(image(s ? tab(many('ab')) ) | "many-ab fails");
end
EOF
res=""; bad=0
for w in w1 w2; do
  ( cd "$T" && "$ICONT" -s -o "$w.x" "$w.icn" ) >/dev/null 2>&1 || { echo "⛔ GATE REFUSE(2) [$G]: icont refuses witness $w"; exit 2; }
  want="$( cd "$T" && timeout -k 5 20 "./$w.x" </dev/null 2>&1 )" || { echo "⛔ GATE REFUSE(2) [$G]: the oracle did not run witness $w"; exit 2; }
  o3="$( cd "$T" && timeout -k 5 20 "$SCRIP" "$w.icn" </dev/null 2>&1 )"
  o4=""; ( cd "$T" && "$SCRIP" --compile -o "$w.s" "$w.icn" </dev/null >/dev/null 2>&1 && gcc -no-pie -o "$w.4" "$w.s" -L"$ROOT/out" -lscrip_rt -lm -lstdc++ -lpthread -Wl,-rpath,"$ROOT/out" >/dev/null 2>&1 ) \
    && o4="$( cd "$T" && timeout -k 5 20 "./$w.4" </dev/null 2>&1 )"
  if [ "$o3" = "$want" ] && [ "$o4" = "$want" ]; then res="$res $w:ok"
  else res="$res $w:RED"; bad=1
    diff <(printf '%s\n' "$want") <(printf '%s\n' "$o3") | head -4 | sed 's/^/    m3 /'; diff <(printf '%s\n' "$want") <(printf '%s\n' "$o4") | head -4 | sed 's/^/    m4 /'; fi
done
echo "  HOLDS: string functions and the scanning cset boxes carry a NUL-carrying string's or cset's length, in both media, as iconx does"
if [ "$bad" = 0 ]; then echo "  arm 1 PASS: both witnesses match the live oracle in both media --$res"; echo "✅ GATE PASS [$G]"; exit 0; fi
echo "  arm 1 FAIL:$res"; echo "⛔ GATE FAIL [$G]"; exit 1
