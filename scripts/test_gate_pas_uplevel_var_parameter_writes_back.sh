#!/bin/bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_pas_uplevel_var_parameter_writes_back.sh -- row pascal-p4-selfhost-compile-and-report (coo, 2026-09-12).
# A nested procedure passing its ENCLOSING procedure's local by reference got no write-back: the emitter resolved a VAR_REF only as a global cell or an own-frame slot and an uplevel name fell to the anonymous fresh-cell path; the marshaller now emits a frame-aware VAR_REF (owner and level, as VAR_FRAME carries) and bb_var_ref_frame yields the cell pointer into the owner's frame through the display. P4's searchid([vars], lcp) with lcp statement's local; the witness prints 7 42 then 42.
# Expected lines cut from fpc 3.2.2 -Miso on 2026-09-12. Hermetic: the oracle is never called.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SCRIP="${SCRIP:-$S4E/SCRIP/scrip}"
RT_DIR="${RT_DIR:-$(cd "$(dirname "$0")/../../SCRIP/out" && pwd)}"
. "$(dirname "$0")/lib_gate.sh"
gate_require_exec "$SCRIP" "the scrip compiler"
gate_require "$RT_DIR/libscrip_rt.so" "the runtime shared object out/libscrip_rt.so"
W=$(mktemp -d) || exit 2; trap 'rm -rf "$W"' EXIT
cat > "$W/g.pas" <<'PAS'
program upref;
type ctp = ^rec; rec = record idtype: integer end;
var g: integer;
procedure statement;
var lcp: ctp; n: integer;
  procedure searchid(k: integer; var fcp: ctp);
  begin new(fcp); fcp^.idtype := k end;
  procedure setn(var x: integer);
  begin x := 42 end;
  procedure forstatement;
  begin searchid(7, lcp); setn(n); writeln(lcp^.idtype, n) end;
begin lcp := nil; n := 0; forstatement; writeln(n) end;
begin statement end.
PAS
cat > "$W/want" <<'REF'
          7         42
         42
REF
IN=/dev/null
PASS=0; FAIL=0
m3=$(cd "$W" && timeout -k 5 8s "$SCRIP" --run "$W/g.pas" < "$IN" 2>&1)
if [ "$m3" = "$(cat "$W/want")" ]; then echo "PASS m3"; PASS=$((PASS+1)); else echo "FAIL m3"; diff <(echo "$m3") "$W/want" | head; FAIL=$((FAIL+1)); fi
( cd "$W" && timeout -k 5 8s "$SCRIP" --compile g.pas < /dev/null > g.s 2>/dev/null && gcc -c g.s -o g.o 2>/dev/null && gcc g.o -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" -o g.bin 2>/dev/null ) || { echo "FAIL m4 (build)"; FAIL=$((FAIL+1)); }
if [ -x "$W/g.bin" ]; then m4=$(cd "$W" && timeout -k 5 8s ./g.bin < "$IN" 2>&1)
  if [ "$m4" = "$(cat "$W/want")" ]; then echo "PASS m4"; PASS=$((PASS+1)); else echo "FAIL m4"; diff <(echo "$m4") "$W/want" | head; FAIL=$((FAIL+1)); fi; fi
echo "upref: PASS=$PASS FAIL=$FAIL (population: 1 program x 2 modes)"
if [ $FAIL -eq 0 ] && [ $PASS -eq 2 ]; then echo "GATE PASS(0) [pas_uplevel_var_parameter_writes_back]: 2/2 modes"; exit 0; else echo "GATE RED [pas_uplevel_var_parameter_writes_back]: $FAIL red of 2"; exit 1; fi
