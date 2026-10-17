#!/usr/bin/env bash
# test_gate_pas_dynamic_and_open_arrays_and_const_and_out_parameters_answer_as_fpc.sh -- FPC's dynamic arrays and open-array parameters,
# which fpc -Miso accepts (so the ISO dialect accepts them, CEO-1624), and const and out parameters, each as its fpc mode answers (the
# dialects row pascal-dialects-...-ceo-1614, chunk 5).
#
# MEASURED 2026-10-11 by hq_pascal: of PasRosetta's 319 graded programs, 63 stopped at a parse error on "array of" and 15 on a const
# parameter, on SCRIP 6eda0b182, where every arm below is a parse error.
# THE SEMANTICS, each as fpc:
#   - array of T is 0-based, empty until setlength. Assignment shares it (a reference type).
#   - setlength(a, n [, m]) makes a fresh array and keeps the old elements. New ones are zero of the element type: integer 0, real 0.0,
#     a record's zero record, char #0, an empty inner array.
#   - length, low and high are read at run time, for an inner array too.
#   - A named dynamic type (TIntArray = array of integer) is the same type.
#   - An open-array formal (a: array of T) sees any actual array 0-based. By value or const it is a copy. A var formal binds a dynamic
#     actual by reference; a static actual is copied in and rebased back out.
#   - const parameters are value parameters.
#   - out parameters are var parameters, and fpc accepts them only in objfpc and delphi, so out flips the dialect to objfpc.
# CONTROLS: PAT iso7185prt0603 and 0607 (malformed parameter lists) are still refused at compile time with the parser's message.
# iso7185prt0508 (var a: array of integer, the "missing index" rejection test) compiles, as under fpc -Miso; its a[1] := 1 on an empty
# array then exits non-zero with the 6.5.3.2 diagnostic, which the PAT grading still reads as PASS.
#
# ARMS, both modes, every expectation cut LIVE from fpc: dyn and opens under -Miso, outp under -Mobjfpc; two compile-time refusal
# controls. FAIL_ONCE=1 corrupts arm dyn.
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
  ( cd "$T" && timeout -k 5 60s "$SCRIP" --compile -o "$T/$p.s" "$p.pas" </dev/null >/dev/null 2>"$T/e" && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4 did not compile or link: $(head -1 "$T/e" | cut -c1-120)" >&2; return 99; }
  ( cd "$T" && timeout -k 5 60s "./$p.m4" </dev/null >"$T/o" 2>"$T/e" ); return $?; }
want() { ( cd "$T" && "$FPC" -M$2 -v0 -o"$1.fpc" $1.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -M$2 would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 60s ./$1.fpc </dev/null >"$T/$1.want" 2>/dev/null ); return $?; }
cat > "$T/dyn.pas" <<'PAS'
program dyn(output);
type TIntArray = array of integer; TPt = record x, y: real end;
var a: array of integer; b: TIntArray; r: array of real; m: array of array of integer; p: array of TPt; i, j: integer;
begin
  writeln(length(a), ' ', high(a));
  setlength(a, 5); for i := 0 to high(a) do a[i] := i * i; writeln(length(a), ' ', low(a), ' ', high(a), ' ', a[4]);
  b := a; b[0] := 99; writeln(a[0]);
  setlength(a, 7); a[6] := 1; writeln(a[4], ' ', a[5], ' ', a[6], ' ', length(b), ' ', b[0]);
  setlength(r, 2); r[1] := 2.5; r[0] := 1; writeln(r[0]:0:1, ' ', r[1]:0:1);
  setlength(m, 3, 4); for i := 0 to 2 do for j := 0 to 3 do m[i][j] := i * 10 + j; writeln(length(m), ' ', length(m[1]), ' ', m[2][3], ' ', m[1, 2]);
  setlength(p, 2); p[1].x := 1.5; writeln(p[1].x:0:1, ' ', p[0].y:0:1)
end.
PAS
cat > "$T/opens.pas" <<'PAS'
program opens(output);
type TIntArray = array of integer; TRec = record k: integer; v: real end;
var st: array [5..8] of integer; dy: TIntArray; rs: array of TRec; i: integer;
function sum(const a: array of integer): integer; var k, t: integer; begin t := 0; for k := low(a) to high(a) do t := t + a[k]; sum := t end;
procedure show(a: array of integer); var k: integer; begin write(length(a), ':'); for k := 0 to high(a) do write(' ', a[k]); a[0] := -1; writeln end;
procedure bump(var a: array of integer); var k: integer; begin for k := 0 to high(a) do a[k] := a[k] + 100 end;
procedure fill(var a: TIntArray; n: integer); var k: integer; begin setlength(a, n); for k := 0 to n - 1 do a[k] := k end;
function total(const r: array of TRec): real; var k: integer; t: real; begin t := 0; for k := 0 to high(r) do t := t + r[k].v * r[k].k; total := t end;
begin
  for i := 5 to 8 do st[i] := i; writeln(sum(st)); show(st); writeln(st[5]); bump(st); writeln(st[5], ' ', st[8]);
  fill(dy, 4); writeln(sum(dy)); show(dy); bump(dy); writeln(dy[0], ' ', dy[3]);
  setlength(rs, 2); rs[0].k := 2; rs[0].v := 1.5; rs[1].k := 3; rs[1].v := 0.5; writeln(total(rs):0:2)
end.
PAS
cat > "$T/outp.pas" <<'PAS'
program outp;
type TIntArray = array of integer;
var dy: TIntArray; n: integer;
procedure fill(out a: TIntArray; k: integer); var j: integer; begin setlength(a, k); for j := 0 to k - 1 do a[j] := j * 3 end;
procedure get(out x: integer); begin x := 42 end;
begin fill(dy, 3); get(n); writeln(length(dy), ' ', dy[2], ' ', n) end.
PAS
cat > "$T/c603.pas" <<'PAS'
program c603;
procedure a(b c: integer); begin b := 1; c := 1 end;
begin a(1, 2) end.
PAS
cat > "$T/c607.pas" <<'PAS'
program c607;
var b: integer;
procedure a(vas b: integer); begin b := 1 end;
begin a(b) end.
PAS
RC=0; N=0
chk() { local m="$1" p="$2" frc="$3"; run $m $p; local rc=$?; N=$((N + 1))
  if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc ($(wc -l < "$T/o") lines)"
  else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; }
want dyn iso; drc=$?; want opens iso; orc=$?; want outp objfpc; prc=$?
if [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/dyn.want"; fi
for m in m3 m4; do chk $m dyn $drc; chk $m opens $orc; chk $m outp $prc; done
refuse() { local p="$1"; ( cd "$T" && timeout -k 5 60s "$SCRIP" --run "$p.pas" </dev/null >"$T/o" 2>"$T/e" ); local rc=$?; N=$((N + 1))
  if [ "$rc" != 0 ] && [ ! -s "$T/o" ] && grep -q 'pascal parse error line [0-9]*: syntax error' "$T/e"; then echo "  $p: refused at compile time with the parser's message (rc=$rc)"
  else echo "  ⛔ $p FAILED: rc=$rc, want a compile-time syntax error: err=[$(head -c 140 "$T/e")]"; RC=1; fi; }
refuse c603; refuse c607
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: dynamic and open arrays, const and out parameters answer as fpc in both modes, $N of $N arms"
else echo "GATE FAIL(1) [$G]: see the arms above"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
