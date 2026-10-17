#!/usr/bin/env bash
# test_gate_pas_a_boolean_tag_field_prints_as_a_boolean_and_new_assigns_a_pointer_field_of_a_variant_arm.sh -- write of a Boolean tag-field prints true or false, and new(r.p) stores the new pointer in a field of a variant arm of a record variable (ISO 7185 6.9.3.3, 6.6.5.3).
#
# MEASURED 2026-10-09 by hq_pascal against fpc -Miso: `type valu = record case intval: boolean of true: (ival: integer); false: (valp: ^integer) end; ... v.intval := false; writeln(v.intval)` printed 0 where fpc prints false, in both modes (the tag field was registered with no Boolean class: the type of a tag is not
# parsed through the field rule that sets it); and `x.t := true; new(x.b); x.b^ := 2` for a record VARIABLE x with a pointer field b in a variant arm died with "the pointer-variable of an identified-variable is undefined", because the argument of new arrives wrapped in the variant read-check and new assigned into the wrapper, not the field
# (the same through a pointer, y^.b, worked). Found running Pascal-P5's compiler, whose valu and attr records are exactly these.
# CURE (pascal.y only; no new global): the tag field of a variant part is registered with the Boolean class of its type (the pending flag is set from the tag's type for that one pas_pend_add and restored); the new() call unwraps the variant read-check from its argument, assigns the allocation to the bare field and keeps the check (the tag must select that arm).
#
# ARMS, both modes: two controls cut LIVE from fpc -Miso that must be byte-identical: a Boolean tag printed after each assignment in a bare variant record and in a record with a leading field; new() of a plain pointer field, of a pointer field in a variant arm of a record variable and of the same through a pointer, then reads through them, and the tag printed. FAIL_ONCE=1 corrupts the first control's ref.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
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
     r2 = record n: integer; case t: boolean of true: (a: integer); false: (b: integer) end;
var v: valu; q: r2;
begin
  v.intval := false; writeln(v.intval);
  q.n := 1; q.t := true; writeln(q.t); q.t := false; writeln(q.t)
end.
PAS
cat > "$T/tctl2.pas" <<'PAS'
program tctl2(output);
type rp = ^integer;
     r = record a: rp; case t: boolean of true: (b: rp); false: (c: integer) end;
var x: r; y: ^r;
begin
  new(x.a); x.a^ := 1; x.t := true; new(x.b); x.b^ := 2; writeln(x.a^, ' ', x.b^);
  new(y); new(y^.a); y^.a^ := 3; y^.t := true; new(y^.b); y^.b^ := 4; writeln(y^.a^, ' ', y^.b^);
  x.t := false; x.c := 5; writeln(x.c); writeln(x.t, ' ', y^.t)
end.
PAS
RC=0; N=0
for c in tctl1 tctl2; do
  frc=$(fpcrun $c)
  if [ -n "${FAIL_ONCE:-}" ] && [ "$c" = tctl1 ]; then echo "corrupted by FAIL_ONCE" >> "$T/$c.want"; fi
  for m in m3 m4; do run $m $c; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$c.want" "$T/o"; then echo "  $c $m: rc=$rc, stdout byte-identical to fpc ($(wc -l < "$T/o") lines)"
    else echo "  ⛔ $c $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$c.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi
  done
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a Boolean tag prints as a Boolean and new fills a variant-arm pointer, as fpc does, $N of $N arms"
else echo "GATE FAIL(1) [$G]: examined 2 programs in 2 modes"; fi
exit $RC
