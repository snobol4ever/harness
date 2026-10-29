#!/usr/bin/env bash
# test_gate_pas_variant_arms_overlay_the_same_storage.sh -- the arms of a record's variant part occupy the SAME storage, as ISO 7185
# 6.4.3.3 and fpc do: the j-th field of every later arm lives in the slot of the j-th field of the first arm, so a value stored through
# one arm's field is the value read through another's.
#
# MEASURED 2026-10-03 by hq_pascal, row pascal-every-suite-to-100-under-nonet-ceo-1266. test_tprec4 and test_tprec12 (FPC; one GPC
# program, sam9) overlay an enumeration field and a subrange field in a packed variant record and store through the subrange
# (v.f2 := 128), then read the enumeration (v.f1 = enum128): every arm's fields had a slot of their own, so the read answered the
# value stored before.
#
# CURE: pascal.y numbers a record's fields by position and a variant arm's fields were appended after the previous arm's; a
# per-case state (pas_vcase_*) now records the first arm's field range and maps each later arm's j-th field to the first arm's
# j-th slot (fldov, carried through the pending table, the record-type table, the record-variable table and the array-of-record
# table), and every node that builds a field selection writes the SLOT where it used to write the field's position -- the field's
# own position still selects its type facts (char, enum, array). Only scalar ordinal fields overlay (a real, a set, a string, an array, a record or a char beside a non-char keeps
# its own slot: the slot model holds values, not bytes).
#
# ARMS, both modes, each program's expected stdout and exit code cut LIVE from fpc: (enum) the tprec4 shape, unpacked and packed,
# an enumeration over a subrange; (int) an integer over a subrange; (with) the same through a with statement; (arr) an array of
# variant records; (anon) an anonymous record variable; (nest) a variant part inside a variant arm. FAIL_ONCE=1 corrupts the enum
# arm's ref.
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
cat > "$T/enum.pas" <<'PAS'
program enum(output);
type e1 = (a0, a1, a2, a3, a4);
     r1 = 0..4;
     t1 = packed record case integer of 1: (f1: e1); 2: (f2: r1); end;
     t2 = record case integer of 1: (g1: e1); 2: (g2: r1); end;
var v: t1; w: t2;
begin
  v.f1 := a0; v.f2 := 4;
  if v.f1 = a4 then writeln('packed ok') else writeln('packed failed');
  w.g1 := a0; w.g2 := 2;
  if w.g1 = a2 then writeln('unpacked ok') else writeln('unpacked failed');
  w.g1 := a3;
  writeln(w.g2);
  if w.g2 = 3 then writeln('back ok')
end.
PAS
cat > "$T/int.pas" <<'PAS'
program int(output);
type t = record case boolean of true: (whole: integer); false: (small: 0..9); end;
var x: t;
begin
  x.whole := 0; x.small := 5;
  writeln(x.whole);
  x.whole := 7;
  writeln(x.small)
end.
PAS
cat > "$T/with.pas" <<'PAS'
program withs(output);
type e1 = (a0, a1, a2);
     t = record case integer of 1: (f1: e1); 2: (f2: 0..2); end;
var v: t;
begin
  with v do begin
    f1 := a0; f2 := 2;
    if f1 = a2 then writeln('with ok') else writeln('with failed');
    f1 := a1;
    writeln(f2)
  end
end.
PAS
cat > "$T/arr.pas" <<'PAS'
program arr(output);
type e1 = (a0, a1, a2);
     t = record n: integer; case integer of 1: (f1: e1); 2: (f2: 0..2); end;
var v: array[1..3] of t; i: integer;
begin
  for i := 1 to 3 do begin v[i].n := i; v[i].f1 := a0; v[i].f2 := i - 1 end;
  for i := 1 to 3 do writeln(v[i].n, ' ', v[i].f2, ' ', ord(v[i].f1))
end.
PAS
cat > "$T/anon.pas" <<'PAS'
program anon(output);
var r: record k: integer; case integer of 1: (a: integer); 2: (b: 0..99); end;
begin
  r.k := 1; r.a := 0; r.b := 42;
  writeln(r.k, ' ', r.a);
  r.a := 17;
  writeln(r.b)
end.
PAS
cat > "$T/nest.pas" <<'PAS'
program nest(output);
type t = record
       case integer of
         1: (p: integer);
         2: (q: 0..9; case boolean of true: (u: integer); false: (w: 0..5));
     end;
var v: t;
begin
  v.p := 0; v.q := 8;
  writeln(v.p);
  v.u := 0; v.w := 3;
  writeln(v.u)
end.
PAS
for p in enum int with arr anon nest; do
  frc=$(fpcrun $p)
  if [ "$p" = enum ] && [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/$p.want"; fi
  for m in m3 m4; do run $m $p; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc -Miso ($(wc -l < "$T/o") lines)"
    else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: the arms of a variant part overlay the same storage, $N of $N program x mode arms"
else echo "GATE FAIL(1) [$G]: examined 6 programs in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
