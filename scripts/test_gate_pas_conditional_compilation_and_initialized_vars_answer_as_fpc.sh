#!/usr/bin/env bash
# test_gate_pas_conditional_compilation_and_initialized_vars_answer_as_fpc.sh -- fpc's conditional compilation, nested, with its
# predefined macros, and initialized variables, every arm byte-identical to fpc (row pascal-dialects-one-switch-..., ceo CEO-1614;
# .github/ARCH-PASCAL-DIALECTS.md section 2: "directives are not ignored any more").
#
# THE LEXER (src/parsers/pascal/pascal.l):
# - {$ifdef} {$ifndef} {$if} {$elseif} {$else} {$endif} {$ifend}, MacPas's {$ifc} {$elsec} {$endc}, and {$define} {$undef} {$setc}
#   are one rule. Nesting is two counters and a taken bit in the parser state g_pascal_cenv: skip, depth, taken. The SKIPC state
#   swallows text, comments and strings until the next conditional.
# - THE MACROS fpc predefines are fpc 3.2.2's own list (fpc -va, 75 common to every mode), plus the active mode's own: FPC_ISO for
#   the ISO dialect, FPC_OBJFPC, FPC_DELPHI, FPC_TP or FPC_MACPAS from {$mode}. FPC_FULLVERSION and kin carry their values;
#   {$define X := v} and {$setc X := v} carry theirs.
# - {$if} reads defined, undefined, declared, option(x), not, and, or, parentheses, and comparisons of numbers, constants and macro
#   values; a {$define X := v} carries its value only under {$macro on}, as fpc's does. option(x) answers only a switch the program set itself ({$x+}/{$x-}, saved and restored by {$push}/{$pop}).
# - AN EXPRESSION IT CANNOT READ (a SizeOf of a record, say) is NEVER GUESSED. Both of its branches are skipped, and a branch that
#   holds program text refuses the compile by name. fpc's own tests guard only {$message fatal} or {$errorc} that way, so they
#   compile.
# - Measured: fpc -Miso honours conditional compilation and initialized variables. Neither flips the dialect: 3 refs cut under
#   -Miso would move (arithmetic-numbers, strong-and-weak-primes, test_cg_tcnvint1).
# INITIALIZED VARIABLES: var k: integer = 7 is the declaration's third child. The lowerer's pas_var_inits moves each initializer
# to the front of its block's statements, so a local is re-initialized at every call. fpc -Mfpc prints "6 6 7", measured.
#
# ARMS, every expectation CUT LIVE from fpc, both modes:
#   cif -- ten {$if} forms (versions, defined, declared, constants, or/not, nesting, define/undef, elseif, fpc_iso), against -Miso.
#   iv -- initialized global and local variables, against -Miso.
#   w1 and w1m -- the dialect row's witness 1, under -Miso and with {$mode fpc}.
#   mac -- {$mode macpas} with {$setc}, {$ifc ... = TRUE}, undefined/defined FPC_MACPAS, and option(j) across {$push}/{$pop}.
#   objm -- {$mode objfpc} makes FPC_OBJFPC defined and FPC_ISO undefined.
# REFUSAL ARMS: an unreadable {$if} guarding only a directive compiles; one guarding program text is refused naming the expression.
# FAIL_ONCE=1 corrupts one ref.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- every arm's expectation is CUT FROM THE ORACLE"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0; ARMS=0
run_mode() { local m="$1" p="$2"
  if [ "$m" = m3 ]; then ( cd "$T" && timeout -k 5 20s "$SCRIP" --run "$p.pas" </dev/null 2>"$T/$p.$m.err" | head -c 8000 >"$T/$p.$m.out"; exit "${PIPESTATUS[0]}" ); return $?; fi
  ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile -o "$T/$p.s" "$p.pas" </dev/null >/dev/null 2>"$T/$p.$m.err" ) || { echo "  ⛔ arm $p m4: did not compile"; return 99; }
  ( cd "$T" && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: arm $p compiled but would not link"; exit 2; }
  ( cd "$T" && timeout -k 5 20s "./$p.m4" </dev/null 2>"$T/$p.$m.err" | head -c 8000 >"$T/$p.$m.out"; exit "${PIPESTATUS[0]}" ); return $?; }
grade() { local p="$1" mode="$2"
  mkdir -p "$T/fpc_$p"
  ( cd "$T" && "$FPC" $mode -v0 -FE"$T/fpc_$p" -FU"$T/fpc_$p" -o"$T/fpc_$p/$p" "$p.pas" >/dev/null 2>&1 && timeout -k 5 20s "$T/fpc_$p/$p" </dev/null | head -c 8000 ) > "$T/$p.want" 2>/dev/null
  [ -s "$T/$p.want" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle produced no output for arm $p"; exit 2; }
  if [ -n "${FAIL_ONCE:-}" ] && [ "$p" = cif ]; then echo "corrupted by FAIL_ONCE" >> "$T/$p.want"; fi
  ARMS=$((ARMS + 1))
  for m in m3 m4; do
    run_mode $m "$p"; rc=$?
    if [ "$rc" = 0 ] && cmp -s "$T/$p.want" "$T/$p.$m.out"; then echo "  arm $p $m: byte-identical to fpc ${mode:-(default mode)}"
    else echo "  ⛔ arm $p $m FAILED: rc=$rc"; echo "      want: $(tr '\n' '|' < "$T/$p.want" | cut -c1-300)"; echo "      got : $(tr '\n' '|' < "$T/$p.$m.out" | cut -c1-300)"
         echo "      err : $(tr '\n' '|' < "$T/$p.$m.err" | cut -c1-200)"; RC=1; fi
  done; }
cat > "$T/cif.pas" <<'PAS'
program cif(output);
const version = 3; flt = 2.5;
begin
{$if FPC_FULLVERSION >= 30200} writeln('a yes'); {$else} writeln('a no'); {$endif}
{$if fpc_version = 3} writeln('b yes'); {$else} writeln('b no'); {$endif}
{$if defined(fpc) and not defined(windows)} writeln('c yes'); {$else} writeln('c no'); {$endif}
{$if version >= 2} writeln('d yes'); {$else} writeln('d no'); {$endif}
{$if declared(flt)} writeln('e yes'); {$else} writeln('e no'); {$endif}
{$if not defined(fpc) or (fpc_fullversion < 20600)} writeln('f yes'); {$else} writeln('f no'); {$endif}
{$ifdef fpc}{$ifndef unix} writeln('g1'); {$else} writeln('g2'); {$endif}{$else} writeln('g3'); {$endif}
{$define mine}{$ifdef MINE} writeln('h yes'); {$endif}{$undef mine}{$ifdef mine} writeln('h bad'); {$endif}
{$if defined(cpu64) or defined(cpu32)} writeln('i yes'); {$elseif defined(cpu16)} writeln('i16'); {$else} writeln('i no'); {$endif}
{$ifdef fpc_iso} writeln('j iso'); {$endif}
{$macro on}{$define flt2 := 1e+2}{$if flt2 < 99} writeln('k bad'); {$else} writeln('k yes'); {$endif}
end.
PAS
cat > "$T/iv.pas" <<'PAS'
program iv(output);
var g: integer = 7;
procedure p;
var x: integer = 5;
begin x := x + 1; write(x, ' ') end;
begin p; p; writeln(g)
end.
PAS
printf "program p(output);\n{\$ifdef fpc} var k: integer = 7; {\$else} var k: integer; {\$endif}\nbegin {\$ifdef fpc} writeln('fpc ', k) {\$else} k := 0; writeln(k) {\$endif} end.\n" > "$T/w1.pas"
{ printf '{$mode fpc}\n'; cat "$T/w1.pas"; } > "$T/w1m.pas"
cat > "$T/mac.pas" <<'PAS'
{$mode macpas}
program mac;
{$setc ADAM := TRUE}
{$setc BERTIL := FALSE}
{$J-}
{$push}
{$J+}
{$pop}
begin
{$ifc ADAM <> TRUE} writeln('a bad'); {$elsec} writeln('a ok'); {$endc}
{$ifc BERTIL = FALSE} writeln('b ok'); {$elsec} writeln('b bad'); {$endc}
{$ifc undefined FPC_MACPAS} writeln('c bad'); {$elsec} writeln('c ok'); {$endc}
{$ifc option(J)} writeln('d bad'); {$elsec} writeln('d ok'); {$endc}
end.
PAS
cat > "$T/objm.pas" <<'PAS'
{$mode objfpc}
program objm;
begin
{$ifdef fpc_objfpc} writeln('objfpc'); {$endif}
{$ifdef fpc_iso} writeln('iso'); {$else} writeln('not iso'); {$endif}
end.
PAS
grade cif "-Miso"
grade iv "-Miso"
grade w1 "-Miso"
grade w1m ""
grade mac ""
grade objm ""
printf "program u1(output);\ntype r = record a: integer end;\n{\$if sizeof(r) <> 4}\n{\$message fatal 'size'}\n{\$endif}\nbegin writeln(1) end.\n" > "$T/u1.pas"
printf "program u2(output);\ntype r = record a: integer end;\nbegin\n{\$if sizeof(r) <> 4} writeln(1); {\$endif}\nend.\n" > "$T/u2.pas"
ARMS=$((ARMS + 1))
( cd "$T" && timeout -k 5 20s "$SCRIP" u1.pas </dev/null >u1.out 2>u1.err ); r1=$?
if [ "$r1" = 0 ] && [ "$(cat "$T/u1.out")" = "          1" ]; then echo "  arm u1: an unreadable {\$if} guarding only a directive compiles"
else echo "  ⛔ arm u1 FAILED: rc=$r1 out=[$(cat "$T/u1.out")] err=[$(head -1 "$T/u1.err")]"; RC=1; fi
ARMS=$((ARMS + 1))
( cd "$T" && timeout -k 5 20s "$SCRIP" u2.pas </dev/null >u2.out 2>u2.err ); r2=$?
if [ "$r2" != 0 ] && grep -q "sizeof(r) <> 4" "$T/u2.err" && grep -q 'holds program text' "$T/u2.err"; then echo "  arm u2: an unreadable {\$if} guarding program text is refused by name (rc=$r2)"
else echo "  ⛔ arm u2 FAILED: rc=$r2 err=[$(head -1 "$T/u2.err" | cut -c1-160)]"; RC=1; fi
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: $ARMS arms -- conditional compilation and initialized variables answer as fpc in both modes; an unreadable {\$if} is never guessed"
else echo "GATE FAIL(1) [$G]: examined $ARMS arms (6 oracle-cut in 2 modes, 2 refusal arms)"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
