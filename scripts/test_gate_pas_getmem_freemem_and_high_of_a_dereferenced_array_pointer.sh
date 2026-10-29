#!/usr/bin/env bash
# test_gate_pas_getmem_freemem_and_high_of_a_dereferenced_array_pointer.sh -- getmem / freemem and low / high of a dereferenced pointer to a static array answer as fpc -Mobjfpc does.
#
# MEASURED 2026-10-14 by hq_pascal for PasRosetta (CEO-1562, CEO-1612 piece 4; row pascal-every-suite-to-100-under-nonet-ceo-1266):
# hofstadter-conway-_10-000-sequence died "error 22: undefined function called" twice over -- getmem / freemem were no routines, and
# high(a^) (a is a pointer to a static array type) passed through to a function named high. THE CURE: getmem(p, n) lowers as p :=
# __pas_alloc_rec(init) -- the pointee's own initial block for a typed pointer, an arr_make(lo, lo + n - 1) of n slots for an untyped Pointer or
# for a pointer to the open-array idiom array[0..0] (one slot per byte covers any element size) -- freemem(p[, n]) as dispose; low / high of
# a^ fold to the pointee array's bounds.
#
# ARMS: gmall -- getmem of a record pointer, of an array[0..0] pointer indexed to 9, of an untyped Pointer retyped to a pointer to array[1..50];
# derefhigh -- new(a) of a pointer to array[0..9] with high(a^). Both modes, stdout and exit code cut LIVE from fpc -Mobjfpc.
# MEASURED on the parent (before the edit): derefhigh died error 22; gmall died error 22. FAIL_ONCE=1 corrupts gmall's expectation.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- every expectation is CUT FROM THE ORACLE"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0; N=0
run() { local m="$1" p="$2"
  if [ "$m" = m3 ]; then ( cd "$T" && LD_LIBRARY_PATH="$RT_DIR" timeout -k 5 20s "$SCRIP" --run "$p.pas" </dev/null >"$T/o" 2>"$T/e" ); return $?; fi
  ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile --out="$T/$p.s" "$p.pas" </dev/null >/dev/null 2>&1 && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4: did not compile and link"; return 125; }
  ( cd "$T" && timeout -k 5 20s "./$p.m4" </dev/null >"$T/o" 2>"$T/e" ); return $?; }
fpcrun() { local mode="$2"; mkdir -p "$T/fpc"; ( cd "$T" && "$FPC" $mode -v0 -FE"$T/fpc" -o"$T/$1.fpc" "$T/$1.pas" >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc $mode would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 20s "./$1.fpc" </dev/null >"$T/$1.want" 2>/dev/null ); echo $?; }
cat > "$T/gmall.pas" <<'PAS'
program g1;
{$mode objfpc}
type
  TRec = record n: integer; s: integer end;
  PRec = ^TRec;
  TInts = array[0..0] of integer;
  PInts = ^TInts;
  TBig = array[1..50] of longword;
  PBig = ^TBig;
var
  r: PRec; q: PInts; p: pointer; b: PBig; i: integer;
begin
  getmem(r, sizeof(TRec)); r^.n := 4; r^.s := 9; writeln(r^.n + r^.s); freemem(r, sizeof(TRec));
  getmem(q, 10 * sizeof(integer)); for i := 0 to 9 do q^[i] := i * 3; writeln(q^[9], ' ', q^[4]); freemem(q);
  getmem(p, sizeof(TBig)); b := p; for i := low(b^) to high(b^) do b^[i] := i; writeln(low(b^), ' ', high(b^), ' ', b^[50]); freemem(p)
end.
PAS
cat > "$T/derefhigh.pas" <<'PAS'
program n;
{$mode objfpc}
type tf = array[0..9] of longword; pf = ^tf;
var a: pf; i: integer;
begin
  new(a);
  for i := 0 to 9 do a^[i] := i * i;
  writeln(a^[3], ' ', high(a^));
  dispose(a)
end.
PAS
for pm in "gmall -Mobjfpc" "derefhigh -Mobjfpc"; do p=${pm% *}; om=${pm#* }
  frc=$(fpcrun $p $om) || exit 2
  if [ -n "${FAIL_ONCE:-}" ] && [ "$p" = gmall ]; then echo "corrupted by FAIL_ONCE" >> "$T/$p.want"; fi
  for m in m3 m4; do run $m $p; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc $om ($(wc -l < "$T/o") lines)"
    else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done; done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: getmem / freemem and high of a dereferenced array pointer, as fpc reads them, $N of $N arms"
else echo "GATE FAIL(1) [$G]: examined two programs in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
