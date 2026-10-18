#!/usr/bin/env bash
# test_gate_pas_a_pointer_target_is_a_variable_parameter_and_is_not_disposed_during_the_call.sh -- (1) a bare pointer dereference p^ or a file buffer f^ passed to a var formal is a VARIABLE the routine may assign; (2) ISO 7185 6.5.4: it is an
# error to remove from its pointer-type the identifying-value of an identified-variable when a reference to the identified-variable exists (PAT iso7185prt1705).
#
# MEASURED 2026-10-09 by hq_pascal: (1) `procedure b(var c: integer); begin c := c + 1 end; ... new(a); a^ := 4; b(a^)` died with `[IDX] BOMB rt_assign_var: lvalue is not a variable` in both modes, because the call passed a^ as a value and the formal assigned it; a
# field through a pointer (r^.n) and an array element worked. fpc prints 5. The same for a file buffer f^ (found while curing 1706a). PAT 1705 (`b(a^)` whose routine does c := 1; dispose(a)) therefore CRASHED rc 134 instead of being refused, which the board counts FAIL.
# CURE (lower_pascal.c only): lower_call's copy-in/copy-out path, which already served array elements and the standard files, now also takes an actual that is a bare __pas_deref of a pointer variable (copy out with the existing __pas_deref_set store) and a file
# buffer (copy out with __pas_fbuf_set / __pas_tbuf_set). A new stop beside the 1706a one: when the actual is p^ and the callee's body disposes that same pointer (pas_tree_disposes), the call lowers to __pas_rterr 6.5.4.
# NOT COVERED, written down: a pointer removed through a second routine or by assignment, and a with-statement reference.
#
# ARMS, both modes: three fault programs (dispose of the pointer in a procedure, in a function called in an expression, with the assignment before it) must stop with rc != 0, the pre-stop stdout intact and the 6.5.4 diagnostic; a control cut LIVE from fpc -Miso (a var actual p^ assigned
# twice, read only, a file buffer assigned, a record field, dispose of ANOTHER pointer in the callee, a value formal whose routine disposes the pointer, dispose after the call) must run byte-identical. FAIL_ONCE=1 corrupts the control's ref.
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
  ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile -o "$T/$p.s" "$p.pas" </dev/null >/dev/null 2>&1 && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4: did not compile or link"; return 99; }
  ( cd "$T" && timeout -k 5 20s "./$p.m4" </dev/null >"$T/o" 2>"$T/e" ); return $?; }
fpcrun() { ( cd "$T" && "$FPC" -Miso -v0 -o"$1.fpc" $1.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 20s ./$1.fpc </dev/null >"$T/$1.want" 2>/dev/null ); echo $?; }
cat > "$T/tctl.pas" <<'PAS'
program tctl(output);
type rec = record n: integer; nxt: ^rec end;
var a, other: ^integer; r: ^rec; x: integer; f: file of integer;
procedure inc1(var c: integer); begin c := c + 1 end;
procedure show(var c: integer); begin writeln(c) end;
procedure setn(var n: integer); begin n := 7 end;
procedure killother(var c: integer); begin c := c + 10; dispose(other) end;
procedure byval(c: integer); begin dispose(a); writeln(c) end;
function fn(var c: integer): integer; begin c := c * 2; fn := c end;
begin
  new(a); a^ := 4; inc1(a^); inc1(a^); writeln(a^);
  show(a^);
  new(r); r^.n := 1; setn(r^.n); writeln(r^.n);
  rewrite(f); f^ := 3; put(f); reset(f); inc1(f^); writeln(f^);
  new(other); other^ := 1; killother(a^); writeln(a^);
  x := 5; inc1(x); writeln(x);
  writeln(fn(a^), a^);
  byval(a^);
  new(a); a^ := 2; inc1(a^); dispose(a); writeln('done')
end.
PAS
cat > "$T/fproc.pas" <<'PAS'
program fproc(output);
var a: ^integer;
procedure b(var c: integer); begin c := 1; dispose(a) end;
begin new(a); writeln('before'); b(a^) end.
PAS
cat > "$T/ffunc.pas" <<'PAS'
program ffunc(output);
var a: ^integer; x: integer;
function fb(var c: integer): integer; begin dispose(a); fb := 1 end;
begin new(a); a^ := 2; writeln('before'); x := fb(a^) end.
PAS
cat > "$T/fassign.pas" <<'PAS'
program fassign(output);
var a: ^integer;
procedure b(var c: integer); begin c := c + 5; dispose(a) end;
begin new(a); a^ := 1; writeln('before'); b(a^); writeln('after') end.
PAS
RC=0; N=0
frc=$(fpcrun tctl)
if [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/tctl.want"; fi
for m in m3 m4; do run $m tctl; rc=$?; N=$((N + 1))
  if [ "$rc" = "$frc" ] && cmp -s "$T/tctl.want" "$T/o"; then echo "  tctl $m: rc=$rc, stdout byte-identical to fpc ($(wc -l < "$T/o") lines)"
  else echo "  ⛔ tctl $m FAILED: rc=$rc (fpc $frc)"; diff "$T/tctl.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi
done
for p in fproc ffunc fassign; do
  for m in m3 m4; do run $m $p; rc=$?; N=$((N + 1))
    if [ "$rc" != 0 ] && grep -q "ISO 7185 6.5.4: the identifying-value of the pointer '[a-z]*' is removed by '[a-z]*' while a reference to its identified-variable exists" "$T/e"; then echo "  $p $m: stopped naming 6.5.4 (rc=$rc, stdout [$(head -c 30 "$T/o" | tr '\n' '|')])"
    else echo "  ⛔ $p $m FAILED: rc=$rc stdout=[$(head -c 60 "$T/o" | tr '\n' '|')] err=[$(head -c 120 "$T/e")]"; RC=1; fi
  done
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a pointer target passed as a variable parameter is assignable and is not disposed during the call, and the legal forms run as fpc does, $N of $N arms"
else echo "GATE FAIL(1) [$G]: examined 4 programs in 2 modes"; fi
exit $RC
