#!/bin/bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_pas_read_at_end_of_line_yields_a_space.sh -- row pascal-p4-selfhost-compile-and-report (coo, 2026-09-12).
# ISO 7185 6.6.6.5: when eoln is true the buffer variable is a space; read(ch) at end of line yields ' ' and moves on. SCRIP handed back the newline itself; P4's scanner classified it illegal on every line. The witness reads 'ab' and 'c' and prints each ord with eoln beside it.
# Expected lines cut from fpc 3.2.2 -Miso on 2026-09-12. Hermetic: the oracle is never called.
# ⛔ RE-CUT 2026-09-26 (hq_pascal, SCRIP 33d239c85): the program asked eoln(input) once more after reading the final end-of-line, i.e. at
# end-of-file, which ISO 7185 6.6.6.5 makes an error (fpc -Miso answers true; SCRIP now stops, as PAT iso7185prt1866 requires). That call
# was incidental to what this gate tests, so the program asks eoln only while not eof and the lines are re-cut from fpc 3.2.2 -Miso.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SCRIP="${SCRIP:-$S4E/SCRIP/scrip}"
RT_DIR="${RT_DIR:-$(cd "$(dirname "$0")/../../SCRIP/out" && pwd)}"
. "$(dirname "$0")/lib_gate.sh"
gate_require_exec "$SCRIP" "the scrip compiler"
gate_require "$RT_DIR/libscrip_rt.so" "the runtime shared object out/libscrip_rt.so"
W=$(mktemp -d) || exit 2; trap 'rm -rf "$W"' EXIT
cat > "$W/g.pas" <<'PAS'
program eolc;
var ch: char; n: integer;
begin n := 0;
  while not eof(input) do begin read(input, ch); n := n + 1; write(ord(ch):4); if not eof(input) then write(eoln(input):6) end;
  writeln; writeln(n)
end.
PAS
cat > "$W/want" <<'REF'
  97 false  98  true  32 false  99  true  32
          5
REF
cat > "$W/in.txt" <<'INP'
ab
c
INP
IN="$W/in.txt"
PASS=0; FAIL=0
m3=$(cd "$W" && timeout -k 5 8s "$SCRIP" --run "$W/g.pas" < "$IN" 2>&1)
if [ "$m3" = "$(cat "$W/want")" ]; then echo "PASS m3"; PASS=$((PASS+1)); else echo "FAIL m3"; diff <(echo "$m3") "$W/want" | head; FAIL=$((FAIL+1)); fi
( cd "$W" && timeout -k 5 8s "$SCRIP" --compile g.pas < /dev/null > g.s 2>/dev/null && gcc -c g.s -o g.o 2>/dev/null && gcc g.o -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" -o g.bin 2>/dev/null ) || { echo "FAIL m4 (build)"; FAIL=$((FAIL+1)); }
if [ -x "$W/g.bin" ]; then m4=$(cd "$W" && timeout -k 5 8s ./g.bin < "$IN" 2>&1)
  if [ "$m4" = "$(cat "$W/want")" ]; then echo "PASS m4"; PASS=$((PASS+1)); else echo "FAIL m4"; diff <(echo "$m4") "$W/want" | head; FAIL=$((FAIL+1)); fi; fi
echo "eolc: PASS=$PASS FAIL=$FAIL (population: 1 program x 2 modes)"
if [ $FAIL -eq 0 ] && [ $PASS -eq 2 ]; then echo "GATE PASS(0) [pas_read_at_end_of_line_yields_a_space]: 2/2 modes"; exit 0; else echo "GATE RED [pas_read_at_end_of_line_yields_a_space]: $FAIL red of 2"; exit 1; fi
