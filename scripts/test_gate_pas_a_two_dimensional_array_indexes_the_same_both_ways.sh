#!/usr/bin/env bash
# test_gate_pas_a_two_dimensional_array_indexes_the_same_both_ways.sh
#
# MEASURED 2026-09-13 by the coo on origin 02c9087c4, taking the P5 self-host row. ISO 7185 6.5.3.2 defines x[i,j] as an
# ABBREVIATION for x[i][j] -- the two spellings are the same access and a processor must accept both. SCRIP accepted only
# the comma form: a two-dimensional array written x[i][j] produced NO OUTPUT AT ALL, silently, in both modes, because the
# selector flattened two subscripts to the array's column count only when they arrived in one bracket pair.
#
# Pascal-P5's compiler pcom.pas declares cdxs as "array [1..6, 1..7] of integer" and writes cdxs[1][1], so this silently
# lost its instruction cost tables and terminated inside initdx before compiling a line. It is the third defect between
# SCRIP and the P5 milestone, after the record-variable scope and the field-table width.
#
# Cure, one rule in pascal.y: a single subscript applied to an already-subscripted VAR whose declared column count is
# known flattens exactly as the comma form does. pascal.y keeps its 5 shift/reduce conflicts.
#
# ⛔ WHAT THIS GATE DOES NOT CLAIM: an array declared as an ARRAY OF AN ARRAY TYPE (array [1..6] of row) indexed r[i][j]
# is a different representation, is still not accepted, and is not cured here. This gate covers the ISO abbreviation of a
# two-dimensional array only, which is what the standard's 6.5.3.2 equivalence is about.
#
# ARMS: one program, both modes, byte-identical to fpc -Miso -- a 6x7 array zeroed through a nested loop in the separate
# subscript form, four elements written and read back, and the whole array summed. FAIL_ONCE=1 corrupts the sum.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "GATE REFUSE(2) [$G]: no fpc at $FPC -- the ref is CUT FROM THE ORACLE, never pinned by hand"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/d.pas" <<'PAS'
program aa(output);
 
var t: array [1..6, 1..7] of integer; i, j, s: integer;
begin
  for i := 1 to 6 do for j := 1 to 7 do t[i][j] := 0;
  t[1][1] := 11;
  t[1][2] := 12;
  t[3][7] := 37;
  t[6][4] := 64;
  s := 0;
  for i := 1 to 6 do for j := 1 to 7 do s := s + t[i][j];
  writeln('t11 ', t[1][1]:1, ' t12 ', t[1][2]:1, ' t37 ', t[3][7]:1, ' t64 ', t[6][4]:1, ' sum ', s:1)
end.
PAS
( cd "$T" && "$FPC" -Miso -v0 d.pas >/dev/null 2>&1 && ./d ) > "$T/d.ref" 2>&1
grep -q 'sum 124$' "$T/d.ref" || { echo "GATE REFUSE(2) [$G]: the oracle did not produce the sum this gate pins -- the oracle moved: $(head -1 "$T/d.ref")"; exit 2; }
( cd "$T" && timeout -k 5 60 "$SCRIP" --compile -o d.s d.pas </dev/null && gcc d.s -o d.bin -L"$RT_DIR" -lscrip_rt -lm -lpthread ) >/dev/null 2>&1 || { echo "GATE FAIL(1) [$G]: the mode-4 witness did not build"; exit 1; }
RC=0
for M in m3 m4; do
  if [ "$M" = m3 ]; then ( cd "$T" && timeout -k 5 60 "$SCRIP" --run d.pas </dev/null ) >"$T/$M.out" 2>&1
  else ( cd "$T" && LD_LIBRARY_PATH="$RT_DIR" timeout -k 5 60 ./d.bin </dev/null ) >"$T/$M.out" 2>&1
  fi
  if [ -n "${FAIL_ONCE:-}" ] && [ "$M" = m3 ]; then sed -i 's/sum 124/sum 123/' "$T/$M.out"; fi
  if diff -u "$T/d.ref" "$T/$M.out" >"$T/$M.diff"; then echo "  $M PASS ($(wc -l <"$T/d.ref") line(s) byte-identical to fpc -Miso)"
  else echo "  $M FAIL ($(grep -c '^[-+][^-+]' "$T/$M.diff") diff lines)"; sed -n '1,10p' "$T/$M.diff" | sed 's/^/      /'; RC=1; fi
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a two-dimensional array reads and writes the same through x[i][j] as through x[i,j], in both modes"
else echo "GATE FAIL(1) [$G]: the two spellings of a two-dimensional subscript are not the same access (examined 2 modes)"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
