#!/usr/bin/env bash
# test_gate_raku_an_element_assignment_through_a_chain_of_subscripts_stores_into_the_nested_container_agree_with_rakudo.sh -- `@a[1][0] = 9`, `%h<a><b> = 3`, `@s[$i][$j] = $i + $j`, `%h<a>[2] = 5`, `$x[1][1] = 9`, `@g[1][0] += 5`, `@g[0][1]++`: AN ELEMENT ASSIGNMENT WHOSE TARGET IS ITSELF AN ELEMENT; ALSO `@a .= sort` / `%h .= grep(...)` (THE METHOD-ASSIGNMENT ON AN ARRAY OR HASH), THE POSTFIX HYPER `@b>>++` / `@b>>--`, AND THE ITEM LITERAL `$[1, 2]`
# (row raku-every-suite-to-100-under-nonet-ceo-1266; found through the RakBench kernels mb-create_and_copy_2d_grid_cross, mb-create_and_copy_2d_grid_cross_unpack and the mb-visit_2d_indices family, which printed Nil/(Any) for the 128x128 grid, and confirmed on an existing nested array).
#
# THE DEFECT, measured against Rakudo: the tree for `@a[1][0] = 9` is TT_ARR_SET whose base is TT_ARR_GET(@a, 1), and the lowerer stores an element only when the base is a plain variable: for any other base it emitted SUCCEED, so the statement DID NOTHING and said nothing. `my @a = [1,2],[3,4]; @a[1][0] = 9; say @a` printed [[1 2] [3 4]] (Rakudo [[1 2] [9 4]]),
# `my @a; @a[1][2] = 5; say @a` printed [] (Rakudo [(Any) [(Any) (Any) 5]]), `%h<a><b> = 3` and `%h{"x"}{"y"} = 3` left %h empty, a matrix filled by `@s[$i][$j] = ...` read back (Any), and the read-modify-write forms (`@g[1][0] += 5`, `@g[0][1]++`) were lost the same way.
# THE CURE: (lower_raku.c rk_nested_elem_sets, a tree pass) a set whose base is an element read becomes a store, into the outer element, of the inner container updated by the new builtin __rk_elem_put(kind, current-inner, index, value) -- which creates an array or hash when the inner is undefined and pads new array positions with the Any type object -- repeated up the chain
# until the base is a variable, which the existing store handles; __rk_arr_set pads with (Any) too, as Rakudo prints a hole.
# TWO SMALLER DEFECTS ON THE SAME PATH (found through the xfail-adjacent probes and the RakBench kernel rc-9-billion-names): the method assignment `.=` worked on a scalar (`$s .= flip`) but `@a .= sort`, `@a .= map(...)`, `%h .= grep(...)` left the variable unchanged (the statement was the bare variable), and the postfix hyper `@b>>++` / `@b>>--` was swallowed the same way; stmt_plain builds the first as an assignment of the converted method result, rkb_postfix the second as `@b = __rk_hyper_incdec(@b, +-1)`. The literal `$[1, 2]` (an itemized array) was read as a variable named "[1, 2]"; r_term parses it like `$(...)` and takes the item of the bracket.
# NOT HERE (own rows, measured): ITEMIZATION IS NOT MODELLED (`my @u = $[1, 2]; @u.elems` is 1 in Rakudo and 2 here: `$[...]`, `$(@a)`, `.item` do not suppress flattening in list assignment); the aliasing binding `my @x := @todo[$x]; @x.shift` (rc-9-billion-names prints 15 15, Rakudo 15 176); `@a[1;2]` multi-dimensional subscripts and shaped arrays; an index expression with a side effect is evaluated twice; slices on the nested path (`@a[0][1,2] = ...`); the functional element store copies its array (O(n) per store -- the performance phase).
#
# THE WITNESS, graded in m3 (--run) and m4 (--compile + link) against a ref cut by Rakudo (/usr/bin/raku), then under SCRIP_GC_STRESS 1 3 5 in both modes.
# FAILED ONCE, measured on SCRIP 2adee34cf before the cure: every witness-mode pair red.
#
# EXIT: 0 every witness matches in both modes; 1 a mismatch or a crash on a witness; 2 REFUSED (stale binary, no gcc).
# Usage: bash ../harness/scripts/test_gate_raku_an_element_assignment_through_a_chain_of_subscripts_stores_into_the_nested_container_agree_with_rakudo.sh   (~10s, no oracle at run time, no network)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_an_element_assignment_through_a_chain_of_subscripts_stores_into_the_nested_container_agree_with_rakudo"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked, so half the population is unmeasured"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/w.raku" <<'EOF'
my @a;
@a[1][2] = 5;
say @a;
my @b;
@b[3] = 1;
say @b;
say @b.elems;
my @c = 1, 2;
@c[4] = 9;
say @c;
my %h;
%h<a><b><c> = 1;
say %h;
my @m;
@m[0][0] = 1;
@m[1][1] = 2;
say @m;
my @g = [1, 2], [3, 4];
@g[1][0] += 5;
@g[0][1]++;
say @g;
my %n = a => [1, 2];
%n<a>[1] = 7;
%n<b>[0] = 8;
say %n<a>;
say %n<b>;
my @t;
@t[2]<k> = 3;
say @t[2]<k>;
my $x = [[1, 2], [3, 4]];
$x[1][1] = 9;
say $x;
say $x[1][1];
my @src;
my @dst;
for flat(1 .. 4 X 1 .. 4) -> $i, $j { @src[$i][$j] = $i + $j }
for flat(1 .. 4 X 1 .. 4) -> $i, $j { @dst[$i][$j] = @src[$i][$j] }
say @dst[4][4];
say @dst[2][3];
say @dst.elems;
my @it = $[1, 2];
say $[3, 4].WHAT;
my @rows = ($[5, 6], $[7]);
say @rows[0].WHAT;
my @ma = 3, 1, 2;
@ma .= sort;
say @ma;
@ma .= reverse;
say @ma;
my @mb = 1, 2, 3;
@mb .= map(* * 2);
say @mb;
@mb>>++;
say @mb;
my @mc = 1, 2, 3;
@mc>>--;
say @mc;
my %mh = b => 2, a => 1;
%mh .= grep({ $_.value > 1 });
say %mh;
EOF
cat > "$W/w.ref" <<'EOF'
[(Any) [(Any) (Any) 5]]
[(Any) (Any) (Any) 1]
4
[1 2 (Any) (Any) 9]
{a => {b => {c => 1}}}
[[1] [(Any) 2]]
[[1 3] [8 4]]
[1 7]
[8]
3
[[1 2] [3 9]]
9
8
5
5
(Array)
(Array)
[1 2 3]
[3 2 1]
[2 4 6]
[3 5 7]
[0 1 2]
{b => 2}
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
gate_verdict "$fails" "witness-mode pair(s) wrong: a nested-subscript store / method-assignment result that disagrees with Rakudo"
