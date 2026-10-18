#!/usr/bin/env bash
# test_gate_pas_array_field_elements_keep_their_declared_width.sh -- an ARRAY field of a record keeps its declared element type, not a byte
#
# MEASURED 2026-09-13 by the coo on origin 71b32337f, both modes, while writing the witness for the heap-root row (NOT that
# row, and not caused by it): a record reached through a pointer whose field is an ARRAY OF INTEGER stored every element
# through the char-indexed field path, so p^.ints[i] := i * 300 read back 255 for every i, an array of real read back the
# ordinals of the characters its values had been truncated to, and one element of a six-element array went missing
# entirely. The parser knew a record field was a PACKED ARRAY OF CHAR (fldca) and knew it was a plain char (fldchar), but
# it had no record of a field that is an array of anything ELSE, so every such field fell to the byte path by default.
#
# Cure: the record-type table carries a third field shape, the non-char array (fldna, with its declared low bound); the
# selector marks such a field, an index into it becomes a SUB-ELEMENT index biased by the declared low bound, and both
# ends route through the sub-element storage that was already built in the runtime and had no caller -- __pas_nrec_get to
# read, __pas_nrec_deref_set through a pointer and __pas_nrec_update through a record variable to write. Packed arrays of
# char keep the byte path they had.
#
# ARMS: one program in both modes, byte-identical to fpc -Miso -- an array of integer holding values past 255 read back
# element by element and summed, an array of real read back and summed, a packed array of char printed whole, a nested
# record field, and a second record linked to the first so a field is read through a second pointer hop. FAIL_ONCE=1
# corrupts the first line to prove the diff arm trips.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- the ref is CUT FROM THE ORACLE, never pinned by hand"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/a.pas" <<'PAS'
program w(output);
type
  inner = record
    lo: integer;
    hi: integer
  end;
  link = ^node;
  node = record
    ints: array [1..6] of integer;
    reals: array [1..3] of real;
    tag: packed array [1..4] of char;
    sub: inner;
    next: link
  end;
var
  p, q: link;
  i, s: integer;
  t: real;
begin
  new(p);
  for i := 1 to 6 do p^.ints[i] := i * 300;
  p^.reals[1] := 1.5;
  p^.reals[2] := -2.25;
  p^.reals[3] := 1000.125;
  p^.tag := 'abcd';
  p^.sub.lo := 4000;
  p^.sub.hi := -70000;
  p^.next := nil;
  s := 0;
  for i := 1 to 6 do s := s + p^.ints[i];
  write('ints');
  for i := 1 to 6 do write(' ', p^.ints[i]:1);
  writeln(' sum ', s:1);
  t := p^.reals[1] + p^.reals[2] + p^.reals[3];
  writeln('reals ', p^.reals[1]:8:3, p^.reals[2]:8:3, p^.reals[3]:10:3, ' sum ', t:10:3);
  writeln('tag ', p^.tag, ' sub ', p^.sub.lo:1, ' ', p^.sub.hi:1);
  new(q);
  for i := 1 to 6 do q^.ints[i] := 7 - i;
  q^.sub.lo := 1;
  q^.sub.hi := 2;
  q^.next := p;
  write('second');
  for i := 1 to 6 do write(' ', q^.ints[i]:1);
  writeln(' first-again ', q^.next^.ints[6]:1, ' ', q^.next^.sub.hi:1)
end.
PAS
( cd "$T" && "$FPC" -Miso -v0 a.pas >/dev/null 2>&1 && ./a ) > "$T/a.ref" 2>&1
grep -q '^ints 300 600 900 1200 1500 1800 sum 6300$' "$T/a.ref" || { echo "⛔ GATE REFUSE(2) [$G]: the oracle did not produce the integer-array line this gate pins -- the oracle moved: $(head -1 "$T/a.ref")"; exit 2; }
( cd "$T" && timeout -k 5 60 "$SCRIP" --compile -o a.s a.pas </dev/null && gcc a.s -o a.bin -L"$RT_DIR" -lscrip_rt -lm -lpthread ) >/dev/null 2>&1 || { echo "⛔ GATE REFUSE(2) [$G]: the mode-4 witness did not build"; exit 2; }
RC=0
for M in m3 m4; do
  if [ "$M" = m3 ]; then ( cd "$T" && timeout -k 5 60 "$SCRIP" --run a.pas </dev/null ) >"$T/$M.out" 2>&1
  else ( cd "$T" && LD_LIBRARY_PATH="$RT_DIR" timeout -k 5 60 ./a.bin </dev/null ) >"$T/$M.out" 2>&1
  fi
  if [ -n "${FAIL_ONCE:-}" ] && [ "$M" = m3 ]; then sed -i '1s/^ints 300/ints 255/' "$T/$M.out"; fi
  if diff -u "$T/a.ref" "$T/$M.out" >"$T/$M.diff"; then echo "  $M PASS ($(wc -l <"$T/a.ref") lines byte-identical to fpc -Miso)"
  else echo "  $M FAIL ($(grep -c '^[-+][^-+]' "$T/$M.diff") diff lines)"; sed -n '1,10p' "$T/$M.diff" | sed 's/^/      /'; RC=1; fi
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: integer, real and packed-char array fields of a record each keep their declared element type in both modes"
else echo "GATE FAIL(1) [$G]: an array field of a record does not keep its declared element type (examined 2 modes)"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
