#!/usr/bin/env bash
# test_gate_pas_a_for_statement_stays_inside_its_control_variables_type.sh -- ISO 7185 6.8.3.9, refused at compile time
#
# MEASURED 2026-09-23 by hq_pascal on SCRIP a1108b4b9, both modes, row pascal-all-test-suites-of-the-language-read-100-percent-on-the-
# suite-table-the-home-stretch (class row pascal-pat-for-loop-control-variable-protection). If the statement of a for-statement is
# executed, its initial-value and final-value shall be assignment-compatible with the control-variable's type. PAT iso7185prt1852
# runs 'for i := 0 to 10' over 'i: 1..9' and SCRIP ran it. pas_for_const_bounds checks the case decidable at compile time: both bounds
# are integer literals, the loop executes (from <= to, or from >= to for downto), and a bound falls outside the variable's subrange.
# ⛔ IT FIRES ONLY WHEN EVERY DECLARATION OF THE NAME AGREES: the parser's registries are flat, so a procedure's 'i: 1..9' outlives the
# procedure; a name that is also declared with a non-subrange type anywhere is left alone (the control's global 'i: integer' looping
# 0..20 in main after p's local 'i: 1..9' is exactly that case). Bounds that are not literals are a run-time check, not graded here.
# ⭐ WHERE THE ORACLE IS STRICTER THAN THE STANDARD: fpc -Miso refuses out-of-range literal bounds even on a loop that never executes
# ('for j := 10 to 0' over 1..9: "range check error while evaluating constants"); ISO constrains only an executed loop, and SCRIP
# follows ISO there. The oracle cannot cut a ref for that shape, so it is named here and not graded.
# Before landing, every acceptance program in the corpus was compiled with the check (PasRungs, the FPC suite, P4, P5, benchmarks): zero
# tripped; the only trip was the P5 copy of this same test.
#
# ARMS: the vendored witness, REFUSED with a non-empty diagnostic in BOTH modes (m4 compiles, and if the compile is accepted, links
# and runs). A second arm proves the check DISCRIMINATES: in-range to/downto loops over a subrange, a named subrange type, and the
# flat-registry case above run byte-identical to fpc -Miso in both modes. FAIL_ONCE=1 flips the witness to prove the arm can fail.
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
for b in iso7185prt1852; do
  f="$SRC/$b.pas"; [ -f "$f" ] || { echo "⛔ GATE REFUSE(2) [$G]: missing vendored witness $f"; exit 2; }
  N=$((N+1)); bad=""
  o3=$( cd "$T" && timeout -k 5 10s "$SCRIP" "$f" </dev/null 2>&1 ); rc3=$?
  if [ -n "${FAIL_ONCE:-}" ] && [ "$b" = iso7185prt1852 ]; then rc3=0; o3=""; fi
  { [ "$rc3" -ne 0 ] && [ "$rc3" -lt 124 ] && [ -n "$o3" ]; } || bad="m3 (rc=$rc3, ${#o3} bytes of diagnostic)"
  m4_run "$f"; o4="$M4O"; rc4=$M4RC
  { [ "$rc4" -ne 0 ] && [ "$rc4" -lt 124 ] && [ -n "$o4" ]; } || bad="$bad m4 (rc=$rc4, ${#o4} bytes of diagnostic)"
  if [ -n "$bad" ]; then echo "  $b ACCEPTED where ISO 7185 6.8.3.9 requires the bounds inside the type: $bad"; RC=1; else echo "  $b refused with a diagnostic in both modes"; fi
done
cat > "$T/ok.pas" <<'PAS'
program forctl(output);
type digit = 0..9;
var i, s: integer; d: digit;
procedure p;
var i: 1..9; t: integer;
begin t := 0; for i := 1 to 9 do t := t + i; for i := 9 downto 1 do t := t + i; writeln('p ', t) end;
begin
  p; s := 0;
  for i := 0 to 20 do s := s + i;
  for d := 0 to 9 do s := s + d;
  writeln('main ', s)
end.
PAS
( cd "$T" && "$FPC" -Miso -v0 ok.pas >/dev/null 2>&1 && ./ok ) > "$T/ok.ref" 2>&1
[ -s "$T/ok.ref" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle produced no control-arm output"; exit 2; }
ok3=$( cd "$T" && timeout -k 5 20s "$SCRIP" --run ok.pas </dev/null 2>&1 ); m4_run "$T/ok.pas"; ok4="$M4O"
if [ "$ok3" = "$(cat "$T/ok.ref")" ] && [ "$ok4" = "$(cat "$T/ok.ref")" ]; then echo "  control arm: in-range subrange loops and the flat-registry case run byte-identical to fpc -Miso in both modes"
else echo "  ⛔ control arm FAILED -- the check refuses or miscompiles LEGAL for-statements"; echo "      want: $(tr '\n' '|' < "$T/ok.ref")"; echo "      m3  : $(printf '%s' "$ok3" | tr '\n' '|')"; echo "      m4  : $(printf '%s' "$ok4" | tr '\n' '|')"; RC=1; fi
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: $N for-statements leaving the control variable type refused with a NAMED diagnostic in both modes, and legal ones are untouched"
else echo "GATE FAIL(1) [$G]: examined $N vendored PAT witnesses plus one legal control"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
