#!/usr/bin/env bash
# test_gate_pas_an_array_of_arrays_holds_each_row_as_an_array_and_copies_a_row_as_fpc_does.sh -- ISO 7185 6.4.3.2: an array whose
# component-type is an array type, array [A] of array [B] of T or array [A] of R with R an array type, holds each component as an
# array of B's bounds, and a component is a value: assigned, passed as a value parameter or bound to a variable parameter as fpc does.
#
# MEASURED 2026-10-11 by hq_pascal on SCRIP dcfaf67ba: var a: array [1..2] of array [1..2] of integer; a[1][2] := 4 died with the 6.5.3.2
# run-time error. Declaration built only the outer array (arr_make(1, 2)), and the first store into a component made a 0-based array
# by the string road, so an inner index outside 0..n-1 was refused and a row was never a value. The comma form array [A, B] of T,
# laid out flat, answered element access correctly. NOW: the elaborator records the component's bounds (a row) for the variable and
# for a named type (grid = array [0..2] of row), the declaration builds each component as its own array (__pas_arr_of), and x[i] of
# such a variable is an aggregate designator, so an assignment or a value parameter copies it (__pas_arr_copy).
#
# NOT COVERED, a separate defect: the comma form keeps its flat layout, where a[i] of array [A, B] of T is not a row (a[1] := a[0]
# writes a[0, 1]).
#
# ARMS, both modes, every expectation cut LIVE from fpc -Miso: rows (a named row type, an array of a named array type indexed [i, j],
# a row as a var and a value parameter), copies (a row copied both ways, an anonymous component indexed [i][j] and [i, j], inner bounds
# 5..6), tconst (a typed constant of arrays of arrays, char rows indexed 'a'..'c'), kinds (a named unpacked char row type, boolean rows
# written, copied, negated and tested: an element prints as its type, which the string-row road answered as an ordinal). FAIL_ONCE=1
# corrupts arm rows' expectation.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- every arm's expectation is CUT FROM THE ORACLE"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
run() { local m="$1" p="$2"
  if [ "$m" = m3 ]; then ( cd "$T" && timeout -k 5 60s "$SCRIP" --run "$p.pas" </dev/null >"$T/o" 2>"$T/e" ); return $?; fi
  ( cd "$T" && timeout -k 5 60s "$SCRIP" --compile --out="$T/$p.s" "$p.pas" </dev/null >/dev/null 2>"$T/e" && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4 did not compile or link: $(head -1 "$T/e" | cut -c1-120)" >&2; return 99; }
  ( cd "$T" && timeout -k 5 60s "./$p.m4" </dev/null >"$T/o" 2>"$T/e" ); return $?; }
want() { ( cd "$T" && "$FPC" -Miso -v0 -o"$1.fpc" $1.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 60s ./$1.fpc </dev/null >"$T/$1.want" 2>/dev/null ); return $?; }
cat > "$T/rows.pas" <<'PAS'
program rows(output);
type row = array [1..3] of integer; grid = array [0..2] of row;
var nest: array [0..1] of row; g: grid; r, s: row; i, j: integer;
procedure bump(var x: row); begin x[3] := x[3] + 100 end;
function sum(x: row): integer; var k, t: integer; begin t := 0; for k := 1 to 3 do t := t + x[k]; x[1] := -5; sum := t end;
begin
  for i := 0 to 1 do for j := 1 to 3 do nest[i][j] := i * 10 + j;
  r[1] := 5; r[2] := 6; r[3] := 7; nest[0] := r; r[1] := 99; writeln(nest[0][1], nest[0, 2], r[1]);
  s := nest[1]; s[2] := -1; writeln(nest[1][2], s[2]);
  bump(nest[1]); writeln(nest[1][3], sum(nest[1]), nest[1][1]);
  for i := 0 to 2 do for j := 1 to 3 do g[i, j] := i + j; writeln(g[2][3], g[0][1], g[1, 2])
end.
PAS
cat > "$T/copies.pas" <<'PAS'
program copies(output);
type row = array [1..3] of integer;
var r, s: row; nest: array [0..1] of row; a2: array [0..1] of array [1..3] of integer; hi: array [1..2] of array [5..6] of real; i: integer;
begin
  r[1] := 1; r[2] := 2; r[3] := 3; s := r; s[1] := 50; writeln(r[1], s[1]);
  nest[0][1] := 7; nest[1] := nest[0]; nest[1][1] := 8; writeln(nest[0][1], nest[1][1]);
  s := nest[0]; s[1] := 60; writeln(nest[0][1], s[1]);
  nest[0] := s; s[1] := 70; writeln(nest[0][1], s[1]);
  a2[0][2] := 4; a2[1, 2] := 5; a2[1][3] := 6; a2[0] := a2[1]; a2[1][2] := 0; writeln(a2[0, 2], a2[1][2], a2[0][3]);
  for i := 1 to 2 do begin hi[i][5] := i / 4; hi[i, 6] := i * 1.5 end; writeln(hi[2][5]:0:2, hi[1, 6]:0:2)
end.
PAS
cat > "$T/tconst.pas" <<'PAS'
program tconst(output);
const nest: array [0..1] of array [1..2] of integer = ((1, 2), (3, 4)); m: array [1..2] of array ['a'..'c'] of char = (('x', 'y', 'z'), ('p', 'q', 'r'));
var i: integer;
begin for i := 0 to 1 do write(nest[i][1], nest[i, 2]); writeln(' ', m[2]['b'], m[1, 'c']) end.
PAS
cat > "$T/kinds.pas" <<'PAS'
program kinds(output);
type crow = array [0..2] of char; brow = array [1..2] of boolean;
var m: array [1..2] of crow; b: array [0..1] of array [1..2] of boolean; c: array [1..2] of brow; i: integer;
begin
  for i := 0 to 2 do begin m[1][i] := chr(97 + i); m[2, i] := chr(65 + i) end; m[2] := m[1]; m[1][0] := 'z'; writeln(m[1][0], m[2][0], m[2, 2]);
  b[0][1] := true; b[1, 2] := false; c[2][1] := 3 > 2; c[1] := c[2]; writeln(b[0][1], b[1, 2], c[1][1], not c[2, 1]);
  if b[0, 1] and c[1][1] then writeln('both')
end.
PAS
RC=0; N=0
chk() { local m="$1" p="$2" frc="$3"; run $m $p; local rc=$?; N=$((N + 1))
  if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc -Miso ($(wc -l < "$T/o") lines)"
  else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; }
want rows; rrc=$?; want copies; crc=$?; want tconst; trc=$?; want kinds; krc=$?
if [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/rows.want"; fi
for m in m3 m4; do chk $m rows $rrc; chk $m copies $crc; chk $m tconst $trc; chk $m kinds $krc; done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: an array of arrays holds each row as an array and copies a row as fpc -Miso does, both modes, $N of $N arms"
else echo "GATE FAIL(1) [$G]: see the arms above"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
