#!/usr/bin/env bash
# test_gate_pl_call_n_with_a_variable_closure_and_a_compound_argument_hands_the_later_arguments_over_as_swipl.sh -- call(G, p(X, Y), D, H, K) with G a clause
# variable builds p(X, Y) in an argument position and then passes D, H and K. The compound-building node carves 64 bytes, so its operand is wider than one cell;
# x86_zop resolved a later sibling's slot as a word inside that wide carve (the first operand to hit won, exact slots were not preferred), and the callee read
# the compound's own words where D, H and K were: r(g, p(1,2), p(1,2), 1, 2) for r(g, p(1,2), dd, hh, kk). It broke every program that builds a structure in
# the arguments of call/N with a variable closure and passes more arguments after it (ProRosetta minesweeper-game: map_grid_row, CEO-1926). The probe is cut
# from swipl in THIS run (swipl_bin); SCRIP's m3 and m4 are compared byte for byte; the self-test feeds the comparison a corrupted reference.
set -u
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP"; exit 2; }
BIN="${SCRIP_BIN:-$ROOT/scrip}"; LIB="$(dirname "$BIN")/out"; [ -d "$LIB" ] || LIB="$ROOT/out"
[ -x "$BIN" ] || { echo "GATE REFUSED(2) [$G]: no $BIN -- run make"; exit 2; }
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$G" "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" || exit 2
command -v gcc >/dev/null 2>&1 || { echo "GATE REFUSED(2) [$G]: gcc absent"; exit 2; }
. "$HERE/lib_oracle_flags.sh" || { echo "GATE REFUSED(2) [$G]: lib_oracle_flags.sh unloadable -- the one accessor of the oracle binaries"; exit 2; }
SW="$(swipl_bin)"; [ -x "$SW" ] || { echo "GATE REFUSED(2) [$G]: no swipl at $SW -- the oracle (swipl_bin)"; exit 2; }
W="$(mktemp -d "${TMPDIR:-/tmp}/plcalln.XXXXXX")" || { echo "GATE REFUSED(2) [$G]: no workdir"; exit 2; }; trap 'rm -rf "$W"' EXIT
cat > "$W/z.pl" <<'EOF'
r(A, B, C, D, E) :- format("r5: ~q | ~q | ~q | ~q | ~q~n", [A, B, C, D, E]).
r(A, B, C, D) :- format("r4: ~q | ~q | ~q | ~q~n", [A, B, C, D]).
a1(G, X, Y, D, H, K) :- call(G, p(X, Y), D, H, K).
a2(G, X, D, H, K) :- call(G, p(X), D, H, K).
a3(G, X, Y, D, H) :- call(G, p(X, Y), D, H).
a4(G, X, Y, D, H, K) :- call(G, [X, Y], D, H, K).
a5(G, X, Y, D, H, K) :- call(G, f(X, Y, X), D, H, K).
a6(G, X, D, H, K) :- call(G, X, D, H, K).
b1(X, Y, D, H, K) :- call(r(g), p(X, Y), D, H, K).
t :- a1(r(g), 1, 2, dd, hh, kk), a2(r(g), 1, dd, hh, kk), a3(r(g), 1, 2, dd, hh), a4(r(g), 1, 2, dd, hh, kk), a5(r(g), 1, 2, dd, hh, kk),
     a6(r(g), 1, dd, hh, kk), b1(1, 2, dd, hh, kk).
:- initialization(t).
EOF
timeout -k 5 30 "$SW" -q -t halt "$W/z.pl" < /dev/null > "$W/ref" 2> "$W/ref.err"
[ "$(grep -c . "$W/ref")" -eq 7 ] || { echo "GATE REFUSED(2) [$G]: swipl did not answer the 7 probe lines ($(head -c 160 "$W/ref.err"))"; exit 2; }
timeout -k 5 60 "$BIN" "$W/z.pl" < /dev/null > "$W/m3" 2>&1
"$BIN" --compile --out="$W/z.s" "$W/z.pl" < /dev/null > "$W/c.err" 2>&1 || { echo "GATE REFUSED(2) [$G]: the witness does not compile ($(head -c 160 "$W/c.err"))"; exit 2; }
gcc -no-pie -o "$W/z.bin" "$W/z.s" -L"$LIB" -lscrip_rt -Wl,-rpath,"$LIB" -lm -lpthread > "$W/link.err" 2>&1 || { echo "GATE REFUSED(2) [$G]: the witness does not link ($(head -c 160 "$W/link.err"))"; exit 2; }
timeout -k 5 30 "$W/z.bin" < /dev/null > "$W/m4" 2>&1
sed '1s/.*/corrupted/' "$W/ref" > "$W/z.bad"
if cmp -s "$W/m3" "$W/z.bad"; then echo "GATE REFUSED(2) [$G]: the comparison accepted a corrupted reference -- the gate could not fail"; exit 2; fi
bad=0
for m in m3 m4; do
  if cmp -s "$W/$m" "$W/ref"; then echo "  ok  $m: the 7 call/N probes hand over every argument as swipl does"; else echo "  RED $m: output differs from swipl:"; diff "$W/ref" "$W/$m" | head -8; bad=1; fi
done
TREE="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo '?')$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)"
if [ $bad -eq 0 ]; then echo "GATE PASS(0) [$G]: call/N with a variable closure, a compound or list built in an argument position and three more arguments after it passes every argument as swipl does, in both modes (self-test: a corrupted reference is seen; tree SCRIP=$TREE)"; exit 0; fi
echo "GATE FAIL(1) [$G]: call/N with a variable closure and a structure built in an argument position hands a later argument wrong in one mode (tree SCRIP=$TREE)"; exit 1
