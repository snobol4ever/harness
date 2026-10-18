#!/usr/bin/env bash
# test_gate_pas_a_for_control_variable_is_undefined_after_the_for_statement.sh -- ISO 7185 6.8.3.9: after a for-statement that is not left by a goto the control-variable is undefined, and a use of it then is an error (PAT iso7185prt1811).
#
# MEASURED 2026-10-08 by hq_pascal: PAT 1811 (write(i) after `for i := 1 to 10 do`) printed 11 where fpc -Miso prints 10 and ISO calls the use an error; fpc accepts it, so the expectation is the ISO text, graded as PAT grades a rejection test (non-zero exit and a diagnostic).
# CURE, three parts: (1) pascal.y marks every TT_FOR it builds in a program with no {$mode} directive with bit 2 of the node's ival (bit 1 stays downto); (2) lower_for assigns the never-assigned
# global __pas_undefined_value to the control variable on the loop's NORMAL exit edge only (the compare failing, or the traced exit), so a goto out of the loop leaves the value and the legal
# `goto found; ... writeln(i)` reads it; (3) lower_pascal_proc collects the marked control-variable names of the routine, lower_for keeps a chain of the loops it is inside on the C stack,
# and lower_var_r wraps a read of a collected name outside every loop over it in a __pas_resundef test that stops with __pas_rterr 6.8.3.9. Assignment, read(i) and a var actual are not rvalue reads.
#
# ARMS, both modes: tctl (a control cut LIVE from fpc -Miso: goto out of a loop then a read, nested loops, downto, an empty loop followed by an assignment, read(i) and a var actual after a loop,
# a reassignment then a read, a local control variable in a routine, a function with a loop) must run byte-identical; five fault programs must stop with rc != 0, the pre-stop stdout intact and
# the 6.8.3.9 diagnostic naming the control-variable; a program with a {$mode objfpc} directive reading the variable after the loop must not be stopped. FAIL_ONCE=1 corrupts the control's ref.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- every arm's expectation is CUT FROM THE ORACLE"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
run() { local m="$1" p="$2"
  if [ "$m" = m3 ]; then ( cd "$T" && timeout -k 5 20s "$SCRIP" --run "$p.pas" <"$T/in" >"$T/o" 2>"$T/e" ); return $?; fi
  ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile -o "$T/$p.s" "$p.pas" </dev/null >/dev/null 2>&1 && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4: did not compile or link"; return 99; }
  ( cd "$T" && timeout -k 5 20s "./$p.m4" <"$T/in" >"$T/o" 2>"$T/e" ); return $?; }
fpcrun() { ( cd "$T" && "$FPC" -Miso -v0 -o"$1.fpc" $1.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 20s ./$1.fpc <"$T/in" >"$T/$1.want" 2>/dev/null ); echo $?; }
echo 55 > "$T/in"
cat > "$T/tctl.pas" <<'PAS'
program tctl(output);
label 20;
var i, j, k, n: integer; a: array[1..5] of integer; s: integer;
procedure setit(var x: integer); begin x := 42 end;
function find(v: integer): integer;
label 10;
var q: integer;
begin
  find := 0;
  for q := 1 to 5 do if a[q] = v then begin find := q; goto 10 end;
  10: ;
end;
function sumto(m: integer): integer;
var t, r: integer;
begin r := 0; for t := 1 to m do r := r + t; sumto := r end;
procedure p2;
var i: integer;
begin for i := 1 to 3 do write(i:2); i := 9; writeln(i:2) end;
begin
  for i := 1 to 5 do a[i] := i * i;
  writeln(find(9), find(7));
  for i := 1 to 5 do if a[i] = 16 then goto 20;
  20: writeln('i after goto=', i:1);
  for i := 1 to 3 do for j := 1 to i do begin write(i * 10 + j:3); if j = i then writeln end;
  for i := 5 downto 1 do s := s + i; i := 0; writeln(s:1, i:2);
  for k := 3 to 1 do writeln('never'); k := 7; writeln(k:1);
  for i := 1 to 2 do writeln(i:1); setit(i); writeln(i:1);
  for i := 1 to 2 do n := i; read(i); writeln(i:1);
  for i := 1 to 3 do ; i := 100; writeln(i + 1:1);
  writeln(sumto(4):1); p2;
  for i := 1 to 3 do begin for j := i to 3 do s := s + j + i; end; writeln(s:1)
end.
PAS
cat > "$T/fmain.pas" <<'PAS'
program fmain(output);
var i: integer;
begin for i := 1 to 3 do write(i:1, ' '); write(i:1) end.
PAS
cat > "$T/fproc.pas" <<'PAS'
program fproc(output);
procedure p;
var i, x: integer;
begin for i := 1 to 3 do write(i:1, ' '); x := i + 1; writeln(x:1) end;
begin p end.
PAS
cat > "$T/ffunc.pas" <<'PAS'
program ffunc(output);
function f: integer;
var q: integer;
begin for q := 1 to 3 do write(q:1, ' '); f := q end;
begin writeln(f:1) end.
PAS
cat > "$T/fdown.pas" <<'PAS'
program fdown(output);
var i: integer; a: array[1..5] of integer;
begin for i := 1 to 5 do a[i] := i; for i := 5 downto 1 do write(a[i]:1, ' '); write(a[i]:1) end.
PAS
cat > "$T/fempty.pas" <<'PAS'
program fempty(output);
var k: integer;
begin write('x '); for k := 3 to 1 do write('never'); write(k:1) end.
PAS
cat > "$T/tmode.pas" <<'PAS'
{$mode objfpc}
program tmode;
var i: integer;
begin for i := 1 to 3 do write(i, ' '); writeln('done') end.
PAS
RC=0; N=0
frc=$(fpcrun tctl)
if [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/tctl.want"; fi
for m in m3 m4; do run $m tctl; rc=$?; N=$((N + 1))
  if [ "$rc" = "$frc" ] && cmp -s "$T/tctl.want" "$T/o"; then echo "  tctl $m: rc=$rc, stdout byte-identical to fpc ($(wc -l < "$T/o") lines)"
  else echo "  ⛔ tctl $m FAILED: rc=$rc (fpc $frc)"; diff "$T/tctl.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi
done
for p in fmain fproc ffunc fdown fempty; do
  for m in m3 m4; do run $m $p; rc=$?; N=$((N + 1))
    if [ "$rc" != 0 ] && grep -q "ISO 7185 6.8.3.9: the control-variable '[a-z]*' of a for-statement is undefined after the for-statement is left" "$T/e"; then echo "  $p $m: stopped naming 6.8.3.9 (rc=$rc, stdout [$(head -c 30 "$T/o" | tr '\n' '|')])"
    else echo "  ⛔ $p $m FAILED: rc=$rc stdout=[$(head -c 60 "$T/o" | tr '\n' '|')] err=[$(head -c 120 "$T/e")]"; RC=1; fi
  done
done
for m in m3 m4; do run $m tmode; rc=$?; N=$((N + 1))
  if [ "$rc" = 0 ] && ! grep -q "6.8.3.9" "$T/e"; then echo "  tmode $m: a {\$mode} program is not held to 6.8.3.9 (rc=0)"
  else echo "  ⛔ tmode $m FAILED: rc=$rc err=[$(head -c 120 "$T/e")]"; RC=1; fi
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: the control-variable of a for-statement is undefined after the statement is left, and the legal forms run as fpc does, $N of $N arms"
else echo "GATE FAIL(1) [$G]: examined 7 programs in 2 modes"; fi
exit $RC
