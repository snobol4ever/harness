#!/usr/bin/env bash
# test_gate_pas_an_arithmetic_or_transfer_function_has_a_value.sh -- ISO 7185 6.6.6.2 / 6.6.6.3, refused at RUN time, out loud
#
# MEASURED 2026-09-23 by hq_pascal on SCRIP f6776d8c1, both modes, row pascal-all-test-suites-of-the-language-read-100-percent-on-the-
# suite-table-the-home-stretch (class row pascal-pat-ordinal-arithmetic-domain-and-range). 6.6.6.2: sqr(x) "shall be an error if such
# a value does not exist", ln(x) "if x is not greater than zero", sqrt(x) "if x is negative"; 6.6.6.3: trunc(x) and round(x) "shall be
# an error if such a value does not exist" in integer-type. Their Pascal arms in by_name_dispatch.c computed v * v, log(d), sqrt(d) and
# a C cast without asking, so PAT iso7185prt1732 (sqr(maxint)), 1733 (ln(0)), 1734 (sqrt(-1)), 1735 (trunc of maxint squared) and 1736
# (round(maxint + 10.0)) ran to rc=0. Each arm now stops through pas_file_err ("scrip: pascal runtime error: ISO 7185 <clause>: ...").
#
# ⭐ WHAT IS CHECKED, AND AGAINST WHAT. An integer sqr is refused beyond |x| = 46340, whose square is the last one <= maxint; a real
# sqr is not checked. trunc and round are checked against -maxint..maxint, the letter of 6.6.6.3 now that maxint is defined
# (04f8b19af). ⛔ FPC's int(x) lowered to the same __pas_trunc arm, and int has no integer range (fpc prints int(1e10) as 1e10):
# ISO trunc now passes a second argument and ONLY the two-argument call is checked, so int(1e10) still prints 10000000000.
# Measured before landing, every graded Pascal program RUN in both modes (the rungs 246, the FPC suite 181, the eleven benchmarks,
# PAT's acceptance programs): no cell moved except the five witnesses' ten.
#
# ARMS: five vendored PAT witnesses, each required to be REFUSED at run time with a non-empty diagnostic in BOTH modes (m4 compiles,
# links and RUNS). A sixth arm proves the check DISCRIMINATES: sqr(+-46340), a real sqr, sqrt(0), sqrt(2), ln(1), ln(0.5),
# trunc(-2147483647.9), round(2147483647.4) and the halves run byte-identical to fpc -Miso in both modes. FAIL_ONCE=1 flips the first
# witness to prove the arm can fail.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- the control arm's ref is CUT FROM THE ORACLE"; exit 2; }
SRC="$S4E/corpus/packages/pascal/pat"
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0; N=0
m4_run() { M4O=$( cd "$T" && timeout -k 5 20s "$SCRIP" --compile --out="$T/w.s" "$1" </dev/null 2>&1 ); M4RC=$?
  if [ "$M4RC" = 0 ]; then
    ( cd "$T" && cc -m64 -no-pie w.s -o w -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: $1 compiled but would not link -- cannot grade the m4 arm"; exit 2; }
    M4O=$( cd "$T" && timeout -k 5 20s ./w </dev/null 2>&1 ); M4RC=$?
  fi; }
for b in iso7185prt1732 iso7185prt1733 iso7185prt1734 iso7185prt1735 iso7185prt1736; do
  f="$SRC/$b.pas"; [ -f "$f" ] || { echo "⛔ GATE REFUSE(2) [$G]: missing vendored witness $f"; exit 2; }
  N=$((N+1)); bad=""
  o3=$( cd "$T" && timeout -k 5 10s "$SCRIP" "$f" </dev/null 2>&1 ); rc3=$?
  if [ -n "${FAIL_ONCE:-}" ] && [ "$b" = iso7185prt1732 ]; then rc3=0; o3=""; fi
  { [ "$rc3" -ne 0 ] && [ "$rc3" -lt 124 ] && [ -n "$o3" ]; } || bad="m3 (rc=$rc3, ${#o3} bytes of diagnostic)"
  m4_run "$f"; o4="$M4O"; rc4=$M4RC
  { [ "$rc4" -ne 0 ] && [ "$rc4" -lt 124 ] && [ -n "$o4" ]; } || bad="$bad m4 (rc=$rc4, ${#o4} bytes of diagnostic)"
  if [ -n "$bad" ]; then echo "  $b RAN TO COMPLETION where ISO 7185 requires an error: $bad"; RC=1; else echo "  $b stopped with a runtime diagnostic in both modes"; fi
done
cat > "$T/ok.pas" <<'PAS'
program numctl(output);
var i: integer; r, z: real;
begin
  i := 46340; writeln(sqr(i):1, ' ', sqr(-i):1, ' ', sqr(2.5):4:2);
  z := 0.0; r := 2.0; writeln(sqrt(z):4:2, ' ', sqrt(r):8:5, ' ', ln(1.0):4:2, ' ', ln(0.5):8:5);
  r := -2147483647.9; writeln(trunc(r):1); r := 2147483647.4; writeln(round(r):1);
  r := -2.5; writeln(trunc(r):1, ' ', round(r):1); r := 2.5; writeln(trunc(r):1, ' ', round(r):1)
end.
PAS
( cd "$T" && "$FPC" -Miso -v0 ok.pas >/dev/null 2>&1 && ./ok ) > "$T/ok.ref" 2>&1
[ -s "$T/ok.ref" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle produced no control-arm output"; exit 2; }
ok3=$( cd "$T" && timeout -k 5 20s "$SCRIP" --run ok.pas </dev/null 2>&1 ); m4_run "$T/ok.pas"; ok4="$M4O"
if [ "$ok3" = "$(cat "$T/ok.ref")" ] && [ "$ok4" = "$(cat "$T/ok.ref")" ]; then echo "  control arm: sqr, sqrt, ln, trunc and round at their legal edges run byte-identical to fpc -Miso in both modes"
else echo "  ⛔ control arm FAILED -- the check refuses or miscompiles a LEGAL program"; echo "      want: $(tr '\n' '|' < "$T/ok.ref")"; echo "      m3  : $(printf '%s' "$ok3" | tr '\n' '|')"; echo "      m4  : $(printf '%s' "$ok4" | tr '\n' '|')"; RC=1; fi
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: $N arithmetic or transfer functions with no value stopped with a NAMED runtime diagnostic in both modes, and legal ones are untouched"
else echo "GATE FAIL(1) [$G]: examined $N vendored PAT witnesses plus one legal control"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
