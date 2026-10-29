#!/usr/bin/env bash
# test_gate_pas_a_two_dimensional_array_of_records_is_indexed_by_both_subscripts.sh -- an array declared with two index types whose
# element is a record (var g: array [0..2, 0..3] of cell) is read and written through BOTH subscripts, g[i, j].f, with and without a
# with-statement. MEASURED 2026-10-09 by hq_pascal on the Star Trek demo of the P5 samples (row pascal-demos-pascal-s-the-basic-interpreter-and-star-trek-...,
# ceo CEO-1579): monitor_run.sh --oracle bracketed the first divergence at step 103 (stno 160, ishistory := FALSE inside with galaxy[i, j]):
# fpx assigns, scr ENDs with error 22 (undefined function called). Cause: var_decl registered an array of records with pas_array_add (one
# dimension) and never recorded its column count, so the selector action left g[i, j] as a three-child index, which no builtin answers.
# CURE (src/lower/lower_pascal_tree.c, the var_decl action): a record-element array declared with two index types registers pas_array_add2d with its
# column count, as an array of integers does, so the selector flattens g[i, j] to g[i * ncols + j] and the field-selection path finds its element.
# ARMS, both modes, expected stdout and exit code cut LIVE from fpc -Miso: (1) grid -- every cell written then read back, a sum that aliases a
# subscript reads wrong; (2) withgrid -- the with-statement shape of the witness; (3) flat -- the three-line shape. FAIL_ONCE=1 corrupts arm 3's ref.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- every arm's expectation is CUT FROM THE ORACLE"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0; N=0
run() { local m="$1" p="$2"
  if [ "$m" = m3 ]; then ( cd "$T" && timeout -k 5 20s "$SCRIP" --run "$p.pas" </dev/null >"$T/o" 2>"$T/e" ); return $?; fi
  ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile --out="$T/$p.s" "$p.pas" </dev/null >/dev/null 2>&1 && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4: did not compile or link"; return 99; }
  ( cd "$T" && timeout -k 5 20s "./$p.m4" </dev/null >"$T/o" 2>"$T/e" ); return $?; }
fpcrun() { ( cd "$T" && "$FPC" -Miso -v0 -o"$1.fpc" $1.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 20s ./$1.fpc </dev/null >"$T/$1.want" 2>/dev/null ); echo $?; }
cat > "$T/grid.pas" <<'PAS'
program grid(output);
type cell = record v: integer; ok: boolean end;
var g: array [0..2, 0..3] of cell; i, j, s: integer;
begin
  for i := 0 to 2 do for j := 0 to 3 do begin g[i, j].v := i * 10 + j; g[i, j].ok := odd(i + j) end;
  s := 0;
  for i := 0 to 2 do for j := 0 to 3 do if g[i, j].ok then s := s + g[i, j].v;
  writeln(s, ' ', g[2, 3].v, ' ', g[1, 0].v, ' ', g[0, 2].v)
end.
PAS
cat > "$T/withgrid.pas" <<'PAS'
program withgrid(output);
type rec = record ishistory: boolean; rnum: integer end;
var galaxy: array [0..3, 0..3] of rec; i, j, n: integer;
begin
  for i := 0 to 3 do for j := 0 to 3 do
    with galaxy[i, j] do begin ishistory := (i = j); rnum := i * 4 + j end;
  n := 0;
  for i := 0 to 3 do for j := 0 to 3 do if galaxy[i, j].ishistory then n := n + galaxy[i, j].rnum;
  writeln(n, ' ', galaxy[3, 1].rnum)
end.
PAS
cat > "$T/flat.pas" <<'PAS'
program flat(output);
type rec = record rnum: integer end;
var galaxy: array [0..3, 0..3] of rec; i, j: integer;
begin
  i := 1; j := 2;
  galaxy[i, j].rnum := 5;
  writeln(galaxy[1, 2].rnum)
end.
PAS
for p in grid withgrid flat; do
  frc=$(fpcrun $p)
  if [ "$p" = flat ] && [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/$p.want"; fi
  for m in m3 m4; do run $m $p; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc -Miso ($(wc -l < "$T/o") lines)"
    else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a two-dimensional array of records is indexed by both subscripts, with and without with, $N of $N program x mode arms"
else echo "GATE FAIL(1) [$G]: examined 3 programs in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
