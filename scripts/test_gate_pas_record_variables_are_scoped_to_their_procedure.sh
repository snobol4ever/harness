#!/usr/bin/env bash
# test_gate_pas_record_variables_are_scoped_to_their_procedure.sh -- a record variable declared in a procedure does not leak into the next procedure
#
# MEASURED 2026-09-13 by the coo on origin 24f1ec353, while taking the P5 self-host row: the parser's record-variable
# table was keyed by NAME ALONE, with no scope, and every lookup took the FIRST entry it found. Pascal-P5's pint.pas
# declares a local "var r: record ..." in eight different procedures, so putrel's "r.r := f" resolved against putint's
# "r", found no field called r there, fell through as an unresolved raw field node, and the lowerer dereferenced a NULL
# name: SCRIP SEGFAULTED compiling pint.pas, in mode 3 and mode 4 alike. A thirty-line witness reproduces it with two
# procedures. This is a CRASH, not a wrong answer, and it stood between SCRIP and the second Pascal milestone.
#
# Cure, entirely in the Pascal frontend: the record-variable table gets the same scope stack the pointer-variable table
# has had all along -- marked at pv_mark, released at every one of the five procedure and function exits -- and its three
# name lookups scan NEWEST FIRST so an inner declaration shadows an outer one for as long as it is in scope. The lowerer
# also stops dereferencing a NULL assignment target, so a future unresolved name is a bad program, never a segfault.
#
# ARMS: one program in both modes, byte-identical to fpc -Miso. A global record variable r, then three procedures each
# declaring their OWN local r with different fields (a variant record, a record whose field shares the variable's name,
# and a two-char record), then the global r read again after all three return to prove the outer declaration survived.
# On the parent tree this witness DUMPS CORE. FAIL_ONCE=1 corrupts the first line to prove the diff arm trips.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "GATE REFUSE(2) [$G]: no fpc at $FPC -- the ref is CUT FROM THE ORACLE, never pinned by hand"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/s.pas" <<'PAS'
program sc(output);
var
  r: record a: integer; b: integer end;
  seen: integer;

procedure first;
var r: record case boolean of
          true:  (i: integer);
          false: (c: char)
       end;
begin
  r.i := 11;
  writeln('first ', r.i:1)
end;

procedure second;
var r: record r: real; n: integer end;
begin
  r.r := 2.5;
  r.n := 22;
  writeln('second ', r.r:6:2, ' ', r.n:1)
end;

procedure third;
var r: record a: char; b: char end;
begin
  r.a := 'x';
  r.b := 'y';
  writeln('third ', r.a, r.b)
end;

begin
  r.a := 1;
  r.b := 2;
  first;
  second;
  third;
  seen := r.a + r.b;
  writeln('outer ', r.a:1, ' ', r.b:1, ' sum ', seen:1)
end.
PAS
( cd "$T" && "$FPC" -Miso -v0 s.pas >/dev/null 2>&1 && ./s ) > "$T/s.ref" 2>&1
grep -q '^outer 1 2 sum 3$' "$T/s.ref" || { echo "GATE REFUSE(2) [$G]: the oracle did not produce the outer-scope line this gate pins -- the oracle moved: $(tail -1 "$T/s.ref")"; exit 2; }
( cd "$T" && timeout -k 5 60 "$SCRIP" --compile -o s.s s.pas </dev/null && gcc s.s -o s.bin -L"$RT_DIR" -lscrip_rt -lm -lpthread ) >/dev/null 2>&1 || { echo "GATE FAIL(1) [$G]: the mode-4 witness did not build -- the frontend still refuses or crashes on a shadowed record variable"; exit 1; }
RC=0
for M in m3 m4; do
  if [ "$M" = m3 ]; then ( cd "$T" && timeout -k 5 60 "$SCRIP" --run s.pas </dev/null ) >"$T/$M.out" 2>&1
  else ( cd "$T" && LD_LIBRARY_PATH="$RT_DIR" timeout -k 5 60 ./s.bin </dev/null ) >"$T/$M.out" 2>&1
  fi
  if [ -n "${FAIL_ONCE:-}" ] && [ "$M" = m3 ]; then sed -i '1s/^first 11/first 12/' "$T/$M.out"; fi
  if diff -u "$T/s.ref" "$T/$M.out" >"$T/$M.diff"; then echo "  $M PASS ($(wc -l <"$T/s.ref") lines byte-identical to fpc -Miso)"
  else echo "  $M FAIL ($(grep -c '^[-+][^-+]' "$T/$M.diff") diff lines)"; sed -n '1,10p' "$T/$M.diff" | sed 's/^/      /'; RC=1; fi
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a record variable declared in a procedure is scoped to it, shadows an outer one, and does not leak into the next procedure"
else echo "GATE FAIL(1) [$G]: record variables are not scoped to their procedure (examined 2 modes)"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
