#!/usr/bin/env bash
# test_gate_pas_maxint_is_the_required_constant.sh -- ISO 7185 6.4.2.2, maxint is a required constant-identifier
#
# MEASURED 2026-09-23 by hq_pascal on SCRIP 4755ec672, both modes, row pascal-all-test-suites-of-the-language-read-100-percent-on-the-
# suite-table-the-home-stretch. "The required constant-identifier maxint" (6.4.2.2) was never defined: mk_ident fell through to an
# undeclared variable, so writeln(maxint) printed NOTHING at rc=0, -maxint printed 0, i := maxint stored nothing, and a subrange
# 0..maxint collapsed to 0..0 (scalar_constant's const lookup failed and left 0). No Pascal source in SCRIP's history ever named it.
# Six PAT rejection witnesses use it (1732 1735 1736 1738 1739 1882), which is why their runtime checks cannot land before it.
# The value is fpc -Miso's, 2147483647, so every FPC-suite ref stays comparable. A program that DEFINES maxint keeps its own value:
# the fallback sits after the constant table in both mk_ident and scalar_constant, and Pascal-P4 (const maxint = 32767) relies on it.
# ⛔ NAMED, NOT CURED HERE: the constant table is flat and first-match, so a PROCEDURE-LOCAL const maxint = 100 leaks into the
# program block (measured: the main body then reads 100) -- the same scoping class as every other local constant, its own landing.
# Before landing, every acceptance program in the corpus (PasRungs, the FPC suite, P4, P5, the benchmarks, 456 programs) was compiled
# with the change: the refused set was identical to the tree before.
#
# ARMS: two legal programs, each cut LIVE from fpc -Miso and required byte-identical in BOTH modes (m4 compiles, links and runs):
# maxint and -maxint in expressions, in constant-definitions, as a subrange bound, in div/mod and assigned to integer, subrange and
# real variables; and a program that redefines maxint at program level, which must use its own value. FAIL_ONCE=1 corrupts the
# first arm's ref to prove the arm can fail.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- every arm's ref is CUT FROM THE ORACLE"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0; N=0
m4_run() { M4O=$( cd "$T" && timeout -k 5 20s "$SCRIP" --compile --out="$T/w.s" "$1" </dev/null 2>&1 ); M4RC=$?
  if [ "$M4RC" = 0 ]; then
    ( cd "$T" && cc -m64 -no-pie w.s -o w -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: $1 compiled but would not link -- cannot grade the m4 arm"; exit 2; }
    M4O=$( cd "$T" && timeout -k 5 20s ./w </dev/null 2>&1 ); M4RC=$?
  fi; }
cat > "$T/ok.pas" <<'PAS'
program maxctl(output);
const m = maxint; n = -maxint; half = 1073741823;
type big = 0..maxint; sym = n..m;
var i: integer; b: big; s: sym; r: real;
begin
  i := maxint; b := maxint div 2; s := -maxint; r := maxint;
  writeln(i:1, ' ', m:1, ' ', n:1, ' ', b = half, ' ', s:1, ' ', r:12:1);
  writeln(maxint - 1:1, ' ', maxint div 10:1, ' ', maxint mod 1000:1, ' ', -maxint + 1:1)
end.
PAS
cat > "$T/redef.pas" <<'PAS'
program maxredef(output);
const maxint = 100;
type small = 0..maxint;
var s: small;
begin s := maxint; writeln(s:1, ' ', maxint div 3:1) end.
PAS
for p in ok redef; do
  N=$((N+1))
  ( cd "$T" && "$FPC" -Miso -v0 $p.pas >/dev/null 2>&1 && ./$p ) > "$T/$p.ref" 2>&1
  [ -s "$T/$p.ref" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle produced no output for arm $p"; exit 2; }
  if [ -n "${FAIL_ONCE:-}" ] && [ "$p" = ok ]; then echo "corrupted by FAIL_ONCE" >> "$T/$p.ref"; fi
  o3=$( cd "$T" && timeout -k 5 20s "$SCRIP" --run $p.pas </dev/null 2>&1 ); m4_run "$T/$p.pas"; o4="$M4O"
  if [ "$o3" = "$(cat "$T/$p.ref")" ] && [ "$o4" = "$(cat "$T/$p.ref")" ]; then echo "  arm $p: byte-identical to fpc -Miso in both modes"
  else echo "  ⛔ arm $p FAILED"; echo "      want: $(tr '\n' '|' < "$T/$p.ref")"; echo "      m3  : $(printf '%s' "$o3" | tr '\n' '|')"; echo "      m4  : $(printf '%s' "$o4" | tr '\n' '|')"; RC=1; fi
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: maxint is the required constant 2147483647 in $N oracle-cut arms in both modes, and a program's own maxint wins"
else echo "GATE FAIL(1) [$G]: examined $N oracle-cut arms"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
