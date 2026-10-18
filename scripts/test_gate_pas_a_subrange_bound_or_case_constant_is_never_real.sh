#!/usr/bin/env bash
# test_gate_pas_a_subrange_bound_or_case_constant_is_never_real.sh -- ISO 7185 6.4.2.4 / 6.4.3.3 / 6.8.3.5, refused at compile time
#
# MEASURED 2026-09-23 by hq_pascal on SCRIP 3b5f301f1, both modes, row pascal-all-test-suites-of-the-language-read-100-percent-on-the-
# suite-table-the-home-stretch. Both constants of a subrange-type shall be of one ordinal-type (6.4.2.4), and a case-constant shall be
# of the ordinal-type of its case-index (6.8.3.5) or of its variant's tag-type (6.4.3.3). The grammar's scalar_constant took a
# REALCONST and truncated it to an integer, so PAT iso7185prt1907a (type 1.1 .. 10), 1907b (type 1 .. 10.1) and 1908 (case label 1.1)
# compiled and ran. The check sits on that one reduction, and it is exact: bison's own report shows every real constant-definition
# (const r = 1.5, = +1.5, = -1.5) SHIFTS into its own const_decl production (states 81/135/137), so scalar_constant: REALCONST is
# reached only from a subrange bound or a case-constant-list, and never from a legal program.
# Before landing, every acceptance program in the corpus was compiled with the check (PasRungs, the FPC suite, P4, P5, the benchmarks,
# 456 programs): the refused set was identical to the tree before, so the check cannot move another suite's row.
#
# ARMS: three vendored PAT witnesses, each required to be REFUSED with a non-empty diagnostic in BOTH modes (m4 compiles, and if the
# compile is accepted, links and runs -- a witness passes that arm if either step refuses). A fourth arm proves the check
# DISCRIMINATES: a legal program with real constant-definitions of all three signs, integer, char and enumerated subranges, integer and
# char case-constants and a variant record runs byte-identical to fpc -Miso in both modes. FAIL_ONCE=1 flips the first witness.
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
for b in iso7185prt1907a iso7185prt1907b iso7185prt1908; do
  f="$SRC/$b.pas"; [ -f "$f" ] || { echo "⛔ GATE REFUSE(2) [$G]: missing vendored witness $f"; exit 2; }
  N=$((N+1)); bad=""
  o3=$( cd "$T" && timeout -k 5 10s "$SCRIP" "$f" </dev/null 2>&1 ); rc3=$?
  if [ -n "${FAIL_ONCE:-}" ] && [ "$b" = iso7185prt1907a ]; then rc3=0; o3=""; fi
  { [ "$rc3" -ne 0 ] && [ "$rc3" -lt 124 ] && [ -n "$o3" ]; } || bad="m3 (rc=$rc3, ${#o3} bytes of diagnostic)"
  m4_run "$f"; o4="$M4O"; rc4=$M4RC
  { [ "$rc4" -ne 0 ] && [ "$rc4" -lt 124 ] && [ -n "$o4" ]; } || bad="$bad m4 (rc=$rc4, ${#o4} bytes of diagnostic)"
  if [ -n "$bad" ]; then echo "  $b ACCEPTED where ISO 7185 requires an ordinal constant: $bad"; RC=1; else echo "  $b refused with a diagnostic in both modes"; fi
done
cat > "$T/ok.pas" <<'PAS'
program ordctl(output);
const r = 1.5; m = -2.5e1; p = +0.25; lo = 2; hi = 7;
type small = lo..hi; letter = 'a'..'e'; color = (red, green, blue); warm = red..green;
     shape = record case k: color of red: (x: integer); green, blue: (y: char) end;
var s: small; c: letter; w: warm; v: shape; i: integer;
begin
  writeln(r:6:2, m:8:2, p:6:2);
  s := 5; c := 'c'; w := green; v.k := green; v.y := 'q';
  for i := 1 to 3 do
    case i of
      1: writeln('one ', s:1);
      2, 3: writeln('two or three ', ord(c) - ord('a'):1)
    end;
  case c of 'a', 'b': writeln('ab'); 'c': writeln('c') end;
  if w = green then writeln('warm green ', v.y)
end.
PAS
( cd "$T" && "$FPC" -Miso -v0 ok.pas >/dev/null 2>&1 && ./ok ) > "$T/ok.ref" 2>&1
[ -s "$T/ok.ref" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle produced no control-arm output"; exit 2; }
ok3=$( cd "$T" && timeout -k 5 20s "$SCRIP" --run ok.pas </dev/null 2>&1 ); m4_run "$T/ok.pas"; ok4="$M4O"
if [ "$ok3" = "$(cat "$T/ok.ref")" ] && [ "$ok4" = "$(cat "$T/ok.ref")" ]; then echo "  control arm: real constant-definitions, ordinal subranges, case-constants and a variant run byte-identical to fpc -Miso in both modes"
else echo "  ⛔ control arm FAILED -- the check refuses or miscompiles a LEGAL program"; echo "      want: $(tr '\n' '|' < "$T/ok.ref")"; echo "      m3  : $(printf '%s' "$ok3" | tr '\n' '|')"; echo "      m4  : $(printf '%s' "$ok4" | tr '\n' '|')"; RC=1; fi
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: $N real constants in an ordinal position refused with a NAMED diagnostic in both modes, and legal real constants are untouched"
else echo "GATE FAIL(1) [$G]: examined $N vendored PAT witnesses plus one legal control"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
