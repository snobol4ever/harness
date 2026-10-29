#!/usr/bin/env bash
# test_gate_pas_a_currency_prints_as_its_exact_four_decimal_value_in_e_format.sh -- write/writeln of a Currency variable or a
# Currency expression prints the exact four-decimal value as fpc does: a sign or space, one digit, a point, EIGHTEEN decimals and
# E+NN / E-NN (two exponent digits) -- not the 17-significant-digit double with a three-digit lowercase exponent.
#
# MEASURED 2026-10-03 by hq_pascal, row pascal-every-suite-to-100-under-nonet-ceo-1266. FPC webtbs_tw38717 prints C := 1234.56 * 4 / 2
# as ` 2.469120000000000000E+03`; SCRIP printed ` 2.4691199999999999e+003`, the double 2469.12 in the real format.
#
# CURE: pascal.y asks the declaration VISIBLE at the use (the uid-scoped scalar-var-type table, which value/var formals now join when
# they are currency) and write/writeln gives a currency variable, or an arithmetic expression with one in it, the format code -6; the runtime rounds the value to four decimals and prints the digits exactly (pas_currency_str). The
# arithmetic itself stays double (the assignment does not yet round), so a value that drifts past the fourth decimal prints rounded.
# An explicit :w:d keeps the ordinary fixed format.
#
# ARMS, both modes, expectations cut LIVE from fpc: (cur) the tw38717 shape plus zero, a negative, 0.5, a large value, a sum and
# a product expression; (fixed) :w:d widths of a currency; (shadow) a currency parameter followed by a longint variable of the same
# name. FAIL_ONCE=1 corrupts the cur arm's ref.
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

cat > "$T/cur.pas" <<'PAS'
{$mode objfpc}{$H+}
program cur(output);
var C, R, D, Z, N, H, B: Currency;
begin
  C := 1234.56; R := 4; D := 2;
  C := C * R / D;
  writeln(C);
  Z := 0; N := -17.25; H := 0.5; B := 123456789.1234;
  writeln(Z); writeln(N); writeln(H); writeln(B);
  writeln(R + D); writeln(C * 2);
  writeln(R, ' ', D)
end.
PAS
cat > "$T/fixed.pas" <<'PAS'
{$mode objfpc}{$H+}
program fixed(output);
var C: Currency;
begin
  C := 1234.5678;
  writeln(C:12:2);
  writeln(C:0:4);
  writeln(C:8:1)
end.
PAS
cat > "$T/shadow.pas" <<'PAS'
{$mode objfpc}{$H+}
program shadow(output);
var x: longint;
procedure P(x: Currency);
begin writeln(x) end;
begin
  P(2.5);
  x := 42;
  writeln(x)
end.
PAS
for p in cur fixed shadow; do
  frc=$(fpcrun $p)
  if [ "$p" = cur ] && [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/$p.want"; fi
  for m in m3 m4; do run $m $p; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc -Miso ($(wc -l < "$T/o") lines)"
    else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a currency prints as fpc does, $N of $N program x mode arms"
else echo "GATE FAIL(1) [$G]: examined 3 programs in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
