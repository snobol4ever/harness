#!/usr/bin/env bash
# test_gate_pas_whole_array_into_a_record_field_round_trips.sh -- a whole array assigned into a record field must read back what was stored
#
# ROW pascal-a-whole-array-assigned-into-a-record-field-reads-back-wrong-collapse-pack-and-the-dense-field-interior-to-one-authority
# (hq_pascal 2026-09-20, ranked first by CEO-1021).  FAIL-ONCE ON ORIGIN 5418432bb: `r.name := t` and `p^.name := t` both read back
# `09899` where fpc -Miso reads `bcdefghi`, in BOTH modes, AT THE SHIPPED ARENA WITH NO STRESS -- a silent wrong answer, exit 0, no
# diagnostic, with no collector anywhere near it.
#
# THE MECHANISM THIS GATE HOLDS, so a future reader knows what it is protecting: a Pascal array value is a SOH-separated string, but a
# record FIELD INTERIOR is DENSE -- __pas_field_idx_set writes element n at byte offset n-1 with no separator.  __pas_ca_pack must
# therefore hand __pas_field_set a DENSE string and __pas_ca_unpack must explode a dense field back into SOH-separated elements.
# DENSE IS THE AUTHORITY because the per-element writer and the reader already agree on it (CEO-1021: collapse to the authority, do
# not synchronise the copies).  If someone makes pack separated again, the per-element form keeps working and only this gate trips.
#
# ⛔ THE FOUR ARMS ARE A BRACKET, NOT A SUITE: `plainarray` and `ptrperchar` were ALREADY CORRECT before the cure and are here as the
# CONTROL -- if a cure breaks them it traded one defect for another, and a gate that graded only the two broken forms could not say so.
# The ref is CUT FROM fpc -Miso at run time, never pinned by hand.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- the ref is CUT FROM THE ORACLE, never pinned by hand"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/w.pas" <<'PAS'
program w(output);
type
  str = packed array [1..8] of char;
  rec = record
    name: str
  end;
  link = ^rec;
var
  p: link;
  r: rec;
  a, t: str;
  j: integer;
begin
  for j := 1 to 8 do
    t[j] := chr(ord('a') + j);
  a := t;
  write('plainarray ');
  for j := 1 to 8 do write(a[j]);
  writeln;
  r.name := t;
  write('localrec   ');
  for j := 1 to 8 do write(r.name[j]);
  writeln;
  new(p);
  p^.name := t;
  write('ptrrec     ');
  for j := 1 to 8 do write(p^.name[j]);
  writeln;
  for j := 1 to 8 do
    p^.name[j] := t[j];
  write('ptrperchar ');
  for j := 1 to 8 do write(p^.name[j]);
  writeln
end.
PAS
( cd "$T" && "$FPC" -Miso -v0 -owfpc w.pas ) >"$T/fpc.log" 2>&1 || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso could not compile the witness -- cannot cut a ref"; tail -3 "$T/fpc.log"; exit 2; }
( cd "$T" && ./wfpc ) >"$T/ref" 2>&1 || { echo "⛔ GATE REFUSE(2) [$G]: the oracle binary did not run -- cannot cut a ref"; exit 2; }
[ -s "$T/ref" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle produced no output -- refusing to grade against an empty ref"; exit 2; }
RC=0; GRADED=0
for MODE in m3 m4; do
  if [ "$MODE" = m3 ]; then
    ( cd "$T" && timeout -k 5 60 "$SCRIP" --run w.pas </dev/null ) >"$T/out.$MODE" 2>&1; mrc=$?
  else
    ( cd "$T" && timeout -k 5 60 "$SCRIP" --compile --out=w.s w.pas </dev/null ) >"$T/c.$MODE" 2>&1 || { echo "  $MODE COMPILE-REFUSE"; RC=1; continue; }
    ( cd "$T" && gcc -o w_m4 w.s -L"$RT_DIR" -lscrip_rt -Wl,-rpath,"$RT_DIR" ) >>"$T/c.$MODE" 2>&1 || { echo "  $MODE LINK-REFUSE"; RC=1; continue; }
    ( cd "$T" && timeout -k 5 60 ./w_m4 </dev/null ) >"$T/out.$MODE" 2>&1; mrc=$?
  fi
  if [ "$mrc" = 124 ]; then echo "  $MODE TIMEOUT(60s) -- NOT a wrong answer and NOT a clean run"; RC=1; continue; fi
  GRADED=$((GRADED+1))
  if diff -q "$T/ref" "$T/out.$MODE" >/dev/null 2>&1; then
    echo "  $MODE PASS (4 arms byte-identical to fpc -Miso)"
  else
    echo "  $MODE FAIL -- ORACLE vs SCRIP:"; diff "$T/ref" "$T/out.$MODE" | head -12; RC=1
  fi
done
[ "$GRADED" -gt 0 ] || { echo "⛔ GATE REFUSE(2) [$G]: graded ZERO modes -- a runner that measured nothing must never print the success shape"; exit 2; }
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a whole array assigned into a record field (local and heap) reads back byte-identical to fpc -Miso in both modes, and the plain-array and per-element controls are unmoved"
else echo "⛔ GATE FAIL [$G]: a whole array assigned into a record field does not read back what was stored"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)  oracle: $FPC $("$FPC" -iV 2>/dev/null)  graded $GRADED mode(s)"
exit $RC
