#!/usr/bin/env bash
export SCRIP_SNO_STMTKW=1   # this grader asks for the instrumentation switch (--stlimit): Icon &trace rides the call/return hooks that are off by default since SCRIP 2026-09-24 (Lon: monitor hooks behind the switch)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ REFUSE(2): no scrip at $SCRIP"; exit 2; }
command -v gcc >/dev/null || { echo "⛔ REFUSE(2): no gcc for mode 4"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/c1.icn" <<'ICN'
procedure main()
   &trace := -1;
   every foo(1 | 2 | 3);
end

procedure foo(x)
   return x;
end
ICN
cat > "$T/c1.want" <<'WANT'
c1.icn       :    3  | foo(1)
c1.icn       :    7  | foo returned 1
c1.icn       :    3  | foo(2)
c1.icn       :    7  | foo returned 2
c1.icn       :    3  | foo(3)
c1.icn       :    7  | foo returned 3
c1.icn       :    4  main failed
WANT
cat > "$T/c2.icn" <<'ICN'
procedure main()
   every foo(1 | 2 | 3);
end

procedure foo(x)
   if x = 3 then return 1 / 0;
   return x;
end
ICN
cat > "$T/c2.want" <<'WANT'

Run-time error 201
File c2.icn; Line 6
division by zero
Traceback:
main()
foo(3) from line 2 in c2.icn
{1 / 0} from line 6 in c2.icn
WANT
fail=0
for w in c1 c2; do
  ( cd "$T" && timeout -k 5 60 "$SCRIP" "$w.icn" </dev/null > "$w.m3" 2>&1 ); rc3=$?; python3 "$ROOT/../harness/scripts/util_render_error_voice.py" icon < "$T/$w.m3" > "$T/$w.m3.r" && mv "$T/$w.m3.r" "$T/$w.m3"
  if cmp -s "$T/$w.m3" "$T/$w.want"; then echo "  PASS  m3 $w (rc=$rc3)"; else echo "  FAIL  m3 $w rc=$rc3"; diff "$T/$w.want" "$T/$w.m3" | head -10 | sed 's/^/        /'; fail=1; fi
  if ( cd "$T" && "$SCRIP" --compile "$w.icn" > "$w.s" 2>/dev/null && gcc -c "$w.s" -o "$w.o" 2>/dev/null && gcc "$w.o" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$w.bin" 2>/dev/null ); then
    ( cd "$T" && timeout -k 5 60 "./$w.bin" </dev/null > "$w.m4" 2>&1 ); rc4=$?; python3 "$ROOT/../harness/scripts/util_render_error_voice.py" icon < "$T/$w.m4" > "$T/$w.m4.r" && mv "$T/$w.m4.r" "$T/$w.m4"
    if cmp -s "$T/$w.m4" "$T/$w.want"; then echo "  PASS  m4 $w (rc=$rc4)"; else echo "  FAIL  m4 $w rc=$rc4"; diff "$T/$w.want" "$T/$w.m4" | head -10 | sed 's/^/        /'; fail=1; fi
  else echo "  FAIL  m4 $w: no binary"; fail=1; fi
done
if [ "$fail" = 0 ]; then echo "✅ PASS: a call re-entered by backtracking reports its own call-site line -- in the &trace call line (c1) and in the traceback's caller line (c2), both modes"; exit 0; fi
echo "⛔ FAIL: a re-entered call is reporting the line last executed, not its call site (see the FAIL rows)"; exit 1
