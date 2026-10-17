#!/bin/bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_pas_pack_unpack_and_text_get_put.sh -- row pascal-p4-selfhost-compile-and-report (coo, 2026-09-12).
# pack(a, i, z) and unpack(z, a, i) (ISO 6.6.5.4) lower to a loop of element copies over z's bounds with a synthetic control variable the 6.8.3.9 checker ignores; on a text file f^ peeks the next character, get(f) consumes one, f^ := c stores into a per-handle buffer and put(f) writes it; an unopened file is runtime error 103, as fpc -Miso gives. P4's int.p uses all of them (pack(word, 1, name); getfile/putfile).
# Expected lines cut from fpc 3.2.2 -Miso on 2026-09-12. Hermetic: the oracle is never called.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SCRIP="${SCRIP:-$S4E/SCRIP/scrip}"
RT_DIR="${RT_DIR:-$(cd "$(dirname "$0")/../../SCRIP/out" && pwd)}"
. "$(dirname "$0")/lib_gate.sh"
gate_require_exec "$SCRIP" "the scrip compiler"
gate_require "$RT_DIR/libscrip_rt.so" "the runtime shared object out/libscrip_rt.so"
W=$(mktemp -d) || exit 2; trap 'rm -rf "$W"' EXIT
cat > "$W/g.pas" <<'PAS'
program p4kit;
var a: array [1..10] of char; z: packed array [1..4] of char; i: integer; f: text; ch: char; n: integer;
begin
  for i := 1 to 10 do a[i] := chr(ord('a') + i - 1);
  pack(a, 3, z); writeln(z);
  z := 'WXYZ'; unpack(z, a, 6); for i := 1 to 10 do write(a[i]); writeln;
  rewrite(f); f^ := 'x'; put(f); f^ := 'y'; put(f); writeln(f, 'z');
  reset(f); n := 0; while not eof(f) do begin ch := f^; get(f); n := n + 1 end;
  writeln(n)
end.
PAS
cat > "$W/want" <<'REF'
cdef
abcdeWXYZj
          4
REF
IN=/dev/null
PASS=0; FAIL=0
m3=$(cd "$W" && timeout -k 5 8s "$SCRIP" --run "$W/g.pas" < "$IN" 2>&1)
if [ "$m3" = "$(cat "$W/want")" ]; then echo "PASS m3"; PASS=$((PASS+1)); else echo "FAIL m3"; diff <(echo "$m3") "$W/want" | head; FAIL=$((FAIL+1)); fi
( cd "$W" && timeout -k 5 8s "$SCRIP" --compile g.pas < /dev/null > g.s 2>/dev/null && gcc -c g.s -o g.o 2>/dev/null && gcc g.o -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" -o g.bin 2>/dev/null ) || { echo "FAIL m4 (build)"; FAIL=$((FAIL+1)); }
if [ -x "$W/g.bin" ]; then m4=$(cd "$W" && timeout -k 5 8s ./g.bin < "$IN" 2>&1)
  if [ "$m4" = "$(cat "$W/want")" ]; then echo "PASS m4"; PASS=$((PASS+1)); else echo "FAIL m4"; diff <(echo "$m4") "$W/want" | head; FAIL=$((FAIL+1)); fi; fi
echo "p4kit: PASS=$PASS FAIL=$FAIL (population: 1 program x 2 modes)"
if [ $FAIL -eq 0 ] && [ $PASS -eq 2 ]; then echo "GATE PASS(0) [pas_pack_unpack_and_text_get_put]: 2/2 modes"; exit 0; else echo "GATE RED [pas_pack_unpack_and_text_get_put]: $FAIL red of 2"; exit 1; fi
