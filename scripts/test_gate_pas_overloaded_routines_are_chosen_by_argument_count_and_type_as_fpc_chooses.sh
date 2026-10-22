#!/usr/bin/env bash
# test_gate_pas_overloaded_routines_are_chosen_by_argument_count_and_type_as_fpc_chooses.sh -- in a source that names a {$mode} (objfpc, delphi, fpc), routines of
# one name declared in one scope with different parameter lists are OVERLOADS: a call picks the one whose parameters fit the actuals by count and by type, the way
# fpc picks it (FPC test tbs_tb0675: Test(Currency) is the Double overload, Test2(Currency) the Extended one).
#
# MEASURED 2026-10-22 by hq_pascal on the parent (SCRIP 3b6aebe95), fpc 3.2.2 against scrip: the first definition of a name won for every call, so F(1), F(2.5) and
# F('s') all ran F(Integer) ("int int int" for fpc's "int dbl str"), a call with another argument count aborted the run with 'libscrip_rt: BOMB -- a block-protocol
# callee is called with the wrong argument count' (rc 134), and an overloaded METHOD ran the first one too.
# THE CURE (lower_pascal_tree.c): pas_overload_name gives a later routine of an already-declared name in the same scope its own internal name (name$N, the shadowing
# mechanism's alias) unless its parameter signature equals an earlier one's (a forward declaration and its body); pas_overload_pick, at a call whose name has two or
# more routines in the innermost scope that declares it, keeps those the actuals can reach (count, with defaults) and takes the cheapest conversion, ties to the
# earlier declaration; with no fit it keeps the first of the right count. Nothing else changes: a name with one routine takes the old road, and the ISO dialect has no overloading.
# THE RANKING (each cut from fpc, see arms): an exact type first; an integer literal is longint (int64 past 32 bits); a real literal is the smallest of single, double,
# extended that holds it exactly; integer arithmetic is int64; a real expression takes its widest real VARIABLE's type; widening beats narrowing and a signed to unsigned
# change; Currency prefers Extended, then Double, then Single; Char beats String for a one-character literal.
# KNOWN GAPS (not asserted): ord(c) and the other builtins' result types, a procedural-type or array parameter (typed '?'), 'overload; forward;' in that order (the parser).
#
# ARMS (both modes, stdout and exit code cut LIVE from fpc -Mobjfpc): ovbasic (count and three types), ovtypes (byte..extended, char, string, boolean, literals and
# expressions, recursion, forward + body, var parameters, defaults, nested routines), ovfloat (literal and variable ranking over single, double, extended and over
# int64, longint, byte, word), ovexpr (arithmetic result types), ovmeth (overloaded methods of a class), tb0675 (the FPC witness, corpus/packages/pascal/fpc_tests).
# FAIL_ONCE=1 corrupts ovbasic's expectation.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
CORPUS="$(cd "$HERE/../../corpus" 2>/dev/null && pwd)" || { echo "⛔ GATE REFUSE(2) [$G]: no corpus beside harness"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- every expectation is CUT FROM THE ORACLE"; exit 2; }
WIT="$CORPUS/packages/pascal/fpc_tests/tbs_tb0675.pas"; [ -f "$WIT" ] || { echo "⛔ GATE REFUSE(2) [$G]: no witness at $WIT"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0; N=0
run() { local m="$1" p="$2"
  if [ "$m" = m3 ]; then ( cd "$T" && LD_LIBRARY_PATH="$RT_DIR" timeout -k 5 20s "$SCRIP" --run "$p.pas" </dev/null >"$T/o" 2>"$T/e" ); return $?; fi
  ( cd "$T" && LD_LIBRARY_PATH="$RT_DIR" timeout -k 5 20s "$SCRIP" --compile -o "$T/$p.s" "$p.pas" </dev/null >/dev/null 2>"$T/e" && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4: did not compile and link ($(head -1 "$T/e" | cut -c1-120))"; return 125; }
  ( cd "$T" && LD_LIBRARY_PATH="$RT_DIR" timeout -k 5 20s "./$p.m4" </dev/null >"$T/o" 2>"$T/e" ); return $?; }
fpcrun() { mkdir -p "$T/fpc"; ( cd "$T" && "$FPC" -Mobjfpc -v0 -FE"$T/fpc" -o"$T/$1.fpc" "$T/$1.pas" >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Mobjfpc would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 20s "./$1.fpc" </dev/null >"$T/$1.want" 2>/dev/null ); echo $?; }
cat > "$T/ovbasic.pas" <<'PAS'
{$mode objfpc}
program ovbasic;
function F(a: Integer): String; begin Result := 'int'; end;
function F(a: Double): String; begin Result := 'dbl'; end;
function F(a: String): String; begin Result := 'str'; end;
procedure P(a: Integer); begin writeln('P int ', a); end;
procedure P(a: Integer; b: Integer); begin writeln('P two ', a, ' ', b); end;
var i: Integer; d: Double; s: String;
begin
  i := 1; d := 2.5; s := 'x';
  writeln(F(i), ' ', F(d), ' ', F(s), ' ', F(3), ' ', F(1.5), ' ', F('lit'));
  P(1); P(1, 2);
end.
PAS
cat > "$T/ovtypes.pas" <<'PAS'
{$mode objfpc}
program ovtypes;
function Name(a: Byte): String; overload; begin Name := 'byte'; end;
function Name(a: Longint): String; overload; begin Name := 'longint'; end;
function Name(a: Int64): String; overload; begin Name := 'int64'; end;
function Name(a: Single): String; overload; begin Name := 'single'; end;
function Name(a: Double): String; overload; begin Name := 'double'; end;
function Name(a: Extended): String; overload; begin Name := 'extended'; end;
function Name(a: Char): String; overload; begin Name := 'char'; end;
function Name(a: String): String; overload; begin Name := 'string'; end;
function Name(a: Boolean): String; overload; begin Name := 'boolean'; end;
function Fact(n: Integer): Int64; overload; begin if n <= 1 then Result := 1 else Result := n * Fact(n - 1); end;
function Fact(n: Integer; acc: Int64): Int64; overload; begin if n <= 1 then Result := acc else Result := Fact(n - 1, acc * n); end;
function Sum(a, b: Integer): Integer; forward;
function Sum(a, b, c: Integer): Integer; overload; begin Result := a + b + c; end;
function Sum(a, b: Integer): Integer; begin Result := a + b; end;
procedure Swap(var a, b: Integer); overload; var t: Integer; begin t := a; a := b; b := t; end;
procedure Swap(var a, b: String); overload; var t: String; begin t := a; a := b; b := t; end;
procedure Show(a: Integer; b: Integer = 7); overload; begin writeln('show1 ', a, ' ', b); end;
procedure Show(s: String); overload; begin writeln('show2 ', s); end;
procedure Outer;
  procedure Inner(x: Integer); overload; begin writeln('inner int ', x); end;
  procedure Inner(x: String); overload; begin writeln('inner str ', x); end;
begin Inner(5); Inner('five'); end;
var b: Byte; l: Longint; i64: Int64; sg: Single; db: Double; ex: Extended; c: Char; s: String; bo: Boolean; i, j: Integer; s1, s2: String;
begin
  b := 1; l := 2; i64 := 3; sg := 1.5; db := 2.5; ex := 3.5; c := 'x'; s := 'hello'; bo := true;
  writeln(Name(b), ' ', Name(l), ' ', Name(i64), ' ', Name(sg), ' ', Name(db), ' ', Name(ex));
  writeln(Name(c), ' ', Name(s), ' ', Name(bo), ' ', Name('lit'), ' ', Name('c'), ' ', Name(true));
  writeln(Name(10), ' ', Name(2.5), ' ', Name(l + 1), ' ', Name(db * 2));
  writeln(Fact(5), ' ', Fact(5, 1), ' ', Sum(1, 2), ' ', Sum(1, 2, 3));
  i := 1; j := 2; Swap(i, j); writeln(i, ' ', j);
  s1 := 'a'; s2 := 'b'; Swap(s1, s2); writeln(s1, ' ', s2);
  Show(1); Show(1, 2); Show('x');
  Outer;
end.
PAS
cat > "$T/ovfloat.pas" <<'PAS'
{$mode objfpc}
program ovfloat;
function N(a: Extended): String; overload; begin N := 'extended'; end;
function N(a: Double): String; overload; begin N := 'double'; end;
function N(a: Single): String; overload; begin N := 'single'; end;
function M(a: Double): String; overload; begin M := 'double'; end;
function M(a: Extended): String; overload; begin M := 'extended'; end;
function K(a: Int64): String; overload; begin K := 'int64'; end;
function K(a: Longint): String; overload; begin K := 'longint'; end;
function K(a: Byte): String; overload; begin K := 'byte'; end;
function K(a: Word): String; overload; begin K := 'word'; end;
function Q(a: Int64): String; overload; begin Q := 'int64'; end;
function Q(a: Double): String; overload; begin Q := 'double'; end;
var l: Longint; w: Word; sm: Smallint; sg: Single; db: Double; by: Byte;
begin
  l := 1; w := 2; sm := 3; sg := 1; db := 2; by := 4;
  writeln(N(2.5), ' ', N(0.1), ' ', M(2.5), ' ', M(0.1), ' ', N(sg), ' ', N(db), ' ', M(sg));
  writeln(K(5), ' ', K(300), ' ', K(100000), ' ', K(l), ' ', K(w), ' ', K(sm), ' ', K(by), ' ', K(by + 1), ' ', K(l + 1), ' ', K(w + 1));
  writeln(Q(5), ' ', Q(l), ' ', Q(2.5), ' ', Q(by));
end.
PAS
cat > "$T/ovexpr.pas" <<'PAS'
{$mode objfpc}
program ovexpr;
function N(a: Extended): String; overload; begin N := 'extended'; end;
function N(a: Double): String; overload; begin N := 'double'; end;
function N(a: Single): String; overload; begin N := 'single'; end;
function N(a: Int64): String; overload; begin N := 'int64'; end;
function N(a: Longint): String; overload; begin N := 'longint'; end;
function N(a: Boolean): String; overload; begin N := 'boolean'; end;
function N(a: Char): String; overload; begin N := 'char'; end;
function N(a: String): String; overload; begin N := 'string'; end;
var l: Longint; db: Double; sg: Single; ex: Extended; i64: Int64; bo: Boolean; ch: Char;
begin
  l := 4; db := 2; sg := 1; ex := 3; i64 := 5; bo := true; ch := 'q';
  writeln(N(l / 2), ' ', N(db / 2), ' ', N(sg * 2), ' ', N(sg + db), ' ', N(sg * 2.5), ' ', N(-sg), ' ', N(l * l), ' ', N(i64 + l), ' ', N(true), ' ', N(not bo), ' ', N(bo and bo));
  writeln(N(ch), ' ', N('ab'), ' ', N('a'), ' ', N(l > 2), ' ', N(abs(l)), ' ', N(sqr(sg)), ' ', N(chr(65)), ' ', N(ex), ' ', N(l mod 3), ' ', N(l div 3));
end.
PAS
cat > "$T/ovmeth.pas" <<'PAS'
{$mode objfpc}
program ovmeth;
type
  TFoo = class
    procedure Say(a: Integer); overload;
    procedure Say(s: String); overload;
    function Twice(a: Integer): Integer;
  end;
procedure TFoo.Say(a: Integer); begin writeln('int ', a); end;
procedure TFoo.Say(s: String); begin writeln('str ', s); end;
function TFoo.Twice(a: Integer): Integer; begin Result := a * 2; end;
var f: TFoo;
begin
  f := TFoo.Create;
  f.Say(3);
  f.Say('x');
  writeln(f.Twice(4));
end.
PAS
cp "$WIT" "$T/tb0675.pas"
arm() { local p="$1" frc
  frc=$(fpcrun "$p") || exit 2
  if [ -n "${FAIL_ONCE:-}" ] && [ "$p" = ovbasic ]; then echo "corrupted by FAIL_ONCE" >> "$T/$p.want"; fi
  for m in m3 m4; do run $m "$p"; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc -Mobjfpc ($(head -c 70 "$T/o" | tr '\n' '|'))"
    else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done; }
for p in ovbasic ovtypes ovfloat ovexpr ovmeth tb0675; do arm "$p"; done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: overloaded routines and methods are chosen as fpc chooses them, $N of $N arms"
else echo "GATE FAIL(1) [$G]: examined six programs over $N arms"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
