#!/usr/bin/env bash
# test_gate_pas_a_for_statement_evaluates_its_initial_and_final_values_once_before_the_loop.sh -- the initial value and the final value of a for-statement are evaluated ONCE, in that order, before the control variable is first assigned (ISO 7185 6.8.3.9).
#
# MEASURED 2026-10-09 by hq_pascal against fpc -Miso: `lim := 4; n := 0; for i := 1 to lim do begin n := n + 1; lim := 1 end` ran the body once where fpc runs it four times, in both modes: the lowerer placed the final-value expression in the loop test and so
# evaluated it again on every iteration (`for i := 1 to f do` with a function f called f five times, `for c := 'a' to chr(ord('a') + lim)` and `for i := 5 downto lim + 1` stopped as soon as the body changed lim). Found running Pascal-P5's compiler under scrip: pcom
# writes a string constant with `for k := 1 to lenpv(p) do ... p := p^.next`, lenpv shrank as p advanced, and `lca 12 'Hello, world'` came out as `lca 12 'Hello, wor'`, so P5's interpreter printed `Hello, wor` and two blanks for P5's own hello sample.
# CURE (pascal.y only; no new global): the two for rules build, for a final value that is not a literal, a hidden per-routine local __pas_flN (pas_local_add: a frame slot, so a recursive routine's activations do not share it), assign the final value to it before
# the loop and give the for-statement that local as its limit; when the initial value is not a literal either, it is captured into its own local first so the order stays initial value, then final value, as fpc does. A literal limit is left as it was.
#
# ARMS, both modes: two controls cut LIVE from fpc -Miso that must be byte-identical: the limit read, a function called as the limit (the number of calls is printed), a limit that is an expression, a char loop, a downto loop with a variable limit, a body that changes the
# limit, an initial value and a final value that are both function calls (the order is printed), and a recursive routine whose for-loop calls itself. FAIL_ONCE=1 corrupts the first control's ref.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- every arm's expectation is CUT FROM THE ORACLE"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
run() { local m="$1" p="$2"
  if [ "$m" = m3 ]; then ( cd "$T" && timeout -k 5 20s "$SCRIP" --run "$p.pas" </dev/null >"$T/o" 2>"$T/e" ); return $?; fi
  ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile -o "$T/$p.s" "$p.pas" </dev/null >/dev/null 2>&1 && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4: did not compile or link"; return 99; }
  ( cd "$T" && timeout -k 5 20s "./$p.m4" </dev/null >"$T/o" 2>"$T/e" ); return $?; }
fpcrun() { ( cd "$T" && "$FPC" -Miso -v0 -o"$1.fpc" $1.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 20s ./$1.fpc </dev/null >"$T/$1.want" 2>/dev/null ); echo $?; }
cat > "$T/tctl1.pas" <<'PAS'
program tctl1(output);
var i, n, calls, lim: integer;
function f: integer; begin calls := calls + 1; f := lim end;
function g(x: integer): integer; begin calls := calls + 1; g := x end;
begin
  calls := 0; lim := 5; n := 0;
  for i := 1 to f do begin n := n + 1; lim := 2 end;
  writeln(n, ' ', calls);
  calls := 0; lim := 5; n := 0;
  for i := 1 to g(lim) do begin n := n + 1; lim := 2 end;
  writeln(n, ' ', calls);
  lim := 4; n := 0;
  for i := 1 to lim do begin n := n + 1; lim := 1 end;
  writeln(n);
  lim := 4; n := 0;
  for i := lim downto 1 do begin n := n + 1; lim := 9 end;
  writeln(n);
  lim := 3; n := 0;
  for i := 1 to lim * 2 do begin n := n + 1; lim := 1 end;
  writeln(n)
end.
PAS
cat > "$T/tctl2.pas" <<'PAS'
program tctl2(output);
var i, n, lim, depth: integer; c: char; seq: integer;
function a: integer; begin seq := seq * 10 + 1; a := 1 end;
function b: integer; begin seq := seq * 10 + 2; b := 3 end;
procedure rec(d: integer);
var k, m: integer;
begin
  m := 0;
  for k := 1 to d do begin m := m + 1; if d > 1 then rec(d - 1) end;
  write(m:2)
end;
begin
  seq := 0; for i := a to b do n := i; writeln(seq);
  lim := 3; for c := 'a' to chr(ord('a') + lim) do begin write(c); lim := 0 end; writeln;
  lim := 2; for i := 5 downto lim + 1 do begin write(i:2); lim := 9 end; writeln;
  rec(3); writeln;
  for i := 1 to 0 do writeln('never'); n := 0; lim := 2; for i := 3 to lim + 2 do n := n + i; writeln(n)
end.
PAS
RC=0; N=0
for c in tctl1 tctl2; do
  frc=$(fpcrun $c)
  if [ -n "${FAIL_ONCE:-}" ] && [ "$c" = tctl1 ]; then echo "corrupted by FAIL_ONCE" >> "$T/$c.want"; fi
  for m in m3 m4; do run $m $c; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$c.want" "$T/o"; then echo "  $c $m: rc=$rc, stdout byte-identical to fpc ($(wc -l < "$T/o") lines)"
    else echo "  ⛔ $c $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$c.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi
  done
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a for-statement evaluates its initial and final values once, in order, before the loop as fpc does, $N of $N arms"
else echo "GATE FAIL(1) [$G]: examined 2 programs in 2 modes"; fi
exit $RC
