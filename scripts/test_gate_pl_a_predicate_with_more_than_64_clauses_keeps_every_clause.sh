#!/usr/bin/env bash
# test_gate_pl_a_predicate_with_more_than_64_clauses_keeps_every_clause.sh -- NO FIXED LIMIT A PROGRAM CAN REACH (Lon 2026-09-23, CEO-1210).
# cto 2026-09-27, row prolog-assertz-of-500-distinct-facts-answers-64-and-takes-75-s-a-reachable-cap-and-a-whole-predicate-recompile-per-assert.
# THE DEFECT: emit_chain (src/emitter/emit.cpp) kept the alternation trampolines of a predicate in two fixed tables of 64 labels and CLAMPED
# n_alt to 64, so a predicate of more than 64 clauses -- static in the file, or dynamic through the whole-predicate recompile every assertz
# runs -- silently lost every clause past the 64th: the IR and the emitted bodies carried them, the dispatch never reached them. Bisected by
# clause count on the assertz road (63 -> 63, 64 -> 64, 65 -> 64, 100 -> 64) and reproduced on a static 70-clause predicate (70 -> 64).
# THE CURE: the two tables grow through ct_grow to the graph's n_alts, the same idiom as the function's node and queue buffers.
# THE EXPECTATIONS ARE swipl's (swipl -q, 2026-09-27): witness 1 a static 70-clause predicate, witness 2 a dynamic one filled by 100
# assertz calls; both modes. RED BEFORE on the pre-cure binary, m3 AND m4: witness 1 read 64/none/none/[63,64] and witness 2 read
# 64/none/none/[] -- the first 64 clauses only.
set -u
GATE_NAME=test_gate_pl_a_predicate_with_more_than_64_clauses_keeps_every_clause
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${SCRIP_BIN:-$HERE/../../SCRIP/scrip}"
RT="${RT_DIR:-$(dirname "$SCRIP")/out}"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first"
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
{ echo ':- initialization(main).'
  for i in $(seq 1 70); do echo "g($i, $((i*7)))."; done
  echo 'main :- findall(x, g(_, _), L), length(L, C), write(C), nl, ( g(65, K) -> write(K) ; write(none) ), nl, ( g(70, K2) -> write(K2) ; write(none) ), nl,'
  echo '        findall(N, (g(N, V), V > 440), L2), write(L2), nl, halt.'
} > "$TMPD/static70.pl"
cat > "$TMPD/assertz100.pl" <<'EOP'
:- initialization(main).
:- dynamic(f/2).
fill(0) :- !.
fill(N) :- K is N * 7, assertz(f(N, K)), N1 is N - 1, fill(N1).
main :- fill(100), findall(x, f(_, _), L), length(L, C), write(C), nl, ( f(1, K) -> write(K) ; write(none) ), nl, ( f(36, K2) -> write(K2) ; write(none) ), nl,
        findall(N, (f(N, V), V < 60), L2), write(L2), nl, halt.
EOP
want_static70='70
455
490
[63,64,65,66,67,68,69,70]'
want_assertz100='100
7
252
[8,7,6,5,4,3,2,1]'
red=0
run_one() {
    local w="$1" mode="$2" want="$3" got rc
    if [ "$mode" = m3 ]; then got="$(timeout -k 5 60 "$SCRIP" "$TMPD/$w.pl" </dev/null 2>"$TMPD/err")"; rc=$?
    else
        timeout -k 5 60 "$SCRIP" --compile --out="$TMPD/$w.s" "$TMPD/$w.pl" </dev/null 2>"$TMPD/err" || refuse "m4 compile of $w failed: $(head -c 160 "$TMPD/err")"
        gcc -m64 -no-pie "$TMPD/$w.s" -o "$TMPD/$w.bin" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2>"$TMPD/err" || refuse "m4 link of $w failed: $(head -c 160 "$TMPD/err")"
        got="$(timeout -k 5 60 "$TMPD/$w.bin" </dev/null 2>"$TMPD/err")"; rc=$?
        rm -f "$TMPD/$w.s" "$TMPD/$w.bin"
    fi
    if [ "$rc" = 0 ] && [ "$got" = "$want" ]; then echo "  ok  $w $mode"
    else echo "  RED $w $mode: rc=$rc out=[$(printf '%s' "$got" | tr '\n' '|')] want [$(printf '%s' "$want" | tr '\n' '|')]"; red=$((red+1)); fi
}
for mode in m3 m4; do
    run_one static70 "$mode" "$want_static70"
    run_one assertz100 "$mode" "$want_assertz100"
done
[ "$red" = 0 ] || { echo "GATE FAIL [$GATE_NAME]: $red arm(s) red -- a predicate past 64 clauses loses its dispatch"; exit 1; }
echo "GATE PASS [$GATE_NAME]: a 70-clause static predicate and a 100-clause asserted one keep every clause, both modes as swipl"
exit 0
