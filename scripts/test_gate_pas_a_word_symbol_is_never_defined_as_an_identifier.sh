#!/usr/bin/env bash
# test_gate_pas_a_word_symbol_is_never_defined_as_an_identifier.sh -- ISO 7185 6.1.2, refused at compile time
#
# MEASURED 2026-09-23 by hq_pascal on SCRIP f82380c7d, both modes, row pascal-all-test-suites-of-the-language-read-100-percent-on-the-
# suite-table-the-home-stretch (class row pascal-pat-lexer-malformed-tokens). ISO 7185 6.1.2 lists the word-symbols, and a word-symbol
# is never an identifier. SCRIP's lexer returns most of them as their own tokens, so they could never be defined -- but it passes 'nil'
# through as an ordinary IDENT (mk_ident turns a USE of it into the null pointer), so PAT iso7185prt1911's 'var nil: integer' compiled
# and ran. The check sits in id_list, which is only ever a DEFINING occurrence (program parameters, enumeration constants, record
# fields, variables, formal parameters), and tests the whole 6.1.2 list, so any word-symbol the lexer lets through is refused the same
# way. Before landing, every acceptance program in the corpus was compiled with the check (PasRungs, the FPC suite, P4, P5, benchmarks):
# zero tripped; the only trip was the P5 copy of this same test.
#
# ARMS: the vendored witness, REFUSED with a non-empty diagnostic in BOTH modes (m4 compiles, and if the compile is accepted, links
# and runs). A second arm proves the check DISCRIMINATES: identifiers that merely CONTAIN a word-symbol (nilcount, endpoint, dotted,
# format, todo, index) as variables, enumeration constants and a parameter run byte-identical to fpc -Miso in both modes.
# FAIL_ONCE=1 flips the witness to prove the arm can fail.
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
for b in iso7185prt1911; do
  f="$SRC/$b.pas"; [ -f "$f" ] || { echo "⛔ GATE REFUSE(2) [$G]: missing vendored witness $f"; exit 2; }
  N=$((N+1)); bad=""
  o3=$( cd "$T" && timeout -k 5 10s "$SCRIP" "$f" </dev/null 2>&1 ); rc3=$?
  if [ -n "${FAIL_ONCE:-}" ] && [ "$b" = iso7185prt1911 ]; then rc3=0; o3=""; fi
  { [ "$rc3" -ne 0 ] && [ "$rc3" -lt 124 ] && [ -n "$o3" ]; } || bad="m3 (rc=$rc3, ${#o3} bytes of diagnostic)"
  m4_run "$f"; o4="$M4O"; rc4=$M4RC
  { [ "$rc4" -ne 0 ] && [ "$rc4" -lt 124 ] && [ -n "$o4" ]; } || bad="$bad m4 (rc=$rc4, ${#o4} bytes of diagnostic)"
  if [ -n "$bad" ]; then echo "  $b ACCEPTED where ISO 7185 6.1.2 forbids defining a word-symbol: $bad"; RC=1; else echo "  $b refused with a diagnostic in both modes"; fi
done
cat > "$T/ok.pas" <<'PAS'
program wsctl(output);
type shade = (endpoint, dotted, format);
var nilcount, index, todo: integer; s: shade;
procedure setup(ofs: integer); begin nilcount := ofs; todo := ofs * 2 end;
begin
  setup(3); index := nilcount + todo; s := dotted;
  writeln('nilcount ', nilcount, ' todo ', todo, ' index ', index, ' shade ', ord(s))
end.
PAS
( cd "$T" && "$FPC" -Miso -v0 ok.pas >/dev/null 2>&1 && ./ok ) > "$T/ok.ref" 2>&1
[ -s "$T/ok.ref" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle produced no control-arm output"; exit 2; }
ok3=$( cd "$T" && timeout -k 5 20s "$SCRIP" --run ok.pas </dev/null 2>&1 ); m4_run "$T/ok.pas"; ok4="$M4O"
if [ "$ok3" = "$(cat "$T/ok.ref")" ] && [ "$ok4" = "$(cat "$T/ok.ref")" ]; then echo "  control arm: identifiers containing word-symbols run byte-identical to fpc -Miso in both modes"
else echo "  ⛔ control arm FAILED -- the check refuses or miscompiles LEGAL identifiers"; echo "      want: $(tr '\n' '|' < "$T/ok.ref")"; echo "      m3  : $(printf '%s' "$ok3" | tr '\n' '|')"; echo "      m4  : $(printf '%s' "$ok4" | tr '\n' '|')"; RC=1; fi
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: $N word-symbol definitions refused with a NAMED diagnostic in both modes, and identifiers that only contain one are untouched"
else echo "GATE FAIL(1) [$G]: examined $N vendored PAT witnesses plus one legal control"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
