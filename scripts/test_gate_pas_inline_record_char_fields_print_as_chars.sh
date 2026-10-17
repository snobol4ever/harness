#!/bin/bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_pas_inline_record_char_fields_print_as_chars.sh -- row pascal-p4-selfhost-compile-and-report (coo, 2026-09-12).
# A char field of a record declared inline in a var part printed its ordinal: the record-variable table carried no char flags (named record types did). The flags now ride from the pending fields onto the variable and the write path asks for them.
# Expected lines cut from fpc 3.2.2 -Miso on 2026-09-12. Hermetic: the oracle is never called.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SCRIP="${SCRIP:-$S4E/SCRIP/scrip}"
RT_DIR="${RT_DIR:-$(cd "$(dirname "$0")/../../SCRIP/out" && pwd)}"
. "$(dirname "$0")/lib_gate.sh"
gate_require_exec "$SCRIP" "the scrip compiler"
gate_require "$RT_DIR/libscrip_rt.so" "the runtime shared object out/libscrip_rt.so"
W=$(mktemp -d) || exit 2; trap 'rm -rf "$W"' EXIT
cat > "$W/g.pas" <<'PAS'
program cf2;
var q: record r: real; n: integer; c: char end;
begin q.r := 2.5; q.n := 3; q.c := 'k'; writeln(q.c); writeln(q.n, q.c); writeln(q.r:6:2, q.c); writeln(q.r:6:2, q.n, ' ', q.c) end.
PAS
cat > "$W/want" <<'REF'
k
          3k
  2.50k
  2.50          3 k
REF
IN=/dev/null
PASS=0; FAIL=0
m3=$(cd "$W" && timeout -k 5 8s "$SCRIP" --run "$W/g.pas" < "$IN" 2>&1)
if [ "$m3" = "$(cat "$W/want")" ]; then echo "PASS m3"; PASS=$((PASS+1)); else echo "FAIL m3"; diff <(echo "$m3") "$W/want" | head; FAIL=$((FAIL+1)); fi
( cd "$W" && timeout -k 5 8s "$SCRIP" --compile g.pas < /dev/null > g.s 2>/dev/null && gcc -c g.s -o g.o 2>/dev/null && gcc g.o -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" -o g.bin 2>/dev/null ) || { echo "FAIL m4 (build)"; FAIL=$((FAIL+1)); }
if [ -x "$W/g.bin" ]; then m4=$(cd "$W" && timeout -k 5 8s ./g.bin < "$IN" 2>&1)
  if [ "$m4" = "$(cat "$W/want")" ]; then echo "PASS m4"; PASS=$((PASS+1)); else echo "FAIL m4"; diff <(echo "$m4") "$W/want" | head; FAIL=$((FAIL+1)); fi; fi
echo "cf2: PASS=$PASS FAIL=$FAIL (population: 1 program x 2 modes)"
if [ $FAIL -eq 0 ] && [ $PASS -eq 2 ]; then echo "GATE PASS(0) [pas_inline_record_char_fields_print_as_chars]: 2/2 modes"; exit 0; else echo "GATE RED [pas_inline_record_char_fields_print_as_chars]: $FAIL red of 2"; exit 1; fi
