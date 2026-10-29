#!/usr/bin/env bash
# test_gate_pas_a_char_subrange_variable_holds_chars.sh -- a variable of a subrange of char is written as a char
#
# MEASURED 2026-09-24 by hq_pascal on SCRIP 6703fb737, both modes, row pascal-all-test-suites-of-the-language-read-100-percent-on-the-
# suite-table-the-home-stretch. A WRONG ANSWER, found writing a control for the 6.4.2.4 gate: var c: 'a'..'e'; c := 'c'; writeln(c)
# printed "         99" in m3 at rc=0 where fpc -Miso prints c, and a named type letter = 'a'..'e' did the same. A subrange's host is
# the type of its bounds (6.4.2.4), but constant DOTDOT constant reduced each char literal to its ordinal through scalar_constant, so
# the pending type never learned it was char and the variable was never registered as a char variable. A new production
# STRINGCONST DOTDOT constant takes a range whose lower bound is a char literal (bison shifts DOTDOT over reducing scalar_constant --
# the sixth shift/reduce conflict, state 94, intended) and marks the pending type char; constant DOTDOT constant clears that mark, so a
# char-indexed array of an integer subrange stays integer; a named char subrange records an alias to char, and simple_type's IDENT arm
# reads char-ness through the alias. No suite cell moved.
#
# ARMS: one program cut LIVE from fpc -Miso and required byte-identical in BOTH modes (m4 compiles, links and runs): inline and named
# char subranges, one bounded by a char constant, a char-indexed array of an integer subrange, comparisons, ord, succ and a for loop
# over a char subrange. It FAILS on the parent tree. FAIL_ONCE=1 corrupts the ref to prove the arm can fail.
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
program charsub(output);
const hi = 'e';
type letter = 'a'..'e'; upto = 'a'..hi; small = 1..5;
var c: 'a'..'e'; d: letter; u: upto; e: char; y: array ['a'..'c'] of small; n: small;
begin
  c := 'c'; d := 'b'; u := 'd'; e := 'z'; y['b'] := 4; n := 3;
  writeln(c, d, u, e, ' ', ord(c):1, ' ', succ(d), ' ', c < d, ' ', c = 'c', ' ', y['b']:1, ' ', n:1);
  for c := 'a' to 'e' do write(c); writeln
end.
PAS
for p in ok; do
  N=$((N+1))
  ( cd "$T" && "$FPC" -Miso -v0 $p.pas >/dev/null 2>&1 && ./$p ) > "$T/$p.ref" 2>&1
  [ -s "$T/$p.ref" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle produced no output for arm $p"; exit 2; }
  if [ -n "${FAIL_ONCE:-}" ] && [ "$p" = ok ]; then echo "corrupted by FAIL_ONCE" >> "$T/$p.ref"; fi
  o3=$( cd "$T" && timeout -k 5 20s "$SCRIP" --run $p.pas </dev/null 2>&1 ); m4_run "$T/$p.pas"; o4="$M4O"
  if [ "$o3" = "$(cat "$T/$p.ref")" ] && [ "$o4" = "$(cat "$T/$p.ref")" ]; then echo "  arm $p: byte-identical to fpc -Miso in both modes"
  else echo "  ⛔ arm $p FAILED"; echo "      want: $(tr '\n' '|' < "$T/$p.ref")"; echo "      m3  : $(printf '%s' "$o3" | tr '\n' '|')"; echo "      m4  : $(printf '%s' "$o4" | tr '\n' '|')"; RC=1; fi
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: char subrange variables hold and write chars, byte-identical to fpc -Miso in both modes"
else echo "GATE FAIL(1) [$G]: examined $N oracle-cut arms"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
