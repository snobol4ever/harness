#!/usr/bin/env bash
# test_gate_pas_xor_keeps_the_iso_dialect.sh -- an infix xor does not flip a program out of the ISO dialect: fpc -Miso accepts xor
# (and integer and / or) and writes every integer at its ISO default width, so SCRIP must too; shl and shr, which fpc -Miso refuses,
# still flip the program to the FPC dialect and its natural widths.
#
# MEASURED 2026-10-14 by hq_pascal for PasRosetta (CEO-1562, row pascal-every-suite-to-100-under-nonet-ceo-1266): bitwise-operations
# (ALL.dialect iso: fpc -Miso cut its ref) printed "a and b = 8" where the ref reads "a and b =           8". pascal.y's lexer wrapper
# called pascal_flip_dialect(PAS_DIALECT_FPC) on an infix xor exactly as on shl / shr; the flip raises the seen_mode event and every
# writeln of the program then passes width -4 (natural). A census by fpc -Miso: xor ACCEPTED ("          6"), shl, shr and otherwise
# REFUSED. THE CURE: xor is still lexed as XOROP after an operand and no longer flips the dialect; pascal.tab.c regenerated with the
# pinned bison 3.8.2 (a one-line diff).
#
# ARMS: isoxor -- ISO widths around an xor, and integer and / or, against fpc -Miso; fpcshl -- a program whose shl flips it, against
# fpc in its default mode (natural widths): the flip the cure keeps. Both modes, stdout and exit code cut LIVE. OPEN, NOT GRADED HERE:
# not on an integer reads as a Boolean (not 10 prints false; fpc -11), a row of its own.
# MEASURED on the parent cdd742fd5 (this session, before the edit): isoxor printed x22 / x8 / x1410 / 106, red; fpcshl green.
# FAIL_ONCE=1 corrupts isoxor's expectation.
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
cat > "$T/isoxor.pas" <<'PAS'
program isoxor(output);
var a, b: integer;
begin
  a := 10; b := 12;
  writeln('x', a + b);
  writeln('x', a and b);
  writeln('x', a or b, a);
  writeln(a, a xor b)
end.
PAS
cat > "$T/fpcshl.pas" <<'PAS'
program fpcshl(output);
var a, b: integer;
begin
  a := 10; b := 12;
  writeln('x', a shl 2, a xor b);
  writeln(a, b shr 1)
end.
PAS
for pm in "isoxor -Miso" "fpcshl -Mfpc"; do p=${pm% *}; om=${pm#* }
  frc=$(fpcrun $p $om) || exit 2
  if [ -n "${FAIL_ONCE:-}" ] && [ "$p" = isoxor ]; then echo "corrupted by FAIL_ONCE" >> "$T/$p.want"; fi
  for m in m3 m4; do run $m $p; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc $om ($(wc -l < "$T/o") lines)"
    else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done; done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: xor keeps the ISO dialect and shl still flips it, as fpc reads them, $N of $N arms"
else echo "GATE FAIL(1) [$G]: examined two programs in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
