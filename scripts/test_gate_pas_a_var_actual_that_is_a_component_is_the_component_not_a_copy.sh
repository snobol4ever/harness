#!/usr/bin/env bash
# test_gate_pas_a_var_actual_that_is_a_component_is_the_component_not_a_copy.sh -- ISO 7185 6.6.3.3: a variable parameter denotes its actual variable for the whole activation.
#
# MEASURED 2026-10-09 by the ceo (CEO-1575, SCRIP fcfc11f2a) and reproduced by hq_pascal: f(var v) doing x.a := 7; v := v + 1 after x.a := 1 and f(x.a) printed 2 in both modes where fpc -Miso prints 8; the array twin
# g(var v) with y[1] printed 11 where fpc prints 71. The lowerer passed a record-field or array-element actual copy-in copy-out (a temporary, then an assignment back), so a write to the containing record or array
# inside the callee was lost. CURE: such an actual is a reference to the component's own cell. __pas_elem_ref(base, idx, tmp) answers a name-reference {DT_N, slen 1, &base.data[idx]} when the base is an array or record
# block (bounds as arr_get: outside the index type it fails to the 6.5.3.2 stop) and, for a character array held as a byte string, which has no cell to point at, copies the element into the caller's temporary and
# references that; the statement after the call stores the reference's current value back into the component (__pas_ref_val), a no-op store of the cell's own value when it was a reference, the old copy-out for the
# string. The collector already follows a DT_N cell reference into a heap block (gc_cell_visit), so a reference held across compacting collections moves with its block.
#
# ARMS, both modes, every expectation cut LIVE from fpc -Miso: (1) the ceo's witness, field and element; (2) a broad control of integer, real, char and Boolean components, nested records and arrays of records, a 2-D element,
# a character-array element, two components of one array swapped, a function with a var element, recursion, a callee that writes the containing array, and an index that is itself an element; (3) a reference held across
# 3000 allocations under SCRIP_GC_STRESS=1 with relocation (SCRIP_GC_RELOC=1 SCRIP_GC_VERIFY=1); (4) an element actual outside its index type still stops with 6.5.3.2 after the output that precedes it.
# FAIL_ONCE=1 corrupts arm 1's ref.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- every arm's expectation is CUT FROM THE ORACLE"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
run() { local m="$1" p="$2"
  if [ "$m" = m3 ]; then ( cd "$T" && timeout -k 5 60s "$SCRIP" --run "$p.pas" </dev/null >"$T/o" 2>"$T/e" ); return $?; fi
  ( cd "$T" && timeout -k 5 60s "$SCRIP" --compile -o "$T/$p.s" "$p.pas" </dev/null >/dev/null 2>&1 && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4 did not compile or link" >&2; return 99; }
  ( cd "$T" && timeout -k 5 60s "./$p.m4" </dev/null >"$T/o" 2>"$T/e" ); return $?; }
want() { ( cd "$T" && "$FPC" -Miso -v0 -o"$1.fpc" $1.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 60s ./$1.fpc </dev/null >"$T/$1.want" 2>/dev/null ); return $?; }
cat > "$T/wit.pas" <<'PAS'
program varfield(output);
type r = record a: integer; b: integer end;
var x: r; y: array[1..2] of integer;
procedure f(var v: integer); begin x.a := 7; v := v + 1 end;
procedure g(var v: integer); begin y[1] := 70; v := v + 1 end;
begin x.a := 1; f(x.a); writeln(x.a); y[1] := 10; g(y[1]); writeln(y[1]) end.
PAS
cat > "$T/ctl.pas" <<'PAS'
program vc(output);
type rec = record a: integer; b: real; c: char; flag: boolean end;
     inner = record p, q: integer end;
     outer = record name: integer; in1: inner; arr: array[1..3] of integer end;
     cs = array[1..5] of char;
var x: rec; y: array[1..4] of integer; o: outer; ao: array[1..2] of outer; m: array[1..3, 1..3] of integer; s: cs; r: array[1..3] of rec; i, j: integer; z: real;
procedure inc(var v: integer); begin v := v + 1 end;
procedure setx(var v: integer; n: integer); begin x.a := 100; v := v + n end;
procedure swap(var p, q: integer); var t: integer; begin t := p; p := q; q := t end;
procedure upc(var c: char); begin c := succ(c) end;
procedure half(var d: real); begin d := d / 2 end;
procedure tog(var f: boolean); begin f := not f end;
function bump(var v: integer): integer; begin v := v * 2; bump := v + 1 end;
procedure down(var v: integer; n: integer); begin if n > 0 then begin v := v + n; down(v, n - 1) end end;
procedure clr(var v: inner); begin v.p := 0; v.q := 0 end;
procedure ovr(var v: integer); begin y[2] := 55; v := v + 1; y[3] := y[3] + v end;
begin
  x.a := 1; x.b := 3.0; x.c := 'a'; x.flag := false;
  inc(x.a); writeln(x.a); setx(x.a, 5); writeln(x.a);
  half(x.b); writeln(x.b:0:2); tog(x.flag); writeln(x.flag);
  for i := 1 to 4 do y[i] := i * 10; swap(y[1], y[4]); writeln(y[1], ' ', y[4]); i := 2; inc(y[i + 1]); writeln(y[3]);
  o.name := 1; o.in1.p := 5; o.in1.q := 6; o.arr[2] := 20; inc(o.in1.q); inc(o.arr[2]); swap(o.in1.p, o.arr[2]); writeln(o.in1.p, ' ', o.in1.q, ' ', o.arr[2]);
  ao[2].in1.p := 9; inc(ao[2].in1.p); clr(ao[2].in1); inc(ao[2].arr[3]); writeln(ao[2].in1.p, ao[2].in1.q, ao[2].arr[3]);
  for i := 1 to 3 do for j := 1 to 3 do m[i, j] := i * 10 + j; inc(m[2, 3]); swap(m[1, 1], m[3, 3]); writeln(m[2, 3], ' ', m[1, 1], ' ', m[3, 3]);
  for i := 1 to 5 do s[i] := chr(ord('a') + i); upc(s[2]); upc(s[5]); writeln(s[1], s[2], s[3], s[4], s[5]);
  r[2].c := 'x'; upc(r[2].c); writeln(r[2].c);
  y[1] := 3; writeln(bump(y[1]), ' ', y[1]);
  y[2] := 0; down(y[2], 4); writeln(y[2]);
  y[3] := 1; ovr(y[1]); writeln(y[1], ' ', y[2], ' ', y[3]);
  y[1] := 1; y[2] := 2; i := 1; inc(y[y[i]]); writeln(y[1], y[2]);
  z := 1.5; r[3].b := 9.0; half(r[3].b); writeln(r[3].b:0:2)
end.
PAS
cat > "$T/chu.pas" <<'PAS'
program chu(output);
type node = record v: integer; next: ^node end;
var a: array[1..3] of integer; keep: array[1..5] of ^node; i: integer;
procedure churn(var x: integer);
var k: integer; q: ^node;
begin
  for k := 1 to 3000 do begin new(q); q^.v := k; q^.next := nil; keep[k mod 5 + 1] := q; if k mod 100 = 0 then x := x + 1 end
end;
begin for i := 1 to 3 do a[i] := i * 100; churn(a[2]); writeln(a[1], ' ', a[2], ' ', a[3]) end.
PAS
cat > "$T/oor.pas" <<'PAS'
program oor(output);
var y: array[1..4] of integer;
procedure inc(var v: integer); begin v := v + 1 end;
begin y[1] := 1; inc(y[1]); writeln('before'); inc(y[9]); writeln('after') end.
PAS
RC=0; N=0
chk() { local m="$1" p="$2" frc="$3"; run $m $p; local rc=$?; N=$((N + 1))
  if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc -Miso ($(wc -l < "$T/o") lines)"
  else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; }
want wit; wrc=$?; want ctl; crc=$?; want chu; hrc=$?
if [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/wit.want"; fi
for m in m3 m4; do chk $m wit $wrc; chk $m ctl $crc; done
export SCRIP_GC_STRESS=1 SCRIP_GC_VERIFY=1
for m in m3 m4; do chk $m chu $hrc; done
unset SCRIP_GC_STRESS SCRIP_GC_VERIFY
for m in m3 m4; do run $m oor; rc=$?; N=$((N + 1))
  if [ "$rc" != 0 ] && [ "$(cat "$T/o")" = before ] && grep -q 6.5.3.2 "$T/e"; then echo "  oor $m: stopped with 6.5.3.2 after printing before (rc=$rc)"
  else echo "  ⛔ oor $m FAILED: rc=$rc stdout=[$(head -c 60 "$T/o" | tr '\n' '|')] err=[$(head -c 100 "$T/e")]"; RC=1; fi
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a var actual that is a record field or an array element is the component itself in both modes, $N of $N arms"
else echo "GATE FAIL(1) [$G]: a component var actual is copied or the reference breaks, see the arms above"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
