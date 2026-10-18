#!/usr/bin/env bash
# test_gate_pas_a_typed_file_var_formal_is_the_callers_file.sh -- ISO 7185 6.6.3.3: a variable formal-parameter denotes its actual-parameter, so a
# typed file passed as `var x: ft` IS the caller's file inside the routine: rewrite(x), write(x, v), reset(x), read(x, v), get(x), put(x), eof(x),
# x^ and x^ := v all act on the caller's file.
#
# MEASURED 2026-10-07 by hq_pascal: the formal x of a named typed-file type was never registered as a file variable (only `text` was), so the
# callee lowered rewrite(x)/write(x, v)/x^ as text-file and pointer operations: the caller's reset(f) then read nothing (fpc: the values written), and
# x^ := n raised 6.5.4 "pointer-variable undefined in deref_set". CURE: pas_formal_tfiles (pascal.y) registers each var formal whose signature type is a
# typed-file type name as a typed-file variable at routine entry, and the table is released with the routine's other marks, so a later routine's
# plain `x: integer` is not read as a file.
#
# ARMS, both modes: wr (write through a var formal, forwarded through a second routine), rd (reset/eof/x^/get through a var formal), buf (x^ := v then
# put(x)), scope (a formal x: ft in one routine, a local integer x in the next). Each run byte-identical to fpc -Miso. FAIL_ONCE=1 corrupts wr's ref.
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


cat > "$T/wr.pas" <<'PAS'
program wr(output);
type ft = file of integer;
var f: ft; v: integer;
procedure emit(var y: ft; n: integer);
begin write(y, n); write(y, n + 1) end;
procedure fill(var x: ft; n: integer);
begin rewrite(x); emit(x, n); emit(x, n + 10) end;
begin
  fill(f, 7);
  reset(f);
  while not eof(f) do begin read(f, v); writeln(v) end
end.
PAS
cat > "$T/rd.pas" <<'PAS'
program rd(output);
type ft = file of integer;
var f: ft; i: integer;
procedure dump(var x: ft);
begin
  reset(x);
  while not eof(x) do begin writeln(x^); get(x) end
end;
begin
  rewrite(f);
  for i := 1 to 4 do write(f, i * i);
  dump(f);
  writeln('again');
  dump(f)
end.
PAS
cat > "$T/buf.pas" <<'PAS'
program buf(output);
type ft = file of integer;
var f: ft; v: integer;
procedure stuff(var x: ft; n: integer);
begin x^ := n; put(x); x^ := n * 2; put(x) end;
begin
  rewrite(f);
  stuff(f, 3);
  stuff(f, 5);
  reset(f);
  while not eof(f) do begin read(f, v); writeln(v) end
end.
PAS
cat > "$T/scope.pas" <<'PAS'
program scope(output);
type ft = file of integer;
var f: ft; v: integer;
procedure p(var x: ft);
begin rewrite(x); write(x, 41) end;
procedure q;
var x: integer;
begin x := 5; x := x + 1; writeln(x) end;
function r(x: integer): integer;
begin r := x * 2 end;
begin
  p(f); reset(f); read(f, v); writeln(v);
  q; writeln(r(21))
end.
PAS
RC=0; N=0
for p in wr rd buf scope; do
  frc=$(fpcrun $p)
  if [ -n "${FAIL_ONCE:-}" ] && [ $p = wr ]; then echo "corrupted by FAIL_ONCE" >> "$T/$p.want"; fi
  for m in m3 m4; do run $m $p; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc -Miso ($(wc -l < "$T/o") lines)"
    else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi
  done
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a typed file passed as a var formal is the caller's file, $N of $N arms"
else echo "GATE FAIL(1) [$G]: examined 4 programs in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
