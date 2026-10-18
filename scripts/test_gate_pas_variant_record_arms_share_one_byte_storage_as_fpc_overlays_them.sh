#!/usr/bin/env bash
# test_gate_pas_variant_record_arms_share_one_byte_storage_as_fpc_overlays_them.sh -- the arms of a variant record are laid over ONE byte storage, in fpc -Miso's layout, so an integer, a real, a set, a character or a Boolean written through one arm reads back through another arm's bytes (CEO-647).
#
# RULED CEO-647 (2026-09-12 19:10 CDT, GOAL-CEO.md): P5's pint writes an integer through one variant of an anonymous variant record and reads its bytes through the other; fpc -Miso overlays the variants in one storage (r.i := 258 reads r.b = 2 1 0 0 0 0 0 0) and SCRIP read back zeros --
# one oracle, no compat switch, no patched pint. MEASURED 2026-10-09 by hq_pascal: Pascal-P5's pint ran no program under SCRIP before this landing, because its getrel/putrel/getint/putint pun a real, an integer, a set and a char through packed byte arrays.
# CURE (pascal.y, by_name_dispatch.c, lower_pascal.c; no new global): a variant part whose every field has a byte class and whose arms are not slot-for-slot compatible becomes a REGION -- the arms share the slot of their first field, which holds
# the region's bytes as a string, laid out per arm in declaration order with natural alignment (fldov, widened to 64 bits: slot, field class and size, byte offset, region size); a read of an arm's field is __pas_rdecode (bytes -> the field's value),
# a write is __pas_rpatch (value -> a copy of the bytes), an array arm is __pas_rarr; a selector reaches the region through a plain record variable, a field of a nested record, a record behind a pointer, an element of an array of records and a with-statement.
# The marks of the old tag checks (6.5.3.3, __pas_vcheck and __pas_resundef) are re-keyed from the slot node to the region node (pas_vt_rekey) and the undefined test runs on the underlying slot, so a write to the arm the tag does not select and a read of
# a variant after the tag changed still stop naming 6.5.3.3. A record variable passed to a var formal as a region field travels copy-in and copy-out through __pas_rpatch in lower_call. The old slot-sharing stays for every variant part with a field that has no byte class
# (a pointer, a record, a file, an unsized array) and for arms that are slot-for-slot compatible, so tprec4, tprec12, the PAT variant tests and P4's compiler read exactly as before (differential --dump-ir and run of every changed package source against the parent).
# NOT COVERED, written down: an array arm whose elements are an INLINE subrange (packed array [1..8] of 0..255 -- the element size and sign are overwritten by the index range before the field is registered; a named byte type works), a region passed whole to a var formal,
# the 6.5.3.3 check on an element of an array arm, and PAT 1702d (a var actual that aliases one arm while another arm is written needs a reference, not a copy -- awaiting the ceo's ruling).
#
# ARMS, both modes: four controls cut LIVE from fpc -Miso (integer/real/set/char/Boolean against bytes in a plain record, a record with a two-field arm against a one-field arm, a pointer, a nested record, an array element, a with-statement, a var actual, and the arithmetic, comparison, div/mod, set and Boolean operators over the fields of a tagless variant record) must be
# byte-identical; two faults must still stop naming 6.5.3.3 with the stdout before the stop intact. FAIL_ONCE=1 corrupts the first control's ref.
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
type
  byte = 0..255;
  wh = (crec, vrec, blck);
  rl = record case boolean of true: (r: real); false: (b: packed array [1..8] of byte) end;
  il = record case boolean of true: (i: integer); false: (b: packed array [1..4] of byte) end;
  pr = record case boolean of true: (r: real); false: (lo, hi: integer) end;
  ci = record case boolean of true: (i: integer); false: (c: char) end;
  bb = record case boolean of true: (f: boolean); false: (b: byte) end;
  sb = record case boolean of true: (s: set of 0..31); false: (b: packed array [1..4] of byte) end;
  rc = record fname: integer; case occur: wh of crec: (clev, cdspl: integer); vrec: (vdspl: integer); blck: () end;
var x: rl; y: il; z: pr; w: ci; v: bb; u: sb; d: array[1..3] of rc; k: integer; m: rc;
procedure bump(var n: integer); begin n := n + 1 end;
begin
  x.r := 6.5;
  for k := 1 to 8 do write(x.b[k]:4); writeln;
  for k := 1 to 8 do x.b[k] := 0; x.b[8] := 64; x.b[7] := 25;
  writeln(x.r:8:4);
  y.i := 258; for k := 1 to 4 do write(y.b[k]:4); writeln;
  y.b[1] := 255; y.b[2] := 0; y.b[3] := 0; y.b[4] := 0; writeln(y.i);
  z.r := 1.0; writeln(z.hi, ' ', z.lo);
  z.lo := 0; z.hi := 1073217536; writeln(z.r:8:4);
  w.i := 1; w.c := 'c'; writeln(w.i);
  w.i := 65; writeln(w.c);
  v.b := 1; writeln(v.f); v.f := false; writeln(v.b);
  u.s := [1, 5, 9]; for k := 1 to 4 do write(u.b[k]:4); writeln;
  u.b[1] := 3; u.b[2] := 0; u.b[3] := 0; u.b[4] := 128; writeln(0 in u.s, 1 in u.s, 2 in u.s, 31 in u.s);
  k := 2; d[k].fname := 7; d[k].occur := crec; d[k].clev := 5; d[k].cdspl := 123;
  writeln(d[k].fname, ' ', d[k].clev, ' ', d[k].cdspl);
  d[1].occur := vrec; d[1].vdspl := 99; writeln(d[1].vdspl, ' ', d[1].clev);
  m.occur := crec; m.clev := 3; m.cdspl := 77; writeln(m.clev, ' ', m.cdspl);
  with m do begin clev := 4; cdspl := 88; writeln(clev, ' ', cdspl) end;
  with d[k] do begin occur := vrec; vdspl := 11; writeln(vdspl, ' ', clev) end;
  y.i := 10; bump(y.i); bump(y.i); writeln(y.i, ' ', y.b[1]);
  m.clev := 40; bump(m.clev); writeln(m.clev);
end.
PAS
cat > "$T/tctl2.pas" <<'PAS'
program tctl2(output);
type
  byte = 0..255;
  ib = record case boolean of true: (r: real); false: (b: packed array [1..8] of byte) end;
  pib = ^ib;
  outer = record tag: integer; inner: ib; n: integer end;
  pw = record case boolean of true: (r: real); false: (b: packed array [1..8] of char) end;
var a: ib; p: pib; o: outer; c: pw; k: integer;
begin
  a.r := 6.5; for k := 1 to 8 do write(a.b[k]:4); writeln;
  new(p); p^.r := 6.5; for k := 1 to 8 do write(p^.b[k]:4); writeln;
  for k := 1 to 8 do p^.b[k] := 0; p^.b[8] := 64; p^.b[7] := 25; writeln(p^.r:8:4);
  o.tag := 1; o.inner.r := 6.5; o.n := 9; for k := 1 to 8 do write(o.inner.b[k]:4); writeln(' ', o.tag, ' ', o.n);
  o.inner.b[8] := 64; o.inner.b[7] := 0; writeln(o.inner.r:8:4);
  c.r := 1.0; for k := 1 to 8 do write(ord(c.b[k]):4); writeln;
end.
PAS
cat > "$T/tctl3.pas" <<'PAS'
program tctl3(output);
type wh = (crec, vrec, blck);
     rc = packed record
            fname: integer;
            case occur: wh of
              crec: (clev: integer; cdspl: integer);
              vrec: (vdspl: integer);
              blck: ()
          end;
var disp: array[0..3] of rc; top: integer; r: rc;
begin
  top := 2;
  disp[top].fname := 7;
  disp[top].occur := crec; disp[top].clev := 5; disp[top].cdspl := 123;
  writeln(disp[top].fname, ' ', disp[top].clev, ' ', disp[top].cdspl);
  disp[1].occur := vrec; disp[1].vdspl := 99;
  writeln(disp[1].vdspl);
  r.occur := crec; r.clev := 3; r.cdspl := 77;
  writeln(r.clev, ' ', r.cdspl);
  with disp[top] do begin occur := vrec; vdspl := 11; writeln(vdspl) end;
  with r do begin clev := 4; cdspl := 88; writeln(clev, ' ', cdspl) end;
end.
PAS
cat > "$T/tctl4.pas" <<'PAS'
program tctl4(output);
type
  kind = (ki, kr, kc, kb, ks);
  cell = record case kind of ki: (i: integer); kr: (r: real); kc: (c: char); kb: (b: boolean); ks: (s: set of 0..30) end;
var st: array[0..3] of cell; x: cell; n: integer; q: real; ch: char; f: boolean; ss: set of 0..30;
begin
  x.i := 17; n := x.i div 5 + x.i mod 5; writeln(n, ' ', x.i * 2 - 1, ' ', abs(-x.i), ' ', sqr(x.i), ' ', odd(x.i));
  if x.i > 10 then writeln('gt') else writeln('le');
  if (x.i >= 17) and (x.i <> 3) then writeln('ge');
  x.i := -x.i; writeln(x.i, ' ', abs(x.i));
  x.r := 7.5; q := x.r / 2.0; writeln(q:8:3, ' ', x.r * 2.0:8:3, ' ', x.r + 1.0:8:2, ' ', trunc(x.r), ' ', round(x.r), ' ', sqrt(x.r):8:4);
  if x.r > 2.5 then writeln('rgt'); if x.r = 7.5 then writeln('req');
  x.r := x.r / 3.0; writeln(x.r:10:6); x.r := -x.r; writeln(x.r:10:6, ' ', abs(x.r):10:6);
  x.c := 'k'; ch := x.c; writeln(ch, ' ', ord(x.c), ' ', succ(x.c), ' ', pred(x.c), ' ', chr(ord(x.c) + 1));
  if x.c = 'k' then writeln('ceq'); if x.c < 'z' then writeln('clt'); x.c := chr(ord(x.c) + 1); writeln(x.c);
  x.b := true; f := x.b; writeln(f, ' ', x.b and f, ' ', x.b or false);
  if x.b then writeln('bt'); if x.b then writeln('bnot') else writeln('bf');
  x.b := false; writeln(x.b); x.b := (n > 3); writeln(x.b);
  x.s := [1, 3, 5]; ss := x.s + [7]; writeln(5 in ss, ' ', 7 in x.s, ' ', 3 in x.s);
  x.s := x.s * [3, 5, 9]; for n := 0 to 10 do if n in x.s then write(n:2); writeln;
  x.s := x.s - [3]; for n := 0 to 10 do if n in x.s then write(n:2); writeln;
  ss := [5]; writeln(x.s = ss, ' ', x.s <= ss, ' ', x.s >= ss, ' ', x.s <> ss);
  x.s := []; writeln(x.s = []);
  st[2].i := 40; st[2].i := st[2].i + 2; st[3].r := st[2].i; writeln(st[2].i, ' ', st[3].r:8:2);
  for n := 0 to 3 do begin st[n].i := n * 10; end; n := 0; while st[n].i < 25 do n := n + 1; writeln(n);
  st[1].c := 'a'; st[1].c := succ(st[1].c); writeln(st[1].c);
  st[0].b := true; st[0].b := st[0].b and (st[1].c = 'b'); writeln(st[0].b);
end.
PAS
cat > "$T/ftag.pas" <<'PAS'
program ftag(output);
type rl = record case t: boolean of true: (r: real); false: (i, j: integer) end;
var x: rl; k: integer;
begin
  x.t := true; x.r := 1.0;
  writeln('before');
  x.i := 5;
  writeln('after')
end.
PAS
cat > "$T/fund.pas" <<'PAS'
program fund(output);
type rl = record case t: boolean of true: (r: real); false: (i, j: integer) end;
var x: rl; k: integer;
begin
  x.t := true; x.r := 1.0; x.t := false;
  writeln('before');
  k := x.j;
  writeln('after')
end.
PAS
RC=0; N=0
for c in tctl1 tctl2 tctl3 tctl4; do
  frc=$(fpcrun $c)
  if [ -n "${FAIL_ONCE:-}" ] && [ "$c" = tctl1 ]; then echo "corrupted by FAIL_ONCE" >> "$T/$c.want"; fi
  for m in m3 m4; do run $m $c; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$c.want" "$T/o"; then echo "  $c $m: rc=$rc, stdout byte-identical to fpc ($(wc -l < "$T/o") lines)"
    else echo "  ⛔ $c $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$c.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi
  done
done
for p in ftag fund; do
  case $p in ftag) want="ISO 7185 6.5.3.3: a component of a variant is accessed while the tag-field selects a different variant";; fund) want="ISO 7185 6.5.3.3: a variant of a variant-part is undefined after the tag-field changes value";; esac
  for m in m3 m4; do run $m $p; rc=$?; N=$((N + 1))
    if [ "$rc" != 0 ] && grep -q "$want" "$T/e" && grep -q before "$T/o" && ! grep -q after "$T/o"; then echo "  $p $m: stopped naming 6.5.3.3 (rc=$rc, stdout [$(head -c 30 "$T/o" | tr '\n' '|')])"
    else echo "  ⛔ $p $m FAILED: rc=$rc stdout=[$(head -c 60 "$T/o" | tr '\n' '|')] err=[$(head -c 120 "$T/e")]"; RC=1; fi
  done
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: the arms of a variant record share one byte storage as fpc overlays them, and the tag checks still stop, $N of $N arms"
else echo "GATE FAIL(1) [$G]: examined 6 programs in 2 modes"; fi
exit $RC
