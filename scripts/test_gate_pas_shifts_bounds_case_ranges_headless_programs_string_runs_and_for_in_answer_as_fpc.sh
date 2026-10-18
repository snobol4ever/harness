#!/usr/bin/env bash
# test_gate_pas_shifts_bounds_case_ranges_headless_programs_string_runs_and_for_in_answer_as_fpc.sh -- the FPC parse tail that stopped PasRosetta
# programs (the dialects row pascal-dialects-...-ceo-1614, chunk 6), each as fpc in its own mode answers.
#
# MEASURED 2026-10-11 by hq_pascal on SCRIP b2a65df31: of 129 PasRosetta programs stopping at a parse error, the classes taken here
# are shr/shl/xor, expressions in subrange and array bounds, case labels as expressions and ranges, a program with no heading, a dotted
# program name, a quoted string run on into #codes ('x'#13#10'y'), and for ... in.
# THE DIALECT: fpc -Miso refuses shl/shr/xor, which are identifiers in ISO (PAT iso7185pat0001 declares variables of those names). So
# the lexer makes them operators only right after an operand (a name, a literal, ')' or ']') and flips the dialect to fpc. fpc -Miso
# accepts the bound and label expressions, case ranges, headless and dotted programs, string runs and for ... in, so the ISO dialect
# takes them (CEO-1624).
# Under fpc's own modes a boolean writes TRUE/FALSE unpadded, which SCRIP now does once the dialect is fpc or objfpc. Integers already
# did; ISO keeps ' true'.
# THE LOWERING: shl is ishift(a, b), shr is ishift(a, -b), xor is ixor, or <> on booleans. Bound and label expressions fold through
# pas_fold_const. A case range is lo <= x <= hi. for x in c is a for over a hidden local index of the routine:
#   - a static array's own bounds;
#   - 0 .. length - 1 for a dynamic array;
#   - 1 .. length for a string;
#   - 0 .. 255 filtered by membership for a set.
# The element is assigned first, so continue and break keep their meaning.
#
# ARMS, both modes, every expectation cut LIVE from fpc in the arm's own mode:
#   - -Miso: bounds, caseranges, strings, quotes, forin, headless, dotted;
#   - -Mfpc: shifts, bools, headless_flip;
#   - -Mobjfpc: bools_objfpc;
#   - the control idents: an ISO program whose variables, field and parameter are named xor, shl and shr. fpc -Miso refuses those
#     names, so its expectation is cut from fpc -Miso running the same program with the names renamed.
# FAIL_ONCE=1 corrupts arm bounds.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- every arm's expectation is CUT FROM THE ORACLE"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/idents.pas" <<'PAS'
program idents(output);
type r = record xor: integer end;
var xor, shl: integer; shr: r;
procedure p(xor: integer; var shl: integer); begin shl := xor * 2 end;
begin xor := 3; p(xor, shl); shr.xor := shl + xor; writeln(xor, shl, shr.xor, (shl) - xor) end.
PAS
sed -e 's/\bxor\b/xor_/g; s/\bshl\b/shl_/g; s/\bshr\b/shr_/g' "$T/idents.pas" > "$T/idents_renamed.pas"
run() { local m="$1" p="$2"
  if [ "$m" = m3 ]; then ( cd "$T" && timeout -k 5 60s "$SCRIP" --run "$p.pas" </dev/null >"$T/o" 2>"$T/e" ); return $?; fi
  ( cd "$T" && timeout -k 5 60s "$SCRIP" --compile -o "$T/$p.s" "$p.pas" </dev/null >/dev/null 2>"$T/e" && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4 did not compile or link: $(head -1 "$T/e" | cut -c1-120)" >&2; return 99; }
  ( cd "$T" && timeout -k 5 60s "./$p.m4" </dev/null >"$T/o" 2>"$T/e" ); return $?; }
want() { ( cd "$T" && "$FPC" -M$2 -v0 -o"$1.fpc" $1.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -M$2 would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 60s ./$1.fpc </dev/null >"$T/$1.want" 2>/dev/null ); echo $? > "$T/$1.wrc"; }
cat > "$T/bounds.pas" <<'PAS'
program bd(output);
const n = 10; m = 3;
type r = 0 .. n - 1; t = array [0 .. (n - 1) div 2] of integer; u = array [-m .. m * 2 + 1] of char; w = array [1 .. n mod 4 + 2] of integer;
  e = (red, green, blue); s = red .. blue; c = 'a' .. 'e';
var x: r; a: t; b: u; q: w; y: s; z: c; k: integer;
begin
  x := 9; a[4] := 1; b[-3] := 'q'; b[7] := 'z'; q[4] := 5; y := blue; z := 'd';
  writeln(x, a[4], high(a), ' ', low(u), ' ', high(u), b[-3], b[7], ' ', high(q), q[4], ' ', ord(y), z);
  for k := 1 to 3 do case k * 2 of 2: write('two'); n - 6: write('four'); m * 2: write('six') end; writeln
end.
PAS
cat > "$T/caseranges.pas" <<'PAS'
program cr(output);
var c: char;
begin for c := 'a' to 'e' do case c of 'a'..'b': write('L'); 'c', 'd'..'e': write('H') end; writeln end.
PAS
cat > "$T/strings.pas" <<'PAS'
program sc(output);
const nl = 'a'#66'c'; t = #$41#$42;
begin writeln(nl, ' ', t, ' ', 'x'#9'y', length('ab'#13#10)) end.
PAS
cat > "$T/quotes.pas" <<'PAS'
program q(output);
begin writeln('it''s', ' ', 'it''s'#33, ' ', 'a', 'b') end.
PAS
cat > "$T/forin.pas" <<'PAS'
program fi3(output);
type e = (r, g, b);
var s: set of e; x: e; c: char; t, k: integer; a: array [3..5] of integer; d: array of integer; cs: set of char; str: packed array [1..3] of char;
begin
  s := [r, b]; t := 0; for x in s do t := t + ord(x); writeln(t);
  for c in 'abc' do write(c); writeln;
  a[3] := 1; a[4] := 2; a[5] := 3; t := 0; for k in a do t := t * 10 + k; writeln(t);
  setlength(d, 3); d[0] := 7; d[1] := 8; d[2] := 9; for k in d do write(k); writeln;
  cs := ['x', 'b', 'm']; for c in cs do write(c); writeln;
  str := 'pqr'; for c in str do write(c, '.'); writeln;
  for k in a do begin if k = 2 then continue; write(k) end; writeln
end.
PAS
cat > "$T/headless.pas" <<'PAS'
var a: integer;
begin a := 10; writeln(a) end.
PAS
cat > "$T/dotted.pas" <<'PAS'
program dn.pas;
begin writeln('x') end.
PAS
cat > "$T/shifts.pas" <<'PAS'
{$mode fpc}
program p;
var a: integer; b: boolean;
begin a := 10; b := true xor false; writeln(a shr 1, ' ', a shl 2, ' ', a xor 3, ' ', b, ' ', (a shr 1) and 1, ' ', 1 shl 30, ' ', a xor a xor 7) end.
PAS
cat > "$T/bools.pas" <<'PAS'
{$mode fpc}
program p;
var b: boolean;
begin b := 3 > 2; writeln(b, ' ', true, ' ', 1 <> 2) end.
PAS
cat > "$T/headless_flip.pas" <<'PAS'
var a: integer;
begin a := 10; writeln(a shr 1, ' ', true) end.
PAS
cat > "$T/bools_objfpc.pas" <<'PAS'
{$mode objfpc}
program p;
begin writeln(true, ' ', false:7, ' ', 1 < 2) end.
PAS
RC=0; N=0
chk() { local m="$1" p="$2" frc; frc=$(cat "$T/$p.wrc"); run $m $p; local rc=$?; N=$((N + 1))
  if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc ($(wc -l < "$T/o") lines)"
  else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; }
for p in bounds caseranges strings quotes forin headless dotted idents_renamed; do want $p iso; done
cp "$T/idents_renamed.want" "$T/idents.want"; cp "$T/idents_renamed.wrc" "$T/idents.wrc"
for p in shifts bools headless_flip; do want $p fpc; done
want bools_objfpc objfpc
if [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/bounds.want"; fi
for m in m3 m4; do for p in bounds caseranges strings quotes forin headless dotted shifts bools headless_flip bools_objfpc idents; do chk $m $p; done; done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: the FPC parse tail answers as fpc in each arm's own mode, both modes, $N of $N arms"
else echo "GATE FAIL(1) [$G]: see the arms above"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
