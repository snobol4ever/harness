#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ REFUSE(2): no scrip at $SCRIP"; exit 2; }
command -v gcc >/dev/null || { echo "⛔ REFUSE(2): no gcc for mode 4"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
# Witnesses (wants cut from icont/iconx 9.5.25a): an Icon procedure reads its statics and initial flags through r9, the global-cell
# base the RTCC bank keeps live across Icon code and reloads after each runtime call.  ENTRY (s2 s3: a generator with a static,
# called through a reassigned global and through a procedure variable -- the IPL procs/iftrace, reassign, regexp and sentence shape):
# b1bee0c53 took the prologue's one runtime call away, so a procedure entered from a C road on its coroutine thread read r9 as C
# left it; the prologue now reloads r9.  RESUME (s5 s7 s8: a generator applied with ! or called by value inside a generator, resumed
# for its second value): older than the block protocol, the resume label reloaded nothing; it now reloads r9.
cat > "$T/s2.icn" <<'ICN'
procedure main()
   abs :=: Abs;
   write(abs(-5));
   every write(abs(-6));
end
procedure Abs(a1)
   static f;
   initial f := proc("abs", 0);
   suspend f(a1);
end
ICN
cat > "$T/s2.want" <<'WANT'
5
6
WANT
cat > "$T/s3.icn" <<'ICN'
procedure main()
   local p;
   p := G;
   write(p(-5));
   every write(p(-6));
end
procedure G(a1)
   static f;
   initial f := proc("abs", 0);
   suspend f(a1);
end
ICN
cat > "$T/s3.want" <<'WANT'
5
6
WANT
cat > "$T/s5.icn" <<'ICN'
procedure main()
   write("F"(2));
   every write("G"(3));
   write(F ! [4]);
   every write(G ! [5]);
   every write(H(6));
end
procedure F(a)
   static s;
   initial s := proc("abs", 0);
   return s(-a);
end
procedure G(a)
   static t;
   initial t := 100;
   suspend t + a | t - a;
end
procedure H(a)
   local p;
   p := G;
   suspend p(a);
end
ICN
cat > "$T/s5.want" <<'WANT'
2
103
97
4
105
95
106
94
WANT
cat > "$T/s7.icn" <<'ICN'
procedure main()
   every write(G ! [5]);
end
procedure F(a)
   static s;
   initial s := proc("abs", 0);
   return s(-a);
end
procedure G(a)
   static t;
   initial t := 100;
   suspend t + a | t - a;
end
procedure H(a)
   local p;
   p := G;
   suspend p(a);
end
ICN
cat > "$T/s7.want" <<'WANT'
105
95
WANT
cat > "$T/s8.icn" <<'ICN'
procedure main()
   every write(H(6));
end
procedure F(a)
   static s;
   initial s := proc("abs", 0);
   return s(-a);
end
procedure G(a)
   static t;
   initial t := 100;
   suspend t + a | t - a;
end
procedure H(a)
   local p;
   p := G;
   suspend p(a);
end
ICN
cat > "$T/s8.want" <<'WANT'
106
94
WANT
fail=0
for w in s2 s3 s5 s7 s8; do
  SW=""
  ( cd "$T" && timeout -k 5 60 "$SCRIP" $SW "$w.icn" </dev/null > "$w.m3" 2>&1 ); rc3=$?; python3 "$ROOT/../harness/scripts/util_render_error_voice.py" icon < "$T/$w.m3" > "$T/$w.m3.r" && mv "$T/$w.m3.r" "$T/$w.m3"
  if cmp -s "$T/$w.m3" "$T/$w.want"; then echo "  PASS  m3 $w (rc=$rc3)"; else echo "  FAIL  m3 $w rc=$rc3"; diff "$T/$w.want" "$T/$w.m3" | head -6 | sed 's/^/        /'; fail=1; fi
  if ( cd "$T" && "$SCRIP" $SW --compile "$w.icn" > "$w.s" 2>/dev/null && gcc -c "$w.s" -o "$w.o" 2>/dev/null && gcc "$w.o" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$w.bin" 2>/dev/null ); then
    ( cd "$T" && timeout -k 5 60 "./$w.bin" </dev/null > "$w.m4" 2>&1 ); rc4=$?; python3 "$ROOT/../harness/scripts/util_render_error_voice.py" icon < "$T/$w.m4" > "$T/$w.m4.r" && mv "$T/$w.m4.r" "$T/$w.m4"
    if cmp -s "$T/$w.m4" "$T/$w.want"; then echo "  PASS  m4 $w (rc=$rc4)"; else echo "  FAIL  m4 $w rc=$rc4"; diff "$T/$w.want" "$T/$w.m4" | head -6 | sed 's/^/        /'; fail=1; fi
  else echo "  FAIL  m4 $w: no binary"; fail=1; fi
done
if [ "$fail" = 0 ]; then echo "✅ PASS: a procedure entered or a generator resumed from a C road reads its statics: r9 is reloaded at entry and at the resume label (2 entry witnesses, 3 resume witnesses, both modes)"; exit 0; fi
echo "⛔ FAIL: a procedure entered or resumed from a C road reads its statics through a stale r9 (see the FAIL rows)"; exit 1
