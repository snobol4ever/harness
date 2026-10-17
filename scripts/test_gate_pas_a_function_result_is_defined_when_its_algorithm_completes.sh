#!/usr/bin/env bash
# test_gate_pas_a_function_result_is_defined_when_its_algorithm_completes.sh -- ISO 7185 6.6.2 with 6.7.3: it is an error if the result of a function is undefined upon completion of its
# algorithm (PAT iso7185prt1918: the assignment to the function identifier is present but not executed).
#
# MEASURED 2026-10-07 by hq_pascal: PAT 1918 compiled and ran to rc 0 in both modes, printing an empty result where fpc -Miso prints a garbage 0; fpc accepts it, so the expectation is the ISO text.
# CURE: when a function body does not assign its result on every path (pas_assigns_result: an assignment, a case-fault call, an if with both branches, a sequence holding one), pascal.y appends
# a test of the result variable after the body -- the new runtime builtin __pas_resundef reads 1 for an unset (DT_SNUL) value and __pas_rterr stops with 6.6.2. A function that provably assigns on
# every path carries no check; a string-typed function (an empty string is a result) and a program that declares a non-ISO dialect are not held to it.
#
# ARMS, both modes: four fault programs (an integer, a real, a boolean and a pointer function whose assignment is not reached) must print what precedes the call, stop non-zero and name 6.6.2;
# three controls cut LIVE from fpc -Miso (integer, real, boolean, char, enumerated, nil and pointer results assigned in branches, loops, a case and by recursion; a case-assigned char; a
# {$mode objfpc} function that leaves its result unset) must run byte-identical. FAIL_ONCE=1 corrupts the first control's ref.
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


cat > "$T/rf1.pas" <<'PAS'
program rf1(output);
function f(n: integer): integer; begin if n > 5 then f := 1 end;
begin writeln('before'); writeln(f(2)) end.
PAS
cat > "$T/rf2.pas" <<'PAS'
program rf2(output);
function f(n: integer): real; begin while n > 5 do begin f := 1.5; n := n - 1 end end;
begin writeln('before'); writeln(f(2):5:1) end.
PAS
cat > "$T/rf3.pas" <<'PAS'
program rf3(output);
function f(n: integer): boolean; begin if n > 5 then f := true else if n > 9 then f := false end;
begin writeln('before'); writeln(f(2)) end.
PAS
cat > "$T/rf4.pas" <<'PAS'
program rf4(output);
type pt = ^integer;
function f(n: integer): pt; var q: pt; begin new(q); if n > 5 then f := q end;
begin writeln('before'); if f(2) = nil then writeln('nil') end.
PAS
cat > "$T/rctl.pas" <<'PAS'
program rctl(output);
type k = (red, green, blue); pt = ^integer;
var p: pt; n: integer;
function fint(n: integer): integer; begin if n > 0 then fint := n * 2 else fint := 0 end;
function fzero(n: integer): integer; begin if n > 100 then fzero := 1; fzero := 0 end;
function freal(n: integer): real; begin if n > 0 then freal := 1.5; if n <= 0 then freal := 0.0 end;
function fbool(n: integer): boolean; begin if n > 0 then fbool := true else if n < 0 then fbool := false else fbool := false end;
function fchar(n: integer): char; begin while n > 0 do begin fchar := 'z'; n := n - 1 end; fchar := 'a' end;
function fenum(n: integer): k; begin if n > 0 then fenum := blue; if n = 0 then fenum := red end;
function fnil(n: integer): pt; begin if n > 0 then fnil := nil; if n <= 0 then fnil := nil end;
function fptr(n: integer): pt; var q: pt; begin new(q); q^ := n; if n > 0 then fptr := q else fptr := nil end;
function fact(n: integer): integer; begin if n <= 1 then fact := 1 else fact := n * fact(n - 1) end;
function fcase(n: integer): integer; begin case n of 1: fcase := 10; 2: fcase := 20; 3: fcase := 30 end end;
function floop(n: integer): integer; var i, s: integer; begin s := 0; for i := 1 to n do begin floop := i; s := s + i end end;
begin
  writeln(fint(4), fzero(1), freal(2):6:2, fbool(3), fchar(2), ord(fenum(1)), fact(5), fcase(2), floop(3));
  p := fnil(1); writeln(p = nil); p := fptr(7); writeln(p^); p := fptr(0); writeln(p = nil)
end.
PAS
cat > "$T/rf5.pas" <<'PAS'
program rf5(output);
function f(n: integer): char; begin case n of 1: f := 'a'; 2: f := 'b' end end;
begin writeln('before'); writeln(f(1)); writeln(f(1)); writeln(f(2)) end.
PAS
cat > "$T/rdialect.pas" <<'PAS'
{$mode objfpc}
program rdialect;
function f(n: integer): integer; begin if n > 5 then f := 1 end;
begin writeln('before'); f(2); writeln('after') end.
PAS
RC=0; N=0
for m in m3 m4; do
  for p in rf1 rf2 rf3 rf4; do
    run $m $p; rc=$?; N=$((N + 1))
    if [ "$rc" != 0 ] && [ "$(cat "$T/o")" = "before" ] && grep -q "ISO 7185 6.6.2" "$T/e"; then echo "  $p $m: stopped naming 6.6.2 after its output (rc=$rc)"
    else echo "  ⛔ $p $m FAILED: rc=$rc stdout=[$(head -c 60 "$T/o" | tr '\n' '|')] err=[$(head -c 100 "$T/e")]"; RC=1; fi
  done
done
first=1
for c in rctl rf5 rdialect; do
  frc=$(fpcrun $c)
  if [ -n "${FAIL_ONCE:-}" ] && [ $first = 1 ]; then echo "corrupted by FAIL_ONCE" >> "$T/$c.want"; fi; first=0
  for m in m3 m4; do run $m $c; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$c.want" "$T/o"; then echo "  $c $m: rc=$rc, stdout byte-identical to fpc ($(wc -l < "$T/o") lines)"
    else echo "  ⛔ $c $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$c.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi
  done
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: an unset function result stops naming 6.6.2 and a legal program runs as fpc, $N of $N arms"
else echo "GATE FAIL(1) [$G]: examined 7 programs in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
