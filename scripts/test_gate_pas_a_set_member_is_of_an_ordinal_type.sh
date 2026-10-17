#!/usr/bin/env bash
# test_gate_pas_a_set_member_is_of_an_ordinal_type.sh -- ISO 7185 6.7.1, refused at compile time
#
# MEASURED 2026-09-23 by hq_pascal on SCRIP a722fc6b4, both modes, row pascal-all-test-suites-of-the-language-read-100-percent-on-the-
# suite-table-the-home-stretch (class row pascal-pat-static-type-and-parameter-checking). The type T "of every expression of each
# member-designator of the set-constructor ... shall be an ordinal-type" (6.7.1). set_member built the constructor whatever its
# expression was, so PAT iso7185prt1901 ([r] <> [] with r: real) compiled and ran. The check sits on both set_member productions
# (x and x..y) and reuses the assignment-compatibility classifiers: a real literal or constant, a string of other than one
# character, or a bare variable whose EVERY declaration resolves to real, is refused.
# Before landing, every acceptance program in the corpus (PasRungs, the FPC suite, P4, P5, the benchmarks, 456 programs) was compiled
# with the check: the refused set was identical to the tree before.
#
# ARMS: one vendored PAT witness, required to be REFUSED with a non-empty diagnostic in BOTH modes (m4 compiles, and if the compile is
# accepted, links and runs). A second arm proves the check DISCRIMINATES: set-constructors over integer variables, expressions and
# ranges, char literals and ranges and enumerated values run byte-identical to fpc -Miso in both modes (fpc refuses a constructor that
# mixes variables with a literal range, so the integer set is built by unions). A third arm is COMPILE-ONLY: [r] over a global integer
# r shadowed by a local r: real must be ACCEPTED, as fpc -Miso accepts it. FAIL_ONCE=1 flips the witness.
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
for b in iso7185prt1901; do
  f="$SRC/$b.pas"; [ -f "$f" ] || { echo "⛔ GATE REFUSE(2) [$G]: missing vendored witness $f"; exit 2; }
  N=$((N+1)); bad=""
  o3=$( cd "$T" && timeout -k 5 10s "$SCRIP" "$f" </dev/null 2>&1 ); rc3=$?
  if [ -n "${FAIL_ONCE:-}" ] && [ "$b" = iso7185prt1901 ]; then rc3=0; o3=""; fi
  { [ "$rc3" -ne 0 ] && [ "$rc3" -lt 124 ] && [ -n "$o3" ]; } || bad="m3 (rc=$rc3, ${#o3} bytes of diagnostic)"
  m4_run "$f"; o4="$M4O"; rc4=$M4RC
  { [ "$rc4" -ne 0 ] && [ "$rc4" -lt 124 ] && [ -n "$o4" ]; } || bad="$bad m4 (rc=$rc4, ${#o4} bytes of diagnostic)"
  if [ -n "$bad" ]; then echo "  $b ACCEPTED where ISO 7185 requires an ordinal-type member: $bad"; RC=1; else echo "  $b refused with a diagnostic in both modes"; fi
done
cat > "$T/ok.pas" <<'PAS'
program setctl(output);
type color = (red, green, blue);
var i, n: integer; c: char; k: color; s: set of 0..20; cs: set of char; ks: set of color;
begin
  i := 3; n := 7; c := 'q'; k := green;
  s := [i, n]; s := s + [1..2]; s := s + [i + 10]; cs := ['a'..'e', c]; ks := [red, k];
  n := 0; for i := 0 to 20 do if i in s then n := n + i;
  writeln(n:1, ' ', 'c' in cs, ' ', c in cs, ' ', 'z' in cs, ' ', blue in ks, ' ', green in ks)
end.
PAS
( cd "$T" && "$FPC" -Miso -v0 ok.pas >/dev/null 2>&1 && ./ok ) > "$T/ok.ref" 2>&1
[ -s "$T/ok.ref" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle produced no control-arm output"; exit 2; }
ok3=$( cd "$T" && timeout -k 5 20s "$SCRIP" --run ok.pas </dev/null 2>&1 ); m4_run "$T/ok.pas"; ok4="$M4O"
if [ "$ok3" = "$(cat "$T/ok.ref")" ] && [ "$ok4" = "$(cat "$T/ok.ref")" ]; then echo "  control arm: set-constructors over integer, char and enumerated members and ranges run byte-identical to fpc -Miso in both modes"
else echo "  ⛔ control arm FAILED -- the check refuses or miscompiles a LEGAL program"; echo "      want: $(tr '\n' '|' < "$T/ok.ref")"; echo "      m3  : $(printf '%s' "$ok3" | tr '\n' '|')"; echo "      m4  : $(printf '%s' "$ok4" | tr '\n' '|')"; RC=1; fi
cat > "$T/shadow.pas" <<'PAS'
program shadow(output);
var r: integer; s: set of 0..9;
procedure p;
var r: real;
begin r := 1.5 end;
begin r := 2; p; s := [r] end.
PAS
( cd "$T" && "$FPC" -Miso -v0 shadow.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso refused the shadow arm's program -- its verdict is the ref"; exit 2; }
if sh4=$( cd "$T" && timeout -k 5 20s "$SCRIP" --compile -o "$T/sh.s" shadow.pas </dev/null 2>&1 ); then echo "  shadow arm: [r] over a global integer r shadowed by a local r: real is accepted, as fpc -Miso accepts it (compile-only, see header)"
else echo "  ⛔ shadow arm FAILED -- a legal set member with a same-named local of another type was refused: $sh4"; RC=1; fi
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: $N set-constructors with a non-ordinal member refused with a NAMED diagnostic in both modes, and ordinal ones are untouched"
else echo "GATE FAIL(1) [$G]: examined $N vendored PAT witnesses plus one legal control"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
