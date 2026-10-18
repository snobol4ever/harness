#!/usr/bin/env bash
# test_gate_pas_an_if_while_or_until_condition_must_be_boolean.sh -- ISO 7185 6.8.3.4 / 6.8.3.7 / 6.8.3.8, refused at compile time
#
# MEASURED 2026-09-23 by hq_pascal on SCRIP 3fab59506, both modes, row pascal-all-test-suites-of-the-language-read-100-percent-on-the-
# suite-table-the-home-stretch (class row pascal-pat-boolean-context-required). The condition of an if-statement, the until part of a
# repeat-statement and the condition of a while-statement shall be of the required-type Boolean. All three went through pas_cond,
# which turned a non-Boolean condition into "e <> 0" and ran it: PAT iso7185prt1904/1905/1906 declare an enumerated look-alike,
# type myBoolean = (myFalse, myTrue), and a program that tests a variable of it printed 'error not detected'. ⛔ pas_cond also
# builds each case-arm test, so the check is NOT in it -- it sits at the four statement sites, which name their own clause.
#
# ⭐ WHAT THE CHECK DELIBERATELY DOES NOT CLAIM. It fires only on a condition that is a bare VARIABLE whose EVERY declaration in the
# parser's type table resolves to an enumerated, integer, real or char type. The table is flat, so a procedure's locals stay in it
# after the procedure ends: requiring every declaration of the name to agree is what keeps a Boolean global legal after an
# enumerated local of the same name (the control arm below proves it). A non-Boolean EXPRESSION (i + 1) is not graded here.
# Before landing, every acceptance program in the corpus was compiled with the check (PasRungs, the FPC suite, P4, P5, the benchmarks):
# zero tripped, so the check cannot move another suite's row. The only trips were the P5 copies of these same three tests.
#
# ARMS: three vendored PAT witnesses, each required to be REFUSED with a non-empty diagnostic in BOTH modes (m4 compiles, and if the
# compile is accepted, links and runs -- a witness passes that arm if either step refuses). A fourth arm proves the check
# DISCRIMINATES: a legal program using a Boolean alias type, a Boolean function in while/until/if, and a Boolean global shadowed by
# an enumerated local runs byte-identical to fpc -Miso in both modes. FAIL_ONCE=1 flips the first witness to prove the arm can fail.
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
for b in iso7185prt1904 iso7185prt1905 iso7185prt1906; do
  f="$SRC/$b.pas"; [ -f "$f" ] || { echo "⛔ GATE REFUSE(2) [$G]: missing vendored witness $f"; exit 2; }
  N=$((N+1)); bad=""
  o3=$( cd "$T" && timeout -k 5 10s "$SCRIP" "$f" </dev/null 2>&1 ); rc3=$?
  if [ -n "${FAIL_ONCE:-}" ] && [ "$b" = iso7185prt1904 ]; then rc3=0; o3=""; fi
  { [ "$rc3" -ne 0 ] && [ "$rc3" -lt 124 ] && [ -n "$o3" ]; } || bad="m3 (rc=$rc3, ${#o3} bytes of diagnostic)"
  m4_run "$f"; o4="$M4O"; rc4=$M4RC
  { [ "$rc4" -ne 0 ] && [ "$rc4" -lt 124 ] && [ -n "$o4" ]; } || bad="$bad m4 (rc=$rc4, ${#o4} bytes of diagnostic)"
  if [ -n "$bad" ]; then echo "  $b ACCEPTED where ISO 7185 requires a Boolean condition: $bad"; RC=1; else echo "  $b refused with a diagnostic in both modes"; fi
done
cat > "$T/ok.pas" <<'PAS'
program boolctl(output);
type flag = boolean; color = (red, green);
var f: flag; b: boolean; n: integer;
function ready: boolean; begin ready := n < 3 end;
procedure p; var b: color; begin b := green; if b = green then writeln('local enum compared') end;
begin
  f := true; b := false; n := 0;
  if f then writeln('alias true');
  if b then writeln('never') else writeln('plain false');
  while ready do n := n + 1;
  repeat n := n - 1 until not ready or (n < 0);
  if ready then writeln('ready ', n);
  p;
  if b then writeln('never') else writeln('global still boolean')
end.
PAS
( cd "$T" && "$FPC" -Miso -v0 ok.pas >/dev/null 2>&1 && ./ok ) > "$T/ok.ref" 2>&1
[ -s "$T/ok.ref" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle produced no control-arm output"; exit 2; }
ok3=$( cd "$T" && timeout -k 5 20s "$SCRIP" --run ok.pas </dev/null 2>&1 ); m4_run "$T/ok.pas"; ok4="$M4O"
if [ "$ok3" = "$(cat "$T/ok.ref")" ] && [ "$ok4" = "$(cat "$T/ok.ref")" ]; then echo "  control arm: Boolean alias, Boolean function and a shadowed Boolean global run byte-identical to fpc -Miso in both modes"
else echo "  ⛔ control arm FAILED -- the check refuses or miscompiles a LEGAL Boolean condition"; echo "      want: $(tr '\n' '|' < "$T/ok.ref")"; echo "      m3  : $(printf '%s' "$ok3" | tr '\n' '|')"; echo "      m4  : $(printf '%s' "$ok4" | tr '\n' '|')"; RC=1; fi
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: $N non-Boolean conditions refused with a NAMED diagnostic in both modes, and legal Boolean conditions are untouched"
else echo "GATE FAIL(1) [$G]: examined $N vendored PAT witnesses plus one legal control"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
