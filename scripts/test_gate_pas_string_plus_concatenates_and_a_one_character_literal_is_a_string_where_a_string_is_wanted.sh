#!/usr/bin/env bash
# test_gate_pas_string_plus_concatenates_and_a_one_character_literal_is_a_string_where_a_string_is_wanted.sh -- in a {$mode objfpc} program `s + 'x'` joins strings, and a one-character literal or a char is a STRING
# wherever a string is expected: a string-typed record field (variable, pointer, array element, with, nested), a string value formal, a string function's result.
#
# MEASURED 2026-10-09 by hq_pascal against fpc -Mobjfpc: (1) `s := s + 'x'` produced no output and exit 1 -- the parser built a numeric TT_ADD of a string and a char code, which fails silently; (2) `x.b := 'q'` for a record field of
# type string stored 113, the char code, and printed 113 (a one-character literal is a char-code node at parse time, and only a plain string VARIABLE was converted back); the same for `p^.b`, `a[i].b`, a `with` field, a string value
# actual (`f('a')`) and a string function's result (`g := 'n'`); (3) a comparison of two concatenations took the numeric path (error 102).
# CURE (pascal.y, lower_pascal.c; no global): pas_arith_or_set builds TT_CAT when either operand is a string (pas_is_stringexpr: a concatenation, a literal longer than one character, a string variable, a string-typed field,
# a user function that returns a string) or, in a program with a mode directive, when both are chars, converting char operands to strings (pas_concat_operand); the Pascal lowerer routes TT_CAT through lower_binop (the shared BINOP
# code 11); mk_assign converts a char right side to a string for a string-typed field target (pas_rectype_field_typename) and a string function's result target; pas_value_actuals_check does the same for an actual of a string value
# formal; pas_is_strval counts a concatenation as a string so a comparison of two uses __pas_strcmp. The set check runs first, so a set union is never a join.
# NOT COVERED, written in the baton: copy, concat, upcase, str, pos on a variable pattern, string indexing writes, and '' (refused by the 6.1.7 ruling).
#
# SCOPE (cfo 2026-10-17, row gate-pascal-string-plus-the-tctl-witness-exits-1-in-both-modes-where-fpc-exits-0-ceo-1807): tctl's f(a: string) shadows its global `a: array[1..2] of r`, and the array-of-string
# test (pas_is_strelem_arr, 9924a117a) and the static-array high lookup (pas_array_high_get) found arrays by name alone: length(a) folded to the global's 2 and a + '!' added a char code, so tctl died rc 1 at f.
# Array entries now carry the scope uid of their declaration: the array-of-string test counts only the array the name resolves to in scope, and the high lookup prefers it. tshadow is the second
# control (a global array of string, a local array of string shadowing it, a string formal shadowing it), also cut LIVE from fpc.
# ARMS, both modes: one control cut LIVE from fpc (the program's own {$mode objfpc} directive selects the dialect) with 21 lines over every shape above; it must be byte-identical. FAIL_ONCE=1 corrupts the control's ref.
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
  ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile --out="$T/$p.s" "$p.pas" </dev/null >/dev/null 2>&1 && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4: did not compile or link"; return 99; }
  ( cd "$T" && timeout -k 5 20s "./$p.m4" </dev/null >"$T/o" 2>"$T/e" ); return $?; }
fpcrun() { ( cd "$T" && "$FPC" -Miso -v0 -o"$1.fpc" $1.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 20s ./$1.fpc </dev/null >"$T/$1.want" 2>/dev/null ); echo $?; }
cat > "$T/tctl.pas" <<'PAS'
{$mode objfpc}
program tctl;
type r = record a: integer; b: string; c: char; p: ansistring end;
     pr = ^r;
var s, u: string; c: char; x: r; p: pr; a: array[1..2] of r; n: integer; cs: set of char;
function f(a: string): string; begin f := a + '!' end;
function g(a: integer): string; begin g := 'n' end;
function h(c: char): string; begin h := c end;
procedure show(a: string; b: string); begin writeln(a, '/', b, length(a)) end;
begin
  s := 'ab'; s := s + 'x'; writeln(s);
  s := s + s; writeln(s, length(s));
  c := 'z'; u := 'ab'; u := u + c; writeln(u);
  u := 'x' + u; writeln(u);
  u := 'ab' + 'cd' + 'ef'; writeln(u);
  c := 'a'; u := c + 'b'; writeln(u);
  writeln('a' + 'b');
  x.b := 'q'; writeln(x.b); x.b := x.b + 'r'; writeln(x.b);
  x.p := 'a'; writeln(x.p);
  new(p); p^.b := 'w'; writeln(p^.b);
  a[2].b := 'm'; writeln(a[2].b);
  with x do begin b := 'y'; c := 'z'; writeln(b, c) end;
  c := 'k'; x.b := c; writeln(x.b);
  writeln(f('a') + f('b'));
  writeln(g(1) + g(2), length(f('abc')));
  c := 'w'; writeln(h(c) + h('v'));
  show(c, 'z'); show('p', 'qq');
  if s + 'y' = 'ababx' + 'y' then writeln('eq');
  n := 3; writeln(n + 4);
  cs := ['a'..'c']; cs := cs + ['x']; if 'x' in cs then writeln('in')
end.
PAS
cat > "$T/tshadow.pas" <<'PAS'
{$mode objfpc}
program tshadow;
var a: array[1..3] of string; i: integer;
procedure loc;
var a: array[1..2] of string;
begin
  a[1] := 'xy'; a[2] := 'z';
  writeln(length(a), ' ', length(a[1]), ' ', a[1] + a[2]);
end;
function sh(a: string): integer; begin sh := length(a) end;
function sc(a: string): string; begin sc := a + '!' end;
begin
  a[1] := 'abc'; a[2] := 'de'; a[3] := 'f';
  writeln(length(a), ' ', length(a[2]), ' ', a[1] + a[3]);
  for i := 1 to 3 do write(length(a[i]));
  writeln;
  if a[2] = 'de' then writeln('eq');
  loc;
  writeln(sh('hello'), ' ', sc('q'));
end.
PAS
RC=0; N=0
for p in tctl tshadow; do
frc=$(fpcrun $p)
if [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/$p.want"; fi
for m in m3 m4; do run $m $p; rc=$?; N=$((N + 1))
  if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc ($(wc -l < "$T/o") lines)"
  else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi
done
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: string + concatenates and a one-character literal is a string where a string is wanted, as fpc does, $N of $N arms"
else echo "GATE FAIL(1) [$G]: examined 2 programs in 2 modes"; fi
exit $RC
