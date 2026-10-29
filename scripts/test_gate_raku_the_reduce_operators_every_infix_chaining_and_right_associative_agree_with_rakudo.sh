#!/usr/bin/env bash
# test_gate_raku_the_reduce_operators_every_infix_chaining_and_right_associative_agree_with_rakudo.sh -- THE REDUCE METAOPERATOR [op] FOR EVERY INFIX OPERATOR: [/] [**] [%] [x] [<] [==] [eq] [&&] [//] [gcd] [lcm] [div] [mod] [=>] [,] [R-] [~~] [===], AND A TYPE OBJECT IS UNDEFINED FOR // AND defined
# (row raku-every-suite-to-100-under-nonet-ceo-1266; found while measuring the hyper operators: rkb_reduce_name answered `__rk_reduce_max` for EVERY operator other than + - * ~ min max; 130 Roast files use a reduce).
#
# THE DEFECT, measured against Rakudo: [/] 8,2,2 printed 8 (Rakudo 2), [**] 2,3,2 printed 3 (512), [%] 10,4,3 printed 10 (2), [x] "a",3 printed a (aaa), [<] 1,2,3 printed 3 (True), [==] 1,1,1 printed 1 (True), [eq] <a a b> printed b (False), [gcd] 12,18 printed 18 (6),
# [lcm] 4,6 printed 6 (12), [,] 1,2,3 printed 3 ((1 2 3)), [=>] 1,2,3 printed 3 (1 => 2 => 3), [R-] 1,2,3 printed 2 (0): the "default" arm of the name table was max. And `Any // 3` and `[//] Any,3,4` answered the type object (a type object is undefined: 3).
# THE CURE (rk_tree.c rk_reduce_general): rkb_reduce_name now answers NULL for an operator the six runtime reducers do not cover and remembers its text; the operator is found in the parser's own operator tables (rkb_op_index over the levels) and the reduce becomes
# `list.reduce({ $^a OP $^b })` built with rkb_binop_raw; a right-associative operator (** and =>) folds the reversed list with the arguments swapped; the R prefix swaps the arguments AND flips the associativity (measured: [R-] 1,2,3 is 0); a chaining comparison
# (every operator of the comparison level but <=>, cmp, leg) maps the operator over __rk_adjacent_pairs and answers __rk_all_true of it (so [<] 1 and [<] () are True); [,] is the list itself; ~~ goes through the smartmatch. __rk_dor and __rk_defined treat a type object as undefined.
# NOT HERE (own rows): the triangle forms [\+] and [\*] (want a list; they still answer the plain reduce); [Z] and [X]; the X and Z metaoperators with an operator and the nested pairs plain Z / X return; [+] over a Range operand; reduces of an empty list for the operators beyond the six.
#
# THE WITNESS, graded in m3 (--run) and m4 (--compile + link) against a ref cut by Rakudo (/usr/bin/raku), then under SCRIP_GC_STRESS 1 3 5 in both modes.
# FAILED ONCE, measured on SCRIP 97bf3894b before the cure: every witness-mode pair red.
#
# EXIT: 0 every witness matches in both modes; 1 a mismatch or a crash on a witness; 2 REFUSED (stale binary, no gcc).
# Usage: bash ../harness/scripts/test_gate_raku_the_reduce_operators_every_infix_chaining_and_right_associative_agree_with_rakudo.sh   (~10s, no oracle at run time, no network)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_the_reduce_operators_every_infix_chaining_and_right_associative_agree_with_rakudo"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked, so half the population is unmeasured"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/w.raku" <<'EOF'
say [+] 1..4; say [-] 10,3,2; say [*] 1..5; say [/] 8,2,2; say [**] 2,3,2; say [%] 10,4,3; say [~] <a b c>; say [x] "a",3; say [min] 3,1,2; say [max] 3,1,2;
say [<] 1,2,3; say [<] 3,2,1; say [==] 1,1,1; say [eq] <a a b>; say [<=] 1,2,2; say [!=] 1,2,3; say [!=] 1,1; say [>] 3,2,1; say [lt] <a b c>; say [<] 1; say [<] ();
say [&&] 1,2,3; say [||] 0,0,5; say [//] Any,3,4; say [gcd] 12,18; say [lcm] 4,6; say [+<] 1,2; say [div] 20,3; say [mod] 20,3;
say [,] 1,2,3; say [=>] 1,2,3; say [R-] 1,2,3; say [R/] 2,8; say [R**] 2,3,2;
say [+] (); say [*] (); say [~] ();
my @a = 5,3,1; say [+] @a; say [*] @a; say [<] @a; say [>] @a; say [+] [1,2],[3,4];
say [~~] 1,1,1; say [===] 1,1;
say Any // 3; say (Int) // 5; say 0 // 5; say Nil // 6; say defined(Any); say defined(5); say Any.defined;
EOF
cat > "$W/w.ref" <<'EOF'
10
5
120
2
512
2
abc
aaa
1
3
True
False
True
False
True
True
False
True
True
True
True
3
5
3
6
12
4
6
2
(1 2 3)
1 => 2 => 3
0
4
512
0
1

9
15
False
True
4
True
True
3
5
0
6
False
True
False
EOF
fails=0; GATE_EXAMINED=0
ck() {
    local w="$1" m="$2" out rc
    GATE_EXAMINED=$((GATE_EXAMINED + 1))
    if [ "$m" = m3 ]; then out="$(env ${ST:+SCRIP_GC_STRESS=$ST} timeout -k 5 120 "$ROOT/scrip" --run "$W/$w.raku" 2>/dev/null </dev/null)"; rc=$?
    else
        if ! timeout -k 5 60 "$ROOT/scrip" --compile --out="$W/$w.s" "$W/$w.raku" </dev/null >"$W/$w.cerr" 2>&1 \
           || ! gcc -o "$W/$w.bin" "$W/$w.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread >>"$W/$w.cerr" 2>&1; then
            printf '  FAIL %-7s %s: did not build (%s)\n' "$w" "$m" "$(head -1 "$W/$w.cerr" | cut -c1-110)"; fails=$((fails + 1)); return; fi
        out="$(env ${ST:+SCRIP_GC_STRESS=$ST} timeout -k 5 120 "$W/$w.bin" 2>/dev/null </dev/null)"; rc=$?
    fi
    if [ "$rc" -ge 124 ]; then printf '  FAIL %-7s %s: died rc=%s\n' "$w" "$m" "$rc"; fails=$((fails + 1)); return; fi
        if [ "$out" = "$(cat "$W/$w.ref")" ]; then printf '  ok   %-7s %s%s\n' "$w" "$m" "${ST:+ stress=$ST}"
    else printf '  FAIL %-7s %s: got [%s] want [%s]\n' "$w" "$m" "$(printf '%s' "$out" | tr '\n' ' ' | cut -c1-110)" "$(tr '\n' ' ' < "$W/$w.ref" | cut -c1-110)"; fails=$((fails + 1)); fi
}
ST=""; for w in w; do for m in m3 m4; do ck "$w" "$m"; done; done
for ST in 1 3 5; do for w in w; do for m in m3 m4; do ck "$w" "$m"; done; done; done
gate_verdict "$fails" "witness-mode pair(s) wrong: a reduce-operator or type-object-undefined result that disagrees with Rakudo"
