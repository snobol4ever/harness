#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ REFUSE(2): no scrip at $SCRIP"; exit 2; }
command -v gcc >/dev/null || { echo "⛔ REFUSE(2): no gcc for mode 4"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/s1.icn" <<'ICN'
procedure main()
   local x;
   every x := gen(3) do x := x + &null;
end
procedure gen(n)
   suspend n;
end
ICN
cat > "$T/s1.want" <<'WANT'

Run-time error 102
File s1.icn; Line 3
numeric expected
offending value: &null
Traceback:
main()
{3 + &null} from line 3 in s1.icn
WANT
cat > "$T/s2.icn" <<'ICN'
procedure main()
   local x;
   every x := gen(3) do write(x);
end
procedure gen(n)
   suspend n | (n + &null);
end
ICN
cat > "$T/s2.want" <<'WANT'
3

Run-time error 102
File s2.icn; Line 6
numeric expected
offending value: &null
Traceback:
main()
gen(3) from line 3 in s2.icn
{3 + &null} from line 6 in s2.icn
WANT
fail=0
for w in s1 s2; do
  ( cd "$T" && timeout -k 5 60 "$SCRIP" "$w.icn" </dev/null > "$w.m3" 2>&1 ); rc3=$?; python3 "$ROOT/../harness/scripts/util_render_error_voice.py" icon < "$T/$w.m3" > "$T/$w.m3.r" && mv "$T/$w.m3.r" "$T/$w.m3"
  if cmp -s "$T/$w.m3" "$T/$w.want"; then echo "  PASS  m3 $w (rc=$rc3)"; else echo "  FAIL  m3 $w rc=$rc3"; diff "$T/$w.want" "$T/$w.m3" | head -6 | sed 's/^/        /'; fail=1; fi
  if ( cd "$T" && "$SCRIP" --compile "$w.icn" > "$w.s" 2>/dev/null && gcc -c "$w.s" -o "$w.o" 2>/dev/null && gcc "$w.o" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$w.bin" 2>/dev/null ); then
    ( cd "$T" && timeout -k 5 60 "./$w.bin" </dev/null > "$w.m4" 2>&1 ); rc4=$?; python3 "$ROOT/../harness/scripts/util_render_error_voice.py" icon < "$T/$w.m4" > "$T/$w.m4.r" && mv "$T/$w.m4.r" "$T/$w.m4"
    if cmp -s "$T/$w.m4" "$T/$w.want"; then echo "  PASS  m4 $w (rc=$rc4)"; else echo "  FAIL  m4 $w rc=$rc4"; diff "$T/$w.want" "$T/$w.m4" | head -6 | sed 's/^/        /'; fail=1; fi
  else echo "  FAIL  m4 $w: no binary"; fail=1; fi
done
if [ "$fail" = 0 ]; then echo "✅ PASS: a suspend hands the caller back its own line (s1: an error in the do-clause reads the call line 3, not the suspend line 6) and a resume gives the generator back its own (s2: an error after the resume reads line 6, not the call site 3), both modes"; exit 0; fi
echo "⛔ FAIL: a suspend or a resume leaves the other side's line in g_line (see the FAIL rows)"; exit 1
