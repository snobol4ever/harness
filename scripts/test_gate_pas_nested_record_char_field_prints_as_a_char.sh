#!/usr/bin/env bash
# test_gate_pas_nested_record_char_field_prints_as_a_char.sh -- a CHAR field of a NESTED record is a char, not its ordinal
#
# MEASURED 2026-09-13 by the coo on origin c24f64cc1, both modes, while extending the witness for the array-field row
# (the same family, a different site): p^.sub.tag := 'q'; writeln(p^.sub.tag) printed 113 where fpc -Miso prints q, and
# r.sub.tag the same through a record variable. A char field at the TOP level of a record was already right -- q.c and
# p^.c both print their character -- so the loss is specific to the nested hop.
#
# THE MECHANISM, and it is two halves that had to be read together:
#   1. pas_nested_field_resolve built the nested selector and marked only its ENUM type and the nrec shape. The one-level
#      resolver marks three more things on the node it builds -- fldca (packed array of char), fldna (array of anything
#      else) and fldchar -- and the nested resolver marked none of them, so a nested field arrived downstream with its
#      declared type erased.
#   2. Marking it was not enough: at `factor: selector` the nrec rewrite CONSUMES the selector node and hands back a
#      fresh __pas_nrec_get call, so any mark on the consumed node dies with it. The mark has to be carried onto the
#      node that survives.
# ⛔ WHAT WAS TRIED AND REVERTED, because it is the obvious cure and it is wrong: wrapping the read in __pas_chr at that
# site. The writeln/write argument path already wraps a char expression itself, so the two wraps compose to chr(chr(n)),
# __pas_chr clamps a non-integer to 0, and the witness prints an EMPTY LINE instead of a wrong number -- a defect that
# looks less like a defect. Carrying the mark lets the one existing wrap do its job exactly once.
#
# ARMS: one program, both modes, byte-identical to fpc -Miso -- a nested char field through a POINTER and through a
# record VARIABLE, a top-level char field beside each (the half that already worked, so a regression there is visible),
# a nested integer and a nested real (the neighbours the mark must not disturb), and ord() of a nested char to prove the
# value itself was never wrong, only its rendering. FAIL_ONCE=1 corrupts the first line to prove the diff arm trips.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- the ref is CUT FROM THE ORACLE, never pinned by hand"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/n.pas" <<'PAS'
program nestedchar(output);
type
  inner = record
    n: integer;
    tag: char;
    amt: real
  end;
  link = ^outer;
  outer = record
    c: char;
    sub: inner
  end;
var
  p: link;
  r: outer;
begin
  new(p);
  p^.c := 'x';
  p^.sub.n := 4096;
  p^.sub.tag := 'q';
  p^.sub.amt := -1.25;
  r.c := 'y';
  r.sub.n := -70000;
  r.sub.tag := 'w';
  r.sub.amt := 2.5;
  writeln('ptr ', p^.c, p^.sub.tag, ' ', p^.sub.n:1, ' ', p^.sub.amt:8:3);
  writeln('var ', r.c, r.sub.tag, ' ', r.sub.n:1, ' ', r.sub.amt:8:3);
  writeln('ord ', ord(p^.sub.tag):1, ' ', ord(r.sub.tag):1);
  if p^.sub.tag = 'q' then writeln('cmp equal') else writeln('cmp differ')
end.
PAS
( cd "$T" && "$FPC" -Miso -v0 n.pas >/dev/null 2>&1 && ./n ) > "$T/n.ref" 2>&1
grep -q '^ptr xq 4096' "$T/n.ref" || { echo "⛔ GATE REFUSE(2) [$G]: the oracle did not produce the nested-char line this gate pins -- the oracle moved: $(head -1 "$T/n.ref")"; exit 2; }
( cd "$T" && timeout -k 5 60 "$SCRIP" --compile -o n.s n.pas </dev/null && gcc n.s -o n.bin -L"$RT_DIR" -lscrip_rt -lm -lpthread ) >/dev/null 2>&1 || { echo "⛔ GATE REFUSE(2) [$G]: the mode-4 witness did not build"; exit 2; }
RC=0
for M in m3 m4; do
  if [ "$M" = m3 ]; then ( cd "$T" && timeout -k 5 60 "$SCRIP" --run n.pas </dev/null ) >"$T/$M.out" 2>&1
  else ( cd "$T" && LD_LIBRARY_PATH="$RT_DIR" timeout -k 5 60 ./n.bin </dev/null ) >"$T/$M.out" 2>&1
  fi
  if [ -n "${FAIL_ONCE:-}" ] && [ "$M" = m3 ]; then sed -i '1s/^ptr xq/ptr x113/' "$T/$M.out"; fi
  if diff -u "$T/n.ref" "$T/$M.out" >"$T/$M.diff"; then echo "  $M PASS ($(wc -l <"$T/n.ref") lines byte-identical to fpc -Miso)"
  else echo "  $M FAIL ($(grep -c '^[-+][^-+]' "$T/$M.diff") diff lines)"; sed -n '1,10p' "$T/$M.diff" | sed 's/^/      /'; RC=1; fi
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a char field of a nested record renders as its character in both modes, through a pointer and through a record variable"
else echo "GATE FAIL(1) [$G]: a nested record's char field does not render as a char (examined 2 modes)"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
