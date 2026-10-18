#!/usr/bin/env bash
# test_gate_pas_a_var_actual_that_is_a_variant_field_is_a_view_of_its_region_not_a_copy.sh -- ISO 7185 6.5.3.3 case D and 6.6.3.3: the formal denotes the actual variable, a field of an undiscriminated variant included.
#
# MEASURED 2026-10-09 by hq_pascal on PAT iso7185prt1702d after SCRIP 9695845d1 had made a record-field and array-element var actual the component's own cell: fpc -Miso prints `i: 99`, SCRIP printed `i: 1`
# in both modes. The actual a.i is a field of an undiscriminated variant, which SCRIP keeps as a byte region inside one record slot (__pas_rdecode over, __pas_rpatch into, an immutable byte string), so it is
# a decoded VIEW of the cell and there is no cell to point at; lower_call's region-actual arm still copied in and out, and the callee's a.c := 'c' patched the cell while its formal kept the stale copy.
# CURE: that arm builds a view, __pas_view(cell reference, offset, kind, size): a variable-cell name reference (VCELL, the road Icon's list and table element lvalues use) whose key is pas_view_key, so
# rt_deref_slow decodes the region on a read (pas_view_get) and c_rt_assign_var_body patches it on a write (pas_view_set); nothing about an ordinary var formal changes, and the formal's read and write are
# the IR_DEREF and IR_ASSIGN_VAR they always were.
#
# ARMS, both modes, every expectation cut LIVE from fpc -Miso: (1) PAT 1702d itself; (2) a control of a variant integer, real, Boolean and character field as a var actual, a callee that writes another
# arm and then writes through the formal, a view passed on to a second routine, a function with a var view, and a variant record in an array; (3) PAT 1702b (case B) is still refused with 6.5.3.3 and
# prints nothing. FAIL_ONCE=1 corrupts arm 1's ref.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- every arm's expectation is CUT FROM THE ORACLE"; exit 2; }
PAT="${PAT_DIR:-$ROOT/../corpus/packages/pascal/pat}"; for f in iso7185prt1702d iso7185prt1702b; do [ -f "$PAT/$f.pas" ] || { echo "⛔ GATE REFUSE(2) [$G]: no $PAT/$f.pas"; exit 2; }; done
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
run() { local m="$1" p="$2"
  if [ "$m" = m3 ]; then ( cd "$T" && timeout -k 5 60s "$SCRIP" --run "$p.pas" </dev/null >"$T/o" 2>"$T/e" ); return $?; fi
  ( cd "$T" && timeout -k 5 60s "$SCRIP" --compile -o "$T/$p.s" "$p.pas" </dev/null >/dev/null 2>&1 && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4 did not compile or link" >&2; return 99; }
  ( cd "$T" && timeout -k 5 60s "./$p.m4" </dev/null >"$T/o" 2>"$T/e" ); return $?; }
want() { ( cd "$T" && "$FPC" -Miso -v0 -o"$1.fpc" $1.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 60s ./$1.fpc </dev/null >"$T/$1.want" 2>/dev/null ); return $?; }
cp "$PAT/iso7185prt1702d.pas" "$T/pat.pas"; cp "$PAT/iso7185prt1702b.pas" "$T/caseb.pas"
cat > "$T/ctl.pas" <<'PAS'
program vw(output);
type u = record case boolean of true: (i: integer); false: (c: char) end;
     w = record k: integer; case integer of 0: (n: integer; b: boolean); 1: (r: real) end;
var a: u; x: w; y: array[1..2] of u;
procedure bump(var j: integer); begin j := j + 1 end;
procedure setc(var j: integer); begin a.c := 'A'; j := j + 1000 end;
procedure thru(var j: integer); begin bump(j); bump(j) end;
function fv(var j: integer): integer; begin j := j * 2; fv := j end;
procedure hv(var q: real); begin q := q / 2.0 end;
procedure tg(var f: boolean); begin f := not f end;
procedure upc(var ch: char); begin ch := succ(ch) end;
procedure other(var j: integer); begin y[1].c := 'B'; j := j + 1 end;
begin
  a.i := 1; bump(a.i); writeln(a.i);
  a.i := 5; setc(a.i); writeln(a.i);
  a.i := 7; thru(a.i); writeln(a.i);
  a.i := 3; writeln(fv(a.i), ' ', a.i);
  x.k := 1; x.n := 10; bump(x.n); writeln(x.n, ' ', x.k);
  x.r := 8.0; hv(x.r); writeln(x.r:0:2);
  x.n := 1; x.b := false; tg(x.b); writeln(x.b);
  a.c := 'a'; upc(a.c); writeln(a.c);
  y[1].i := 100; other(y[1].i); writeln(y[1].i);
  y[2].i := 9; bump(y[2].i); writeln(y[2].i)
end.
PAS
RC=0; N=0
chk() { local m="$1" p="$2" frc="$3"; run $m $p; local rc=$?; N=$((N + 1))
  if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc -Miso ($(wc -l < "$T/o") lines)"
  else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; }
want pat; prc=$?; want ctl; crc=$?
if [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/pat.want"; fi
for m in m3 m4; do chk $m pat $prc; chk $m ctl $crc; done
for m in m3 m4; do run $m caseb; rc=$?; N=$((N + 1))
  if [ "$rc" != 0 ] && [ ! -s "$T/o" ] && grep -q 6.5.3.3 "$T/e"; then echo "  caseb $m: refused with 6.5.3.3 and no output (rc=$rc)"
  else echo "  ⛔ caseb $m FAILED: rc=$rc stdout=[$(head -c 60 "$T/o" | tr '\n' '|')] err=[$(head -c 100 "$T/e")]"; RC=1; fi
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a var actual that is a variant field is a view of its region in both modes, $N of $N arms"
else echo "GATE FAIL(1) [$G]: a variant-field var actual is copied, or case B is no longer refused, see the arms above"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
