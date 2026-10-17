#!/bin/bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_pas_declared_locals_get_frame_slots.sh -- row pascal-p4-selfhost-compile-and-report, first cure (coo, 2026-09-12).
# An outer procedure's DECLARED local that only its nested procedures reference got no frame slot: frame_layout.c
# allocates slots for the names the owner's own IR nodes mention, so a grandchild's assignment to it hit
# bb_assign_frame's "owner vslot unresolved" bomb at run time (P4's fieldlist writing block's Boolean `test` -- the
# P4 compiler died listing line 98 of its own source). The Pascal lowerer now publishes its declared locals on the
# graph (lnames/nlocals, the Icon lowerer's own shape) and the allocator seeds a slot for each on graphs the Pascal
# lowerer stamps caller_frame. Expected lines cut from fpc 3.2.2 -Miso on 2026-09-12. Hermetic: the oracle is never called.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SCRIP="${SCRIP:-$S4E/SCRIP/scrip}"
RT_DIR="${RT_DIR:-$(cd "$(dirname "$0")/../../SCRIP/out" && pwd)}"
. "$(dirname "$0")/lib_gate.sh"
gate_require_exec "$SCRIP" "the scrip compiler"
gate_require "$RT_DIR/libscrip_rt.so" "the runtime shared object out/libscrip_rt.so"
W=$(mktemp -d) || exit 2; trap 'rm -rf "$W"' EXIT
cat > "$W/g.pas" <<'PAS'
program declaredlocals;
var sy: integer;
procedure block;
var test: boolean; n: integer; c: char;
  procedure typ;
    procedure fieldlist;
    begin test := sy = 7; n := n + 5; c := 'q' end;
  begin fieldlist end;
  procedure report;
  begin if test then writeln('yes ', n, ' ', c) else writeln('no ', n, ' ', c) end;
begin n := 0; sy := 7; typ; report; sy := 8; typ; report end;
begin block end.
PAS
printf 'yes           5 q\nno          10 q\n' > "$W/want"
PASS=0; FAIL=0
m3=$(timeout -k 5 8s "$SCRIP" --run "$W/g.pas" < /dev/null 2>&1)
if [ "$m3" = "$(cat "$W/want")" ]; then echo "PASS m3"; PASS=$((PASS+1)); else echo "FAIL m3"; diff <(echo "$m3") "$W/want" | head; FAIL=$((FAIL+1)); fi
( cd "$W" && timeout -k 5 8s "$SCRIP" --compile g.pas < /dev/null > g.s 2>/dev/null && gcc -c g.s -o g.o 2>/dev/null && gcc g.o -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$(cd "$RT_DIR" && pwd)" -o g.bin 2>/dev/null ) || { echo "FAIL m4 (build)"; FAIL=$((FAIL+1)); }
if [ -x "$W/g.bin" ]; then m4=$(cd "$W" && timeout -k 5 8s ./g.bin < /dev/null 2>&1)
  if [ "$m4" = "$(cat "$W/want")" ]; then echo "PASS m4"; PASS=$((PASS+1)); else echo "FAIL m4"; diff <(echo "$m4") "$W/want" | head; FAIL=$((FAIL+1)); fi; fi
echo "pas-declared-locals-get-frame-slots: PASS=$PASS FAIL=$FAIL (population: 1 program x 2 modes, 2 expected lines each)"
if [ $FAIL -eq 0 ] && [ $PASS -eq 2 ]; then echo "GATE PASS(0) [pas_declared_locals_get_frame_slots]: 2/2 modes"; exit 0; else echo "GATE RED [pas_declared_locals_get_frame_slots]: $FAIL red of 2"; exit 1; fi
