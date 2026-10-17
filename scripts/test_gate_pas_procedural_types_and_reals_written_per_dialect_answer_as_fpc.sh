#!/usr/bin/env bash
# test_gate_pas_procedural_types_and_reals_written_per_dialect_answer_as_fpc.sh -- procedural types as parameter types, @routine as a
# procedural actual, and reals written as each fpc mode writes them (the dialects row pascal-dialects-...-ceo-1614, chunk 7).
#
# MEASURED 2026-10-11 by hq_pascal on SCRIP a3e771ee1: 13 PasRosetta programs stopped at a parse error on a procedural type
# (TNewtonCooling = FUNCTION (t: REAL): REAL), whose usual use is as a parameter type (procedure Euler(F: TNewtonCooling; ...)).
# THE DIALECT, measured:
#   - fpc -Miso accepts the procedural type as a parameter type with a routine name as the actual (euler-method's dialect is iso).
#   - fpc -Miso REFUSES @routine as that actual ("got Pointer"), so @ on a declared routine flips the program to fpc. A pre-pass over
#     the tree finds it before anything is elaborated.
#   - Under fpc's own modes a real writes with an uppercase E (1.5000000000000000E+000); fpc -Miso writes e. The runtime takes width
#     code -4 (fpc's unpadded default) and -10 (an explicit width under fpc) as E. Booleans and integers already followed the dialect.
# THE LOWERING:
#   - A procedural type registers its signature (pas_pf_sig).
#   - A value parameter of that type is the procedural formal it abbreviates (pas_pf_formal, one per name).
#   - @routine reaches the closure as its stable hash, mapped back to the routine.
#
# ARMS, both modes, every expectation cut LIVE from fpc in the arm's own mode:
#   - ptypes under -Miso: function and procedure types, a parameterless one, nested application;
#   - atroutine and reals_fpc under -Mfpc; reals_objfpc under -Mobjfpc; reals_iso under -Miso (the lowercase-e control);
#   - atflip: @routine with no directive, graded against fpc -Mfpc.
# FAIL_ONCE=1 corrupts arm ptypes.
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
want() { ( cd "$T" && "$FPC" -M$3 -v0 -o"$1.fpc" $2.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -M$3 would not compile $2"; exit 2; }; ( cd "$T" && timeout -k 5 60s ./$1.fpc </dev/null >"$T/$1.want" 2>/dev/null ); echo $? > "$T/$1.wrc"; }
cat > "$T/ptypes.pas" <<'PAS'
program pt1(output);
type TFun = function(t: real): real; TProc = procedure(n: integer); TNullary = function: integer;
function cooling(t: real): real; begin cooling := -0.07 * (t - 20) end;
function sq(t: real): real; begin sq := t * t end;
procedure show(n: integer); begin write('<', n, '>') end;
function seven: integer; begin seven := 7 end;
function apply(f: TFun; x: real): real; begin apply := f(x) end;
procedure euler(f: TFun; y, h: real; n: integer); var i: integer; begin for i := 1 to n do y := y + h * f(y); writeln(y:0:4) end;
procedure each(p: TProc; a, b: integer); var i: integer; begin for i := a to b do p(i); writeln end;
function twice(g: TNullary): integer; begin twice := 2 * g end;
begin writeln(apply(sq, 3.0):0:2, ' ', apply(cooling, 100.0):0:2); euler(cooling, 100.0, 2.0, 5); each(show, 1, 3); writeln(twice(seven)) end.
PAS
cat > "$T/atroutine.pas" <<'PAS'
{$mode fpc}
program pt2;
type TFun = function(t: real): real;
function sq(t: real): real; begin sq := t * t end;
function apply(f: TFun; x: real): real; begin apply := f(x) end;
begin writeln(apply(@sq, 3.0):0:2) end.
PAS
cat > "$T/atflip.pas" <<'PAS'
program pt2b;
type TFun = function(t: real): real;
function sq(t: real): real; begin sq := t * t end;
function apply(f: TFun; x: real): real; begin apply := f(x) end;
begin writeln(apply(@sq, 3.0):0:2) end.
PAS
cat > "$T/reals_fpc.pas" <<'PAS'
{$mode fpc}
program rf3;
var r: real; i: integer; b: boolean; c: char;
begin r := -1.5; i := 42; b := true; c := 'z'; writeln(r); writeln(r:12); writeln(r:12:3); writeln(i:6, b:7, c:3, 'ab':4) end.
PAS
cat > "$T/reals_objfpc.pas" <<'PAS'
{$mode objfpc}
program rf3;
var r: real; i: integer; b: boolean; c: char;
begin r := -1.5; i := 42; b := true; c := 'z'; writeln(r); writeln(r:12); writeln(r:12:3); writeln(i:6, b:7, c:3, 'ab':4) end.
PAS
cat > "$T/reals_iso.pas" <<'PAS'
program rf5(output);
var r: real; i: integer; b: boolean; c: char;
begin r := -1.5; i := 42; b := true; c := 'z'; writeln(r); writeln(r:12); writeln(r:12:3); writeln(i:6, b:7, c:3, 'ab':4) end.
PAS
sed -e '1i {$mode fpc}' "$T/atflip.pas" > "$T/atflip_oracle.pas"
RC=0; N=0
chk() { local m="$1" p="$2" frc; frc=$(cat "$T/$p.wrc"); run $m $p; local rc=$?; N=$((N + 1))
  if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc ($(wc -l < "$T/o") lines)"
  else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; }
want ptypes ptypes iso; want atroutine atroutine fpc; want atflip atflip_oracle fpc; want reals_fpc reals_fpc fpc; want reals_objfpc reals_objfpc objfpc; want reals_iso reals_iso iso
if [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/ptypes.want"; fi
for m in m3 m4; do for p in ptypes atroutine atflip reals_fpc reals_objfpc reals_iso; do chk $m $p; done; done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: procedural types and reals per dialect answer as fpc, both modes, $N of $N arms"
else echo "GATE FAIL(1) [$G]: see the arms above"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
