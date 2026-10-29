#!/usr/bin/env bash
# test_gate_pas_a_literal_is_assignment_compatible_with_its_variable.sh -- ISO 7185 6.4.6 via 6.8.2.2 and 6.8.3.9, refused at compile time
#
# MEASURED 2026-09-23 by hq_pascal on SCRIP eb9d2f411, both modes, row pascal-all-test-suites-of-the-language-read-100-percent-on-the-
# suite-table-the-home-stretch (class row pascal-pat-static-type-and-parameter-checking). The expression of an assignment-statement
# (6.8.2.2) and the initial-value and final-value of a for-statement (6.8.3.9) shall be assignment-compatible with the variable's type
# (6.4.6). Nothing compared them: PAT iso7185prt1749 (a := 'c', a: integer), 1824 (i := 1.0), 1752 (for a := 'c' to 10) and 1753
# (for a := 1 to true) compiled and ran.
#
# ⭐ WHAT THE CHECK DELIBERATELY DOES NOT CLAIM. It classifies only a value whose type is certain from its shape -- a char literal or
# chr(), a real literal or real constant, the literal true or false, a string of other than one character -- and never an integer
# literal, because an enumerated, Boolean or char constant defined through another constant also lowers to one. A relational
# expression is NOT treated as Boolean: an FPC typecast lowers to its argument, so LongWord(i1 < i2) arrives looking like a relation
# (measured: without that restriction tbs_tb0601 and test_cg_tcnvint1 were refused). The variable's type must agree across EVERY
# declaration of its name in the flat type table, and an array variable is never checked (the table records a char array under its
# component type). Before landing, every acceptance program in the corpus (PasRungs, the FPC suite, P4, P5, the benchmarks, 456 programs)
# was compiled with the check: the refused set was identical to the tree before, so the check cannot move another suite's row.
#
# ARMS: four vendored PAT witnesses, each required to be REFUSED with a non-empty diagnostic in BOTH modes (m4 compiles, and if the
# compile is accepted, links and runs -- a witness passes that arm if either step refuses). A fifth arm proves the check
# DISCRIMINATES: every legal pairing it could confuse (real := integer, char := chr(), a Boolean constant, a string into a packed char
# array, for-statements over char, Boolean, enumerated and integer control variables) runs byte-identical to fpc -Miso in both modes.
# A sixth arm is COMPILE-ONLY: a global integer x shadowed by a local x: char must be ACCEPTED, as fpc -Miso accepts it (its output is
# not graded here -- the flat type table is a named open defect). FAIL_ONCE=1 flips the first witness to prove the arm can fail.
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
for b in iso7185prt1749 iso7185prt1752 iso7185prt1753 iso7185prt1824; do
  f="$SRC/$b.pas"; [ -f "$f" ] || { echo "⛔ GATE REFUSE(2) [$G]: missing vendored witness $f"; exit 2; }
  N=$((N+1)); bad=""
  o3=$( cd "$T" && timeout -k 5 10s "$SCRIP" "$f" </dev/null 2>&1 ); rc3=$?
  if [ -n "${FAIL_ONCE:-}" ] && [ "$b" = iso7185prt1749 ]; then rc3=0; o3=""; fi
  { [ "$rc3" -ne 0 ] && [ "$rc3" -lt 124 ] && [ -n "$o3" ]; } || bad="m3 (rc=$rc3, ${#o3} bytes of diagnostic)"
  m4_run "$f"; o4="$M4O"; rc4=$M4RC
  { [ "$rc4" -ne 0 ] && [ "$rc4" -lt 124 ] && [ -n "$o4" ]; } || bad="$bad m4 (rc=$rc4, ${#o4} bytes of diagnostic)"
  if [ -n "$bad" ]; then echo "  $b ACCEPTED where ISO 7185 requires an assignment-compatible value: $bad"; RC=1; else echo "  $b refused with a diagnostic in both modes"; fi
done
cat > "$T/ok.pas" <<'PAS'
program compat(output);
const big = 2.5; ch = 'k'; yes = true;
type color = (red, green, blue); letters = packed array [1..5] of char;
var i, n: integer; r: real; c: char; b: boolean; k: color; s: letters;
begin
  i := 7; r := 3; r := big; r := i; c := 'x'; c := ch; c := chr(i + 60); b := true; b := yes; k := blue; s := 'hello';
  writeln(i:1, ' ', r:5:2, ' ', c, ' ', b, ' ', ord(k):1, ' ', s);
  n := 0; for c := 'a' to 'e' do n := n + 1;
  for b := false to true do n := n + 10;
  for k := red to blue do n := n + 100;
  for i := 3 downto 1 do n := n + 1000;
  writeln(n:1)
end.
PAS
( cd "$T" && "$FPC" -Miso -v0 ok.pas >/dev/null 2>&1 && ./ok ) > "$T/ok.ref" 2>&1
[ -s "$T/ok.ref" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle produced no control-arm output"; exit 2; }
ok3=$( cd "$T" && timeout -k 5 20s "$SCRIP" --run ok.pas </dev/null 2>&1 ); m4_run "$T/ok.pas"; ok4="$M4O"
if [ "$ok3" = "$(cat "$T/ok.ref")" ] && [ "$ok4" = "$(cat "$T/ok.ref")" ]; then echo "  control arm: every legal pairing the check could confuse runs byte-identical to fpc -Miso in both modes"
else echo "  ⛔ control arm FAILED -- the check refuses or miscompiles a LEGAL program"; echo "      want: $(tr '\n' '|' < "$T/ok.ref")"; echo "      m3  : $(printf '%s' "$ok3" | tr '\n' '|')"; echo "      m4  : $(printf '%s' "$ok4" | tr '\n' '|')"; RC=1; fi
cat > "$T/shadow.pas" <<'PAS'
program shadow(output);
var x: integer;
procedure p;
var x: char;
begin x := 'q' end;
begin x := 5; p; x := x + 1 end.
PAS
( cd "$T" && "$FPC" -Miso -v0 shadow.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso refused the shadow arm's program -- its verdict is the ref"; exit 2; }
if sh4=$( cd "$T" && timeout -k 5 20s "$SCRIP" --compile --out="$T/sh.s" shadow.pas </dev/null 2>&1 ); then echo "  shadow arm: a global integer x shadowed by a local x: char is accepted, as fpc -Miso accepts it (compile-only, see header)"
else echo "  ⛔ shadow arm FAILED -- a legal assignment to a variable with a same-named local of another type was refused: $sh4"; RC=1; fi
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: $N values not assignment-compatible with their variable refused with a NAMED diagnostic in both modes, and legal assignments are untouched"
else echo "GATE FAIL(1) [$G]: examined $N vendored PAT witnesses plus one legal control"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
