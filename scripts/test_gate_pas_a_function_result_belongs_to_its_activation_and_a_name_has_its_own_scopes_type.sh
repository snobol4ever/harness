#!/usr/bin/env bash
# test_gate_pas_a_function_result_belongs_to_its_activation_and_a_name_has_its_own_scopes_type.sh -- recursion, nested routines and named array types answer as fpc -Miso.
#
# MEASURED 2026-10-10 by hq_pascal on the Scheme demo (an ISO 7185 port of pascal-lisp, row pascal-demos-...-ceo-1579), each red in both modes on SCRIP 85fe66208:
# (1) a function's result variable was one global shared by every activation: f := n * 10; t := f(n - 1) returned the innermost
#     activation's value (fpc 30, SCRIP 0), and the Scheme expander's expandlist returned its last recursive call's list. CURE: the function
#     name is a local of its own activation (pas_local_add at both function-body entries); a result never assigned now stops with 6.6.2
#     on every call (it read the previous call's value).
# (2) a nested routine passing its enclosing routine's var parameter on as a var actual built a plain variable read, not the uplevel slot,
#     and died BOMB rt_assign_var: lvalue is not a variable. CURE: the pass-on of a var-parameter actual resolves the name and reads the
#     uplevel slot (IR_VAR_FRAME) as the reference-building road already did.
# (3) av[1]^.k through a variable of a named array-of-pointer type (argvec = array [1..4] of lv) lost the pointer's target: a variant
#     field lowered to a GOTO operand (FATAL emit_drive ... emit.cpp) and a plain field to a runtime BOMB. CURE: a named array type records
#     its element's pointer target, and a variable or formal of that type inherits it, as an inline array of pointers always did.
# (4) a variable's type was looked up by name alone, so a routine's pointer v took another routine's real v and v := f(...) became
#     v := f(...) + 0.0. CURE: the lookup prefers the entry of the definition visible at the use (its scope uid); every declared variable
#     is entered (a pointer by its type, an inline type as ?); the table grows instead of dropping entries at 512; the 6.8.3.9 for-range
#     check reads the visible declaration.
#
# ARMS, both modes, expectations cut LIVE from fpc -Miso: rec (1), nest (2), named (3), scope (4); plus two controls that fpc does not
# check: und (a function whose result is never assigned stops with 6.6.2 on the call, after the output before it) and range (PAT 1852's
# shape, a for over a 1..9 variable from 0 to 10, is refused at compile time with 6.8.3.9). FAIL_ONCE=1 corrupts arm rec's expectation.
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
cat > "$T/rec.pas" <<'PAS'
program rec(output);
type lv = ^cell; cell = record n: integer; next: lv end;
var r: lv;
function f(n: integer): integer;
var t: integer;
begin f := n * 10; if n > 0 then t := f(n - 1) end;
procedure outer;
  function g(n: integer): integer; forward;
  function h(n: integer): integer;
  var t: integer;
  begin h := n + 100; if n > 0 then t := g(n - 1) end;
  function g; begin g := h(n) end;
begin writeln(h(3)) end;
function build(n: integer): lv;
var p, rest: lv;
begin new(p); p^.n := n; build := p; if n > 1 then begin rest := build(n - 1); p^.next := rest end else p^.next := nil end;
function fib(n: integer): integer;
begin if n < 2 then fib := n else fib := fib(n - 1) + fib(n - 2) end;
begin
  writeln(f(3)); outer; writeln(fib(15));
  r := build(4); while r <> nil do begin write(r^.n:2); r := r^.next end; writeln
end.
PAS
cat > "$T/nest.pas" <<'PAS'
program nest(output);
var g, h: integer;
procedure bump(var v: integer); begin v := v + 1 end;
procedure outer(var p: integer; q: integer);
  var loc: integer;
  procedure inner; begin bump(p); bump(q); bump(loc) end;
  procedure deeper;
    procedure deepest; begin bump(p); p := p * 2 end;
  begin deepest end;
begin loc := 5; inner; deeper; writeln(p, q, loc) end;
function sum3(var a, b: integer): integer;
  function both: integer; begin bump(a); bump(b); both := a + b end;
begin sum3 := both end;
begin g := 1; outer(g, 10); writeln(g); g := 1; h := 2; writeln(sum3(g, h), g, h) end.
PAS
cat > "$T/named.pas" <<'PAS'
program named(output);
type kind = (kempty, kfix, kpair); lv = ^cell;
  cell = record case k: kind of kfix: (ival: integer); kpair: (a, d: lv); kempty: () end;
  argvec = array [1..4] of lv;
  plain = ^pcell; pcell = record n: integer; m: integer end; pvec = array [0..2] of plain;
var av: argvec; pv: pvec; x, y: lv; i: integer;
function fix(n: integer): lv; var p: lv; begin new(p); p^.k := kfix; p^.ival := n; fix := p end;
procedure fill(var v: argvec; n: integer); var j: integer; begin for j := 1 to 4 do v[j] := fix(n * j) end;
function total(v: argvec): integer; var j, s: integer; begin s := 0; for j := 1 to 4 do if v[j]^.k = kfix then s := s + v[j]^.ival; total := s end;
begin
  fill(av, 3); writeln(total(av), av[2]^.ival, ord(av[4]^.k));
  new(x); x^.k := kpair; x^.a := av[1]; x^.d := av[2]; av[3] := x; y := av[3]^.d; writeln(y^.ival, av[3]^.a^.ival);
  for i := 0 to 2 do begin new(pv[i]); pv[i]^.n := i * 7; pv[i]^.m := i end; writeln(pv[2]^.n + pv[1]^.m)
end.
PAS
cat > "$T/scope.pas" <<'PAS'
program scope(output);
type lv = ^cell; cell = record n: integer end;
var c: lv;
function mk(n: integer): lv; var p: lv; begin new(p); p^.n := n; mk := p end;
function realsum(k: integer): real;
var v, f: real; i: integer;
begin v := 0.0; f := 0.5; for i := 1 to k do v := v + f; realsum := v end;
function pick(e: lv): lv;
var v: lv;
begin v := e; pick := v end;
procedure host;
var v: real;
  function inner(e: lv): lv;
  var v: lv;
  begin v := e; inner := v end;
begin v := 2.5; c := inner(mk(4)); writeln(v:0:2, c^.n) end;
begin writeln(realsum(3):0:2); c := pick(mk(7)); writeln(c^.n); host end.
PAS
cat > "$T/und.pas" <<'PAS'
program und(output);
var k: integer;
function f(n: integer): integer; begin if n > 5 then f := n end;
begin k := f(9); writeln(k); k := f(2); writeln('after') end.
PAS
cat > "$T/range.pas" <<'PAS'
program range(output);
var i: 1..9;
begin for i := 0 to 10 do writeln('i: ', i) end.
PAS
RC=0; N=0
chk() { local m="$1" p="$2" frc="$3"; run $m $p; local rc=$?; N=$((N + 1))
  if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc -Miso ($(wc -l < "$T/o") lines)"
  else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; }
want rec; rrc=$?; want nest; nrc=$?; want named; mrc=$?; want scope; src=$?
if [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/rec.want"; fi
for m in m3 m4; do chk $m rec $rrc; chk $m nest $nrc; chk $m named $mrc; chk $m scope $src; done
for m in m3 m4; do run $m und; rc=$?; N=$((N + 1))
  if [ "$rc" != 0 ] && [ "$(cat "$T/o")" = "$(printf '          9')" ] && grep -q '6\.6\.2' "$T/e"; then echo "  und $m: stopped with 6.6.2 on the call that leaves the result unassigned, after the output before it (rc=$rc)"
  else echo "  ⛔ und $m FAILED: rc=$rc stdout=[$(head -c 60 "$T/o" | tr '\n' '|')] err=[$(head -c 120 "$T/e")]"; RC=1; fi
done
( cd "$T" && timeout -k 5 60s "$SCRIP" --run range.pas </dev/null >"$T/o" 2>"$T/e" ); rc=$?; N=$((N + 1))
if [ "$rc" != 0 ] && [ ! -s "$T/o" ] && grep -q '6\.8\.3\.9' "$T/e"; then echo "  range: refused at compile time with 6.8.3.9, no output (rc=$rc)"
else echo "  ⛔ range FAILED: rc=$rc stdout=[$(head -c 60 "$T/o" | tr '\n' '|')] err=[$(head -c 120 "$T/e")]"; RC=1; fi
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: function results per activation, nested var pass-on, named pointer arrays and scoped variable types answer as fpc -Miso in both modes, $N of $N arms"
else echo "GATE FAIL(1) [$G]: see the arms above"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
