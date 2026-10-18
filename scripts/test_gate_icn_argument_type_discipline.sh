#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ REFUSE(2): no scrip at $SCRIP"; exit 2; }
command -v gcc >/dev/null || { echo "⛔ REFUSE(2): no gcc for mode 4"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/w1.icn" <<'ICN'
procedure main()
   local c, s, t, i;
   c := list(2); s := "abc"; t := table(); i := 1;
   &error := 200;
   write("01 |||:= ", image(c |||:= s) | ("ERR " || &errornumber));
   write("02 ~==   ", image([] ~== "x") | ("ERR " || &errornumber));
   write("03 t(t)  ", image(t(t)) | ("ERR " || &errornumber));
   write("04 ||    ", image(&lcase || numeric) | ("ERR " || &errornumber));
   write("05 <=    ", image(i <= []) | ("ERR " || &errornumber));
   write("06 right ", image(right("","")) | ("ERR " || &errornumber));
   write("07 close ", image(close("F")) | ("ERR " || &errornumber));
   write("08 trim  ", image(trim(&lcase,[])) | ("ERR " || &errornumber));
   write("09 pos   ", image(pos("a")) | ("ERR " || &errornumber));
   write("10 |||   ", image(list(10) ||| "abc") | ("ERR " || &errornumber));
   write("11 *null ", image(*&null) | ("ERR " || &errornumber));
   write("12 *proc ", image(*main) | ("ERR " || &errornumber));
   write("13 ?null ", image(?&null) | ("ERR " || &errornumber));
   write("14 sub   ", image(nowhere[1]) | ("ERR " || &errornumber));
   write("15 call  ", image(nowhere(1)) | ("ERR " || &errornumber));
   write("16 disp  ", image(display(,[])) | ("ERR " || &errornumber));
   write("17 bylist ", image("|||"([1,2],[3])) | ("ERR " || &errornumber));
   write("18 bycat  ", image("||"("a","b")) | ("ERR " || &errornumber));
   write("19 byplus ", image("+"(1,2)) | ("ERR " || &errornumber));
end
ICN
cat > "$T/w1.want" <<'WANT'
01 |||:= ERR 108
02 ~==   ERR 103
03 t(t)  ERR 106
04 ||    ERR 103
05 <=    ERR 102
06 right ERR 101
07 close ERR 105
08 trim  ERR 104
09 pos   ERR 101
10 |||   ERR 108
11 *null ERR 112
12 *proc ERR 112
13 ?null ERR 113
14 sub   ERR 114
15 call  ERR 106
16 disp  ERR 105
17 bylist list_9(3)
18 bycat  "ab"
19 byplus 3
WANT
cat > "$T/w2.icn" <<'ICN'
procedure main()
   local L, e;
   &error := 200;
   L := [1, 2.5, "5", "s", 'ab', "", [1], table()];
   write("A ", image(1 || "x"), image(2.5 || "x"), image("s" || "x"), image('ab' || "x"), image("" || "x"));
   write("B ", image(*""), image(*"abc"), image(*'ab'), image(*[1,2]), image(*table()));
   write("C ", image("3" <= 5), image(2 <= 2.5), image("a" ~== "b"), image(1 ~== 2));
   write("D ", image([1] ||| [2]), image([] ||| [1]));
   write("E ", image(trim("ab ")), image(right("ab")), image(trim("ab ", 5)), image(right("ab", 2.9)));
   write("F ", image(?"abc"), image(?5), image(L[2]), image(L[-1]));
   write("G ", &errornumber);
end
ICN
cat > "$T/w2.want" <<'WANT'
A "1x""2.5x""sx""abx""x"
B 03220
C 52.5"b""2"
D list_6(2)list_9(1)
E "ab""b""ab ""ab"
F "a"32.5table_1(0)
WANT
cat > "$T/w3.icn" <<'ICN'
record rr(a,b)
procedure main()
   local L, R;
   &error := 200;
   write("01 sort  ", image(sort(&lcase)) | ("ERR " || &errornumber));
   write("02 sort  ", image(sort(&null,1)) | ("ERR " || &errornumber));
   write("03 put   ", image(put("s",1)) | ("ERR " || &errornumber));
   write("04 push  ", image(push(&null,1)) | ("ERR " || &errornumber));
   write("05 get   ", image(get(&null)) | ("ERR " || &errornumber));
   write("06 pop   ", image(pop("x")) | ("ERR " || &errornumber));
   write("07 pull  ", image(pull(&null)) | ("ERR " || &errornumber));
   write("08 put   ", image(put(table(),1)) | ("ERR " || &errornumber));
   L := [3,1,2]; R := rr(1,2);
   write("09 keep  ", image(sort(L)), image(sort(table())), image(sort(set([1]))), image(sort(R)));
   put(L,9); push(L,0);
   write("10 keep  ", pull(L), get(L), pop(L), *L);
   write("11 last  ", &errornumber);
end
ICN
cat > "$T/w3.want" <<'WANT'
01 sort  ERR 115
02 sort  ERR 115
03 put   ERR 108
04 push  ERR 108
05 get   ERR 108
06 pop   ERR 108
07 pull  ERR 108
08 put   ERR 108
09 keep  list_2(3)list_3(0)list_5(1)list_6(2)
10 keep  9032
11 last  108
WANT
fail=0
for w in w1 w2 w3; do
  ( cd "$T" && timeout -k 5 60 "$SCRIP" "$w.icn" </dev/null > "$w.m3" 2>&1 ); rc3=$?
  if [ "$rc3" = 0 ] && cmp -s "$T/$w.m3" "$T/$w.want"; then echo "  PASS  m3 $w"; else echo "  FAIL  m3 $w rc=$rc3"; diff "$T/$w.want" "$T/$w.m3" | head -8 | sed 's/^/        /'; fail=1; fi
  if ( cd "$T" && "$SCRIP" --compile "$w.icn" > "$w.s" 2>/dev/null && gcc -c "$w.s" -o "$w.o" 2>/dev/null && gcc "$w.o" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$w.bin" 2>/dev/null ); then
    ( cd "$T" && timeout -k 5 60 "./$w.bin" </dev/null > "$w.m4" 2>&1 ); rc4=$?
    if [ "$rc4" = 0 ] && cmp -s "$T/$w.m4" "$T/$w.want"; then echo "  PASS  m4 $w"; else echo "  FAIL  m4 $w rc=$rc4"; diff "$T/$w.want" "$T/$w.m4" | head -8 | sed 's/^/        /'; fail=1; fi
  else echo "  FAIL  m4 $w: no binary"; fail=1; fi
done
cat > "$T/s1.sno" <<'SNO'
	X =
	OUTPUT = SIZE(X)
	OUTPUT = SIZE("abc")
	OUTPUT = "a" 5
END
SNO
printf '0\n3\na5\n' > "$T/s1.want"
( cd "$T" && timeout -k 5 60 "$SCRIP" s1.sno </dev/null > s1.out 2>&1 )
if cmp -s "$T/s1.out" "$T/s1.want"; then echo "  PASS  snobol4 control arm: SIZE and concatenation keep their own discipline"; else echo "  FAIL  snobol4 control arm"; diff "$T/s1.want" "$T/s1.out" | head -6 | sed 's/^/        /'; fail=1; fi
if [ "$fail" = 0 ]; then echo "✅ PASS: Icon's argument type discipline -- 24 refusals with icont's own codes (w3: the eight structure builtins, whose wants are cut from Arizona icont, not typed), 24 conversions still accepted, both modes, SNOBOL4 unaffected"; exit 0; fi
echo "⛔ FAIL: an Icon operation coerces where iconx raises, or raises where iconx converts (see the FAIL rows)"; exit 1
