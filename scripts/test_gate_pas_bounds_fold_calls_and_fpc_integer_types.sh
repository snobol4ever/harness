#!/usr/bin/env bash
# test_gate_pas_bounds_fold_calls_and_fpc_integer_types.sh -- a subrange bound may be a call fpc folds at compile time (SizeOf, Ord,
# Succ, Pred, Abs, High and Low of a subrange, an enumeration or a predeclared integer type), the FPC integer type names (uint8..uint64,
# int8..int32, nativeint, nativeuint, sizeint, sizeuint, ptrint, ptruint) are predeclared, and Length of a static array is its element
# count -- each as fpc reads it, -Miso included.
#
# MEASURED 2026-10-14 by hq_pascal for PasRosetta (CEO-1562; hq_snocone's ask on first-perfect-square-in-base-n-with-n-unique-digits-2;
# the ceo's CEO-1709 empty-output class): pascal.y's b_factor and lo_term took only a scalar constant or a parenthesised bound, so
# tRegion1 = 0..63 - 2 * SizeOf(byte) was a syntax error; pas_fold_const folded no call; pas_is_int_typename knew no uint64, so
# High(Uint64) in triangular-numbers stopped at ISO 7185 6.2.2.1 (fpc -Miso itself accepts every name above, measured one by one); and
# Length of array [3..12] read 13. THE CURE: b_factor and lo_term take IDENT ( b_expr ), a TT_FNC as an ordinary call builds it;
# pas_fold_const folds sizeof, ord, chr, succ, pred, abs, high and low (an enum constant argument allowed, an enum result flagged
# through pas_last_const_enum), never over a user routine of that name; the integer names join pas_is_int_typename; length of a
# static array variable lowers to high - low + 1. pascal.tab.c regenerated with the pinned bison 3.8.2 (the one s/r conflict unchanged).
#
# ARMS: isobound and isoints against fpc -Miso, objbound and objlen against fpc -Mobjfpc, both modes, cut LIVE. OPEN, NOT GRADED
# HERE: a subrange of an enumeration whose bound is a call (Low(colour)..Pred(cyan)) writes its values as ordinals, not names.
# MEASURED on the parent (in-tree swap of pascal.y, pascal.tab.c and lower_pascal_tree.c): all four red. FAIL_ONCE=1 corrupts isobound.
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
cat > "$T/isobound.pas" <<'PAS'
program isobound(output);
type
  tRegion1 = 0..63 - 2 * SizeOf(byte);
  tSmall = Ord('a')..Ord('e');
  tWide = 1..SizeOf(longint) * 2;
var r: tRegion1; a: array [tSmall] of integer; i: integer; w: array [tWide] of char;
begin
  r := high(tRegion1); writeln(r, ' ', low(tSmall), ' ', high(tSmall), ' ', high(tWide));
  for i := low(a) to high(a) do a[i] := i; writeln(a[Ord('c')]);
  writeln(sizeof(w))
end.
PAS
cat > "$T/objbound.pas" <<'PAS'
program objbound;
{$mode objfpc}
type
  colour = (red, green, blue, cyan);
  tByteHalf = 0..High(byte) div 2;
  tFromEnum = Ord(green)..Ord(High(colour)) * 3;
  tPairs = Pred(4)..Succ(9) + Abs(-2);
  tC = Low(colour)..Pred(cyan);
var x: tByteHalf; y: tFromEnum; z: tPairs; c: tC; w: array [Low(tPairs)..High(tPairs)] of integer;
begin
  x := High(tByteHalf); y := Low(tFromEnum); z := High(tPairs); c := High(tC);
  writeln(x, ' ', y, ' ', High(tFromEnum), ' ', Low(tPairs), ' ', z, ' ', Ord(c), ' ', Length(w), ' ', SizeOf(w) div SizeOf(integer))
end.
PAS
cat > "$T/isoints.pas" <<'PAS'
program isoints(output);
type tRow = array [5..9] of int64;
var n: uint64; k: nativeint; s: sizeint; p: ptrint; r: tRow; c: array ['a'..'f'] of byte; i: integer;
begin
  n := High(Uint64) div 8; k := High(int32) - 1; s := SizeOf(uint16) + SizeOf(r); p := Low(int8);
  for i := Low(r) to High(r) do r[i] := i * 1000000000;
  writeln(n, ' ', k, ' ', s, ' ', p, ' ', Length(r), ' ', Length(c), ' ', r[9] + r[5], ' ', High(uint8) + High(int16))
end.
PAS
cat > "$T/objlen.pas" <<'PAS'
program objlen;
{$mode objfpc}
var w: array [3..12] of integer;
begin writeln(Length(w), ' ', Low(w), ' ', High(w)) end.
PAS
for pm in "isobound -Miso" "objbound -Mobjfpc" "isoints -Miso" "objlen -Mobjfpc"; do p=${pm% *}; om=${pm#* }
  frc=$(fpcrun $p $om) || exit 2
  if [ -n "${FAIL_ONCE:-}" ] && [ "$p" = isobound ]; then echo "corrupted by FAIL_ONCE" >> "$T/$p.want"; fi
  for m in m3 m4; do run $m $p; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc $om ($(wc -l < "$T/o") lines)"
    else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done; done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: bound calls fold, the FPC integer names are predeclared and Length counts a static array, as fpc reads them, $N of $N arms"
else echo "GATE FAIL(1) [$G]: examined four programs in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
