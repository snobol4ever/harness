#!/usr/bin/env bash
# test_gate_pas_what_fpc_miso_accepts_beyond_iso_answers_as_fpc.sh -- the extensions fpc -Miso accepts answer as fpc does (ARCH-PASCAL-DIALECTS.md section 2:
# a flip point is a construct fpc -Miso refuses; one it accepts is the ISO dialect's to accept, row pascal-dialects-...-ceo-1614, the FPC chunk).
#
# MEASURED 2026-10-11 by hq_pascal on PasRosetta (35 of 664; of its 319 graded programs 215 stopped at a parse error), each a red in both modes on
# SCRIP 45e63ef51 where fpc -Miso compiles and runs the program:
#   - s += 2, s -= 1, s *= 5, r /= 2 (a compound assignment carries its operator as a keyword child of the assignment node; the lowerer
#     combines it with the left side read as a value);
#   - writeln() and f() with an empty argument list (the same node as the bare call);
#   - break and continue inside for, while and repeat, nested (a jump to the loop's continuation or its next test; a for left by break keeps
#     its control variable, as a for left by goto does, ISO 7185 6.8.3.9);
#   - ansichar as char;
#   - a constant defined by an expression: folded when its operands are constants (string +, integer and real arithmetic, div, mod), else
#     the elaborated expression substituted at each use (sqrt(2.0), a set ['a'..'z'], not false, maxint arithmetic), scoped by its defining point;
#   - pi, fpc's system function;
#   - typed constants, x: T = v, with array aggregates indexed by integer, char, boolean and enumerated ranges, 2-D aggregates, record
#     aggregates (f: v; ...) and arrays of them, at program and procedure level.
# CONTROLS that must not move: an empty argument list on a procedure with formals is still refused (6.8.2.3, PAT 0800, which the empty-
# parentheses grammar first let through to a run-time BOMB), write() with none still refused (6.9.3, PAT 0900), and the 6.2.1 order of
# declaration parts still refused (Lon's ISO-as-oracle ruling, CEO-1225).
#
# ARMS, both modes, every expectation cut LIVE from fpc -Miso: assign, loops, consts, tconsts; three refusal controls. FAIL_ONCE=1 corrupts
# arm assign's expectation.
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
want() { ( cd "$T" && "$FPC" -Miso -v0 -o"$1.fpc" $1.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 60s ./$1.fpc </dev/null >"$T/$1.want" 2>/dev/null ); return $?; }
cat > "$T/assign.pas" <<'PAS'
program assign(output);
var s: integer; r: real; c: ansichar; a: array [1..3] of integer;
function f: integer; begin f := 41 end;
begin
  s := 1; s += 2; s -= 1; s *= 5; r := 9.0; r /= 2; a[2] := 3; a[2] += 4;
  writeln(s, ' ', r:0:2, ' ', a[2], ' ', f() + 1); writeln(); c := 'z'; writeln(c, ord(c))
end.
PAS
cat > "$T/loops.pas" <<'PAS'
program loops(output);
var i, j, s: integer;
begin
  s := 0; for i := 1 to 10 do begin if i = 3 then continue; if i = 7 then break; s := s + i end; writeln(s, ' ', i);
  i := 0; s := 0; while i < 20 do begin i := i + 1; if odd(i) then continue; if i > 12 then break; s := s + i end; writeln(s, ' ', i);
  i := 0; repeat i := i + 1; if i = 2 then continue; if i = 5 then break; write(i) until i > 8; writeln;
  for i := 1 to 3 do begin for j := 1 to 3 do begin if j = 2 then break; write(i, j) end; if i = 2 then continue; write('|') end; writeln;
  for i := 3 downto 1 do begin if i = 2 then continue; write(i) end; writeln
end.
PAS
cat > "$T/consts.pas" <<'PAS'
program consts(output);
const a = 'ab' + 'cd'; b = 3 * 4 + 1; c = b div 2 - 1; r = 1.5 * 2; neg = -b; q = 7 mod 3; ch = 'x'; dot = ch + '.'; h = 10 / 4;
  vowels = ['a', 'e', 'i', 'o', 'u']; digits = ['0'..'9']; r2 = sqrt(2.0); big = 10 * maxint div 100000; flag = not false; t = pi / 2;
var arr: array [1..b] of integer; k: char; n: integer;
procedure inner; const vowels = ['x']; begin writeln('x' in vowels, 'a' in vowels) end;
begin
  arr[b] := 2; writeln(a, ' ', b, ' ', c, ' ', r:0:2, ' ', neg, ' ', q, ' ', dot, ' ', h:0:2, ' ', arr[13]);
  n := 0; for k := 'a' to 'z' do if k in vowels then n := n + 1; writeln(n, '7' in digits, r2:0:4, ' ', big, ' ', flag, ' ', t:0:5, ' ', pi:0:5); inner
end.
PAS
cat > "$T/tconsts.pas" <<'PAS'
program tconsts(output);
const w: array [0..7] of integer = (+6, +4, +2, +4, +2, +4, +6, +2); n: integer = 5;
  bs: array [boolean] of char = ('F', 'T'); cv: array ['1'..'3'] of char = ('A', 'C', 'G');
  half: record num, den: integer end = (num: 1; den: 2);
  m: array [0..1, 0..2] of integer = ((1, 2, 3), (4, 5, 6)); pts: array [1..2] of record x, y: real end = ((x: 1.5; y: 2.0), (x: -1.0; y: 0.5));
  rr: real = 2.5; cc: char = 'q'; colours: array [(red, green, blue)] of integer = (7, 8, 9);
var i: integer;
procedure show; const loc: array [1..3] of integer = (10, 20, 30); begin writeln(loc[1] + loc[3]) end;
begin
  for i := 0 to 7 do write(w[i]); writeln(' ', n, ' ', bs[true], bs[false], cv['2'], ' ', half.num, '/', half.den, ' ', m[1, 2], m[0, 1]);
  writeln(pts[2].x:0:1, ' ', pts[1].y:0:1, ' ', rr:0:1, cc, ' ', colours[green]); show
end.
PAS
cat > "$T/c800.pas" <<'PAS'
program c800(output);
procedure test(a, b: integer); begin a := 1; b := 1 end;
begin test() end.
PAS
cat > "$T/c900.pas" <<'PAS'
program c900(output);
begin write() end.
PAS
cat > "$T/c621.pas" <<'PAS'
program c621(output);
type t = integer;
const k = 3;
begin writeln(k) end.
PAS
RC=0; N=0
chk() { local m="$1" p="$2" frc="$3"; run $m $p; local rc=$?; N=$((N + 1))
  if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc -Miso ($(wc -l < "$T/o") lines)"
  else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; }
want assign; arc=$?; want loops; lrc=$?; want consts; crc=$?; want tconsts; trc=$?
if [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/assign.want"; fi
for m in m3 m4; do chk $m assign $arc; chk $m loops $lrc; chk $m consts $crc; chk $m tconsts $trc; done
refuse() { local p="$1" clause="$2"; ( cd "$T" && timeout -k 5 60s "$SCRIP" --run "$p.pas" </dev/null >"$T/o" 2>"$T/e" ); local rc=$?; N=$((N + 1))
  if [ "$rc" != 0 ] && [ ! -s "$T/o" ] && grep -q "$clause" "$T/e"; then echo "  $p: refused at compile time with $clause (rc=$rc)"
  else echo "  ⛔ $p FAILED: rc=$rc, want a compile-time $clause refusal: stdout=[$(head -c 60 "$T/o" | tr '\n' '|')] err=[$(head -c 140 "$T/e")]"; RC=1; fi; }
refuse c800 '6\.8\.2\.3'; refuse c900 '6\.9\.3'; refuse c621 '6\.2\.1'
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: what fpc -Miso accepts beyond ISO answers as fpc in both modes, and the three ISO refusals stand, $N of $N arms"
else echo "GATE FAIL(1) [$G]: see the arms above"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
