#!/usr/bin/env bash
# test_gate_pas_uses_and_units_answer_as_fpc.sh -- a program's uses clause names units SCRIP compiles WITH it, whole-program, and
# every arm answers byte-identical to fpc (Lon 2026-10-10 to the ceo, CEO-1611: "Certainly we should allow the "uses" feature for
# Pascal since SNOBOL4 has INCLUDE, and Snocone will have import."; row pascal-uses-and-units-compile-time-whole-program-...).
#
# THE DESIGN (the ceo's, CEO-1611): uses is COMPILE-TIME. The grammar takes a unit (interface, implementation, initialization or a
# begin part, finalization) and a uses clause in a program, a unit's interface and its implementation; uses, unit, interface,
# implementation, initialization and finalization are CONTEXTUAL keywords, so an ISO program keeps them as identifiers (arm kw).
# The driver (pascal_driver.c) resolves each named unit once, transitively, as a file beside the program matched case-insensitively
# (.pas or .pp) or SCRIP's own prelude unit (src/parsers/pascal/prelude/: sysutils, math, strings, strutils), refuses crt as
# NEEDS_INTERACTIVE_TTY, and hangs the units on the program as a trailing units part in dependency order. The lowerer's
# pas_flatten_units merges them into the program before E_program: a unit's implementation-only names and a public name two scopes
# declare become U.name in the unit's scope; a bare name in a scope resolves to its own declaration, else to the LAST unit of that
# scope's uses clauses exporting it (fpc's rule, arm clash's two orders); U.name qualified resolves directly; interface headings
# become forward declarations; initialization parts run in dependency order before the body. FINALIZATION, A MEASURED FACT OF THE
# ORACLE fpc 3.2.2 AND NOT A PASCAL RULE (ceo CEO-1617: a later oracle swap re-measures it, ARCH-PASCAL-DIALECTS.md section 2): fpc runs a unit's
# finalization part AFTER it has closed the standard files, so its writes never appear (measured: a finalization that writes a file
# and then writeln -- the file is written, the line is not); SCRIP runs the finalization parts in reverse order after the body behind
# __pas_std_mute, which flushes stdout and points fd 1 at /dev/null.
#
# ARMS, every expectation CUT LIVE from fpc (fpc's default mode for the unit arms, -Miso for arm kw), byte-identical in BOTH modes:
#   units  -- ubase/utop/p: a private helper in two units, a qualified call ubase.twice(1), initialization order, a finalization
#             whose output fpc never shows, the prelude's IntToStr, UpperCase, Trim, Max and Power.
#   shapes -- Shapes/q: a unit's enum, record, const and var; a begin initialization; an implementation-only var; the program's own
#             Value shadowing the unit's; the qualified statement shapes.bump; the qualified enum constant Shapes.Green.
#   clash  -- ua/ub with f in both: uses ua, ub and uses ub, ua answer differently, as fpc does.
#   kw     -- unit, interface, implementation, initialization, finalization and uses as variables of an ISO program.
#   mode   -- {$mode objfpc} sets the dialect switch before the parse (ARCH-PASCAL-DIALECTS.md § 2, CEO-1614): the six words are
#             reserved, uses needs no flip, and integers print bare as in every non-ISO dialect.
# THE SWITCH: one dialect per program, the parser state's dialect field (ISO by default, ISO, FPC, ObjFPC, Delphi), set by the lexer
# on {$mode} and flipped from the ISO default to FPC by the first uses or unit; the decision reaches the lowerer only through the
# tree, as the lexer's seen_mode event on the next leaf -- which pas_flatten_units applies from the uses part it drops.
# REFUSALS (SCRIP's own diagnostics, rc non-zero): a missing unit, uses crt, and a unit compiled as a program.
# FAIL_ONCE=1 corrupts one ref to prove the gate can fail.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- every arm's expectation is CUT FROM THE ORACLE"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0; ARMS=0
run_mode() { local m="$1" d="$2" p="$3"
  if [ "$m" = m3 ]; then ( cd "$d" && timeout -k 5 20s "$SCRIP" --run "$p.pas" </dev/null 2>"$d/$p.$m.err" | head -c 8000 >"$d/$p.$m.out"; exit "${PIPESTATUS[0]}" ); return $?; fi
  ( cd "$d" && timeout -k 5 20s "$SCRIP" --compile -o "$d/$p.s" "$p.pas" </dev/null >/dev/null 2>"$d/$p.$m.err" ) || { echo "  ⛔ arm $p m4: did not compile"; return 99; }
  ( cd "$d" && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: arm $p compiled but would not link"; exit 2; }
  ( cd "$d" && timeout -k 5 20s "./$p.m4" </dev/null 2>"$d/$p.$m.err" | head -c 8000 >"$d/$p.$m.out"; exit "${PIPESTATUS[0]}" ); return $?; }
grade() { local arm="$1" p="$2" mode="$3" d="$T/$1"
  mkdir -p "$d/fpc"
  ( cd "$d" && "$FPC" $mode -v0 -B -FE"$d/fpc" -FU"$d/fpc" -o"$d/fpc/$p" "$p.pas" >/dev/null 2>&1 && timeout -k 5 20s "$d/fpc/$p" </dev/null | head -c 8000 ) > "$d/$p.want" 2>/dev/null
  [ -s "$d/$p.want" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle produced no output for arm $arm ($p)"; exit 2; }
  if [ -n "${FAIL_ONCE:-}" ] && [ "$arm" = units ]; then echo "corrupted by FAIL_ONCE" >> "$d/$p.want"; fi
  ARMS=$((ARMS + 1))
  for m in m3 m4; do
    run_mode $m "$d" "$p"; rc=$?
    if [ "$rc" = 0 ] && cmp -s "$d/$p.want" "$d/$p.$m.out"; then echo "  arm $arm/$p $m: byte-identical to fpc"
    else echo "  ⛔ arm $arm/$p $m FAILED: rc=$rc"; echo "      want: $(tr '\n' '|' < "$d/$p.want" | cut -c1-400)"; echo "      got : $(tr '\n' '|' < "$d/$p.$m.out" | cut -c1-400)"
         echo "      err : $(tr '\n' '|' < "$d/$p.$m.err" | cut -c1-300)"; RC=1; fi
  done; }
refuse() { local arm="$1" p="$2" want="$3" d="$T/$1"
  ARMS=$((ARMS + 1))
  ( cd "$d" && timeout -k 5 20s "$SCRIP" --run "$p.pas" </dev/null >"$d/$p.out" 2>"$d/$p.err" ); rc=$?
  if [ "$rc" != 0 ] && grep -qF -- "$want" "$d/$p.err"; then echo "  arm $arm/$p: refused rc=$rc naming '$want'"
  else echo "  ⛔ arm $arm/$p FAILED: rc=$rc, stderr lacks '$want': $(tr '\n' '|' < "$d/$p.err" | cut -c1-300)"; RC=1; fi; }
mkdir -p "$T/units" "$T/shapes" "$T/clash" "$T/kw" "$T/mode" "$T/refuse"
cat > "$T/units/ubase.pas" <<'PAS'
unit ubase;
interface
const greeting = 'hello';
function twice(x: integer): integer;
procedure show(s: string);
implementation
function helper(x: integer): integer; begin helper := x * 2 end;
function twice(x: integer): integer; begin twice := helper(x) end;
procedure show(s: string); begin writeln('base: ', s) end;
initialization
  writeln('init base');
finalization
  writeln('fini base');
end.
PAS
cat > "$T/units/utop.pas" <<'PAS'
unit utop;
interface
uses ubase;
function thrice(x: integer): integer;
implementation
function helper(x: integer): integer; begin helper := x * 3 end;
function thrice(x: integer): integer; begin thrice := helper(x) + twice(0) end;
initialization
  writeln('init top');
end.
PAS
cat > "$T/units/p.pas" <<'PAS'
program p;
uses utop, ubase, sysutils, math;
begin
  show(greeting);
  writeln(twice(5), ' ', thrice(5), ' ', ubase.twice(1));
  writeln(IntToStr(42) + '-' + UpperCase('ab') + Trim('  x  '), ' ', Max(3, 7), ' ', Power(2, 10):0:0);
end.
PAS
cat > "$T/shapes/Shapes.pas" <<'PAS'
unit Shapes;
interface
type
  Color = (Red, Green, Blue);
  Point = record x, y: integer end;
const
  Origin = 0;
var
  Count: integer;
function MakePoint(a, b: integer): Point;
procedure Bump;
function ColorName(c: Color): string;
function Value: integer;
implementation
var hidden: integer;
function MakePoint(a, b: integer): Point;
var p: Point;
begin
  p.x := a; p.y := b; MakePoint := p
end;
procedure Bump;
begin
  Count := Count + 1; hidden := hidden + 10
end;
function ColorName(c: Color): string;
begin
  case c of Red: ColorName := 'red'; Green: ColorName := 'green'; Blue: ColorName := 'blue' end
end;
function Value: integer;
begin
  Value := hidden + Count
end;
begin
  Count := 100; hidden := 1
end.
PAS
cat > "$T/shapes/q.pas" <<'PAS'
program q;
uses Shapes;
var p: Point; c: Color;
function Value: integer;
begin
  Value := -1
end;
begin
  p := MakePoint(3, 4);
  writeln(p.x + p.y + Origin);
  Bump; shapes.bump;
  writeln(Count, ' ', Shapes.Count);
  writeln(Value, ' ', Shapes.Value);
  for c := Red to Blue do write(ColorName(c), ' ');
  writeln;
  c := Shapes.Green;
  writeln(ord(c))
end.
PAS
cat > "$T/clash/ua.pas" <<'PAS'
unit ua;
interface
function f: integer;
implementation
function f: integer; begin f := 1 end;
end.
PAS
cat > "$T/clash/ub.pas" <<'PAS'
unit ub;
interface
uses ua;
function f: integer;
function g: integer;
implementation
function f: integer; begin f := 20 + ua.f end;
function g: integer; begin g := f end;
end.
PAS
cat > "$T/clash/r.pas" <<'PAS'
program r;
uses ua, ub;
begin
  writeln(f, ' ', ua.f, ' ', ub.f, ' ', g)
end.
PAS
cat > "$T/clash/r2.pas" <<'PAS'
program r2;
uses ub, ua;
begin
  writeln(f, ' ', g)
end.
PAS
cat > "$T/kw/k.pas" <<'PAS'
program k(output);
var unit, interface, implementation, initialization, finalization, uses: integer;
begin
  unit := 1; interface := 2; implementation := 3; initialization := 4; finalization := 5; uses := 6;
  writeln(unit + interface + implementation + initialization + finalization + uses)
end.
PAS
printf '{$mode objfpc}\nprogram mo;\nuses ua;\nvar n: integer;\nbegin\n  n := 40;\n  writeln(f, n + 2)\nend.\n' > "$T/mode/mo.pas"
cp "$T/clash/ua.pas" "$T/mode/ua.pas"
printf 'program m;\nuses nosuchunit;\nbegin end.\n' > "$T/refuse/m.pas"
printf 'program c;\nuses crt;\nbegin writeln(1) end.\n' > "$T/refuse/c.pas"
cp "$T/clash/ua.pas" "$T/refuse/ua.pas"
grade units p ""
grade shapes q ""
grade clash r ""
grade clash r2 ""
grade kw k "-Miso"
grade mode mo ""
refuse refuse m "uses nosuchunit"
refuse refuse c "NEEDS_INTERACTIVE_TTY"
refuse refuse ua "is a unit, not a program"
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: $ARMS arms -- uses, units and their contextual keywords answer as fpc in both modes; the three refusals name their cause"
else echo "GATE FAIL(1) [$G]: examined $ARMS arms (6 oracle-cut in 2 modes, 3 refusals)"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
