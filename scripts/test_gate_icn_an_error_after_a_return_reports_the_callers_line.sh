#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ REFUSE(2): no scrip at $SCRIP"; exit 2; }
command -v gcc >/dev/null || { echo "⛔ REFUSE(2): no gcc for mode 4"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/r1.icn" <<'ICN'
procedure main()
   local x;
   x := f(2) + &null;
   write(x);
end
procedure f(n)
   local y;
   y := n;
   return y;
end
ICN
cat > "$T/r1.want" <<'WANT'

Run-time error 102
File r1.icn; Line 3
numeric expected
offending value: &null
Traceback:
main()
{2 + &null} from line 3 in r1.icn
WANT
cat > "$T/r2.icn" <<'ICN'
procedure main()
   local x;
   x := (f(2) | 1) + &null;
   write(x);
end
procedure f(n)
   local y;
   y := n;
   fail;
end
ICN
cat > "$T/r2.want" <<'WANT'

Run-time error 102
File r2.icn; Line 3
numeric expected
offending value: &null
Traceback:
main()
{1 + &null} from line 3 in r2.icn
WANT
cat > "$T/r3.icn" <<'ICN'
procedure main()
   local x;
   x := fact(4);
   write(x);
   x := [] + fact(2);
end
procedure fact(n)
   if n <= 1 then
      return 1;
   return n * fact(n - 1);
end
ICN
cat > "$T/r3.want" <<'WANT'
24

Run-time error 102
File r3.icn; Line 5
numeric expected
offending value: list_1 = []
Traceback:
main()
{list_1 = [] + 2} from line 5 in r3.icn
WANT
cat > "$T/r4.icn" <<'ICN'
procedure q();
   return 1;
end
procedure r(n);
   local x;
   if n = 0 then {
      x := q() + "a";
      return x;
   };
   return r(n - 1);
end
procedure main();
   write(r(70000));
end
ICN
{ printf '\nRun-time error 102\nFile r4.icn; Line 7\nnumeric expected\noffending value: "a"\nTraceback:\nmain()\nr(70000) from line 13 in r4.icn\n'
  awk 'BEGIN { for (k = 69999; k >= 0; k--) printf "r(%d) from line 10 in r4.icn\n", k }'
  printf '{1 + "a"} from line 7 in r4.icn\n'; } > "$T/r4.want"
fail=0
for w in r1 r2 r3 r4; do
  sw=(); [ "$w" = r4 ] && sw=(-s262144k)
  ( cd "$T" && timeout -k 5 60 "$SCRIP" "${sw[@]}" "$w.icn" </dev/null > "$w.m3" 2>&1 ); rc3=$?; python3 "$ROOT/../harness/scripts/util_render_error_voice.py" icon < "$T/$w.m3" > "$T/$w.m3.r" && mv "$T/$w.m3.r" "$T/$w.m3"
  if cmp -s "$T/$w.m3" "$T/$w.want"; then echo "  PASS  m3 $w (rc=$rc3)"; else echo "  FAIL  m3 $w rc=$rc3"; diff "$T/$w.want" "$T/$w.m3" | head -10 | sed 's/^/        /'; fail=1; fi
  if ( cd "$T" && "$SCRIP" --compile "$w.icn" > "$w.s" 2>/dev/null && gcc -c "$w.s" -o "$w.o" 2>/dev/null && gcc "$w.o" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$w.bin" 2>/dev/null ); then
    ( cd "$T" && timeout -k 5 60 "./$w.bin" ${sw[@]+"${sw[@]}" --} </dev/null > "$w.m4" 2>&1 ); rc4=$?; python3 "$ROOT/../harness/scripts/util_render_error_voice.py" icon < "$T/$w.m4" > "$T/$w.m4.r" && mv "$T/$w.m4.r" "$T/$w.m4"
    if cmp -s "$T/$w.m4" "$T/$w.want"; then echo "  PASS  m4 $w (rc=$rc4)"; else echo "  FAIL  m4 $w rc=$rc4"; diff "$T/$w.want" "$T/$w.m4" | head -10 | sed 's/^/        /'; fail=1; fi
  else echo "  FAIL  m4 $w: no binary"; fail=1; fi
done
if [ "$fail" = 0 ]; then echo "✅ PASS: a run-time error raised in the caller after a procedure returns (r1, r3) or fails (r2) reports the caller's line, untraced, both modes -- and r4 at level 70000, past the 65536 records the table held before it grew, keeps every record (line 7, all 70001 frames)"; exit 0; fi
echo "⛔ FAIL: an error after a return or failure is reporting the callee's last line, not the caller's (see the FAIL rows)"; exit 1
