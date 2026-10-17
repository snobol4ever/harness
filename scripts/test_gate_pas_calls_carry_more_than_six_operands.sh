#!/bin/bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_pas_calls_carry_more_than_six_operands.sh -- row pascal-write-multi-formatted-real-corrupts-non-first-args
# (coo, 2026-09-12). ONE root under four symptoms: the emitter's per-operand zeta-read arrays (op_zread, op_zkind,
# op_zread_xf in emit.h; g_zd_read/g_zd_kind/g_zd_anchor in emit.cpp) were sized 6 and indexed by the raw operand
# index, so every call node with more than six operands read its 7th operand onward from whatever sat after the
# array (seat15's trace in the baton). In Pascal that is: writeln with four or more items (two operands per item),
# a set constructor with seven or more members, and the row's own witness of several width:decimals reals.
# NOT covered here: a user procedure with five or more parameters arrives empty on origin 5eeeb3a47 too (seat08's
# FINDING of 2026-09-03), a second root on the callee side -- its own row and gate. Expected lines cut from fpc 3.2.2 -Miso on 2026-09-12 (p8.oracle, w7.oracle
# in the coo's scratchpad, reproduced here verbatim). Hermetic: the oracle is never called.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SCRIP="${SCRIP:-$S4E/SCRIP/scrip}"
. "$(dirname "$0")/lib_gate.sh"
gate_require_exec "$SCRIP" "the scrip compiler"
gate_require "${RT_DIR:-$(dirname "$0")/../../SCRIP/out}/libscrip_rt.so" "the runtime shared object out/libscrip_rt.so"
W=$(mktemp -d) || exit 2; trap 'rm -rf "$W"' EXIT
cat > "$W/g.pas" <<'PAS'
program g;
var s: set of 1..20; y, x, z: real;
begin
  s := [1, 3, 5, 7, 9, 11, 13];
  if 13 in s then writeln('13 in') else writeln('13 out');
  if 11 in s then writeln('11 in') else writeln('11 out');
  writeln(1.5:1:1, 2.5:1:1, 3.5:1:1, 4.5:1:1);
  y := 1.0; x := 2.0; z := 3.0; write(y:1:1, x:1:1, z:1:1); writeln;
  writeln(1, ' ', 2, ' ', 3, ' ', 4);
  writeln(1, ' ', 2, ' ', 3, ' ', 4, ' ', 5)
end.
PAS
cat > "$W/want" <<'REF'
13 in
11 in
1.52.53.54.5
1.02.03.0
          1           2           3           4
          1           2           3           4           5
REF
PASS=0; FAIL=0
m3=$(timeout -k 5 8s "$SCRIP" --run "$W/g.pas" < /dev/null 2>&1)
if [ "$m3" = "$(cat "$W/want")" ]; then echo "PASS m3"; PASS=$((PASS+1)); else echo "FAIL m3"; diff <(echo "$m3") "$W/want" | head -20; FAIL=$((FAIL+1)); fi
( cd "$W" && timeout -k 5 8s "$SCRIP" --compile g.pas < /dev/null > g.s 2>/dev/null && gcc -c g.s -o g.o 2>/dev/null && gcc g.o -L"$S4E/SCRIP/out" -lscrip_rt -lm -Wl,-rpath,"$S4E/SCRIP/out" -o g.bin 2>/dev/null ) || { echo "FAIL m4 (build)"; FAIL=$((FAIL+1)); }
if [ -x "$W/g.bin" ]; then m4=$(cd "$W" && timeout -k 5 8s ./g.bin < /dev/null 2>&1)
  if [ "$m4" = "$(cat "$W/want")" ]; then echo "PASS m4"; PASS=$((PASS+1)); else echo "FAIL m4"; diff <(echo "$m4") "$W/want" | head -20; FAIL=$((FAIL+1)); fi; fi
echo "pas-calls-carry-more-than-six-operands: PASS=$PASS FAIL=$FAIL (population: 1 program x 2 modes, 6 expected lines each)"
[ $FAIL -eq 0 ] && [ $PASS -eq 2 ]
