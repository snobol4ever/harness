#!/usr/bin/env bash
# test_gate_pas_division_by_zero_is_the_iso_6_7_2_2_error_and_in_the_fpc_dialects_fpcs_runtime_error_code.sh -- a Pascal division whose divisor is zero is an
# error. In the ISO dialect (no {$mode} directive) the refusal names the clause, ISO 7185 6.7.2.2 (PAT iso7185prt1744 x/y, prt1745 i div j); in a source that
# names a {$mode} it ends the way fpc ends: stderr "Runtime error N at $...", exit N, N = 200 for an integer div or mod, 208 for a real x/0.0 over a nonzero x,
# 207 for 0.0/0.0.
#
# MEASURED 2026-10-22 by hq_pascal on the parent (SCRIP fb35bf3d1): PAT prt1744 read "scrip: error 262: division caused real overflow", prt1745 "scrip: error 2:
# division caused integer overflow" -- the SNOBOL4 words, no clause; an objfpc source ended rc 1 with the same words. fpc 3.2.2 under -Miso and -Mobjfpc alike:
# idiv 200, imod 200, x/0.0 208, 0.0/0.0 207, integer a/b with b zero 208.
# THE CURE (ruled by the cfo, route (a), a Pascal twin of the arithmetic entries): lower_binop sets IR_STRICT_DIVERR_ISO7185 or IR_STRICT_DIVERR_RTERR on a
# TT_DIV and TT_MOD node from pas_dialect_fpc; the template picks column 3 or 4 of rtop_tab, rt_div_diviso / rt_div_divrc / rt_mod_diviso / rt_mod_divrc, asm
# aliases of the existing fast path (rtx_arith.s), whose zero divisor already declines to the C twin; c_rt_{div,mod}_{diviso,divrc} in arithmetic.c raise the
# error. No guard sits on the hot path: the emitted code differs from the parent's only in the callee's name.
#
# ARMS (both modes, the fpc expectation CUT LIVE from fpc under the matching -M): fi/fm/fr/fz/fn ({$mode objfpc}: integer div, integer mod, real x/0.0, real
# 0.0/0.0, integer a/b) -- exit code and the "Runtime error N" words equal fpc's; ii/im/ir (no directive): fpc -Miso ends non-zero, scrip ends non-zero and names
# ISO 7185 6.7.2.2; ok (objfpc) and okiso (no directive): nonzero divisors answer byte-identical to fpc. FAIL_ONCE=1 corrupts fi's expectation.
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
  ( cd "$T" && LD_LIBRARY_PATH="$RT_DIR" timeout -k 5 20s "$SCRIP" --compile -o "$T/$p.s" "$p.pas" </dev/null >/dev/null 2>"$T/e" && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4: did not compile and link ($(head -1 "$T/e" | cut -c1-120))"; return 125; }
  ( cd "$T" && LD_LIBRARY_PATH="$RT_DIR" timeout -k 5 20s "./$p.m4" </dev/null >"$T/o" 2>"$T/e" ); return $?; }
fpcrun() { local mode="$2"; mkdir -p "$T/fpc"; ( cd "$T" && "$FPC" $mode -v0 -FE"$T/fpc" -o"$T/$1.fpc" "$T/$1.pas" >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc $mode would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 20s "./$1.fpc" </dev/null >"$T/$1.want" 2>"$T/$1.werr" ); echo $?; }
body() { local p="$1" md="$2" stmt="$3"
  { [ -n "$md" ] && echo "{\$mode $md}"; echo "program $p;"; echo "var a, b: integer; x, y: real;"; echo "begin"; echo "  a := 7; b := 2; x := 7.5; y := 2.5;"; echo "  writeln('before');"; echo "  $stmt"; echo "  writeln('after ', a, ' ', x:0:2)"; echo "end."; } > "$T/$p.pas"; }
body fi objfpc "b := 0; a := a div b;"
body fm objfpc "b := 0; a := a mod b;"
body fr objfpc "y := 0.0; x := x / y;"
body fz objfpc "x := 0.0; y := 0.0; x := x / y;"
body fn objfpc "b := 0; x := a / b;"
body ii "" "b := 0; a := a div b;"
body im "" "b := 0; a := a mod b;"
body ir "" "y := 0.0; x := x / y;"
body ok objfpc "a := a div b + a mod b; x := x / y; b := 0;"
body okiso "" "a := a div b + a mod b; x := x / y; b := 0;"
armrt() { local p="$1" frc want got
  frc=$(fpcrun "$p" -Mobjfpc) || exit 2
  want=$(sed -n '1s/ at .*//p' "$T/$p.werr"); [ -n "${FAIL_ONCE:-}" ] && [ "$p" = fi ] && frc=$((frc + 1))
  for m in m3 m4; do run $m "$p"; rc=$?; N=$((N + 1)); got=$(sed -n '1s/ at .*//p' "$T/e")
    if [ "$rc" = "$frc" ] && [ "$got" = "$want" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, \"$got\" and stdout equal to fpc -Mobjfpc"
    else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc), stderr \"$got\" (fpc \"$want\")"; diff "$T/$p.want" "$T/o" | head -4 | sed 's/^/      /'; RC=1; fi; done; }
armiso() { local p="$1" frc
  frc=$(fpcrun "$p" -Miso) || exit 2
  [ "$frc" != 0 ] || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso ran $p to the end -- the oracle gives no refusal to name"; exit 2; }
  for m in m3 m4; do run $m "$p"; rc=$?; N=$((N + 1))
    if [ "$rc" != 0 ] && grep -q 'ISO 7185 6\.7\.2\.2' "$T/e"; then echo "  $p $m: rc=$rc, names ISO 7185 6.7.2.2 (fpc -Miso ends $frc)"
    else echo "  ⛔ $p $m FAILED: rc=$rc, stderr \"$(head -1 "$T/e" | cut -c1-100)\" names no 6.7.2.2 (fpc -Miso ends $frc)"; RC=1; fi; done; }
armok() { local p="$1" om="$2" frc
  frc=$(fpcrun "$p" "$om") || exit 2
  for m in m3 m4; do run $m "$p"; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc $om ($(tr '\n' '|' < "$T/o" | cut -c1-40))"
    else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -4 | sed 's/^/      /'; RC=1; fi; done; }
for p in fi fm fr fz fn; do armrt $p; done
for p in ii im ir; do armiso $p; done
armok ok -Mobjfpc
armok okiso -Miso
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a zero divisor ends as ISO 7185 6.7.2.2 in the ISO dialect and as fpc's Runtime error 200/207/208 in the FPC dialects, $N of $N arms"
else echo "GATE FAIL(1) [$G]: examined ten programs over $N arms"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
