#!/usr/bin/env bash
# test_gate_pas_move_copies_a_run_of_array_elements_or_string_characters.sh -- Move(src[i], dst[j], bytes) over static or dynamic arrays
# (element size from the declared type, overlapping runs in either direction, rows of a two-level array, nested aggregates) and over string
# characters (Move(t[2], s[3], 4)) copies exactly the run fpc copies.
#
# MEASURED 2026-10-14 by hq_pascal for PasRosetta's empty-output class (ceo CEO-1709): 10 of its programs call Move and died "error 22:
# undefined function called" (or, for a whole array, "integer expected"). THE CURE: mk_call lowers Move whose first two arguments are
# element selects of array or string variables, in the FPC dialects, to the new runtime __pas_move (a 0-based or declared-lo aware run copy
# of bytes / element-size cells, memmove order, pas_agg_copy for aggregate cells) or, for strings, s := __pas_strmove(s, j, t, i, n).
# The element size comes from pas_elem_size. OPEN, NOT GRADED HERE: Move on pointer dereferences (move(p^, ...)), on a whole array
# (move(a, b, n)), on two-dimensional element selects (a[i, j]) and between an array and a string.
#
# ARMS: moves against fpc -Mobjfpc, both modes, cut LIVE. MEASURED on the parent (in-tree swap): red. FAIL_ONCE=1 corrupts it.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- every expectation is CUT FROM THE ORACLE"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0; N=0
run() { local m="$1" p="$2"
  if [ "$m" = m3 ]; then ( cd "$T" && LD_LIBRARY_PATH="$RT_DIR" timeout -k 5 20s "$SCRIP" --run "$p.pas" </dev/null >"$T/o" 2>"$T/e" ); return $?; fi
  ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile -o "$T/$p.s" "$p.pas" </dev/null >/dev/null 2>&1 && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4: did not compile and link"; return 125; }
  ( cd "$T" && timeout -k 5 20s "./$p.m4" </dev/null >"$T/o" 2>"$T/e" ); return $?; }
fpcrun() { local mode="$2"; mkdir -p "$T/fpc"; ( cd "$T" && "$FPC" $mode -v0 -FE"$T/fpc" -o"$T/$1.fpc" "$T/$1.pas" >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc $mode would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 20s "./$1.fpc" </dev/null >"$T/$1.want" 2>/dev/null ); echo $?; }
cat > "$T/moves.pas" <<'PAS'
program moves;
{$mode objfpc}
type tarr = array[1..8] of integer; trow = array[0..2] of word;
var a, b: tarr; d, e: array of int64; s, t: string; i: integer; r1, r2: array[0..4] of trow; q: array[3..6] of byte; u: array[0..3] of byte;
begin
  for i := 1 to 8 do begin a[i] := i * 10; b[i] := 0 end;
  move(a[2], b[1], 3 * sizeof(integer));
  for i := 1 to 8 do write(b[i], ' '); writeln;
  move(a[1], a[3], 4 * sizeof(integer));
  for i := 1 to 8 do write(a[i], ' '); writeln;
  setlength(d, 6); setlength(e, 6);
  for i := 0 to 5 do d[i] := i * i + 1;
  move(d[1], e[0], 4 * sizeof(int64)); move(d[0], d[2], 3 * sizeof(d[0]));
  for i := 0 to 5 do write(e[i], '/', d[i], ' '); writeln;
  s := 'abcdefgh'; t := 'XYZ12345';
  move(t[2], s[3], 4);
  writeln(s);
  setlength(s, 4); fillchar(s[1], 4, '.'); move(t[1], s[2], 2); writeln(s);
  for i := 0 to 4 do begin r1[i][0] := i; r1[i][1] := i + 100; r1[i][2] := i + 200 end;
  move(r1[1], r2[0], 2 * sizeof(trow));
  writeln(r2[0][0], ' ', r2[1][2], ' ', r2[2][0]);
  for i := 3 to 6 do q[i] := i; for i := 0 to 3 do u[i] := 0;
  move(q[4], u[1], 3);
  for i := 0 to 3 do write(u[i], ' '); writeln
end.
PAS
for pm in "moves -Mobjfpc"; do p=${pm% *}; om=${pm#* }
  frc=$(fpcrun $p $om) || exit 2
  if [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/$p.want"; fi
  for m in m3 m4; do run $m $p; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc $om ($(wc -l < "$T/o") lines)"
    else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done; done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: Move copies array runs and string runs as fpc's does, $N of $N arms"
else echo "GATE FAIL(1) [$G]: examined one program in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
