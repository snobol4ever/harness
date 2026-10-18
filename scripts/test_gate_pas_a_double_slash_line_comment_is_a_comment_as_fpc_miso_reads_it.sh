#!/usr/bin/env bash
# test_gate_pas_a_double_slash_line_comment_is_a_comment_as_fpc_miso_reads_it.sh -- the oracle, fpc -Miso, reads // to the end of the line as a comment (its
# scanner does so in every mode). MEASURED 2026-10-09 by the ceo grading the ISO-dialect Pascal downloads (CEO-1589): ten Rosetta solutions that fpc -Miso
# builds stopped at "pascal parse error ... syntax error" on a // comment (largest-proper-divisor-of-n-1, lucas-lehmer-test-1, arithmetic-numbers,
# roots-of-unity, both comb sorts, square-but-not-cube, strange-numbers, sum-multiples-of-3-and-5-2, strong-and-weak-primes). CAUSE: pascal.l had no rule
# for it, so // lexed as two RDIV tokens. CURE: pascal.l reads "//"[^\n]* as a comment (longer than "/", so flex prefers it; a string literal and the two
# block comments lex by their own rules first, so // inside them is untouched), pascal.lex.c regenerated with it.
# ARMS, both modes, cut LIVE from fpc -Miso: (1) places -- after the heading, inside an expression across a line break, after a statement, inside a string,
# inside both block comments; (2) only -- a line that is nothing but a comment, between declarations and at the end. FAIL_ONCE=1 corrupts arm 2's ref.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- every arm's expectation is CUT FROM THE ORACLE"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0; N=0
run() { local m="$1" p="$2"
  if [ "$m" = m3 ]; then ( cd "$T" && timeout -k 5 20s "$SCRIP" --run "$p.pas" <"$T/$p.in" >"$T/o" 2>"$T/e" ); return $?; fi
  ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile -o "$T/$p.s" "$p.pas" </dev/null >/dev/null 2>&1 && cc "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4: compile or link failed"; return 99; }
  ( cd "$T" && timeout -k 5 20s "./$p.m4" <"$T/$p.in" >"$T/o" 2>"$T/e" ); return $?; }
fpcrun() { ( cd "$T" && "$FPC" -Miso -v0 -o"$1.fpc" "$1.pas" >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 20s "./$1.fpc" <"$T/$1.in" >"$T/$1.want" 2>/dev/null ) || { echo "⛔ GATE REFUSE(2) [$G]: the fpc -Miso run of $1 failed"; exit 2; }; [ -s "$T/$1.want" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle printed nothing for $1"; exit 2; }; }
cat > "$T/places.pas" <<'PAS'
program places(output); // the heading
var x: integer; s: packed array [1..4] of char;
begin
  x := 6 // a comment inside an expression
    * 7; // and after a statement
  s := 'a//b'; { // inside a brace comment }
  writeln(x, ' ', s) (* // inside a paren comment *)
end.
PAS
: > "$T/places.in"
cat > "$T/only.pas" <<'PAS'
program only(output);
// a line that is only a comment
const n = 3;
// another, between declarations
var i: integer;
begin for i := 1 to n do writeln(i * i) end.
// and one after the end
PAS
: > "$T/only.in"
for p in places only; do fpcrun "$p"; done
[ "${FAIL_ONCE:-0}" = 1 ] && printf 'corrupted\n' >> "$T/only.want"
for p in places only; do
  for m in m3 m4; do
    N=$((N+1)); run "$m" "$p"; rc=$?
    if cmp -s "$T/$p.want" "$T/o"; then echo "  ✅ $p $m equals fpc -Miso (rc=$rc)"
    else RC=1; echo "  ⛔ $p $m differs from fpc -Miso (rc=$rc): $(head -c 160 "$T/e" | tr '\n' ' ') $(diff "$T/$p.want" "$T/o" | head -3 | tr '\n' '|')"; fi
  done
done
echo "population: $N arms (2 programs x 2 modes), every expectation cut live from fpc -Miso"
[ "$RC" = 0 ] && { echo "✅ GATE PASS [$G]: a // line comment is a comment as fpc -Miso reads it, in both modes"; exit 0; }
echo "⛔ GATE FAIL [$G]: a // line comment is not read as fpc -Miso reads it"; exit 1
