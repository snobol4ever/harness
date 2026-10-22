#!/usr/bin/env bash
# test_gate_pas_a_dynamic_array_var_takes_its_initializer_and_move_into_an_open_array_copies_the_byte_count.sh -- two FPC-dialect defects that one PasRosetta pair
# (sorting-algorithms-heapsort, sorting-algorithms-merge-sort-1) shows:
#   (1) var a: array of Integer = (-9, 42, -38);  -- a dynamic array declared with an initializer. The parent dropped the initializer: Length(a) read 0, High(a)
#       read -1, and the first a[0] died with 'ISO 7185 6.5.3.2: an index value is not assignment-compatible'. fpc: SetLength to the element count and each element
#       stored. Covers Integer, Double, String, record, array of array (a single-element inner (6) is an array of one), and a routine's local.
#   (2) Move(Buf[0], A[L], Succ(R - L) * SizeOf(Integer)) into an OPEN-ARRAY parameter A. The lowering asked the DESTINATION for the element size; an open-array
#       parameter has none, so the byte count was read as an element count and, with Buf longer than the run, every element of Buf after the run (zeros) was copied
#       over A. fpc copies exactly the bytes. The cure asks the source when the destination does not know.
# MEASURED 2026-10-22 by hq_pascal on the parent (SCRIP 8db00166f), fpc 3.2.2 against scrip: heapsort died on a2 with the 6.5.3.2 text (rc 1); merge-sort-1 ended rc 0
# with a1 '[-47, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 27]' for fpc's sorted '[-49, -47, -40, ...]'.
#
# ARMS (both modes, stdout and exit code cut LIVE from fpc): dyninit, movepar, and the two corpus witnesses by path (corpus/packages/pascal/rosetta-pascal; each names its
# own {$mode objfpc}). FAIL_ONCE=1 corrupts dyninit's expectation.
# KNOWN GAPS (not asserted): NUL bytes in a Pascal string (fillchar(s[1], n, #0) empties the string), an enumeration-indexed constant array (soundex).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
CORPUS="$(cd "$HERE/../../corpus" 2>/dev/null && pwd)" || { echo "⛔ GATE REFUSE(2) [$G]: no corpus beside harness"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- every expectation is CUT FROM THE ORACLE"; exit 2; }
ROS="$CORPUS/packages/pascal/rosetta-pascal"
for w in sorting-algorithms-heapsort sorting-algorithms-merge-sort-1; do [ -f "$ROS/$w.pas" ] || { echo "⛔ GATE REFUSE(2) [$G]: no witness at $ROS/$w.pas"; exit 2; }; done
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0; N=0
run() { local m="$1" p="$2"
  if [ "$m" = m3 ]; then ( cd "$T" && LD_LIBRARY_PATH="$RT_DIR" timeout -k 5 20s "$SCRIP" --run "$p.pas" </dev/null >"$T/o" 2>"$T/e" ); return $?; fi
  ( cd "$T" && LD_LIBRARY_PATH="$RT_DIR" timeout -k 5 20s "$SCRIP" --compile -o "$T/$p.s" "$p.pas" </dev/null >/dev/null 2>"$T/e" && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4: did not compile and link ($(head -1 "$T/e" | cut -c1-120))"; return 125; }
  ( cd "$T" && LD_LIBRARY_PATH="$RT_DIR" timeout -k 5 20s "./$p.m4" </dev/null >"$T/o" 2>"$T/e" ); return $?; }
fpcrun() { mkdir -p "$T/fpc"; ( cd "$T" && "$FPC" -Mobjfpc -v0 -FE"$T/fpc" -FU"$T/fpc" -o"$T/$1.fpc" "$T/$1.pas" >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 20s "./$1.fpc" </dev/null >"$T/$1.want" 2>/dev/null ); echo $?; }
cat > "$T/dyninit.pas" <<'PAS'
{$mode objfpc}
program dyninit;
type TRec = record n: Integer; s: String; end;
var a: array of Integer = (-9, 42, -38, 7);
    d: array of Double = (1.5, 2.25);
    s: array of String = ('a', 'bc', 'def');
    nn: array of array of Integer = ((1, 2), (3, 4, 5), (6));
    r: array of TRec = ((n: 1; s: 'one'), (n: 2; s: 'two'));
    t: array of Integer = (10, 20, 30);
    i, j: Integer;
procedure Local;
var la: array of Integer = (5, 6, 7);
    k: Integer;
begin
  for k := 0 to High(la) do write(la[k], ' ');
  writeln(Length(la));
end;
begin
  writeln(Length(a), ' ', Low(a), ' ', High(a), ' ', a[0], ' ', a[3]);
  writeln(Length(d), ' ', d[0]:0:2, ' ', d[1]:0:2);
  writeln(Length(s), ' ', s[0], s[1], s[2]);
  writeln(Length(nn), ' ', Length(nn[0]), ' ', Length(nn[1]), ' ', Length(nn[2]));
  for i := 0 to High(nn) do begin for j := 0 to High(nn[i]) do write(nn[i][j], ' '); end; writeln;
  writeln(Length(r), ' ', r[0].n, r[0].s, ' ', r[1].n, r[1].s);
  writeln(Length(t), ' ', t[2]);
  a[1] := 100; writeln(a[0], ' ', a[1]);
  Local;
end.
PAS
cat > "$T/movepar.pas" <<'PAS'
{$mode objfpc}
program movepar;
procedure Mrg(var A: array of Integer; L, R: Integer);
var Buf: array of Integer;
  procedure Run;
  var K: Integer;
  begin
    for K := 0 to R - L do Buf[K] := A[L + K] + 1000;
    Move(Buf[0], A[L], Succ(R - L) * SizeOf(Integer));
  end;
begin
  SetLength(Buf, Length(A));
  Run;
end;
var d: array of Integer = (1, 2, 3, 4, 5);
    s: array[-2..2] of Integer = (1, 2, 3, 4, 5);
    k: Integer;
begin
  Mrg(d, 1, 2); for k := 0 to 4 do write(d[k], ' '); writeln;
  Mrg(s, 0, 1); for k := -2 to 2 do write(s[k], ' '); writeln;
  Mrg(d, 0, 4); for k := 0 to 4 do write(d[k], ' '); writeln;
end.
PAS
cp "$ROS/sorting-algorithms-heapsort.pas" "$T/heapsort.pas"
cp "$ROS/sorting-algorithms-merge-sort-1.pas" "$T/mergesort.pas"
arm() { local p="$1" frc
  frc=$(fpcrun "$p") || exit 2
  if [ -n "${FAIL_ONCE:-}" ] && [ "$p" = dyninit ]; then echo "corrupted by FAIL_ONCE" >> "$T/$p.want"; fi
  for m in m3 m4; do run $m "$p"; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc ($(head -c 70 "$T/o" | tr '\n' '|'))"
    else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done; }
for p in dyninit movepar heapsort mergesort; do arm "$p"; done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a dynamic array takes its initializer and Move into an open array copies exactly its bytes, $N of $N arms"
else echo "GATE FAIL(1) [$G]: examined four programs over $N arms"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
