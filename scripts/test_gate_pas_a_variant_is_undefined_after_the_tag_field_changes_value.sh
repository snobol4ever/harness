#!/usr/bin/env bash
# test_gate_pas_a_variant_is_undefined_after_the_tag_field_changes_value.sh -- ISO 7185 6.5.3.3 (6.5.3.1, 6.6.5.3): when the tag-field of a variant-part changes value the variants are undefined until assigned, and a use is an error (PAT iso7185prt1851).
#
# MEASURED 2026-10-08 by hq_pascal: PAT 1851 (`r.b := true; r.i := 1; r.b := false; c := r.c`) ran to rc 0 in both modes; fpc -Miso accepts it too, so the expectation is the ISO text, graded as PAT grades a rejection test.
# __pas_vcheck already validated the tag against the field's arm (satisfied here: the tag is false and c belongs to the false arm), but nothing recorded that the arm had no value since the tag moved.
# CURE (pascal.y, both halves in the variant machinery of landings 31/41/49): (1) pas_vt_undefine_variants: an assignment to the tag-field of a plain variable whose right side is pure (constants, variables, operators)
# is preceded by `if tag <> rhs then every variant slot := __pas_undefined_value`, the never-assigned global of the for-control landing, so an UNCHANGED tag keeps its variants; (2) pas_vt_wrap_read: a read of a variant field
# after the tag was assigned also tests the slot with __pas_resundef and stops with __pas_rterr 6.5.3.3, and pas_vt_unwrap_read takes the longer check chain. A {$mode} program is exempt, as every ISO check of this series is.
# NOT COVERED, written down: a tag reached through a pointer, a with-statement or an array element, and a tag assigned from an expression with a call.
#
# ARMS, both modes: four fault programs (PAT 1851's boolean tag, an enumerated tag with two-field arms, a local record in a procedure, a tag changed in a loop) must stop with rc != 0, the pre-stop stdout intact and the 6.5.3.3
# diagnostic; a control cut LIVE from fpc -Miso (fields assigned after the tag, the tag re-assigned its own value, fixed fields untouched, an untagged variant used for punning, two variables of one record type, a
# local record, a tag set from a variable, a loop, an unassigned variant field passed to a var formal of a procedure and of a function and read from the input) must run byte-identical; a {$mode objfpc} program reading a changed-tag variant must not be stopped. FAIL_ONCE=1 corrupts the control's ref.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- every arm's expectation is CUT FROM THE ORACLE"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
echo 77 > "$T/in"
run() { local m="$1" p="$2"
  if [ "$m" = m3 ]; then ( cd "$T" && timeout -k 5 20s "$SCRIP" --run "$p.pas" <"$T/in" >"$T/o" 2>"$T/e" ); return $?; fi
  ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile -o "$T/$p.s" "$p.pas" </dev/null >/dev/null 2>&1 && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4: did not compile or link"; return 99; }
  ( cd "$T" && timeout -k 5 20s "./$p.m4" <"$T/in" >"$T/o" 2>"$T/e" ); return $?; }
fpcrun() { ( cd "$T" && "$FPC" -Miso -v0 -o"$1.fpc" $1.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 20s ./$1.fpc <"$T/in" >"$T/$1.want" 2>/dev/null ); echo $?; }
cat > "$T/tctl.pas" <<'PAS'
program tctl(output);
type color=(red,green,blue);
  shape=record n: integer; case k: color of red:(r:integer); green,blue:(g:char; h:char) end;
  flip=record case b: boolean of true:(i:integer); false:(c:char) end;
  pun=record case integer of 1:(i:integer); 2:(c:char) end;
var s, t: shape; f: flip; u: pun; x, y: integer; kk: color; ch: char;
procedure setit(var q: integer); begin q := 5 end;
function getit(var q: integer): integer; begin q := 6; getit := q end;
procedure p;
var l: flip;
begin l.b := true; l.i := 7; writeln(l.i); l.b := false; l.c := 'p'; writeln(l.c); l.b := true; l.i := 8; writeln(l.i) end;
begin
  s.n := 4; s.k := red; s.r := 10; writeln(s.r); s.k := green; s.g := 'a'; s.h := 'b'; writeln(s.g, s.h, s.n:2);
  t.n := 9; t.k := blue; t.g := 'z'; s.k := red; s.r := 3; writeln(t.g, s.r:2, t.n:2);
  f.b := true; f.i := 5; f.b := true; writeln(f.i);
  f.b := false; f.c := 'q'; f.b := false; writeln(f.c);
  u.i := 65; writeln(u.i);
  kk := green; s.k := kk; s.g := 'm'; writeln(s.g);
  for x := 1 to 3 do begin f.b := (x mod 2 = 1); if f.b then begin f.i := x; writeln(f.i) end else begin f.c := chr(64 + x); writeln(f.c) end end;
  p;
  f.b := true; setit(f.i); writeln(f.i); f.b := false; f.b := true; writeln(getit(f.i), f.i); read(f.i); writeln(f.i);
  s.k := red; s.r := 11; y := s.r + s.n; writeln(y)
end.
PAS
cat > "$T/fbool.pas" <<'PAS'
program fbool(output);
var r: record case b: boolean of true: (i: integer); false: (c: char) end; c: char;
begin r.b := true; r.i := 1; r.b := false; writeln('before error'); c := r.c; writeln('after') end.
PAS
cat > "$T/fenum.pas" <<'PAS'
program fenum(output);
type color = (red, green, blue);
var s: record n: integer; case k: color of red: (r: integer); green, blue: (g: char; h: char) end; x: char;
begin s.n := 1; s.k := green; s.g := 'a'; s.h := 'b'; writeln('ok'); s.k := red; s.r := 2; s.k := blue; x := s.h; writeln('after') end.
PAS
cat > "$T/fproc.pas" <<'PAS'
program fproc(output);
procedure p;
var l: record case b: boolean of true: (i: integer); false: (c: char) end; q: integer;
begin l.b := true; l.i := 3; writeln('in'); l.b := false; q := ord(l.c); writeln(q:1) end;
begin p end.
PAS
cat > "$T/floop.pas" <<'PAS'
program floop(output);
var f: record case b: boolean of true: (i: integer); false: (c: char) end; x: integer; ch: char;
begin for x := 1 to 2 do begin f.b := (x = 1); if x = 1 then f.i := 4 else begin writeln('second'); ch := f.c end end end.
PAS
cat > "$T/tmode.pas" <<'PAS'
{$mode objfpc}
program tmode;
var r: record case b: boolean of true: (i: integer); false: (c: char) end; c: char;
begin r.b := true; r.i := 1; r.b := false; c := r.c; writeln('done') end.
PAS
RC=0; N=0
frc=$(fpcrun tctl)
if [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/tctl.want"; fi
for m in m3 m4; do run $m tctl; rc=$?; N=$((N + 1))
  if [ "$rc" = "$frc" ] && cmp -s "$T/tctl.want" "$T/o"; then echo "  tctl $m: rc=$rc, stdout byte-identical to fpc ($(wc -l < "$T/o") lines)"
  else echo "  ⛔ tctl $m FAILED: rc=$rc (fpc $frc)"; diff "$T/tctl.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi
done
for p in fbool fenum fproc floop; do
  for m in m3 m4; do run $m $p; rc=$?; N=$((N + 1))
    if [ "$rc" != 0 ] && grep -q "ISO 7185 6.5.3.3: a variant of a variant-part is undefined after the tag-field changes value" "$T/e" && ! grep -q after "$T/o"; then echo "  $p $m: stopped naming 6.5.3.3 (rc=$rc, stdout [$(head -c 30 "$T/o" | tr '\n' '|')])"
    else echo "  ⛔ $p $m FAILED: rc=$rc stdout=[$(head -c 60 "$T/o" | tr '\n' '|')] err=[$(head -c 120 "$T/e")]"; RC=1; fi
  done
done
for m in m3 m4; do run $m tmode; rc=$?; N=$((N + 1))
  if [ "$rc" = 0 ] && ! grep -q "6.5.3.3" "$T/e"; then echo "  tmode $m: a {\$mode} program is not held to 6.5.3.3 (rc=0)"
  else echo "  ⛔ tmode $m FAILED: rc=$rc err=[$(head -c 120 "$T/e")]"; RC=1; fi
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a variant is undefined after the tag-field changes value and the legal forms run as fpc does, $N of $N arms"
else echo "GATE FAIL(1) [$G]: examined 6 programs in 2 modes"; fi
exit $RC
