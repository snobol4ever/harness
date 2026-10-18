#!/usr/bin/env bash
# test_gate_pas_a_char_field_of_a_variant_record_variable_prints_as_a_character.sh -- a char field inside a variant arm of a record VARIABLE is a char, not its ordinal.
#
# MEASURED 2026-10-08 by hq_pascal: `s.g := '*'; writeln(s.g)` with g a char field of a variant arm printed 42 where fpc -Miso prints *, for an enumerated and for a boolean tag.
# CAUSE: once the record's tag is assigned, the selection of a variant field is wrapped by pas_vt_wrap_read as TT_SEQ_EXPR(__pas_vcheck(...), selection) so the arm's validity is
# checked on the read; the char mark of the selection node (pas_cvfield_mark_add) sits on the INNER node and pas_is_charexpr asked about the wrapper, so write formatted the char as
# an integer. A pointer base is not wrapped, which is why p^.g was always right. CURE: pas_is_charexpr looks through the variant-check wrapper (pas_vt_unwrap_read) first.
#
# ARMS, both modes, every expectation CUT LIVE from fpc -Miso: tenum (enumerated tag), tbool (boolean tag), tmany (a record variable, a pointer, an array element and a with, chars read
# in write, write with a width, ord, comparison, succ; the ints that overlay the same slots read back as integers). FAIL_ONCE=1 corrupts one ref.
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
cat > "$T/tenum.pas" <<'PAS'
program tenum(output);
const star='*';
type color=(red,green,blue);
  shape=record case k: color of red:(r:integer); green,blue:(g:char) end;
var s: shape;
begin s.k:=green; s.g:=star; writeln(s.g) end.
PAS
cat > "$T/tbool.pas" <<'PAS'
program tbool(output);
const star='*';
type shape=record case b: boolean of true:(r:integer); false:(g:char) end;
var s: shape;
begin s.b:=false; s.g:=star; writeln(s.g) end.
PAS
cat > "$T/tmany.pas" <<'PAS'
program tmany(output);
const star='*';
type color=(red,green,blue);
  shape=record n: integer; case k: color of red:(r:integer); green,blue:(g:char; h:char) end;
  flip=record case b: boolean of true:(c:char); false:(i:integer; j:integer) end;
var s: shape; f: flip; p: ^shape; a: array[1..2] of shape;
begin
  s.n:=7; s.k:=green; s.g:=star; s.h:='x';
  writeln(s.g); writeln(s.g,s.h); writeln(s.g:3); writeln(ord(s.g)); writeln(s.g='*');
  s.k:=red; s.r:=65; writeln(s.r); writeln(s.n);
  f.b:=true; f.c:='Q'; writeln(f.c); writeln(succ(f.c));
  f.b:=false; f.i:=66; f.j:=67; writeln(f.i); writeln(f.j); writeln(f.i+1);
  f.b:=true; f.c:='z'; writeln(f.c,f.c);
  new(p); p^.k:=blue; p^.g:='P'; writeln(p^.g); p^.k:=red; p^.r:=44; writeln(p^.r);
  a[2].k:=green; a[2].g:='W'; writeln(a[2].g);
  with s do begin k:=green; g:='M'; writeln(g); k:=red; r:=77; writeln(r) end
end.
PAS
RC=0; N=0
for c in tenum tbool tmany; do
  frc=$(fpcrun $c)
  if [ -n "${FAIL_ONCE:-}" ] && [ "$c" = tenum ]; then echo "corrupted by FAIL_ONCE" >> "$T/$c.want"; fi
  for m in m3 m4; do run $m $c; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$c.want" "$T/o"; then echo "  $c $m: rc=$rc, stdout byte-identical to fpc ($(wc -l < "$T/o") lines)"
    else echo "  ⛔ $c $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$c.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi
  done
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a char field of a variant record variable prints as a character as fpc does, $N of $N arms"
else echo "GATE FAIL(1) [$G]: examined 3 programs in 2 modes"; fi
exit $RC
