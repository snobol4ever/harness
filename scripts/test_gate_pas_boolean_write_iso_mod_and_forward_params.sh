#!/bin/bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_pas_boolean_write_iso_mod_and_forward_params.sh -- three Pascal-rungs reds cured together (coo, row
# pascal-ladder-every-feature-in-isolation-with-variations, 2026-09-12; ladder rungs 01, 02, 05):
#   1. write(<Boolean>) prints the word true/false, right-justified in a default field of 5, an explicit width
#      pads or truncates like a string (fpc 3.2.2 -Miso measured 2026-09-12 16:0x CDT: " true", "false",
#      "    true" at :8, "t" at :1, "" at :0); a Boolean is a variable/parameter/function of type boolean or an
#      alias of it, a relation, not/and/or of Booleans, in, eof, eoln, and the literals true/false.
#   2. i mod j for j > 0 lies in 0..j-1 (ISO 7185 6.7.2.2; fpc -Miso: i := -7; i mod 2 = 1). Note that
#      -7 mod 2 as a LITERAL expression is -(7 mod 2) = -1 by precedence, the oracle agrees.
#   3. a procedure/function declared forward keeps its formal parameter list when the body is given
#      without one (ISO 7185 6.6.1; the body of "procedure announce(n: integer); forward;" is
#      "procedure announce; begin ... n ... end;").
# Every expected string below was cut from fpc -Miso on the same program (the oracle receipt is in the
# header line above); the gate is hermetic and never calls the oracle.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SCRIP="${SCRIP:-$S4E/SCRIP/scrip}"
. "$(dirname "$0")/lib_gate.sh"
gate_require_exec "$SCRIP" "the scrip compiler"
gate_require "${RT_DIR:-$(dirname "$0")/../../SCRIP/out}/libscrip_rt.so" "the runtime shared object out/libscrip_rt.so"
W=$(mktemp -d) || exit 2; trap 'rm -rf "$W"' EXIT
cat > "$W/g.pas" <<'PAS'
program g;
type flag = boolean;
var b: boolean; f: flag; i: integer;
function isbig(n: integer): boolean; forward;
procedure announce(n: integer; var k: integer); forward;
function isbig;
begin isbig := n > 100 end;
procedure announce;
begin writeln('n=', n); k := n + 1 end;
begin
  b := true; f := false; i := -7;
  writeln(b); writeln(f); writeln(true); writeln(false);
  writeln(b:8); writeln(b:1); writeln(b:0); write(b); writeln('|');
  writeln(i > 2); writeln(odd(i) and b); writeln(not b); writeln(isbig(101)); writeln(isbig(1) or b);
  writeln(i mod 2); writeln(i mod 3); writeln(-8 mod 3); writeln(8 mod 3); writeln(7 mod 2);
  announce(42, i); writeln(i)
end.
PAS
cat > "$W/want" <<'REF'
 true
false
 true
false
    true
t

 true|
false
 true
false
 true
 true
          1
          2
         -2
          2
          1
n=         42
         43
REF
PASS=0; FAIL=0
m3=$(timeout -k 5 8s "$SCRIP" --run "$W/g.pas" < /dev/null 2>&1)
if [ "$m3" = "$(cat "$W/want")" ]; then echo "PASS m3"; PASS=$((PASS+1)); else echo "FAIL m3"; diff <(echo "$m3") "$W/want" | head -20; FAIL=$((FAIL+1)); fi
( cd "$W" && timeout -k 5 8s "$SCRIP" --compile g.pas < /dev/null > g.s 2>/dev/null && gcc -c g.s -o g.o 2>/dev/null && gcc g.o -L"$S4E/SCRIP/out" -lscrip_rt -lm -Wl,-rpath,"$S4E/SCRIP/out" -o g.bin 2>/dev/null ) || { echo "FAIL m4 (build)"; FAIL=$((FAIL+1)); }
if [ -x "$W/g.bin" ]; then m4=$(cd "$W" && timeout -k 5 8s ./g.bin < /dev/null 2>&1)
  if [ "$m4" = "$(cat "$W/want")" ]; then echo "PASS m4"; PASS=$((PASS+1)); else echo "FAIL m4"; diff <(echo "$m4") "$W/want" | head -20; FAIL=$((FAIL+1)); fi; fi
echo "pas-boolean-write-iso-mod-forward-params: PASS=$PASS FAIL=$FAIL (population: 1 program x 2 modes, 20 expected lines each)"
[ $FAIL -eq 0 ] && [ $PASS -eq 2 ]
