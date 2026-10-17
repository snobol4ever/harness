#!/bin/bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_pas_five_or_more_parameters_arrive.sh -- row pascal-procedure-with-five-or-more-parameters-arrives-empty
# (coo, 2026-09-12; seat08's FINDING of 2026-09-03). A Pascal procedure or function with five or more parameters
# received every parameter EMPTY in both modes: bb_call_proc_staged.cpp's zeta-read branch, for a statically known
# callee with more than four arguments, called rt_proc_call_open_det(idx, nargs) without first staging the arguments
# through rt_arg_stage (the branch's dynamic-callee case and the Icon path both stage), so the callee's prologue read
# an unstaged g_call_args. Witnesses: a five-parameter procedure, an eight-parameter procedure (the "eight" witness
# the row's DONE-WHEN names), a six-parameter function, and a nested call chain. Expected lines cut from
# fpc 3.2.2 -Miso on 2026-09-12. Hermetic: the oracle is never called.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SCRIP="${SCRIP:-$S4E/SCRIP/scrip}"
. "$(dirname "$0")/lib_gate.sh"
gate_require_exec "$SCRIP" "the scrip compiler"
gate_require "${RT_DIR:-$(dirname "$0")/../../SCRIP/out}/libscrip_rt.so" "the runtime shared object out/libscrip_rt.so"
W=$(mktemp -d) || exit 2; trap 'rm -rf "$W"' EXIT
cat > "$W/g.pas" <<'PAS'
program g;
var t: integer;
procedure five(p1, p2, p3, p4, p5: integer);
begin writeln(p1, p5) end;
procedure eight(a, b, c, d, e, f, g, h: integer);
begin writeln(a, b, c); writeln(d, e, f); writeln(g, h) end;
function six(a, b, c, d, e, f: integer): integer;
begin six := a + b + c + d + e + f end;
procedure outer(a, b, c, d, e: integer);
begin five(e, d, c, b, a); eight(a, b, c, d, e, a + 10, b + 10, c + 10) end;
begin
  five(1, 2, 3, 4, 5);
  eight(1, 2, 3, 4, 5, 6, 7, 8);
  t := six(1, 2, 3, 4, 5, 6); writeln(t);
  outer(11, 12, 13, 14, 15)
end.
PAS
cat > "$W/want" <<'REF'
          1          5
          1          2          3
          4          5          6
          7          8
         21
         15         11
         11         12         13
         14         15         21
         22         23
REF
PASS=0; FAIL=0
m3=$(timeout -k 5 8s "$SCRIP" --run "$W/g.pas" < /dev/null 2>&1)
if [ "$m3" = "$(cat "$W/want")" ]; then echo "PASS m3 (five, eight, six and nested witnesses)"; PASS=$((PASS+1)); else echo "FAIL m3"; diff <(echo "$m3") "$W/want" | head -20; FAIL=$((FAIL+1)); fi
( cd "$W" && timeout -k 5 8s "$SCRIP" --compile g.pas < /dev/null > g.s 2>/dev/null && gcc -c g.s -o g.o 2>/dev/null && gcc g.o -L"$S4E/SCRIP/out" -lscrip_rt -lm -Wl,-rpath,"$S4E/SCRIP/out" -o g.bin 2>/dev/null ) || { echo "FAIL m4 (build)"; FAIL=$((FAIL+1)); }
if [ -x "$W/g.bin" ]; then m4=$(cd "$W" && timeout -k 5 8s ./g.bin < /dev/null 2>&1)
  if [ "$m4" = "$(cat "$W/want")" ]; then echo "PASS m4 (five, eight, six and nested witnesses)"; PASS=$((PASS+1)); else echo "FAIL m4"; diff <(echo "$m4") "$W/want" | head -20; FAIL=$((FAIL+1)); fi; fi
echo "pas-five-or-more-parameters-arrive: PASS=$PASS FAIL=$FAIL (population: 1 program x 2 modes, 9 expected lines each; the eight-parameter witness is eight(1..8))"
if [ $FAIL -eq 0 ] && [ $PASS -eq 2 ]; then echo "GATE PASS(0) [pas_five_or_more_parameters_arrive]: 2/2 modes"; exit 0; else echo "GATE RED [pas_five_or_more_parameters_arrive]: $FAIL red of 2"; exit 1; fi
