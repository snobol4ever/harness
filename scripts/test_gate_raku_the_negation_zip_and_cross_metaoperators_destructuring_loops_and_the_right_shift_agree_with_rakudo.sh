#!/usr/bin/env bash
# test_gate_raku_the_negation_zip_and_cross_metaoperators_destructuring_loops_and_the_right_shift_agree_with_rakudo.sh -- THE NEGATION METAOPERATOR (!<, !eq, !==), Z AND X WITH AN OPERATOR (Z+, Z~, X*, Z=>, Zcmp) AND THEIR NESTED SHAPE, `-> ($a, $b)` DESTRUCTURING IN for, AND +>
# (row raku-every-suite-to-100-under-nonet-ceo-1266; the third family of operators the expression levels silently dropped, found by comparing the metaoperators with Rakudo after the hyper and reduce landings; 103 Roast files use Z or X).
#
# THE DEFECTS, each measured against Rakudo: `3 !< 2` printed 3 and `"a" !eq "b"` printed a (the negated operator and its right operand were swallowed by x_elem, the same loop that dropped the hyper operators); `(1,2) Z+ (10,20)` printed (1 2), `<a b> Z~ <c d>` printed (a b),
# `(1,2) X* (3,4)` printed (1 2), `Z=>` and `Zcmp` likewise; plain `(1,2) Z (3,4)` answered the FLAT list (1 3 2 4) where Rakudo answers a list of lists ((1 3) (2 4)) (so `for (1,2) Z (3,4) { say $_ }` printed four lines and `my @r = ...; @r.elems` was 4);
# `for @p -> ($x, $y)` stepped TWO elements per iteration (it treated the parenthesised group as the flat parameter list `-> $x, $y`) where Rakudo unpacks ONE element per iteration; `7 +> 1` printed 7 (the operator was not in the table: Rakudo 3).
# THE CURE: x_in knows the negation (rkb_neg_index: `!` before a comparison operator) and x_cmp wraps the comparison in the prefix `!`; x_listinfix accepts a Z or X with an inner operator (rkb_cross_inner finds it in the same operator tables as the hyper and reduce forms) and rkb_cross maps
# the operator over the rows (folded left for 3 or more lists); __rk_zip and __rk_cross answer a LIST OF ROW LISTS; rk_for_multi takes a destructuring flag (step one element, unpack its parts with __rk_arr_at) for a parenthesised parameter group; `+>` joins the multiplicative level as ishift(l, 0 - r).
# NOT HERE (own rows): `-> [$a, $b]` and `-> (:key($k), :value($v))` (the native emitter refuses them); `.=` on an array; the compound `**=` `%=` `x=`; `?&`, `^`, `~^`, the Unicode × and −, `S+`, `R-=`; the flip-flops; the triangle reduces; Rakudo DIES on `for %h.sort -> ($k, $v)` (a Pair does not unpack) where SCRIP unpacks it.
#
# THE WITNESS, graded in m3 (--run) and m4 (--compile + link) against a ref cut by Rakudo (/usr/bin/raku), then under SCRIP_GC_STRESS 1 3 5 in both modes.
# FAILED ONCE, measured on SCRIP c7c51d99b before the cure: every witness-mode pair red.
#
# EXIT: 0 every witness matches in both modes; 1 a mismatch or a crash on a witness; 2 REFUSED (stale binary, no gcc).
# Usage: bash ../harness/scripts/test_gate_raku_the_negation_zip_and_cross_metaoperators_destructuring_loops_and_the_right_shift_agree_with_rakudo.sh   (~10s, no oracle at run time, no network)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_the_negation_zip_and_cross_metaoperators_destructuring_loops_and_the_right_shift_agree_with_rakudo"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked, so half the population is unmeasured"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/w.raku" <<'EOF'
say 3 !< 2; say 3 !== 3; say "a" !eq "b"; say 1 !<= 2; say 3 !~~ 3; say 2 !> 3; say 5 !>= 5;
say (1,2) Z+ (10,20); say <a b> Z~ <c d>; say (1,2) X* (3,4); say (1,2) Z=> (3,4); say 1,2 Zcmp 3,4; say (1,2) Zcmp (1,3);
say (1,2) Z+ (3,4) Z+ (5,6); say <a b> X~ <c d>; say (1,2) X- (3,4); say (3,1,2) Zmax (2,2,2);
say (1,2) Z (3,4); say (1,2) X (3,4); say (1,2,3) Z <a b>; say (1,2) Z (3,4) Z (5,6); say <a b> Z 1..2;
my %h = (1,2) Z=> (3,4); say %h;
my @r = (1,2) Z (3,4); say @r.elems; say @r; say @r[1]; say @r[0][1];
for (1,2) Z (3,4) { say $_ }
for (1,2) Z (3,4) -> $a, $b { say "$a $b" }
for (1,2) Z (3,4) -> ($a, $b) { say "$a $b" }
for ((1,3),(2,4)) -> ($a, $b) { say "$a $b" }
my @p = (1,3),(2,4); for @p -> ($x, $y) { say $x * $y }
for (1,2) X (3,4) -> ($a, $b) { say "$a|$b" }
for (1,2) Z <a b> -> ($n, $l) { say "$n$l" }
for (1,2,3,4) -> $a, $b { say "$a $b" }
for <a b>.kv -> $i, $v { say "$i:$v" }
say 7 +> 1; say 8 +> 2; say -8 +> 1; say 255 +> 4; say 7 +< 1;
EOF
cat > "$W/w.ref" <<'EOF'
True
False
True
False
False
True
False
(11 22)
(ac bd)
(3 4 6 8)
(1 => 3 2 => 4)
(Less Less)
(Same Less)
(9 12)
(ac ad bc bd)
(-2 -3 -1 -2)
(3 2 2)
((1 3) (2 4))
((1 3) (1 4) (2 3) (2 4))
((1 a) (2 b))
((1 3 5) (2 4 6))
((a 1) (b 2))
{1 => 3, 2 => 4}
2
[(1 3) (2 4)]
(2 4)
3
(1 3)
(2 4)
1 3 2 4
1 3
2 4
1 3
2 4
3
8
1|3
1|4
2|3
2|4
1a
2b
1 2
3 4
0:a
1:b
3
2
-4
15
14
EOF
fails=0; GATE_EXAMINED=0
ck() {
    local w="$1" m="$2" out rc
    GATE_EXAMINED=$((GATE_EXAMINED + 1))
    if [ "$m" = m3 ]; then out="$(env ${ST:+SCRIP_GC_STRESS=$ST} timeout -k 5 120 "$ROOT/scrip" --run "$W/$w.raku" 2>/dev/null </dev/null)"; rc=$?
    else
        if ! timeout -k 5 60 "$ROOT/scrip" --compile -o "$W/$w.s" "$W/$w.raku" </dev/null >"$W/$w.cerr" 2>&1 \
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
gate_verdict "$fails" "witness-mode pair(s) wrong: a negation, zip/cross, destructuring-for or right-shift result that disagrees with Rakudo"
