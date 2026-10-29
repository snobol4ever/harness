#!/usr/bin/env bash
# test_gate_pas_an_ordinal_function_result_exists_in_its_type.sh -- ISO 7185 6.6.6.4, refused at RUN time, out loud
#
# MEASURED 2026-09-23 by hq_pascal on SCRIP 04f8b19af, both modes, row pascal-all-test-suites-of-the-language-read-100-percent-on-the-
# suite-table-the-home-stretch (class row pascal-pat-ordinal-arithmetic-domain-and-range). chr(x) yields the char whose ordinal number
# is x "if such a character value exists", succ(x) the value one greater and pred(x) the value one less "if such a value exists"; "it
# shall be an error if such a value does not exist" (6.6.6.4). mk_call lowered succ and pred to x + 1 and x - 1 and chr to a bare
# wrapper, so PAT iso7185prt1737 (chr(-1)), 1738 (succ(maxint)), 1739 (pred(-maxint)), 1864 (succ of the last enumerated value) and
# 1865 (pred of the first) ran to rc=0. A result is now passed through __pas_ord_check(v, lo, hi, what), a Pascal arm of
# by_name_dispatch.c that stops the program through pas_file_err ("scrip: pascal runtime error: ISO 7185 6.6.6.4: ...", rc=1).
#
# ⭐ WHERE THE CHECK IS, AND WHERE IT DELIBERATELY IS NOT. chr of anything but an integer literal is checked against 0..255. succ and
# pred are checked only when the argument is a bare variable whose EVERY declaration resolves to one of integer (-maxint..maxint, the
# letter of 6.6.6.4 and PAT's own note on 1739), char (0..255), Boolean (0..1) or an enumerated type (0..its last ordinal): an int64,
# longint or other FPC integer type, a subrange (whose succ yields its HOST type, not its own range) and an expression are left
# unchecked, so no legal program of any of those types can be stopped by it. No benchmark calls succ, pred or chr.
# Measured before landing, every graded Pascal program RUN in both modes (the rungs 246, the FPC suite 181, the eleven benchmarks,
# PAT's acceptance programs): no cell moved except the five witnesses' ten.
#
# ARMS: five vendored PAT witnesses, each required to be REFUSED at run time with a non-empty diagnostic in BOTH modes (m4 compiles,
# links and RUNS). A sixth arm proves the check DISCRIMINATES: succ(maxint - 1), pred(-maxint + 1), enumerated walks to both ends,
# succ and pred of chars, succ(false), succ of a subrange variable and chr over 32..126 run byte-identical to fpc -Miso in both modes.
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
m4_run() { M4O=$( cd "$T" && timeout -k 5 20s "$SCRIP" --compile --out="$T/w.s" "$1" </dev/null 2>&1 ); M4RC=$?
  if [ "$M4RC" = 0 ]; then
    ( cd "$T" && cc -m64 -no-pie w.s -o w -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: $1 compiled but would not link -- cannot grade the m4 arm"; exit 2; }
    M4O=$( cd "$T" && timeout -k 5 20s ./w </dev/null 2>&1 ); M4RC=$?
  fi; }
for b in iso7185prt1737 iso7185prt1738 iso7185prt1739 iso7185prt1864 iso7185prt1865; do
  f="$SRC/$b.pas"; [ -f "$f" ] || { echo "⛔ GATE REFUSE(2) [$G]: missing vendored witness $f"; exit 2; }
  N=$((N+1)); bad=""
  o3=$( cd "$T" && timeout -k 5 10s "$SCRIP" "$f" </dev/null 2>&1 ); rc3=$?
  if [ -n "${FAIL_ONCE:-}" ] && [ "$b" = iso7185prt1737 ]; then rc3=0; o3=""; fi
  { [ "$rc3" -ne 0 ] && [ "$rc3" -lt 124 ] && [ -n "$o3" ]; } || bad="m3 (rc=$rc3, ${#o3} bytes of diagnostic)"
  m4_run "$f"; o4="$M4O"; rc4=$M4RC
  { [ "$rc4" -ne 0 ] && [ "$rc4" -lt 124 ] && [ -n "$o4" ]; } || bad="$bad m4 (rc=$rc4, ${#o4} bytes of diagnostic)"
  if [ -n "$bad" ]; then echo "  $b RAN TO COMPLETION where ISO 7185 requires an error: $bad"; RC=1; else echo "  $b stopped with a runtime diagnostic in both modes"; fi
done
cat > "$T/ok.pas" <<'PAS'
program ordrange(output);
type color = (red, green, blue); shade = red..green;
var i, n: integer; c, d: char; k: color; b: boolean; s: shade;
begin
  i := maxint - 1; i := succ(i); n := -maxint + 1; n := pred(n);
  writeln(i:1, ' ', n:1);
  k := red; while k <> blue do k := succ(k); writeln(ord(k):1);
  k := blue; while k <> red do k := pred(k); writeln(ord(k):1);
  c := 'a'; d := succ(c); c := 'z'; c := pred(c); writeln(c, d);
  b := false; b := succ(b); writeln(b);
  s := red; k := succ(s); writeln(ord(k):1);
  n := 0; for i := 32 to 126 do if chr(i) = 'A' then n := i; writeln(n:1, ' ', chr(n + 1))
end.
PAS
( cd "$T" && "$FPC" -Miso -v0 ok.pas >/dev/null 2>&1 && ./ok ) > "$T/ok.ref" 2>&1
[ -s "$T/ok.ref" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle produced no control-arm output"; exit 2; }
ok3=$( cd "$T" && timeout -k 5 20s "$SCRIP" --run ok.pas </dev/null 2>&1 ); m4_run "$T/ok.pas"; ok4="$M4O"
if [ "$ok3" = "$(cat "$T/ok.ref")" ] && [ "$ok4" = "$(cat "$T/ok.ref")" ]; then echo "  control arm: in-range succ, pred and chr at every edge run byte-identical to fpc -Miso in both modes"
else echo "  ⛔ control arm FAILED -- the check refuses or miscompiles a LEGAL program"; echo "      want: $(tr '\n' '|' < "$T/ok.ref")"; echo "      m3  : $(printf '%s' "$ok3" | tr '\n' '|')"; echo "      m4  : $(printf '%s' "$ok4" | tr '\n' '|')"; RC=1; fi
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: $N ordinal-function results outside their type stopped with a NAMED runtime diagnostic in both modes, and in-range ones are untouched"
else echo "GATE FAIL(1) [$G]: examined $N vendored PAT witnesses plus one legal control"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
