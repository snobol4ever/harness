#!/usr/bin/env bash
# test_gate_pl_the_swi_list_constructor_is_the_bar_bracket_functor_as_swipl.sh -- IN THE SWI DIALECT A LIST CELL IS THE COMPOUND '[|]'(H,T): written in source, built by functor/3 and =../2, and named by functor/3,
# =../2, compound_name_arity/3 and compound_name_arguments/3, as swipl 9 does (hq_prolog 2026-10-28, ProRosetta catamorphism-5 and -6 build their lists as '[|]'(Item,ThreadIn)).
#
# SCRIP's list cell keeps the internal functor '.'; before this, `'[|]'(1,[])` was a plain compound that printed as '[|]'(1,[]) and was no list (length/2 raised a type error), and `functor([a],N,A)`
# answered '.'/2 where swipl answers '[|]'/2. The mapping is the SWI dialect's only (the dialect a program's SWI-only constructs select): the ISO and GNU dialects keep '.' as the list functor.
# Expected text is cut from swipl 9 in THIS run (swipl_bin), never written here. The program names a library so SCRIP reads it as SWI. rc=0 every probe line as swipl in m3 and m4 · rc=1 a divergence ·
# rc=2 REFUSAL (no swipl, no build, swipl silent).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; G=pl_the_swi_list_constructor_is_the_bar_bracket_functor_as_swipl
[ -x "$ROOT/scrip" ] || { echo "GATE REFUSED(2) [$G]: no $ROOT/scrip -- run make"; exit 2; }
[ -f "$ROOT/out/libscrip_rt.so" ] || { echo "GATE REFUSED(2) [$G]: out/libscrip_rt.so is not built -- mode 4 cannot link"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$G" "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" || exit 2
command -v gcc >/dev/null 2>&1 || { echo "GATE REFUSED(2) [$G]: gcc absent"; exit 2; }
. "$HERE/lib_oracle_flags.sh" || { echo "GATE REFUSED(2) [$G]: lib_oracle_flags.sh unloadable -- the one accessor of the oracle binaries"; exit 2; }
SW="$(swipl_bin)"; [ -x "$SW" ] || { echo "GATE REFUSED(2) [$G]: no swipl at $SW -- the oracle (swipl_bin)"; exit 2; }
W="$(mktemp -d "${TMPDIR:-/tmp}/plbarb.XXXXXX")" || { echo "GATE REFUSED(2) [$G]: no workdir"; exit 2; }; trap 'rm -rf "$W"' EXIT
cat > "$W/z.pl" <<'EOF'
:- use_module(library(lists)).
t(G) :- catch((G -> true ; write(no)), error(E, _), writeq(E)), nl.
p('[|]'(H, _), H).
build([], []).
build([X|Xs], R) :- build(Xs, R0), R =.. ['[|]', X, R0].
main :-
    t((X1 = '[|]'(1, []), writeq(X1))),
    t((Y2 =.. ['[|]', 1, []], writeq(Y2))),
    t((functor([a], N3, A3), writeq(N3/A3))),
    t(('[|]'(H4, T4) = [a,b], writeq(H4-T4))),
    t((functor(W5, '[|]', 2), W5 = [_|_], write(list))),
    t(([a,b] =.. L6, writeq(L6))),
    t((compound_name_arity([a], N7, A7), writeq(N7/A7))),
    t((compound_name_arguments([a,b], N8, As8), writeq(N8-As8))),
    t((build([1,2,3], R9), writeq(R9))),
    t(('[|]'(1, '[|]'(2, [])) == [1,2] -> write(yes) ; write(no))),
    t((length('[|]'(1, '[|]'(2, [])), L10), writeq(L10))),
    t((p([a,b], H11), writeq(H11))),
    t((findall(Z, member(Z, '[|]'(x, '[|]'(y, []))), L12), writeq(L12))).
:- initialization((main, halt)).
EOF
timeout -k 5 60 "$SW" -q -t halt "$W/z.pl" < /dev/null > "$W/z.ref" 2> "$W/ref.err"
[ "$(grep -c . "$W/z.ref")" -eq 13 ] || { echo "GATE REFUSED(2) [$G]: swipl did not answer the 13 probe lines ($(grep -c . "$W/z.ref") of them; $(head -c 160 "$W/ref.err"))"; exit 2; }
( cd "$W" && timeout -k 5 120 "$ROOT/scrip" z.pl < /dev/null > m3.out 2>&1 ); r3=$?
( cd "$W" && timeout -k 5 120 "$ROOT/scrip" --compile -o z.s z.pl < /dev/null > c.err 2>&1 && gcc -no-pie -o z.bin z.s -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread > link.err 2>&1 ) || { echo "GATE REFUSED(2) [$G]: the witness does not compile or link in mode 4 ($(head -c 120 "$W/c.err" "$W/link.err" 2>/dev/null | tr '\n' ' '))"; exit 2; }
( cd "$W" && timeout -k 5 120 ./z.bin < /dev/null > m4.out 2>&1 ); r4=$?
bad=0
for m in m3 m4; do rc=$([ $m = m3 ] && echo $r3 || echo $r4)
    if [ "$rc" -eq 0 ] && cmp -s "$W/z.ref" "$W/$m.out"; then echo "  ok  $m: rc=0, the 13 probe lines as swipl"; else echo "  RED $m: rc=$rc, output differs from swipl (swipl line, then SCRIP line):"; diff "$W/z.ref" "$W/$m.out" | head -10; bad=1; fi
done
TREE="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo '?')$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)"
if [ $bad -eq 0 ]; then echo "GATE PASS(0) [$G]: in the SWI dialect '[|]'(H,T) is a list cell in source, functor/3, =../2, compound_name_arity/3 and compound_name_arguments/3, in both modes as swipl (tree SCRIP=$TREE)"; exit 0; fi
echo "GATE FAIL(1) [$G]: the '[|]' list functor answers differently from swipl in one mode (tree SCRIP=$TREE)"; exit 1
