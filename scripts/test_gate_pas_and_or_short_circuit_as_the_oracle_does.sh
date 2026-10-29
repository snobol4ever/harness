#!/usr/bin/env bash
# test_gate_pas_and_or_short_circuit_as_the_oracle_does.sh -- ISO 7185 6.7.2.1 leaves the evaluation of the second operand of a
# Boolean and/or implementation-dependent; the one oracle (fpc -Miso) short-circuits, and so does SCRIP (ceo CEO-1274)
#
# MEASURED 2026-09-26 by hq_pascal, both modes, row pascal-every-suite-to-100-under-nonet-ceo-1266. The parser lowered a Boolean and/or
# to TT_MUL/TT_ADD of two 0/1 values, so both operands always ran: FPC webtbs_tw37780 ('(v = 10) or ((v = 5) and (next^.v = 5))' with
# next = nil) stopped with the 6.5.4 nil dereference where fpc prints nothing, and a function operand's side effects ran where fpc skips
# them. NO BRACKET: the divergence is an event fpc never sends. The cure: a Boolean and/or is TT_CONJ/TT_ALT, and the Pascal lowerer's
# pas_cond wires the second operand's test only on the first one's gamma (and) or omega (or). In a value context every exit edge gets
# its own 0/1 leaf and a main-program temporary is a registered program variable -- an rsp-relative temporary shared by exits of two
# tests at different spine depths is stored at the wrong depth (the emitter's defect, not this lane's node; see the landing's commit).
#
# ARMS, both modes, each program's expected stdout and exit code cut LIVE from fpc -Miso: (1) side effects -- function operands that
# print, in if/while/assignment/writeln, at program level, in a procedure and in a recursive function; (2) fifteen and/or/not shapes in
# if, while, repeat, writeln and assignment; (3) the tw37780 nil guard; (4) the PAT 1909 array-index guard. It FAILS on the parent
# (every arm but (2) diverges when both operands run). FAIL_ONCE=1 corrupts arm (2)'s ref.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- every arm's expectation is CUT FROM THE ORACLE"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0; N=0
run() { local m="$1" p="$2"
  if [ "$m" = m3 ]; then ( cd "$T" && timeout -k 5 20s "$SCRIP" --run "$p.pas" </dev/null >"$T/o" 2>"$T/e" ); return $?; fi
  ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile --out="$T/$p.s" "$p.pas" </dev/null >/dev/null 2>&1 && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4: did not compile or link"; return 99; }
  ( cd "$T" && timeout -k 5 20s "./$p.m4" </dev/null >"$T/o" 2>"$T/e" ); return $?; }
fpcrun() { ( cd "$T" && "$FPC" -Miso -v0 -o"$1.fpc" $1.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 20s ./$1.fpc </dev/null >"$T/$1.want" 2>/dev/null ); echo $?; }
cat > "$T/side.pas" <<'PAS'
program side(output);
var i, calls: integer; a: array [1..5] of integer; r: boolean;
function f(x: integer): boolean;
begin calls := calls + 1; writeln('f', x); f := x > 2 end;
function g(n: integer): boolean;
var loc: boolean;
begin
  loc := (n > 0) and g(n - 1) or (n = 0);
  g := loc and ((n < 100) or f(n))
end;
procedure p;
var u: boolean;
begin
  u := f(1) and f(7); writeln(u); u := f(8) or f(9); writeln(u);
  if not (f(0) or f(1)) then writeln('neither') ; writeln((calls > 0) and f(3))
end;
begin
  calls := 0;
  for i := 1 to 5 do a[i] := i * i;
  if f(1) and f(2) then writeln('both') else writeln('not both');
  if f(3) or f(4) then writeln('either') else writeln('neither');
  r := f(5) and f(0); writeln(r);
  r := f(0) or f(6); writeln(r);
  i := 6;
  while (i > 1) and (a[i - 1] > 4) do i := i - 1;
  writeln(i);
  i := 0;
  if (i >= 1) and (a[i] = 1) then writeln('bad') else writeln('guarded');
  writeln(g(4), calls);
  p;
  writeln((calls = 99) and f(9), calls)
end.
PAS
{
  echo 'program shapes(output);'
  echo 'var a, b, n: integer; t: boolean;'
  echo 'begin'
  for c in "(a = 10) or (b = 6)" "(a = 10) and (b = 5)" "(a = 6) and (b = 6)" "(a = 6) and (b = 5)" "((a = 5) and (b = 5)) or (a = 10)" \
           "(a = 10) or ((a = 6) and (b = 5))" "not ((a = 6) and (b = 5))" "not ((a = 7) or (b = 4))" "t or (a = 6)" "(a < b) or t and (b > 0)" \
           "((a = 6) and (b = 5)) = t" "not t and not (a = 6)" "not (not t or (a <> 6)) and ((b = 5) or (a = b))" \
           "(a > b) and ((b > 1) or t) and not ((a = 6) and t)" "(a = 7) or (b = 5)"; do
    echo "  a := 6; b := 5; t := false;"
    echo "  if $c then writeln(1) else writeln(0);"
    echo "  writeln($c); t := $c; writeln(t);"
    echo "  n := 0; while ($c) and (n < 3) do n := n + 1; writeln(n);"
    echo "  n := 0; repeat n := n + 1 until ($c) or (n > 2); writeln(n); t := true; writeln($c);"
  done
  echo '  writeln(0)'
  echo 'end.'
} > "$T/shapes.pas"
cat > "$T/nilg.pas" <<'PAS'
program nilg(output);
type p = ^r; r = record v: integer; next: p end;
var x: r;
begin
  x.v := 6; x.next := nil;
  if (x.v = 10) or ((x.v = 5) and (x.next^.v = 5)) then writeln('OK');
  writeln((x.next <> nil) and (x.next^.v = 1))
end.
PAS
cat > "$T/idxg.pas" <<'PAS'
program idxg(output);
var i: integer; a: array [1..10] of char;
begin
  i := 11;
  writeln('The result is: ', (i = 1) and (a[i] = 'g'));
  writeln('or: ', (i = 11) or (a[i] = 'g'))
end.
PAS
for p in side shapes nilg idxg; do
  frc=$(fpcrun $p)
  if [ "$p" = shapes ] && [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/$p.want"; fi
  for m in m3 m4; do run $m $p; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc -Miso ($(wc -l < "$T/o") lines)"
    else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: and/or short-circuit as fpc -Miso does, $N of $N program x mode arms"
else echo "GATE FAIL(1) [$G]: examined 4 programs in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
