#!/usr/bin/env bash
# test_gate_pas_a_call_carries_as_many_actuals_as_formals.sh -- ISO 7185 6.7.3 / 6.8.2.3, refused at compile time
#
# MEASURED 2026-09-23 by hq_pascal on SCRIP 4229d181b, both modes, row pascal-all-test-suites-of-the-language-read-100-percent-on-the-
# suite-table-the-home-stretch (class row pascal-pat-static-type-and-parameter-checking). "The number of actual-parameters shall be
# equal to the number of formal-parameters" (6.7.3 for a function-designator, 6.8.2.3 for a procedure-statement). Nothing counted
# them: PAT iso7185prt1829 calls a(b: integer; c: char) with one actual and 1830 with three, and both compiled and ran. The check
# sits in call_with_args and reads the formal count the parser already keeps (nvp, one flag per formal, filled by pas_proc_vparams).
#
# ⭐ WHAT THE CHECK DELIBERATELY DOES NOT CLAIM, and why each gap is there. The procedure table is FLAT -- a nested procedure's entry
# outlives its scope, and the body of a forward-declared procedure adds a second entry with no formals -- so a call is refused only
# when EVERY entry of its name disagrees with the actual count. A name that is one of ISO's required procedures or functions is never
# checked, because Pascal-P4's compiler declares local procedures named new, ord, chr and eof and calls the REQUIRED ones outside
# them (measured: without that exemption P4 comp.pas and pcom.pas were refused). An argument list carrying a write-parameter width
# is not counted. A formal count of 16 or more is not counted (the table caps at 16).
# Before landing, every acceptance program in the corpus (PasRungs, the FPC suite, P4, P5, the benchmarks, 456 programs) was compiled
# with the check: the refused set was identical to the tree before, so the check cannot move another suite's row.
#
# ARMS: two vendored PAT witnesses, each required to be REFUSED with a non-empty diagnostic in BOTH modes (m4 compiles, and if the
# compile is accepted, links and runs -- a witness passes that arm if either step refuses). A third arm proves the check
# DISCRIMINATES: a legal program with a forward-declared two-formal procedure called before and after its body, a recursive function,
# a zero-formal function, a nested procedure and six required functions runs byte-identical to fpc -Miso in both modes.
# FAIL_ONCE=1 flips the first witness to prove the arm can fail.
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
for b in iso7185prt1829 iso7185prt1830; do
  f="$SRC/$b.pas"; [ -f "$f" ] || { echo "⛔ GATE REFUSE(2) [$G]: missing vendored witness $f"; exit 2; }
  N=$((N+1)); bad=""
  o3=$( cd "$T" && timeout -k 5 10s "$SCRIP" "$f" </dev/null 2>&1 ); rc3=$?
  if [ -n "${FAIL_ONCE:-}" ] && [ "$b" = iso7185prt1829 ]; then rc3=0; o3=""; fi
  { [ "$rc3" -ne 0 ] && [ "$rc3" -lt 124 ] && [ -n "$o3" ]; } || bad="m3 (rc=$rc3, ${#o3} bytes of diagnostic)"
  m4_run "$f"; o4="$M4O"; rc4=$M4RC
  { [ "$rc4" -ne 0 ] && [ "$rc4" -lt 124 ] && [ -n "$o4" ]; } || bad="$bad m4 (rc=$rc4, ${#o4} bytes of diagnostic)"
  if [ -n "$bad" ]; then echo "  $b ACCEPTED where ISO 7185 requires as many actual-parameters as formal-parameters: $bad"; RC=1; else echo "  $b refused with a diagnostic in both modes"; fi
done
cat > "$T/ok.pas" <<'PAS'
program arity(output);
var t: integer;
procedure helper(a: integer);
begin writeln('helper ', a:1) end;
procedure later(x, y: integer); forward;
function fact(n: integer): integer;
begin if n <= 1 then fact := 1 else fact := n * fact(n - 1) end;
function zero: integer;
begin zero := 0 end;
procedure outer;
  procedure inner(a, b: integer);
  begin writeln('inner ', a + b:1) end;
begin inner(2, 3); later(4, 5) end;
procedure later;
begin writeln('later ', x * y:1) end;
begin
  t := zero;
  helper(1); outer; later(6, 7);
  writeln('fact ', fact(5):1, ' ', ord('A'):1, ' ', chr(66), ' ', t:1, ' ', odd(3), ' ', abs(-4):1, ' ', sqr(3):1)
end.
PAS
( cd "$T" && "$FPC" -Miso -v0 ok.pas >/dev/null 2>&1 && ./ok ) > "$T/ok.ref" 2>&1
[ -s "$T/ok.ref" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle produced no control-arm output"; exit 2; }
ok3=$( cd "$T" && timeout -k 5 20s "$SCRIP" --run ok.pas </dev/null 2>&1 ); m4_run "$T/ok.pas"; ok4="$M4O"
if [ "$ok3" = "$(cat "$T/ok.ref")" ] && [ "$ok4" = "$(cat "$T/ok.ref")" ]; then echo "  control arm: a forward declaration, recursion, a zero-formal function, a nested procedure and required functions run byte-identical to fpc -Miso in both modes"
else echo "  ⛔ control arm FAILED -- the check refuses or miscompiles a LEGAL program"; echo "      want: $(tr '\n' '|' < "$T/ok.ref")"; echo "      m3  : $(printf '%s' "$ok3" | tr '\n' '|')"; echo "      m4  : $(printf '%s' "$ok4" | tr '\n' '|')"; RC=1; fi
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: $N calls with the wrong number of actual-parameters refused with a NAMED diagnostic in both modes, and legal calls are untouched"
else echo "GATE FAIL(1) [$G]: examined $N vendored PAT witnesses plus one legal control"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
