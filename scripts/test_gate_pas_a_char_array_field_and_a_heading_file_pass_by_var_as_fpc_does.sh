#!/usr/bin/env bash
# test_gate_pas_a_char_array_field_and_a_heading_file_pass_by_var_as_fpc_does.sh -- two variables that lost themselves when passed to a
# var parameter (ISO 7185 6.6.3.3: the formal denotes the actual variable for the activation), each answered as fpc -Miso answers.
#
# MEASURED 2026-10-11 by hq_pascal on SCRIP 515fb5622, from the PasDemo red demos/pascal/prettyp (CRASH in both modes in the coo's reading):
#   (1) A char-array field of a record passed to a var parameter of a procedure (prettyp's WITH NEXTSYM^ DO GETNEXTSYMBOL(..., VALUE, ...)):
#       the elaborator converted the field to the callee's array form, a value and not a designator, so the callee's
#       VALUE[LENGTH] := c stored into a bare array and died with the rt_assign_var BOMB (dtype 16; dtype 2 before 85fe66208). NOW: copy-in
#       to a local of the calling routine sized by the field's own bounds (an uninitialized field included), the local passed by
#       reference, and copy-out packed back into the field after the call.
#   (2) A program-heading text file reset or rewritten through a var parameter (prettyp's INITIALIZE(INPUTFILE, OUTPUTFILE, ...) does
#       RESET(INPUTFILE)): the binding to the program argument of its position, or to the console with none, was decided by the name at the
#       reset site, so the formal's name was opened as a file ("Runtime error 2"). NOW: under the ISO dialect each heading text file starts
#       as minus its heading position, and reset and rewrite take the binding from the variable wherever it is reset.
# NOT COVERED: a char-array field passed by var to a FUNCTION (an expression cannot carry the copy-out), and heading typed files.
#
# ARMS, both modes, every expectation cut LIVE from fpc -Miso: field (a pointer's field through WITH and two levels, an uninitialized
# field, a plain record), hdrfile (reset and rewrite through var parameters, the input fed on stdin). FAIL_ONCE=1 corrupts arm field.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- every arm's expectation is CUT FROM THE ORACLE"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
printf 'ab cd\nefg\n' > "$T/in.txt"
run() { local m="$1" p="$2"
  if [ "$m" = m3 ]; then ( cd "$T" && timeout -k 5 60s "$SCRIP" --run "$p.pas" <"$T/in.txt" >"$T/o" 2>"$T/e" ); return $?; fi
  ( cd "$T" && timeout -k 5 60s "$SCRIP" --compile -o "$T/$p.s" "$p.pas" </dev/null >/dev/null 2>"$T/e" && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4 did not compile or link: $(head -1 "$T/e" | cut -c1-120)" >&2; return 99; }
  ( cd "$T" && timeout -k 5 60s "./$p.m4" <"$T/in.txt" >"$T/o" 2>"$T/e" ); return $?; }
want() { ( cd "$T" && "$FPC" -Miso -v0 -o"$1.fpc" $1.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 60s ./$1.fpc <"$T/in.txt" >"$T/$1.want" 2>/dev/null ); return $?; }
cat > "$T/field.pas" <<'PAS'
program field(output);
type str = array [1..4] of char; symbol = record value: str; length: integer end; symbolinfo = ^symbol;
var nextsym, other: symbolinfo; r: symbol; i: integer;
procedure store(var length: integer; var value: str); begin length := length + 1; value[length] := chr(ord('w') + length) end;
procedure getsym(var value: str; var length: integer); begin store(length, value); store(length, value) end;
begin
  new(nextsym); nextsym^.length := 0; for i := 1 to 4 do nextsym^.value[i] := '.';
  with nextsym^ do getsym(value, length);
  for i := 1 to 4 do write(nextsym^.value[i]); writeln(nextsym^.length);
  new(other); other^.length := 1; getsym(other^.value, other^.length); writeln(other^.value[2], other^.value[3], other^.length);
  r.length := 0; for i := 1 to 4 do r.value[i] := '-'; store(r.length, r.value); store(r.length, r.value);
  for i := 1 to 4 do write(r.value[i]); writeln(r.length)
end.
PAS
cat > "$T/hdrfile.pas" <<'PAS'
program hdrfile(inputfile, outputfile);
var inputfile, outputfile: text; n, l, c: integer;
procedure init(var f, g: text); begin reset(f); rewrite(g) end;
procedure getc(var f: text; var k: integer);
begin if eof(f) then k := 0 else if eoln(f) then k := 1 else k := 2; if k <> 0 then get(f) end;
begin
  init(inputfile, outputfile); n := 0; l := 0; c := 0;
  repeat getc(inputfile, n); if n = 1 then l := l + 1; if n = 2 then c := c + 1 until n = 0;
  writeln(outputfile, 'lines ', l, ' chars ', c)
end.
PAS
RC=0; N=0
chk() { local m="$1" p="$2" frc="$3"; run $m $p; local rc=$?; N=$((N + 1))
  if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc -Miso ($(wc -l < "$T/o") lines)"
  else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; }
want field; frc=$?; want hdrfile; hrc=$?
if [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/field.want"; fi
for m in m3 m4; do chk $m field $frc; chk $m hdrfile $hrc; done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a char-array field and a heading file pass by var as fpc -Miso does, both modes, $N of $N arms"
else echo "GATE FAIL(1) [$G]: see the arms above"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
