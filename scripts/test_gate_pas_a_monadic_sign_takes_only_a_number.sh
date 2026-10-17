#!/usr/bin/env bash
# test_gate_pas_a_monadic_sign_takes_only_a_number.sh -- ISO 7185 6.7.2.2 (table 4), refused at compile time
#
# MEASURED 2026-09-23 by hq_pascal on SCRIP ca0cfcd4b, both modes, row pascal-all-test-suites-of-the-language-read-100-percent-on-the-
# suite-table-the-home-stretch. A monadic + or - takes an operand of integer-type or real-type only (6.7.2.2, table 4). The grammar
# returned +x unchanged and -x as mk_neg(x) whatever x was, so PAT iso7185prt1916 (writeln(+c), c: char) compiled and ran. The check
# reuses the classification of the assignment-compatibility check (pas_expr_lit_class, pas_var_decl_class): a char, Boolean or string
# literal, or a bare variable whose EVERY declaration is char, Boolean or enumerated, is refused; anything else is left alone.
# Before landing, every acceptance program in the corpus (PasRungs, the FPC suite, P4, P5, the benchmarks, 456 programs) was compiled
# with the check: the refused set was identical to the tree before.
#
# ARMS: one vendored PAT witness, required to be REFUSED with a non-empty diagnostic in BOTH modes (m4 compiles, and if the compile is
# accepted, links and runs). A second arm proves the check DISCRIMINATES: signs on integer and real variables, ord() of a char, an
# expression, maxint and a signed constant run byte-identical to fpc -Miso in both modes (a doubled sign, - -3, is NOT in it: ISO's
# grammar has no sign inside a factor, fpc accepts it as an extension, and SCRIP refuses it). A third arm is COMPILE-ONLY: a global
# integer x shadowed by a local x: char must be ACCEPTED under -x, as fpc -Miso accepts it. FAIL_ONCE=1 flips the witness.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
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
for b in iso7185prt1916; do
  f="$SRC/$b.pas"; [ -f "$f" ] || { echo "⛔ GATE REFUSE(2) [$G]: missing vendored witness $f"; exit 2; }
  N=$((N+1)); bad=""
  o3=$( cd "$T" && timeout -k 5 10s "$SCRIP" "$f" </dev/null 2>&1 ); rc3=$?
  if [ -n "${FAIL_ONCE:-}" ] && [ "$b" = iso7185prt1916 ]; then rc3=0; o3=""; fi
  { [ "$rc3" -ne 0 ] && [ "$rc3" -lt 124 ] && [ -n "$o3" ]; } || bad="m3 (rc=$rc3, ${#o3} bytes of diagnostic)"
  m4_run "$f"; o4="$M4O"; rc4=$M4RC
  { [ "$rc4" -ne 0 ] && [ "$rc4" -lt 124 ] && [ -n "$o4" ]; } || bad="$bad m4 (rc=$rc4, ${#o4} bytes of diagnostic)"
  if [ -n "$bad" ]; then echo "  $b ACCEPTED where ISO 7185 requires an integer or real operand: $bad"; RC=1; else echo "  $b refused with a diagnostic in both modes"; fi
done
cat > "$T/ok.pas" <<'PAS'
program signctl(output);
const k = 5; neg = -k;
var i: integer; r: real; c: char;
begin
  i := 7; r := 2.5; c := 'a';
  writeln(-i:1, ' ', +i:1, ' ', -r:5:2, ' ', +r:5:2, ' ', -ord(c):1, ' ', -(i + 1):1, ' ', +maxint:1, ' ', neg:1)
end.
PAS
( cd "$T" && "$FPC" -Miso -v0 ok.pas >/dev/null 2>&1 && ./ok ) > "$T/ok.ref" 2>&1
[ -s "$T/ok.ref" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle produced no control-arm output"; exit 2; }
ok3=$( cd "$T" && timeout -k 5 20s "$SCRIP" --run ok.pas </dev/null 2>&1 ); m4_run "$T/ok.pas"; ok4="$M4O"
if [ "$ok3" = "$(cat "$T/ok.ref")" ] && [ "$ok4" = "$(cat "$T/ok.ref")" ]; then echo "  control arm: signs on integer, real, ord(), expression and constant operands run byte-identical to fpc -Miso in both modes"
else echo "  ⛔ control arm FAILED -- the check refuses or miscompiles a LEGAL program"; echo "      want: $(tr '\n' '|' < "$T/ok.ref")"; echo "      m3  : $(printf '%s' "$ok3" | tr '\n' '|')"; echo "      m4  : $(printf '%s' "$ok4" | tr '\n' '|')"; RC=1; fi
cat > "$T/shadow.pas" <<'PAS'
program shadow(output);
var x: integer;
procedure p;
var x: char;
begin x := 'q' end;
begin x := 5; p; x := -x end.
PAS
( cd "$T" && "$FPC" -Miso -v0 shadow.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso refused the shadow arm's program -- its verdict is the ref"; exit 2; }
if sh4=$( cd "$T" && timeout -k 5 20s "$SCRIP" --compile -o "$T/sh.s" shadow.pas </dev/null 2>&1 ); then echo "  shadow arm: -x on a global integer x shadowed by a local x: char is accepted, as fpc -Miso accepts it (compile-only, see header)"
else echo "  ⛔ shadow arm FAILED -- a legal sign on a variable with a same-named local of another type was refused: $sh4"; RC=1; fi
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: $N monadic signs on a non-numeric operand refused with a NAMED diagnostic in both modes, and legal signs are untouched"
else echo "GATE FAIL(1) [$G]: examined $N vendored PAT witnesses plus one legal control"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
