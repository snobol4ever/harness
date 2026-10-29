#!/usr/bin/env bash
# test_gate_pas_a_qword_divides_unsigned_and_a_wide_integer_prints_as_fpc_miso_does.sh -- QWord (unsigned 64-bit) values above 2^63 divide and mod as
# unsigned and print as unsigned decimals, and an integer written with no width in default (ISO) mode is right-justified to 11 characters and cut to its
# first 11 when longer, exactly as `fpc -Miso` writes int64 and qword values.
#
# MEASURED 2026-10-04 by hq_pascal on FPC tbs_tb0598 (10000000000000000000 div 1000000 read negative; the ref shows 10000000000, the first 11 characters
# of 10000000000000). CURE: pascal.y lowers div/mod of a qword/uint64 variable or a literal past int64 to __pas_udiv/__pas_umod and writes a qword variable
# with format code -7 (unsigned); the runtime's default-width integer print pads to 11 and cuts at 11 characters (explicit widths and objfpc/delphi mode,
# whose width is -4, print in full). Not claimed: qword arithmetic other than div/mod and comparison of values past 2^63.
#
# ARMS, both modes, expectations cut LIVE from fpc -Miso: (big) the tb0598 shape; (wide) int64/qword/longint/negative widths; (mix) qword mod and div by a
# literal (fpc's own qword div/mod by a LONGINT variable is signed, and is not matched). FAIL_ONCE=1 corrupts the big arm's ref.
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

cat > "$T/big.pas" <<'PAS'
{$R-}
program big;
var a: Cardinal; b: QWord; c1, c2: QWord;
begin
  a := 1000000; b := 10000000000000000000;
  c1 := b div a; c2 := 10000000000000000000 div a;
  Write(c1, ' = ', c2, ': ');
  if (c1 <> c2) or (c2 <> 10000000000000) then Writeln('FAIL') else Writeln('OK')
end.
PAS
cat > "$T/wide.pas" <<'PAS'
{$R-}
program wide;
var a: int64; b: qword; c: longint;
begin
  a := 10000000000000; b := 10000000000000; c := 2147483647;
  writeln(a, '|', b, '|', c, '|', -a, '|');
  a := 9223372036854775807; writeln(a, '|', high(int64), '|');
  b := 18446744073709551615; writeln(b, '|', b = 18446744073709551615, '|')
end.
PAS
cat > "$T/mix.pas" <<'PAS'
{$R-}
program mix;
var b: qword; k: longint;
begin
  b := 10000000000000000000; k := 7;
  writeln(b mod 7, '|', b div 1000000, '|')
end.
PAS
for p in big wide mix; do
  frc=$(fpcrun $p)
  if [ "$p" = big ] && [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/$p.want"; fi
  for m in m3 m4; do run $m $p; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc -Miso ($(wc -l < "$T/o") lines)"
    else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a qword and a wide integer print and divide as fpc -Miso does, $N of $N program x mode arms"
else echo "GATE FAIL(1) [$G]: examined 3 programs in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
