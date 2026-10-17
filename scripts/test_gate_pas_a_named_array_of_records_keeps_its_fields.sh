#!/usr/bin/env bash
# test_gate_pas_a_named_array_of_records_keeps_its_fields.sh -- a variable of a NAMED array-of-record type reads back its fields
#
# MEASURED 2026-09-23 by hq_pascal on SCRIP 70bea131d, both modes, row pascal-all-test-suites-of-the-language-read-100-percent-on-the-
# suite-table-the-home-stretch. A WRONG ANSWER, found writing a control for the 6.4.1 gate: with type row = array [1..3] of pt (pt a
# record), var r: row; r[2].v := 7; writeln(r[2].v:1) printed NOTHING in m3 at rc=0 while fpc -Miso prints 7, and var r: array
# [1..3] of pt printed 7. Cause, by diffing the two ASTs: simple_type's IDENT arm returned a named ARRAY type's bound and never loaded
# its element record's fields into the pending field list (pas_rectype_to_pend ran only in the non-array arm), so var_decl saw no
# fields, skipped the flattened array-of-record registration, and r[2].v became a generic TT_FIELD that reads nothing. type_decl had
# already registered row with pt's fields, so the arm now loads them too; the named form then builds the IDENTICAL AST to the inline
# form. No suite cell moved (no PAT, FPC, rungs or benchmark program declares a variable through a named array-of-record type).
# ⛔ NAMED, NOT CURED HERE: a record nested inside an arrayed record (r[2].b.x) still reads back empty -- its own landing.
#
# ARMS: one program cut LIVE from fpc -Miso and required byte-identical in BOTH modes (m4 compiles, links and runs): a two-field record
# in a named array type and in an alias of it, filled in a loop and read back. It FAILS on the parent tree. FAIL_ONCE=1 corrupts the
# ref to prove the arm can fail.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- every arm's ref is CUT FROM THE ORACLE"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0; N=0
m4_run() { M4O=$( cd "$T" && timeout -k 5 20s "$SCRIP" --compile -o "$T/w.s" "$1" </dev/null 2>&1 ); M4RC=$?
  if [ "$M4RC" = 0 ]; then
    ( cd "$T" && cc -m64 -no-pie w.s -o w -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: $1 compiled but would not link -- cannot grade the m4 arm"; exit 2; }
    M4O=$( cd "$T" && timeout -k 5 20s ./w </dev/null 2>&1 ); M4RC=$?
  fi; }
cat > "$T/ok.pas" <<'PAS'
program namedarr(output);
type pt = record v: integer; c: char end;
     row = array [1..4] of pt;
     table = row;
var r: row; t: table; i, s: integer;
begin
  for i := 1 to 4 do begin r[i].v := i * i; r[i].c := chr(ord('a') + i) end;
  s := 0; for i := 1 to 4 do s := s + r[i].v;
  t[3].v := 30; t[3].c := 'z';
  writeln(s:1, ' ', r[2].v:1, ' ', r[4].c, ' ', t[3].v:1, ' ', t[3].c)
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
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a named array-of-record variable reads back every field byte-identical to fpc -Miso in both modes"
else echo "GATE FAIL(1) [$G]: examined $N oracle-cut arms"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
