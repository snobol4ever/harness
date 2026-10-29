#!/usr/bin/env bash
# test_gate_pl_reverse_ends_on_a_partial_list_and_duplicate_term_copies_a_bound_cell_as_swipl.sh -- TWO SWI FIDELITY CURES, ONE WITNESS PROGRAM, BOTH MODES (hq_prolog 2026-10-28, ProRosetta lunar-arithmetic).
#
# (1) reverse/2 with an unbound or partial first list and a proper second list ENDS, as swipl's four-argument reverse does (its bound is the second list): `findall(Y, reverse(Y, [a,b]), L)` is [[b,a]].
#     The base prelude's naive reverse found [b,a] and then looked for longer lists for ever; lunar-arithmetic's number_digits/2 calls it that way and ran the heap out at every cap.
# (2) duplicate_term/2 is a REAL copy: a term whose argument cell is a bound variable is copied with the VALUE, so it survives the backtracking that unbinds the original. The base prelude defined it as
#     copy_term/2, which shares a ground term, so library(nb_set) (add_nb_set/3, behind distinct/1,2) stored keys that read as `v(_)` after the next backtrack and then rejected every new key whose hash
#     bucket held one: distinct/1 over compound witnesses lost about two thirds of its solutions past the 14th (lunar-arithmetic's "First 20 distinct even numbers").
# Expected text is cut from swipl 9 in THIS run (swipl_bin), never written here. rc=0 every probe line as swipl in m3 and m4 · rc=1 a divergence · rc=2 REFUSAL (no swipl, no build, swipl silent).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; G=pl_reverse_ends_on_a_partial_list_and_duplicate_term_copies_a_bound_cell_as_swipl
[ -x "$ROOT/scrip" ] || { echo "GATE REFUSED(2) [$G]: no $ROOT/scrip -- run make"; exit 2; }
[ -f "$ROOT/out/libscrip_rt.so" ] || { echo "GATE REFUSED(2) [$G]: out/libscrip_rt.so is not built -- mode 4 cannot link"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$G" "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" || exit 2
command -v gcc >/dev/null 2>&1 || { echo "GATE REFUSED(2) [$G]: gcc absent"; exit 2; }
. "$HERE/lib_oracle_flags.sh" || { echo "GATE REFUSED(2) [$G]: lib_oracle_flags.sh unloadable -- the one accessor of the oracle binaries"; exit 2; }
SW="$(swipl_bin)"; [ -x "$SW" ] || { echo "GATE REFUSED(2) [$G]: no swipl at $SW -- the oracle (swipl_bin)"; exit 2; }
W="$(mktemp -d "${TMPDIR:-/tmp}/plrvdt.XXXXXX")" || { echo "GATE REFUSED(2) [$G]: no workdir"; exit 2; }; trap 'rm -rf "$W"' EXIT
cat > "$W/z.pl" <<'EOF'
:- use_module(library(nb_set)).
t(G) :- catch((G -> true ; write(no)), error(E, _), writeq(E)), nl.
dpc(K, C) :- G =.. [duplicate_term, K, C], call(G).
main :-
    t((findall(Y, reverse(Y, [a,b]), L1), writeq(L1))),
    t((findall(Z-W, limit(3, reverse(Z, W)), L2), numbervars(L2, 0, _), writeq(L2))),
    t((findall(R, reverse([1,2,3], R), L3), writeq(L3))),
    t((X4 = [a|T4], findall(X4-T4, reverse(X4, [p,q,r]), L4), numbervars(L4, 0, _), writeq(L4))),
    t((findall(P, reverse([1,2|P], [z,y,x]), L5), writeq(L5))),
    t((findall(Q, reverse(Q, []), L6), writeq(L6))),
    t((reverse([a,b|_], [c]) -> write(yes) ; write(no))),
    t((H = h(none), K = v(E), ( member(E, [9, 10]), duplicate_term(K, C), nb_linkarg(1, H, C), fail ; arg(1, H, R8), writeq(direct(R8)) ))),
    t((H9 = h(none), K9 = v(E9), ( member(E9, [9, 10]), dpc(K9, C9), nb_linkarg(1, H9, C9), fail ; arg(1, H9, R9), writeq(call_n(R9)) ))),
    t((K1 = v(E1), empty_nb_set(S1), findall(E1, (between(0, 60, E1), add_nb_set(K1, S1, true)), L10), length(L10, N10), writeq(prebuilt_key_set(N10)))),
    t((findall(E2, limit(40, distinct(E2, (between(0, 200, N2), E2 is N2 // 3))), L11), length(L11, N11), last(L11, La), writeq(distinct(N11, La)))),
    t((findall(E3, distinct(v(E3), (between(0, 60, E3))), L12), length(L12, N12), writeq(distinct_compound(N12)))).
:- initialization((main, halt)).
EOF
timeout -k 5 60 "$SW" -q -t halt "$W/z.pl" < /dev/null > "$W/z.ref" 2> "$W/ref.err"
[ "$(grep -c . "$W/z.ref")" -eq 12 ] || { echo "GATE REFUSED(2) [$G]: swipl did not answer the 12 probe lines ($(grep -c . "$W/z.ref") of them; $(head -c 160 "$W/ref.err"))"; exit 2; }
( cd "$W" && timeout -k 5 120 "$ROOT/scrip" z.pl < /dev/null > m3.out 2>&1 ); r3=$?
( cd "$W" && timeout -k 5 120 "$ROOT/scrip" --compile --out=z.s z.pl < /dev/null > c.err 2>&1 && gcc -no-pie -o z.bin z.s -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread > link.err 2>&1 ) || { echo "GATE REFUSED(2) [$G]: the witness does not compile or link in mode 4 ($(head -c 120 "$W/c.err" "$W/link.err" 2>/dev/null | tr '\n' ' '))"; exit 2; }
( cd "$W" && timeout -k 5 120 ./z.bin < /dev/null > m4.out 2>&1 ); r4=$?
bad=0
for m in m3 m4; do rc=$([ $m = m3 ] && echo $r3 || echo $r4)
    if [ "$rc" -eq 0 ] && cmp -s "$W/z.ref" "$W/$m.out"; then echo "  ok  $m: rc=0, the 12 probe lines as swipl"; else echo "  RED $m: rc=$rc, output differs from swipl (swipl line, then SCRIP line):"; diff "$W/z.ref" "$W/$m.out" | head -10; bad=1; fi
done
TREE="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo '?')$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)"
if [ $bad -eq 0 ]; then echo "GATE PASS(0) [$G]: reverse/2 ends on a partial first list and duplicate_term/2 copies a bound cell, so distinct/1,2 keeps every new solution, in both modes as swipl (tree SCRIP=$TREE)"; exit 0; fi
echo "GATE FAIL(1) [$G]: reverse/2 on a partial list or duplicate_term/2 on a bound cell answers differently from swipl in one mode (tree SCRIP=$TREE)"; exit 1
