#!/usr/bin/env bash
# test_gate_pas_a_mod_divisor_is_positive.sh -- ISO 7185 6.7.2.2, refused at RUN time, out loud
#
# MEASURED 2026-09-23 by hq_pascal on SCRIP 42308cfae, both modes, row pascal-all-test-suites-of-the-language-read-100-percent-on-the-
# suite-table-the-home-stretch (class row pascal-pat-runtime-value-guards-div-mod-case). "A term of the form i mod j shall be an error
# if j is zero or negative" (6.7.2.2). pas_mod lowered i mod j to ((i mod j) + j) mod j, which answers a negative j without
# complaint, so PAT iso7185prt1746b (1 mod -1) ran to rc=0. A divisor that is not a positive integer literal now passes, on the FIRST of
# pas_mod's three uses of it, through __pas_ord_check(j, 1, max, what, "6.7.2.2") -- the ordinal-range arm of by_name_dispatch.c,
# which takes an optional clause -- and stops through pas_file_err. A positive literal divisor, the common case, is never checked.
# j = 0 now stops with this same 6.7.2.2 message instead of the shared runtime's "error 2", so 1746A (the zero half) is an arm too.
# Measured before landing, every graded Pascal program RUN in both modes (the rungs 246, the FPC suite 181, the eleven benchmarks,
# PAT's acceptance programs): no cell moved except 1746b's two. No benchmark uses a variable divisor.
#
# ARMS: two vendored PAT witnesses (the negative and the zero divisor), each required to be REFUSED at run time with a non-empty
# diagnostic in BOTH modes (m4 compiles, links and RUNS). A third arm proves the check DISCRIMINATES: mod over negative and positive
# dividends by variable, literal and expression divisors runs byte-identical to fpc -Miso in both modes. FAIL_ONCE=1 flips the first
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
m4_run() { M4O=$( cd "$T" && timeout -k 5 20s "$SCRIP" --compile -o "$T/w.s" "$1" </dev/null 2>&1 ); M4RC=$?
  if [ "$M4RC" = 0 ]; then
    ( cd "$T" && cc -m64 -no-pie w.s -o w -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: $1 compiled but would not link -- cannot grade the m4 arm"; exit 2; }
    M4O=$( cd "$T" && timeout -k 5 20s ./w </dev/null 2>&1 ); M4RC=$?
  fi; }
for b in iso7185prt1746b iso7185prt1746A; do
  f="$SRC/$b.pas"; [ -f "$f" ] || { echo "⛔ GATE REFUSE(2) [$G]: missing vendored witness $f"; exit 2; }
  N=$((N+1)); bad=""
  o3=$( cd "$T" && timeout -k 5 10s "$SCRIP" "$f" </dev/null 2>&1 ); rc3=$?
  if [ -n "${FAIL_ONCE:-}" ] && [ "$b" = iso7185prt1746b ]; then rc3=0; o3=""; fi
  { [ "$rc3" -ne 0 ] && [ "$rc3" -lt 124 ] && [ -n "$o3" ]; } || bad="m3 (rc=$rc3, ${#o3} bytes of diagnostic)"
  m4_run "$f"; o4="$M4O"; rc4=$M4RC
  { [ "$rc4" -ne 0 ] && [ "$rc4" -lt 124 ] && [ -n "$o4" ]; } || bad="$bad m4 (rc=$rc4, ${#o4} bytes of diagnostic)"
  if [ -n "$bad" ]; then echo "  $b RAN TO COMPLETION where ISO 7185 requires an error: $bad"; RC=1; else echo "  $b stopped with a runtime diagnostic in both modes"; fi
done
cat > "$T/ok.pas" <<'PAS'
program modctl(output);
var a, b, n: integer;
begin
  n := 0;
  for a := -7 to 7 do for b := 1 to 4 do n := (n * 3 + a mod b) mod 1000003;
  writeln(n:1);
  a := -7; b := 3; writeln(a mod b:1, ' ', 7 mod 3:1, ' ', (a * 2) mod (b + 1):1, ' ', maxint mod b:1)
end.
PAS
( cd "$T" && "$FPC" -Miso -v0 ok.pas >/dev/null 2>&1 && ./ok ) > "$T/ok.ref" 2>&1
[ -s "$T/ok.ref" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle produced no control-arm output"; exit 2; }
ok3=$( cd "$T" && timeout -k 5 20s "$SCRIP" --run ok.pas </dev/null 2>&1 ); m4_run "$T/ok.pas"; ok4="$M4O"
if [ "$ok3" = "$(cat "$T/ok.ref")" ] && [ "$ok4" = "$(cat "$T/ok.ref")" ]; then echo "  control arm: mod by variable, literal and expression divisors over signed dividends runs byte-identical to fpc -Miso in both modes"
else echo "  ⛔ control arm FAILED -- the check refuses or miscompiles a LEGAL program"; echo "      want: $(tr '\n' '|' < "$T/ok.ref")"; echo "      m3  : $(printf '%s' "$ok3" | tr '\n' '|')"; echo "      m4  : $(printf '%s' "$ok4" | tr '\n' '|')"; RC=1; fi
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: $N mod terms with a zero or negative divisor stopped with a NAMED runtime diagnostic in both modes, and legal ones are untouched"
else echo "GATE FAIL(1) [$G]: examined $N vendored PAT witnesses plus one legal control"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
