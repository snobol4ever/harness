#!/usr/bin/env bash
# test_gate_pl_swi_a_meta_argument_qualification_collapses_a_chain_as_swipl_does.sh -- a meta argument of spec ':' that arrives already qualified is collapsed the way swipl
# 9.0.4 collapses it (CEO-2081, ARCH-PROLOG-DATABASE section 6 rule 4; SWI core/test_meta_predicate qualify#6). swipl drops the OUTER qualifier when it is an atom and the inner term
# is itself _:_ (the inner first argument may be an atom, a variable, a number, a compound or a list), repeats, and stops when the outer qualifier is not an atom: m2:m1:x gives
# m1:x, m2:42:x gives 42:x, m2:f(a):x gives f(a):x, m2:1:2:x gives 1:2:x, m2:m3:_:x gives _:x, while 1:2:x and 1:m3:x stay. Before the cure '$mq_inner' continued only while the INNER
# qualifier was an atom, so the number, compound, list and variable cases kept the outer module. Double-quoted text is left out on purpose: its default flag differs by dialect and
# is not this rule. The probe is cut from swipl in THIS run (swipl_bin); SCRIP's m3 and m4 are compared byte for byte; the self-test feeds the comparison a corrupted reference.
set -u
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP"; exit 2; }
BIN="${SCRIP_BIN:-$ROOT/scrip}"; LIB="$(dirname "$BIN")/out"; [ -d "$LIB" ] || LIB="$ROOT/out"
[ -x "$BIN" ] || { echo "GATE REFUSED(2) [$G]: no $BIN -- run make"; exit 2; }
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$G" "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" || exit 2
command -v gcc >/dev/null 2>&1 || { echo "GATE REFUSED(2) [$G]: gcc absent"; exit 2; }
. "$HERE/lib_oracle_flags.sh" || { echo "GATE REFUSED(2) [$G]: lib_oracle_flags.sh unloadable -- the one accessor of the oracle binaries"; exit 2; }
SW="$(swipl_bin)"; [ -x "$SW" ] || { echo "GATE REFUSED(2) [$G]: no swipl at $SW -- the oracle (swipl_bin)"; exit 2; }
W="$(mktemp -d "${TMPDIR:-/tmp}/plmqchain.XXXXXX")" || { echo "GATE REFUSED(2) [$G]: no workdir"; exit 2; }; trap 'rm -rf "$W"' EXIT
cat > "$W/z.pl" <<'EOF'
:- meta_predicate m(:, -).
m(X, X).
w(G) :- m(G, X), writeq(X), nl.
open_kept :- m(m1:Y, X), X = m1:Y1, ( Y1 == Y -> writeln(open_inner_kept) ; writeln(open_inner_lost) ).
var_kept(G, Tag) :- m(G, X), X = V:x, ( var(V) -> format("~w: var qualifier kept~n", [Tag]) ; format("~w: var qualifier lost~n", [Tag]) ).
main :- w(x), w(m1:x), w(m2:m1:x), w(m2:m3:m1:x), w(m2:42:x), w(42:x), w(m2:f(a):x), w(m2:m3:f(a):x), w(m2:1:2:x), w(1:2:x), w(1:m3:x), w(m2:42:m3:x),
    w(m2:(42:x)), w(m2:[a]:x), w(m2:[]:x), w(m2:1.5:x), w(m2:f(1):m3:x), open_kept, var_kept(m2:_:x, one), var_kept(m2:m3:_:x, two), var_kept(_:x, three).
:- initialization(main).
EOF
timeout -k 5 60 "$SW" -q -t halt "$W/z.pl" < /dev/null > "$W/ref" 2> "$W/ref.err"
[ "$(grep -c . "$W/ref")" -ge 21 ] || { echo "GATE REFUSED(2) [$G]: swipl did not answer the probe as designed ($(head -c 200 "$W/ref.err"))"; head -30 "$W/ref"; exit 2; }
grep -q '^42:x$' "$W/ref" && grep -q '^f(a):x$' "$W/ref" && grep -q '^1:2:x$' "$W/ref" || { echo "GATE REFUSED(2) [$G]: swipl's reference lacks the number, compound and chain answers this gate is about"; head -30 "$W/ref"; exit 2; }
timeout -k 5 120 "$BIN" "$W/z.pl" < /dev/null > "$W/m3" 2>&1
"$BIN" --compile --out="$W/z.s" "$W/z.pl" < /dev/null > "$W/c.err" 2>&1 || { echo "GATE REFUSED(2) [$G]: the witness does not compile ($(head -c 160 "$W/c.err"))"; exit 2; }
gcc -o "$W/z.bin" "$W/z.s" -L"$LIB" -lscrip_rt -Wl,-rpath,"$LIB" -lm -lpthread > "$W/link.err" 2>&1 || { echo "GATE REFUSED(2) [$G]: the witness does not link ($(head -c 160 "$W/link.err"))"; exit 2; }
timeout -k 5 60 "$W/z.bin" < /dev/null > "$W/m4" 2>&1
sed '1s/.*/corrupted/' "$W/ref" > "$W/z.bad"
if cmp -s "$W/m3" "$W/z.bad"; then echo "GATE REFUSED(2) [$G]: the comparison accepted a corrupted reference -- the gate could not fail"; exit 2; fi
bad=0
for m in m3 m4; do
  if cmp -s "$W/$m" "$W/ref"; then echo "  ok  $m: the $(grep -c . "$W/ref") meta-argument qualification answers as swipl"; else echo "  RED $m: output differs from swipl:"; diff "$W/ref" "$W/$m" | head -12; bad=1; fi
done
TREE="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo '?')$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)"
if [ "$bad" = 0 ]; then echo "GATE PASS(0) [$G]: 2 mode(s) (SCRIP $TREE)"; exit 0; fi
echo "GATE RED(1) [$G]: see the RED modes above (SCRIP $TREE)"; exit 1
