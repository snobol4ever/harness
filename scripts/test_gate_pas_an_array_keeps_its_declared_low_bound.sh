#!/usr/bin/env bash
# test_gate_pas_an_array_keeps_its_declared_low_bound.sh -- an array is indexed over its declared index-type, not over 0..high
#
# MEASURED 2026-09-25 by hq_pascal, both modes, row pascal-every-suite-to-100-under-nonet-ceo-1266 (landing 2). mk_array_init emitted
# arr_make(high), a block over 0..high, whatever the declared low: array [-2..2] failed on every in-range negative index, an index below
# a positive low (a[4] on [5..9]) was accepted, low(a) of an array folded to 0, a named-subrange or builtin-ordinal index type
# (array [smallint]) never registered as an array at all, and the array's recorded low was read AFTER its element type, so an element
# subrange clobbered it. FPC test_jvm_tsmallintarr is the suite witness. The cure: the 1-D array rule captures its index bounds in two
# mid-rule actions before the element type and restores them after it; arr_make takes (lo, hi); low(a) folds to the recorded low; a
# variable of a named array type takes that type's low; small builtin ordinal index types (at most 65536 values) register.
#
# ARMS: one program cut LIVE from fpc -Miso and required byte-identical in BOTH modes (negative bounds, a positive low with low/high,
# a named-subrange index, a named array type with a negative low, an element subrange beside a 0 low, a char subrange index, a smallint
# index, a local array whose range crosses zero); and one below-low store that must, like fpc -Miso -Cr, print what precedes
# the fault, exit non-zero and name ISO 7185 6.5.3.2. It FAILS on the parent tree. OPEN EDGE, NOT GRADED HERE: an index range whose
# HIGH bound is negative (array [-4..-1]) still does not register, because the frontend's type value uses high >= 0 as its only
# "this is an array" signal (-1 scalar, -2 set, -3 pointer); curing it means replacing that sentinel, a landing of its own. FAIL_ONCE=1 corrupts the ref to prove it can fail.
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
  if [ "$m" = m3 ]; then ( cd "$T" && timeout -k 5 20s "$SCRIP" --run "$p.pas" </dev/null >"$T/$p.$m.out" 2>"$T/$p.$m.err" ); return $?; fi
  ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile -o "$T/$p.s" "$p.pas" </dev/null >/dev/null 2>&1 ) || { echo "  ⛔ arm $p m4: did not compile"; return 99; }
  ( cd "$T" && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: arm $p compiled but would not link"; exit 2; }
  ( cd "$T" && timeout -k 5 20s "./$p.m4" </dev/null >"$T/$p.$m.out" 2>"$T/$p.$m.err" ); return $?; }
cat > "$T/lb.pas" <<'PAS'
program lb(output);
type idx = 3..7; negt = array [-3..3] of integer; small = 1..5;
var n: array [-2..2] of integer; f: array [5..9] of integer; g: array [idx] of integer; t: negt;
    e: array [0..9] of small; c: array ['c'..'f'] of integer; s: array [smallint] of integer; i: integer; ch: char;
procedure loc;
var q: array [-4..1] of integer; k: integer;
begin
  for k := low(q) to high(q) do q[k] := k * k;
  for k := -4 to 1 do write(q[k]:3); writeln(' loc ', low(q):1, ' ', high(q):1)
end;
begin
  for i := -2 to 2 do n[i] := i * 10;
  for i := low(n) to high(n) do write(n[i]:4); writeln(' n ', low(n):1, ' ', high(n):1);
  for i := low(f) to high(f) do f[i] := i; for i := 5 to 9 do write(f[i]:2); writeln(' f ', low(f):1, ' ', high(f):1);
  for i := low(g) to high(g) do g[i] := -i; for i := 3 to 7 do write(g[i]:3); writeln(' g ', low(g):1, ' ', high(g):1);
  for i := -3 to 3 do t[i] := i + 100; for i := low(t) to high(t) do write(t[i]:4); writeln(' t ', low(t):1, ' ', high(t):1);
  for i := 0 to 9 do e[i] := i mod 5 + 1; for i := low(e) to high(e) do write(e[i]:2); writeln(' e ', low(e):1, ' ', high(e):1);
  for ch := 'c' to 'f' do c[ch] := ord(ch); writeln(c['c']:4, c['f']:4, ' c ', ord(low(c)):1, ' ', ord(high(c)):1);
  s[-32768] := 7; s[0] := 8; s[32767] := 9; writeln(s[-32768]:2, s[0]:2, s[32767]:2, ' s ', low(s):1, ' ', high(s):1);
  loc
end.
PAS
cat > "$T/below.pas" <<'PAS'
program below(output);
var f: array [5..9] of integer; i: integer;
begin f[5] := 1; writeln(f[5]:1, ' ', low(f):1); i := 4; f[i] := 2; writeln('after') end.
PAS
( cd "$T" && "$FPC" -Miso -v0 -o"lb.fpc" lb.pas >/dev/null 2>&1 && ./lb.fpc ) > "$T/lb.want" 2>&1
[ -s "$T/lb.want" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle produced no output for arm lb"; exit 2; }
if [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/lb.want"; fi
for m in m3 m4; do
  run_mode $m lb; rc=$?
  if [ "$rc" = 0 ] && cmp -s "$T/lb.want" "$T/lb.$m.out"; then echo "  arm lb $m: byte-identical to fpc -Miso"
  else echo "  ⛔ arm lb $m FAILED: rc=$rc"; echo "      want: $(tr '\n' '|' < "$T/lb.want")"; echo "      got : $(tr '\n' '|' < "$T/lb.$m.out")"
       echo "      err : $(tr '\n' '|' < "$T/lb.$m.err" | cut -c1-160)"; RC=1; fi
done
( cd "$T" && "$FPC" -Miso -Cr -v0 -o"below.fpc" below.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso -Cr would not compile arm below"; exit 2; }
( cd "$T" && timeout -k 5 20s ./below.fpc </dev/null >"$T/below.want" 2>/dev/null ); frc=$?
[ "$frc" -ne 0 ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle ran arm below to rc=0 -- the arm does not carry the range fault it claims"; exit 2; }
for m in m3 m4; do
  run_mode $m below; rc=$?
  if [ "$rc" -ne 0 ] && [ "$rc" -lt 99 ] && cmp -s "$T/below.want" "$T/below.$m.out" && grep -q 'ISO 7185 6\.5\.3\.2' "$T/below.$m.err"; then
       echo "  arm below $m: rc=$rc, stdout = fpc -Miso -Cr before its fault, stderr names 6.5.3.2"
  else echo "  ⛔ arm below $m FAILED: rc=$rc (oracle rc=$frc)"; echo "      want out: $(tr '\n' '|' < "$T/below.want")"; echo "      got  out: $(tr '\n' '|' < "$T/below.$m.out")"; RC=1; fi
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: arrays keep their declared low bound (in-range arm byte-identical to fpc -Miso, below-low arm diagnosed), both modes"
else echo "GATE FAIL(1) [$G]: examined 2 oracle-cut arms in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
