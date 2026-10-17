#!/bin/bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_pas_set_constructor_takes_a_subrange_member.sh -- row pascal-set-constructor-does-not-take-a-subrange-member
# (coo, 2026-09-12; ISO 7185 6.7.1 member-designator). ['A'..'Z'] was a parse error: the constructor took only single
# expressions. The grammar now has set_member (expression | expression .. expression) and the runtime a Pascal-own
# __pas_setrange(lo, hi) beside __pas_set in the by-name chain; members union through __pas_setuni. The witness covers
# literal char and integer ranges, an enum range, a variable-bound range added by union, mixed members, membership
# counts, subset, intersection with the empty set, and an empty range (hi < lo). Expected lines cut from fpc 3.2.2
# -Miso on 2026-09-12. Hermetic: the oracle is never called. P5's pcom.pas:930 is the road this opens.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SCRIP="${SCRIP:-$S4E/SCRIP/scrip}"
RT_DIR="${RT_DIR:-$(cd "$(dirname "$0")/../../SCRIP/out" && pwd)}"
. "$(dirname "$0")/lib_gate.sh"
gate_require_exec "$SCRIP" "the scrip compiler"
gate_require "$RT_DIR/libscrip_rt.so" "the runtime shared object out/libscrip_rt.so"
W=$(mktemp -d) || exit 2; trap 'rm -rf "$W"' EXIT
cat > "$W/g.pas" <<'PAS'
program setrange;
type sym = (a, b, c, d, e, f);
var letters: set of char; nums: set of 0..20; syms: set of sym; lo, hi, i: integer; ch: char; n: integer;
begin
  letters := ['A'..'Z', 'x'];
  nums := [1..3, 7, 9..10];
  syms := [b..d, f];
  lo := 12; hi := 15; nums := nums + [lo..hi];
  n := 0; for ch := 'A' to 'z' do if ch in letters then n := n + 1; writeln(n);
  n := 0; for i := 0 to 20 do if i in nums then n := n + 1; writeln(n);
  if (b in syms) and (c in syms) and not (a in syms) and not (e in syms) and (f in syms) then writeln('syms ok') else writeln('syms bad');
  if [2..3] <= nums then writeln('sub ok') else writeln('sub bad');
  if ['a'..'c'] * letters = [] then writeln('empty ok') else writeln('empty bad');
  hi := 2; if [lo..hi] = [] then writeln('rev ok') else writeln('rev bad')
end.
PAS
cat > "$W/want" <<'REF'
         27
         10
syms ok
sub ok
empty ok
rev ok
REF
PASS=0; FAIL=0
m3=$(timeout -k 5 8s "$SCRIP" --run "$W/g.pas" < /dev/null 2>&1)
if [ "$m3" = "$(cat "$W/want")" ]; then echo "PASS m3"; PASS=$((PASS+1)); else echo "FAIL m3"; diff <(echo "$m3") "$W/want" | head; FAIL=$((FAIL+1)); fi
( cd "$W" && timeout -k 5 8s "$SCRIP" --compile g.pas < /dev/null > g.s 2>/dev/null && gcc -c g.s -o g.o 2>/dev/null && gcc g.o -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$(cd "$RT_DIR" && pwd)" -o g.bin 2>/dev/null ) || { echo "FAIL m4 (build)"; FAIL=$((FAIL+1)); }
if [ -x "$W/g.bin" ]; then m4=$(cd "$W" && timeout -k 5 8s ./g.bin < /dev/null 2>&1)
  if [ "$m4" = "$(cat "$W/want")" ]; then echo "PASS m4"; PASS=$((PASS+1)); else echo "FAIL m4"; diff <(echo "$m4") "$W/want" | head; FAIL=$((FAIL+1)); fi; fi
echo "pas-set-constructor-takes-a-subrange-member: PASS=$PASS FAIL=$FAIL (population: 1 program x 2 modes, 6 expected lines each)"
if [ $FAIL -eq 0 ] && [ $PASS -eq 2 ]; then echo "GATE PASS(0) [pas_set_constructor_takes_a_subrange_member]: 2/2 modes"; exit 0; else echo "GATE RED [pas_set_constructor_takes_a_subrange_member]: $FAIL red of 2"; exit 1; fi
