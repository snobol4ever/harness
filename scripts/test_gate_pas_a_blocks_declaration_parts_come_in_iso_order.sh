#!/usr/bin/env bash
# test_gate_pas_a_blocks_declaration_parts_come_in_iso_order.sh -- ISO 7185 6.2.1, refused at compile time
#
# MEASURED 2026-09-23 by hq_pascal on SCRIP b034cc02f, both modes, row pascal-all-test-suites-of-the-language-read-100-percent-on-the-
# suite-table-the-home-stretch. A block is label, const, type, var, then procedures and functions, each part at most once (6.2.1).
# The grammar accepted the parts in any order, so PAT iso7185prt0024/0031/0040/0054/0055 (each one reversed pair) compiled and ran.
# decl_part now yields its rank and decl_part_list carries the last rank on bison's own value stack -- no new state, nesting free.
# ⛔⭐ THIS IS A RULING, NOT ONLY A CURE (Lon 2026-09-23, in-chat to the ceo, verbatim: "use ISO as oracle"; CEO-1225). fpc -Miso
# ACCEPTS out-of-order parts, and 15 programs of the vendored FPC suite rely on it (13 were green the day this landed). ISO wins:
# they are named, with the measurement, in corpus/packages/pascal/fpc_tests/OUTSIDE_ISO_BASELINE.tsv (mirrored by UNGRADABLE.tsv),
# stay in the FPC row's denominator (CEO-749 shape, OUTSIDE=15), and test_pascal_fpc_suite.sh cross-checks each run that every one
# is still refused. Before landing, every other acceptance program in the corpus was compiled with the check (PasRungs, P4, P5,
# benchmarks): zero tripped.
#
# ARMS: the five vendored witnesses, each REFUSED with a non-empty diagnostic in BOTH modes (m4 compiles, and if the compile is
# accepted, links and runs). A sixth arm proves the check DISCRIMINATES: a program with every part in order at program level and in
# a procedure (with a nested function carrying its own var part) runs byte-identical to fpc -Miso in both modes. FAIL_ONCE=1 flips
# the first witness to prove the arm can fail.
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
for b in iso7185prt0024 iso7185prt0031 iso7185prt0040 iso7185prt0054 iso7185prt0055; do
  f="$SRC/$b.pas"; [ -f "$f" ] || { echo "⛔ GATE REFUSE(2) [$G]: missing vendored witness $f"; exit 2; }
  N=$((N+1)); bad=""
  o3=$( cd "$T" && timeout -k 5 10s "$SCRIP" "$f" </dev/null 2>&1 ); rc3=$?
  if [ -n "${FAIL_ONCE:-}" ] && [ "$b" = iso7185prt0024 ]; then rc3=0; o3=""; fi
  { [ "$rc3" -ne 0 ] && [ "$rc3" -lt 124 ] && [ -n "$o3" ]; } || bad="m3 (rc=$rc3, ${#o3} bytes of diagnostic)"
  m4_run "$f"; o4="$M4O"; rc4=$M4RC
  { [ "$rc4" -ne 0 ] && [ "$rc4" -lt 124 ] && [ -n "$o4" ]; } || bad="$bad m4 (rc=$rc4, ${#o4} bytes of diagnostic)"
  if [ -n "$bad" ]; then echo "  $b ACCEPTED where ISO 7185 6.2.1 requires the ISO order: $bad"; RC=1; else echo "  $b refused with a diagnostic in both modes"; fi
done
cat > "$T/ok.pas" <<'PAS'
program declctl(output);
label 1;
const k = 3;
type small = 1..10;
var n: small; total: integer;
procedure outer(m: integer);
label 2;
const j = 2;
type pair = record a, b: integer end;
var p: pair;
  function twice(x: integer): integer;
  var t: integer;
  begin t := x * j; twice := t end;
begin p.a := m; p.b := twice(m); total := total + p.a + p.b; if total > 100 then goto 2; 2: end;
begin
  total := 0; n := k;
  outer(n);
  if total = 9 then goto 1;
  writeln('never');
  1: writeln('ordered parts accepted, total = ', total)
end.
PAS
( cd "$T" && "$FPC" -Miso -v0 ok.pas >/dev/null 2>&1 && ./ok ) > "$T/ok.ref" 2>&1
[ -s "$T/ok.ref" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle produced no control-arm output"; exit 2; }
ok3=$( cd "$T" && timeout -k 5 20s "$SCRIP" --run ok.pas </dev/null 2>&1 ); m4_run "$T/ok.pas"; ok4="$M4O"
if [ "$ok3" = "$(cat "$T/ok.ref")" ] && [ "$ok4" = "$(cat "$T/ok.ref")" ]; then echo "  control arm: every declaration part in ISO order, at two levels, runs byte-identical to fpc -Miso in both modes"
else echo "  ⛔ control arm FAILED -- the check refuses or miscompiles LEGAL declaration parts"; echo "      want: $(tr '\n' '|' < "$T/ok.ref")"; echo "      m3  : $(printf '%s' "$ok3" | tr '\n' '|')"; echo "      m4  : $(printf '%s' "$ok4" | tr '\n' '|')"; RC=1; fi
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: $N out-of-order declaration parts refused with a NAMED diagnostic in both modes, and ordered ones are untouched"
else echo "GATE FAIL(1) [$G]: examined $N vendored PAT witnesses plus one legal control"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
