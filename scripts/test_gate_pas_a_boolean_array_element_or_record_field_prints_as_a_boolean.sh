#!/usr/bin/env bash
# test_gate_pas_a_boolean_array_element_or_record_field_prints_as_a_boolean.sh -- write and writeln of a Boolean array element or record field print true or false, not 1 or 0 (ISO 7185 6.9.3.3).
#
# MEASURED 2026-10-08 by hq_pascal against fpc -Miso: `writeln(a[2])` for a Boolean array element and `writeln(r.f)` for a Boolean record field printed 1 where fpc prints ' true', in both modes, for a plain array, a
# named array type, a two-dimensional array, a field of a record variable, of a nested record, of a record through a pointer and inside a with. pas_is_boolexpr knew a Boolean VARIABLE (pas_is_boolvar) and a relation, never
# an element or a field, because the array table and the field tables carried no Boolean flag. CURE (pascal.y, no new global): the arrays table and the named array-type table gain an isbool member set from the element type
# at the declaration; the field tables' fldchar column becomes a class code (0 other, 1 char, 2 boolean; every char reader tests == 1, the overlay-compatibility test compares the char class only, and the field-size test is
# unchanged); pas_is_boolexpr gets a TT_IDX arm that asks the array flag, then the record variable's field class, then the record type's. The writer passes an element or field to __pas_enum_name as its stored 0/1 -- NOT as a
# new `x <> 0` relation: a relation over an array fetch in value position is a separate defect (a false one leaves a null; asked to the cfo and hq_zetas, the spine planner's), and wrapping the stored value in one printed
# true for a false element inside a for loop in the first cut of this cure.
# NOT COVERED, written down: `not` of a true element (a relation over an array fetch, the separate defect), and an array or record passed as a parameter.
#
# ARMS, both modes: one control cut LIVE from fpc -Miso that prints Boolean elements and fields of every shape above, in a for loop and out of one, with and, or and not over false and true operands that do not need a false
# relation over a fetch, and conditions; it must be byte-identical. FAIL_ONCE=1 corrupts the control's ref.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- every arm's expectation is CUT FROM THE ORACLE"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
run() { local m="$1" p="$2"
  if [ "$m" = m3 ]; then ( cd "$T" && timeout -k 5 20s "$SCRIP" --run "$p.pas" </dev/null >"$T/o" 2>"$T/e" ); return $?; fi
  ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile -o "$T/$p.s" "$p.pas" </dev/null >/dev/null 2>&1 && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4: did not compile or link"; return 99; }
  ( cd "$T" && timeout -k 5 20s "./$p.m4" </dev/null >"$T/o" 2>"$T/e" ); return $?; }
fpcrun() { ( cd "$T" && "$FPC" -Miso -v0 -o"$1.fpc" $1.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 20s ./$1.fpc </dev/null >"$T/$1.want" 2>/dev/null ); echo $?; }
cat > "$T/tctl.pas" <<'PAS'
program tctl(output);
type bar = array[1..3] of boolean;
     m2 = array[1..2, 1..2] of boolean;
     inner = record ok: boolean; n: integer end;
     rec = record n: integer; f: boolean; g: char; in1: inner end;
     prec = ^rec;
var a: array[1..3] of boolean; ba: bar; mm: m2; r: rec; p: prec; i: integer; b: boolean; ch: char;
begin
  a[1] := true; a[2] := false; a[3] := true;
  ba[1] := false; ba[2] := true; ba[3] := false;
  mm[1,1] := true; mm[1,2] := false; mm[2,1] := false; mm[2,2] := true;
  r.n := 1; r.f := false; r.g := 'k'; r.in1.ok := true; r.in1.n := 9;
  new(p); p^.f := true; p^.g := 'z'; p^.n := 2;
  for i := 1 to 3 do begin write(a[i]); write(' '); writeln(ba[i]) end;
  writeln(mm[1,1], ' ', mm[1,2], ' ', mm[2,1], ' ', mm[2,2]);
  writeln(r.f); writeln(r.g); writeln(r.in1.ok); writeln(p^.f); writeln(p^.g);
  writeln(not a[2]); writeln(not r.f);
  writeln(a[1] and a[3]); writeln(a[1] or a[2]); writeln(r.f or r.in1.ok);
  with r do begin writeln(f); writeln(in1.ok) end;
  b := a[1]; writeln(b); b := r.in1.ok; writeln(b);
  writeln(a[1] = a[3]);
  if a[2] then writeln('wrong') else writeln('right');
  if not ba[1] then writeln('nb1');
  for i := 1 to 3 do writeln(a[i]);
  i := 1; b := a[i] and a[2]; if b then writeln('T') else writeln('F');
  writeln(a[1] and a[2]); writeln(a[2] or a[2]); writeln(r.f or r.in1.ok)
end.
PAS
RC=0; N=0
frc=$(fpcrun tctl)
if [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/tctl.want"; fi
for m in m3 m4; do run $m tctl; rc=$?; N=$((N + 1))
  if [ "$rc" = "$frc" ] && cmp -s "$T/tctl.want" "$T/o"; then echo "  tctl $m: rc=$rc, stdout byte-identical to fpc ($(wc -l < "$T/o") lines)"
  else echo "  ⛔ tctl $m FAILED: rc=$rc (fpc $frc)"; diff "$T/tctl.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: Boolean array elements and record fields print as true and false as fpc does, $N of $N arms"
else echo "GATE FAIL(1) [$G]: examined 1 program in 2 modes"; fi
exit $RC
