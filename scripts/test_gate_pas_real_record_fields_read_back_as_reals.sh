#!/bin/bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_pas_real_record_fields_read_back_as_reals.sh -- row pascal-p4-selfhost-compile-and-report, third cure (coo, 2026-09-12).
# A record is a SOH-joined string of its fields; the segment decoder (elem_to_descr) turned an integer-looking segment
# back into an integer but left a real-looking one as a string, so q.r := 2.5 read back as "2.5": writeln(q.r:6:2)
# printed 0.00 and a same-named field (r.r, P5's getrel) reached the lowerer nameless. The decoder now returns a real
# for a segment that parses whole as a real and carries a point or an exponent. Expected lines cut from fpc 3.2.2 -Miso
# on 2026-09-12 (formatted reals only; the unformatted real shape is ISO-delegated, ARCH-LANGUAGES.md). Hermetic.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SCRIP="${SCRIP:-$S4E/SCRIP/scrip}"
RT_DIR="${RT_DIR:-$(cd "$(dirname "$0")/../../SCRIP/out" && pwd)}"
. "$(dirname "$0")/lib_gate.sh"
gate_require_exec "$SCRIP" "the scrip compiler"
gate_require "$RT_DIR/libscrip_rt.so" "the runtime shared object out/libscrip_rt.so"
W=$(mktemp -d) || exit 2; trap 'rm -rf "$W"' EXIT
cat > "$W/g.pas" <<'PAS'
program realrec;
type valu = record case boolean of true: (ival: integer); false: (rval: real) end;
var q: record r: real; n: integer end; v: valu; s: real;
procedure p;
var r: record case boolean of true: (r: real); false: (b: packed array [1..8] of 0..255) end;
begin r.r := 1.5; writeln(r.r:6:2) end;
begin
  q.r := 2.5; q.n := 3; s := q.r * 2;
  writeln(s:6:2); writeln(q.r:6:2, q.n);
  v.rval := 0.25; writeln(v.rval:8:3); v.ival := 7; writeln(v.ival);
  p
end.
PAS
printf '  5.00\n  2.50          3\n   0.250\n          7\n  1.50\n' > "$W/want"
PASS=0; FAIL=0
m3=$(cd "$W" && timeout -k 5 8s "$SCRIP" --run "$W/g.pas" < /dev/null 2>&1)
if [ "$m3" = "$(cat "$W/want")" ]; then echo "PASS m3"; PASS=$((PASS+1)); else echo "FAIL m3"; diff <(echo "$m3") "$W/want" | head; FAIL=$((FAIL+1)); fi
( cd "$W" && timeout -k 5 8s "$SCRIP" --compile g.pas < /dev/null > g.s 2>/dev/null && gcc -c g.s -o g.o 2>/dev/null && gcc g.o -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" -o g.bin 2>/dev/null ) || { echo "FAIL m4 (build)"; FAIL=$((FAIL+1)); }
if [ -x "$W/g.bin" ]; then m4=$(cd "$W" && timeout -k 5 8s ./g.bin < /dev/null 2>&1)
  if [ "$m4" = "$(cat "$W/want")" ]; then echo "PASS m4"; PASS=$((PASS+1)); else echo "FAIL m4"; diff <(echo "$m4") "$W/want" | head; FAIL=$((FAIL+1)); fi; fi
echo "pas-real-record-fields-read-back-as-reals: PASS=$PASS FAIL=$FAIL (population: 1 program x 2 modes, 5 expected lines each)"
if [ $FAIL -eq 0 ] && [ $PASS -eq 2 ]; then echo "GATE PASS(0) [pas_real_record_fields_read_back_as_reals]: 2/2 modes"; exit 0; else echo "GATE RED [pas_real_record_fields_read_back_as_reals]: $FAIL red of 2"; exit 1; fi
