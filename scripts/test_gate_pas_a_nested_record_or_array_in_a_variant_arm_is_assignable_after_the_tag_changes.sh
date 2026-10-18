#!/usr/bin/env bash
# test_gate_pas_a_nested_record_or_array_in_a_variant_arm_is_assignable_after_the_tag_changes.sh -- a field of a record or an element of an array that is itself a field of a variant arm can be assigned after the tag field changed value (ISO 7185 6.5.3.3).
#
# MEASURED 2026-10-09 by hq_pascal against fpc -Miso: `gattr.kind := varbl; ...; gattr.kind := cst; gattr.cval.intval := false` with `cval: valu` a record field of the arm cst died with "an index value is not assignment-compatible with the index-type of the array" in both modes, and so did
# `v.t := true; v.a[i] := ...` for an array field of an arm: a change of the tag field replaced every variant slot of the record with the undefined-value marker, which destroyed the nested record or array that the slot held, and a field of an undefined nested record is
# assignable (it defines that field) but a field of the marker is not. Found running Pascal-P5's compiler on its own sample pascals.pas: pcom's `gattr.cval.intval := false` after an expression had switched gattr's kind.
# CURE (pascal.y only; no new global): when the tag changes, a variant slot whose field is a record or a numeric array is reset to a FRESH structure of its type (pas_field_init_tree, the same initializer a new record gets: nested records and arrays included), and every other slot to the undefined marker as before, so a read
# of an undefined scalar variant still stops naming 6.5.3.3 (the neighbouring gates keep that).
#
# ARMS, both modes: one control cut LIVE from fpc -Miso that must be byte-identical: a record field in an arm assigned after the tag went away and came back (twice, with a pointer field in it), an array field in an arm filled after the tag changed, and a record field that holds a record with its own variant part, three levels deep. FAIL_ONCE=1 corrupts the control's ref.
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
cat > "$T/tctl1.pas" <<'PAS'
program tctl1(output);
type valu = record case intval: boolean of true: (ival: integer); false: (valp: ^integer) end;
     ak = (cst, varbl, expr);
     attr = record typtr: ^integer; case kind: ak of cst: (cval: valu); varbl: (packing: boolean; n: integer); expr: () end;
     arrv = record case t: boolean of true: (a: array [1..4] of integer); false: (b: integer) end;
     deep = record case d: boolean of true: (inner: attr); false: (z: integer) end;
var g: attr; v: arrv; w: deep; i: integer; q: ^integer;
begin
  new(q); q^ := 9;
  g.kind := cst; g.cval.intval := false; g.cval.valp := q;
  g.kind := varbl; g.packing := true; g.n := 3; writeln(g.n);
  g.kind := cst; g.cval.intval := true; g.cval.ival := 5; writeln(g.cval.ival);
  g.cval.intval := false; g.cval.valp := q; writeln(g.cval.valp^);
  v.t := false; v.b := 1; v.t := true; for i := 1 to 4 do v.a[i] := i * i; writeln(v.a[3], ' ', v.a[4]);
  v.t := false; v.b := 7; writeln(v.b); v.t := true; v.a[2] := 11; writeln(v.a[2]);
  w.d := false; w.z := 1; w.d := true; w.inner.kind := cst; w.inner.cval.intval := true; w.inner.cval.ival := 8; writeln(w.inner.cval.ival);
  w.d := false; w.z := 2; w.d := true; w.inner.kind := varbl; w.inner.n := 4; writeln(w.inner.n)
end.
PAS
RC=0; N=0
for c in tctl1; do
  frc=$(fpcrun $c)
  if [ -n "${FAIL_ONCE:-}" ] && [ "$c" = tctl1 ]; then echo "corrupted by FAIL_ONCE" >> "$T/$c.want"; fi
  for m in m3 m4; do run $m $c; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$c.want" "$T/o"; then echo "  $c $m: rc=$rc, stdout byte-identical to fpc ($(wc -l < "$T/o") lines)"
    else echo "  ⛔ $c $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$c.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi
  done
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a nested record or array in a variant arm stays assignable across tag changes, as fpc does, $N of $N arms"
else echo "GATE FAIL(1) [$G]: examined 1 program in 2 modes"; fi
exit $RC
