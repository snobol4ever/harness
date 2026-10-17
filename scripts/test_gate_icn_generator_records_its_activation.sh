#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ REFUSE(2): no scrip at $SCRIP"; exit 2; }
command -v gcc >/dev/null || { echo "⛔ REFUSE(2): no gcc for mode 4"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/g3.icn" <<'ICN'
procedure main()
   write(f(3));
end
procedure f(n)
   local v;
   every v := g(n) do
      write("f ", v);
   return "end";
end
procedure g(m)
   local w;
   w := m + 1;
   suspend w;
   suspend 1 / 0;
end
ICN
cat > "$T/g3.want" <<'WANT'
f 4

Run-time error 201
File g3.icn; Line 14
division by zero
Traceback:
main()
f(3) from line 2 in g3.icn
g(3) from line 6 in g3.icn
{1 / 0} from line 14 in g3.icn
WANT
cat > "$T/g4.icn" <<'ICN'
procedure main()
   local x;
   every x := outer(2) do write("main got ", x);
   write("done");
end
procedure outer(n)
   local a, b;
   a := n * 10;
   b := "gen";
   suspend inner(a);
   display(3, &output);
   suspend a + 1;
end
procedure inner(k)
   local q;
   q := k + 5;
   suspend q;
end
ICN
cat > "$T/g4.want" <<'WANT'
main got 25
co-expression_1(1)

outer local identifiers:
   n = 2
   a = 20
   b = "gen"
main local identifiers:
   x = 25

global identifiers:
   display = function display
   inner = procedure inner
   main = procedure main
   outer = procedure outer
   write = function write
main got 21
done
WANT
fail=0
for w in g3 g4; do
  ( cd "$T" && timeout -k 5 60 "$SCRIP" "$w.icn" </dev/null > "$w.m3" 2>&1 ); rc3=$?; python3 "$ROOT/../harness/scripts/util_render_error_voice.py" icon < "$T/$w.m3" > "$T/$w.m3.r" && mv "$T/$w.m3.r" "$T/$w.m3"
  if cmp -s "$T/$w.m3" "$T/$w.want"; then echo "  PASS  m3 $w (rc=$rc3)"; else echo "  FAIL  m3 $w rc=$rc3"; diff "$T/$w.want" "$T/$w.m3" | head -8 | sed 's/^/        /'; fail=1; fi
  if ( cd "$T" && "$SCRIP" --compile "$w.icn" > "$w.s" 2>/dev/null && gcc -c "$w.s" -o "$w.o" 2>/dev/null && gcc "$w.o" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$w.bin" 2>/dev/null ); then
    ( cd "$T" && timeout -k 5 60 "./$w.bin" </dev/null > "$w.m4" 2>&1 ); rc4=$?; python3 "$ROOT/../harness/scripts/util_render_error_voice.py" icon < "$T/$w.m4" > "$T/$w.m4.r" && mv "$T/$w.m4.r" "$T/$w.m4"
    if cmp -s "$T/$w.m4" "$T/$w.want"; then echo "  PASS  m4 $w (rc=$rc4)"; else echo "  FAIL  m4 $w rc=$rc4"; diff "$T/$w.want" "$T/$w.m4" | head -8 | sed 's/^/        /'; fail=1; fi
  else echo "  FAIL  m4 $w: no binary"; fail=1; fi
done
if [ "$fail" = 0 ]; then echo "✅ PASS: a generator records its activation -- the traceback carries every live frame (main -> f -> g) and display reads a generator's locals"; exit 0; fi
echo "⛔ FAIL: a generator frame is missing from the record (see the FAIL rows)"; exit 1
