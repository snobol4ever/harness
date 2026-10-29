#!/usr/bin/env bash
# test_gate_pas_a_char_code_literal_is_a_char.sh -- #n and #$h are character literals of ordinal n, #0 included (FPC)
#
# MEASURED 2026-09-25 by hq_pascal, both modes, row pascal-every-suite-to-100-under-nonet-ceo-1266. pascal.l lexed #n into a one-byte C
# string returned as STRINGCONST, and every grammar site decides "char, not string" by strlen == 1, so #0 -- a NUL, strlen 0 -- became
# the empty string: c := #0 was refused as a string assigned to a char (6.4.6), and x <> #0 compared a char with ''. FPC
# test_tparray10 halted at its unone[3] <> #0 check with every element right (0 0 65 66 67 68 0 0 0); with #0 spelled chr(0) it matched
# its ref. NO BRACKET FOR THIS DEFECT: the monitor stops that program earlier, at step 7 (s := pacone stores the packed array's
# internal form into a string -- a separate defect whose value never reaches output there), so it was found by ablation. The cure: #n
# and #$h lex to a CHARCODE token carrying the ordinal, and the four sites that take a char literal (a factor, a constant definition,
# a scalar constant, a subrange's low bound) take it; the two new shift/reduce conflicts are the exact twins of STRINGCONST's, resolved
# by shift to the specific rule.
#
# ARMS: one program cut LIVE from fpc -Miso and required byte-identical in BOTH modes: #0 assigned and compared, #n and #$h in a
# constant definition, a subrange type #0..#31, array elements, and case labels #0 #32 #64 #$60. It FAILS on the parent (refused at
# compile). OPEN EDGE, NOT GRADED HERE: low/high of a char subrange TYPE read 0/255 and print as integers (on the parent too).
# FAIL_ONCE=1 corrupts the ref to prove it can fail.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- every arm's expectation is CUT FROM THE ORACLE"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0
run_mode() { local m="$1" p="$2"
  if [ "$m" = m3 ]; then ( cd "$T" && timeout -k 5 20s "$SCRIP" --run "$p.pas" </dev/null 2>"$T/$p.$m.err" | head -c 8000 >"$T/$p.$m.out"; exit "${PIPESTATUS[0]}" ); return $?; fi
  ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile --out="$T/$p.s" "$p.pas" </dev/null >/dev/null 2>&1 ) || { echo "  ⛔ arm $p m4: did not compile"; return 99; }
  ( cd "$T" && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: arm $p compiled but would not link"; exit 2; }
  ( cd "$T" && timeout -k 5 20s "./$p.m4" </dev/null 2>"$T/$p.$m.err" | head -c 8000 >"$T/$p.$m.out"; exit "${PIPESTATUS[0]}" ); return $?; }
cat > "$T/cc.pas" <<'PAS'
program cc(output);
const nul = #0; bell = #7; big = #$41;
type ctl = #0..#31;
var a: array[1..4] of char; c: char; k: ctl; i: integer;
begin
  c := #0;
  writeln(ord(c), ' ', ord(nul), ' ', ord(bell), ' ', big, ' ', #66, #$43);
  if c = #0 then writeln('c = #0') else writeln('c <> #0');
  if c = chr(0) then writeln('c = chr(0)') else writeln('c <> chr(0)');
  a[1] := #0; a[2] := #$30; a[3] := #57; a[4] := nul;
  for i := 1 to 4 do write(ord(a[i]), ' '); writeln;
  if (a[1] = #0) and (a[4] = #0) and (a[2] < a[3]) then writeln('array ok');
  k := #10; writeln('k ', ord(k), ' ', ord(succ(k)));
  for i := 0 to 3 do
  begin
    c := chr(i * 32);
    case c of
      #0: writeln(i, ' is nul');
      #32: writeln(i, ' is space');
      #64: writeln(i, ' is at');
      #$60: writeln(i, ' is grave')
    end
  end
end.
PAS
( cd "$T" && "$FPC" -Miso -v0 -o"cc.fpc" cc.pas >/dev/null 2>&1 && timeout -k 5 20s ./cc.fpc | head -c 8000 ) > "$T/cc.want" 2>&1
[ -s "$T/cc.want" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle produced no output for arm cc"; exit 2; }
if [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/cc.want"; fi
for m in m3 m4; do
  run_mode $m cc; rc=$?
  if [ "$rc" = 0 ] && cmp -s "$T/cc.want" "$T/cc.$m.out"; then echo "  arm cc $m: byte-identical to fpc -Miso"
  else echo "  ⛔ arm cc $m FAILED: rc=$rc"; echo "      want: $(tr '\n' '|' < "$T/cc.want" | cut -c1-400)"; echo "      got : $(tr '\n' '|' < "$T/cc.$m.out" | cut -c1-400)"
       echo "      err : $(tr '\n' '|' < "$T/cc.$m.err" | cut -c1-200)"; RC=1; fi
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: #n and #\$h are character literals, #0 included (byte-identical to fpc -Miso), both modes"
else echo "GATE FAIL(1) [$G]: examined 1 oracle-cut arm in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
