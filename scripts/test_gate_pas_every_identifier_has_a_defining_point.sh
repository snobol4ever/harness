#!/usr/bin/env bash
# test_gate_pas_every_identifier_has_a_defining_point.sh -- ISO 7185 6.2.2.1, refused at compile time
#
# MEASURED 2026-09-24 by hq_pascal on SCRIP 8b6cb3607, both modes, row pascal-all-test-suites-of-the-language-read-100-percent-on-the-
# suite-table-the-home-stretch. "Each identifier or label contained by the program-block shall have a defining-point" (6.2.2.1).
# The Pascal parser kept only flat per-kind tables and no table of defining-points, so an identifier declared nowhere became a fresh
# variable: PAT iso7185prt0138 (for id := ...), 1300 (a := nul), 1508 (a := e+5) and 1838 (i := 1 with no var part) compiled and ran,
# and so did the coo's program bad; begin undeclared := 1 end. g_pas_scope -- THE ONE NEW GLOBAL, GRANTED BY LON IN-CHAT 2026-09-24
# ("I grant the use of the global variable.") -- is a stack of scopes of defining-points: constants, types, enumerated constants,
# variables, record fields and tags, program-parameters, routine names in the enclosing scope, and formal parameters (a forward-declared
# routine's parameters restored at its body) in the routine's own scope, pushed and popped with each routine body. An identifier in a
# variable position (mk_ident's fall-through) or a for-statement control-variable with no defining-point in an enclosing scope is
# refused. Required identifiers (true, false, maxint, input, output) and SCRIP's own type identifiers (integer, real, char, boolean,
# text, string and the FPC integer and real type names) are defined by the implementation.
# Measured before landing, every acceptance program (PasRungs, the FPC suite, P4, P5, the benchmarks, 456 programs): the only programs
# newly refused are five FPC-suite programs that apply an FPC system-unit identifier (inoutres, random, returnnilifgrowheapfails,
# cp_acp) -- fpc -Miso runs them, ISO 7185 refuses them -- named in fpc_tests/ISO_EXPECTED_REFUSALS.tsv under CEO-1225/1228.
#
# ARMS: four vendored PAT witnesses and one minted one (a procedure's local applied after its procedure has closed -- the arm that
# proves the table is SCOPED, not flat; fpc -Miso refuses it too: Identifier not found), each required to be REFUSED with a non-empty
# diagnostic in BOTH modes. A sixth arm proves the check DISCRIMINATES: parameters, a forward-declared routine's parameters used in its
# body, locals, uplevel variables, function results, with-fields, enumerated constants, record tags and constants run byte-identical to
# fpc -Miso in both modes. FAIL_ONCE=1 flips the first witness.
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
cat > "$T/closed.pas" <<'PAS'
program closed(output);
procedure p;
var q: integer;
begin q := 1 end;
begin p; q := 2 end.
PAS
for b in iso7185prt0138 iso7185prt1300 iso7185prt1508 iso7185prt1838 closed; do
  f="$SRC/$b.pas"; [ "$b" = closed ] && f="$T/closed.pas"; [ -f "$f" ] || { echo "⛔ GATE REFUSE(2) [$G]: missing vendored witness $f"; exit 2; }
  N=$((N+1)); bad=""
  o3=$( cd "$T" && timeout -k 5 10s "$SCRIP" "$f" </dev/null 2>&1 ); rc3=$?
  if [ -n "${FAIL_ONCE:-}" ] && [ "$b" = iso7185prt0138 ]; then rc3=0; o3=""; fi
  { [ "$rc3" -ne 0 ] && [ "$rc3" -lt 124 ] && [ -n "$o3" ]; } || bad="m3 (rc=$rc3, ${#o3} bytes of diagnostic)"
  m4_run "$f"; o4="$M4O"; rc4=$M4RC
  { [ "$rc4" -ne 0 ] && [ "$rc4" -lt 124 ] && [ -n "$o4" ]; } || bad="$bad m4 (rc=$rc4, ${#o4} bytes of diagnostic)"
  if [ -n "$bad" ]; then echo "  $b ACCEPTED where ISO 7185 requires a defining-point: $bad"; RC=1; else echo "  $b refused with a diagnostic in both modes"; fi
done
cat > "$T/ok.pas" <<'PAS'
program scopes(input, output);
const limit = 3; half = 1.5; star = '*';
type color = (red, green, blue); pt = record x, y: integer end;
     shape = record case k: color of red: (r: integer); green, blue: (g: char) end;
var total: integer; p: pt; s: shape; c: color;
procedure later(a, b: integer); forward;
function twice(n: integer): integer;
  var local: integer;
  function inner(m: integer): integer;
  begin inner := m + local end;
begin local := n; twice := inner(n) end;
procedure later;
var i: integer;
begin for i := a to b do total := total + twice(i) end;
begin
  total := 0; later(1, limit);
  with p do begin x := 4; y := 5 end;
  s.k := green; s.g := star; c := blue;
  writeln(total:1, ' ', p.x + p.y:1, ' ', s.g, ' ', ord(c):1, ' ', half:3:1)
end.
PAS
( cd "$T" && "$FPC" -Miso -v0 ok.pas >/dev/null 2>&1 && ./ok ) > "$T/ok.ref" 2>&1
[ -s "$T/ok.ref" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle produced no control-arm output"; exit 2; }
ok3=$( cd "$T" && timeout -k 5 20s "$SCRIP" --run ok.pas </dev/null 2>&1 ); m4_run "$T/ok.pas"; ok4="$M4O"
if [ "$ok3" = "$(cat "$T/ok.ref")" ] && [ "$ok4" = "$(cat "$T/ok.ref")" ]; then echo "  control arm: every kind of defining-point, scoped and uplevel, runs byte-identical to fpc -Miso in both modes"
else echo "  ⛔ control arm FAILED -- the check refuses or miscompiles a LEGAL program"; echo "      want: $(tr '\n' '|' < "$T/ok.ref")"; echo "      m3  : $(printf '%s' "$ok3" | tr '\n' '|')"; echo "      m4  : $(printf '%s' "$ok4" | tr '\n' '|')"; RC=1; fi
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: $N identifiers with no defining-point refused with a NAMED diagnostic in both modes, and declared ones are untouched"
else echo "GATE FAIL(1) [$G]: examined $N vendored PAT witnesses plus one legal control"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
