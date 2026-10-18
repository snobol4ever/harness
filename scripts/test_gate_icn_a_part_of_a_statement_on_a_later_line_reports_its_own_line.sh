#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ REFUSE(2): no scrip at $SCRIP"; exit 2; }
command -v gcc >/dev/null || { echo "⛔ REFUSE(2): no gcc for mode 4"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
# Witnesses (wants cut from icont/iconx 9.5.25a): iconx reports an error or a trace event at the line of the location record that
# governs the instruction after it, so a do-clause, a loop body, an if arm or a case clause written on a later line than its control
# expression reports its own line, and control resumed or re-entered in the control expression reports the control line again.
# Fail-before (12): v6 every-do; a3 b4 a generator resumed after the do-clause; b1 c4 a while condition re-entered; b2 b3 if arms; b7 a case
# clause; c2 until; c3 repeat; c5 an if as a case clause; c6 an if as a loop body.  Controls (5): a2 a4 an operator or an argument on a
# later line still reports the statement line; c1 an if whose value an operator on the first line consumes; c7 a one-line program;
# t1 (traced, --stlimit) a while body with no line-recording construct keeps the condition line, as Jcon tracing.icn does.
cat > "$T/v6.icn" <<'ICN'
procedure main()
   local x;
   every x := 1 to 3 do
      x := x + &null;
end
ICN
cat > "$T/v6.want" <<'WANT'

Run-time error 102
File v6.icn; Line 4
numeric expected
offending value: &null
Traceback:
main()
{1 + &null} from line 4 in v6.icn
WANT
cat > "$T/a3.icn" <<'ICN'
procedure main()
   local x;
   every x := (1 | &null) + 1 do
      write(x);
end
ICN
cat > "$T/a3.want" <<'WANT'
2

Run-time error 102
File a3.icn; Line 3
numeric expected
offending value: &null
Traceback:
main()
{&null + 1} from line 3 in a3.icn
WANT
cat > "$T/b1.icn" <<'ICN'
procedure main()
   local x, y;
   x := 1;
   while y := 1 + x do
      x := write("b") & &null;
end
ICN
cat > "$T/b1.want" <<'WANT'
b

Run-time error 102
File b1.icn; Line 4
numeric expected
offending value: "b"
Traceback:
main()
{1 + "b"} from line 4 in b1.icn
WANT
cat > "$T/b2.icn" <<'ICN'
procedure main()
   local x;
   if x := 1 then
      x := x + &null;
end
ICN
cat > "$T/b2.want" <<'WANT'

Run-time error 102
File b2.icn; Line 4
numeric expected
offending value: &null
Traceback:
main()
{1 + &null} from line 4 in b2.icn
WANT
cat > "$T/b3.icn" <<'ICN'
procedure main()
   local x;
   if x := &null then
      write("t")
   else
      x := 1;
   x := 1;
   if x = 2 then
      write("t")
   else
      x := x + &null;
end
ICN
cat > "$T/b3.want" <<'WANT'
t

Run-time error 102
File b3.icn; Line 11
numeric expected
offending value: &null
Traceback:
main()
{1 + &null} from line 11 in b3.icn
WANT
cat > "$T/b4.icn" <<'ICN'
procedure main()
   local x;
   every x := (1 | &null) + 1 do {
      write(x);
      write("in")
      };
end
ICN
cat > "$T/b4.want" <<'WANT'
2
in

Run-time error 102
File b4.icn; Line 3
numeric expected
offending value: &null
Traceback:
main()
{&null + 1} from line 3 in b4.icn
WANT
cat > "$T/b7.icn" <<'ICN'
procedure main()
   local x;
   x := 2;
   case x of {
      1: write("one");
      2: x := x +
         &null
      };
end
ICN
cat > "$T/b7.want" <<'WANT'

Run-time error 102
File b7.icn; Line 6
numeric expected
offending value: &null
Traceback:
main()
{2 + &null} from line 6 in b7.icn
WANT
cat > "$T/c2.icn" <<'ICN'
procedure main()
   local x;
   x := 0;
   until x > 2 do
      x := x + &null;
end
ICN
cat > "$T/c2.want" <<'WANT'

Run-time error 102
File c2.icn; Line 5
numeric expected
offending value: &null
Traceback:
main()
{0 + &null} from line 5 in c2.icn
WANT
cat > "$T/c3.icn" <<'ICN'
procedure main()
   local x;
   x := 1;
   repeat
      x := x + &null;
end
ICN
cat > "$T/c3.want" <<'WANT'

Run-time error 102
File c3.icn; Line 5
numeric expected
offending value: &null
Traceback:
main()
{1 + &null} from line 5 in c3.icn
WANT
cat > "$T/c4.icn" <<'ICN'
procedure main()
   local x, y;
   x := 1;
   while y := 1 + x do {
      write(y);
      x := &null
      };
end
ICN
cat > "$T/c4.want" <<'WANT'
2

Run-time error 102
File c4.icn; Line 4
numeric expected
offending value: &null
Traceback:
main()
{1 + &null} from line 4 in c4.icn
WANT
cat > "$T/c5.icn" <<'ICN'
procedure main()
   local x;
   x := 2;
   case x of {
      1: write("one");
      2: if x = 2 then
            x := x + &null
      };
end
ICN
cat > "$T/c5.want" <<'WANT'

Run-time error 102
File c5.icn; Line 7
numeric expected
offending value: &null
Traceback:
main()
{2 + &null} from line 7 in c5.icn
WANT
cat > "$T/c6.icn" <<'ICN'
procedure main()
   local x;
   every x := 1 to 3 do
      if x = 2 then
         x := x + &null;
end
ICN
cat > "$T/c6.want" <<'WANT'

Run-time error 102
File c6.icn; Line 5
numeric expected
offending value: &null
Traceback:
main()
{2 + &null} from line 5 in c6.icn
WANT
cat > "$T/a2.icn" <<'ICN'
procedure main()
   local x;
   x := 1
      + &null;
end
ICN
cat > "$T/a2.want" <<'WANT'

Run-time error 102
File a2.icn; Line 3
numeric expected
offending value: &null
Traceback:
main()
{1 + &null} from line 3 in a2.icn
WANT
cat > "$T/a4.icn" <<'ICN'
procedure main()
   write(1,
      &null + 1);
end
ICN
cat > "$T/a4.want" <<'WANT'

Run-time error 102
File a4.icn; Line 2
numeric expected
offending value: &null
Traceback:
main()
{&null + 1} from line 2 in a4.icn
WANT
cat > "$T/c1.icn" <<'ICN'
procedure main()
   local x, y;
   x := 1;
   y := (if x = 1 then
      &null else 1) + 1;
end
ICN
cat > "$T/c1.want" <<'WANT'

Run-time error 102
File c1.icn; Line 4
numeric expected
offending value: &null
Traceback:
main()
{&null + 1} from line 4 in c1.icn
WANT
cat > "$T/c7.icn" <<'ICN'
procedure main()
   local x, y;
   x := 1;
   y := (if x = 1 then 2 else 3) + 1;
   every write(x | y);
   while x < 3 do x +:= 1;
   if x = 3 then
      write("three");
   y := &null + 1;
end
ICN
cat > "$T/c7.want" <<'WANT'
1
3
three

Run-time error 102
File c7.icn; Line 9
numeric expected
offending value: &null
Traceback:
main()
{&null + 1} from line 9 in c7.icn
WANT
cat > "$T/t1.icn" <<'ICN'
procedure main()
   local args;
   &trace := -1;
   args := [1, 2];
   while pull(args) do
      every p ! args;
end
procedure p(a[])
   return a;
end
ICN
cat > "$T/t1.want" <<'WANT'
t1.icn       :    5  | p(list_2 = [1])
t1.icn       :    9  | p returned list_2 = [1]
t1.icn       :    5  | p(list_3 = [])
t1.icn       :    9  | p returned list_3 = []
t1.icn       :    7  main failed
WANT
fail=0
for w in v6 a3 b1 b2 b3 b4 b7 c2 c3 c4 c5 c6 a2 a4 c1 c7 t1; do
  SW=""; [ "$w" = t1 ] && SW="--stlimit"
  ( cd "$T" && timeout -k 5 60 "$SCRIP" $SW "$w.icn" </dev/null > "$w.m3" 2>&1 ); rc3=$?; python3 "$ROOT/../harness/scripts/util_render_error_voice.py" icon < "$T/$w.m3" > "$T/$w.m3.r" && mv "$T/$w.m3.r" "$T/$w.m3"
  if cmp -s "$T/$w.m3" "$T/$w.want"; then echo "  PASS  m3 $w (rc=$rc3)"; else echo "  FAIL  m3 $w rc=$rc3"; diff "$T/$w.want" "$T/$w.m3" | head -6 | sed 's/^/        /'; fail=1; fi
  if ( cd "$T" && "$SCRIP" $SW --compile "$w.icn" > "$w.s" 2>/dev/null && gcc -c "$w.s" -o "$w.o" 2>/dev/null && gcc "$w.o" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$w.bin" 2>/dev/null ); then
    ( cd "$T" && timeout -k 5 60 "./$w.bin" </dev/null > "$w.m4" 2>&1 ); rc4=$?; python3 "$ROOT/../harness/scripts/util_render_error_voice.py" icon < "$T/$w.m4" > "$T/$w.m4.r" && mv "$T/$w.m4.r" "$T/$w.m4"
    if cmp -s "$T/$w.m4" "$T/$w.want"; then echo "  PASS  m4 $w (rc=$rc4)"; else echo "  FAIL  m4 $w rc=$rc4"; diff "$T/$w.want" "$T/$w.m4" | head -6 | sed 's/^/        /'; fail=1; fi
  else echo "  FAIL  m4 $w: no binary"; fail=1; fi
done
if [ "$fail" = 0 ]; then echo "✅ PASS: a part of a statement on a later line reports its own line and control back in the control expression reports the control line, as iconx does: every-do, a resumed generator, while and until re-entry, if arms, case clauses, repeat, an if as a clause or a loop body (12 witnesses), with five controls, both modes"; exit 0; fi
echo "⛔ FAIL: a part of a statement on a later line reports another line than iconx (see the FAIL rows)"; exit 1
