#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ REFUSE(2): no scrip at $SCRIP"; exit 2; }
command -v gcc >/dev/null || { echo "⛔ REFUSE(2): no gcc for mode 4"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/k1.icn" <<'ICN'
procedure main()
   local y;
   y := 3 || [];
end
ICN
cat > "$T/k1.want" <<'WANT'

Run-time error 103
File k1.icn; Line 3
string expected
offending value: list_1 = []
Traceback:
main()
{"3" || list_1 = []} from line 3 in k1.icn
WANT
cat > "$T/k2.icn" <<'ICN'
procedure main()
   local y;
   y := "3" + [];
end
ICN
cat > "$T/k2.want" <<'WANT'

Run-time error 102
File k2.icn; Line 3
numeric expected
offending value: list_1 = []
Traceback:
main()
{3 + list_1 = []} from line 3 in k2.icn
WANT
cat > "$T/k3.icn" <<'ICN'
procedure main()
   local y;
   y := 3 ++ [];
end
ICN
cat > "$T/k3.want" <<'WANT'

Run-time error 120
File k3.icn; Line 3
two csets or two sets expected
offending value: list_1 = []
Traceback:
main()
{'3' ++ list_1 = []} from line 3 in k3.icn
WANT
cat > "$T/k4.icn" <<'ICN'
procedure main()
   local y;
   y := "7" < [];
end
ICN
cat > "$T/k4.want" <<'WANT'

Run-time error 102
File k4.icn; Line 3
numeric expected
offending value: list_1 = []
Traceback:
main()
{7 < list_1 = []} from line 3 in k4.icn
WANT
cat > "$T/k5.icn" <<'ICN'
procedure main()
   local y;
   y := 3.0 || [];
end
ICN
cat > "$T/k5.want" <<'WANT'

Run-time error 103
File k5.icn; Line 3
string expected
offending value: list_1 = []
Traceback:
main()
{"3.0" || list_1 = []} from line 3 in k5.icn
WANT
cat > "$T/k6.icn" <<'ICN'
procedure main()
   local y;
   y := "a" ~== [];
end
ICN
cat > "$T/k6.want" <<'WANT'

Run-time error 103
File k6.icn; Line 3
string expected
offending value: list_1 = []
Traceback:
main()
{"a" ~== list_1 = []} from line 3 in k6.icn
WANT
cat > "$T/k7.icn" <<'ICN'
procedure main()
   local y;
   y := 3 << [];
end
ICN
cat > "$T/k7.want" <<'WANT'

Run-time error 103
File k7.icn; Line 3
string expected
offending value: list_1 = []
Traceback:
main()
{"3" << list_1 = []} from line 3 in k7.icn
WANT
fail=0
for w in k1 k2 k3 k4 k5 k6 k7; do
  ( cd "$T" && timeout -k 5 60 "$SCRIP" "$w.icn" </dev/null > "$w.m3" 2>&1 ); rc3=$?; python3 "$ROOT/../harness/scripts/util_render_error_voice.py" icon < "$T/$w.m3" > "$T/$w.m3.r" && mv "$T/$w.m3.r" "$T/$w.m3"
  if cmp -s "$T/$w.m3" "$T/$w.want"; then echo "  PASS  m3 $w (rc=$rc3)"; else echo "  FAIL  m3 $w rc=$rc3"; diff "$T/$w.want" "$T/$w.m3" | head -6 | sed 's/^/        /'; fail=1; fi
  if ( cd "$T" && "$SCRIP" --compile "$w.icn" > "$w.s" 2>/dev/null && gcc -c "$w.s" -o "$w.o" 2>/dev/null && gcc "$w.o" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$w.bin" 2>/dev/null ); then
    ( cd "$T" && timeout -k 5 60 "./$w.bin" </dev/null > "$w.m4" 2>&1 ); rc4=$?; python3 "$ROOT/../harness/scripts/util_render_error_voice.py" icon < "$T/$w.m4" > "$T/$w.m4.r" && mv "$T/$w.m4.r" "$T/$w.m4"
    if cmp -s "$T/$w.m4" "$T/$w.want"; then echo "  PASS  m4 $w (rc=$rc4)"; else echo "  FAIL  m4 $w rc=$rc4"; diff "$T/$w.want" "$T/$w.m4" | head -6 | sed 's/^/        /'; fail=1; fi
  else echo "  FAIL  m4 $w: no binary"; fail=1; fi
done
if [ "$fail" = 0 ]; then echo "✅ PASS: when the RIGHT operand of a binary operator fails to convert, the traceback images the LEFT after its own conversion, as iconx does (|| string, + and < numeric, ++ cset, << string; ~== converts nothing), both modes"; exit 0; fi
echo "⛔ FAIL: a traceback images a left operand unconverted where iconx images it converted (see the FAIL rows)"; exit 1
