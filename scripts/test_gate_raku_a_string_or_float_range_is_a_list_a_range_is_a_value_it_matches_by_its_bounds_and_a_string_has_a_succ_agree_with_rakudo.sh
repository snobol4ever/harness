#!/usr/bin/env bash
# test_gate_raku_a_string_or_float_range_is_a_list_a_range_is_a_value_it_matches_by_its_bounds_and_a_string_has_a_succ_agree_with_rakudo.sh -- `'a'..'e'`, `1.5..4.5`, `5 ~~ 1..10`, `my $r = 1..5`, `f(1..3)`, `[1..3]`, `say 1..3`, `"az".succ`, `* ~~ 5..8`
# (row raku-every-suite-to-100-under-nonet-ceo-1266; found by probing the Range type after `5 ~~ 1..10` answered False in a sampled file: 50 Roast files mention Range, `when 1..5` and `ok $x ~~ 1..10` are everywhere).
#
# THE DEFECTS, measured against Rakudo: `..` was lowered to TT_TO, the Icon integer generator `i to j`, and nothing else: (1) `for 'a'..'e' { print $_ }` printed 0, `my @a = 'a'..'e'` held [0], `('aa'..'ad').list` was (0), `(1.5..4.5).list` was (1 2 3 4) (the endpoints were truncated to integers); (2) `5 ~~ 1..10` was False because the range, an ARGUMENT of __rk_smartmatch, produced its first value (1); (3) `my $r = 1..5` held 1 (so `$r.WHAT` was Int, `5 ~~ $r` False), `say 1..3` printed 1, a range passed to a call gave its first value only (`f(1..3)` with a slurpy parameter saw one element, `g(1..3).WHAT` was Int), `[1..3]` was [1], `put 1..3` printed 1; (4) Str.succ did not exist ("az".succ answered "az"); (5) the WhateverCode `* ~~ 5..8` was not curried, so `(1..20).grep(* ~~ 5..8)` kept everything.
# THE CURE: (by_name_dispatch.c rk_range_arr_make) the finite list of a range by the type of its endpoints: integers as before, a real start steps by one up to the end, and two non-numeric strings step by Raku's magical string increment (rk_str_succ_buf: az -> ba, zz -> aaa, a9 -> b0, Zz -> AAa, a9z -> b0a, 9 -> 10, a-z -> a-aa) until the end string is reached or the string grows past its length, empty when the start sorts after the end ('x'..'ab'); Str.succ; (rk_tree.c) a smartmatch against a range literal is __rk_in_range (numeric when the three are numeric, otherwise string order) and a WhateverCode left operand is curried; (lower_raku.c rk_range_values, rk_nonint_ranges) a plain `..` in a VALUE position (the right side of a scalar assignment or declaration, an argument of say / print / put and of a call, an invocant of .WHAT / .raku / .gist / .min / .max / .minmax / .bounds / .excludes-min / .excludes-max, an element of an array composer) is __rk_range_val, an array tagged "Range" (Rakudo's type name and gist 1..5, "a".."c"; it is a List to every list consumer, and an Int range keeps its declared bounds and exclusion flags in the spare lo2 / hi2 / proto_bare fields of the array block), and a range with a string or float literal endpoint anywhere else is __rk_range_arr; a one-element composer [1..3] flattens it.
# NOT HERE (own rows, measured): the exclusion forms as values (`1^..3`, `1..^3`, `^3` are still plain lists), infinite ranges (`1..*`, `1..Inf`: .elems should throw X::Cannot::Lazy), `for $r -> $x` (Rakudo itemizes the range, this iterates its elements), a `for $a..$b` whose endpoints are strings held in variables (the integer fast path), Rat endpoints, .pick / .roll / .is-int / .int-bounds, Range eqv.
# THE WITNESS (57 lines cut by the INSTALLED Rakudo 2022.12), graded in m3 (--run) and m4 (--compile + link), then under SCRIP_GC_STRESS 1 3 5 in both modes.
# FAILED ONCE, measured on the sitting's control build cfcfaf46d: 37 of the 57 lines differ.
#
# EXIT: 0 every witness matches in both modes; 1 a mismatch or a crash on a witness; 2 REFUSED (stale binary, no gcc).
# Usage: bash ../harness/scripts/test_gate_raku_a_string_or_float_range_is_a_list_a_range_is_a_value_it_matches_by_its_bounds_and_a_string_has_a_succ_agree_with_rakudo.sh   (~10s, no oracle at run time, no network)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_a_string_or_float_range_is_a_list_a_range_is_a_value_it_matches_by_its_bounds_and_a_string_has_a_succ_agree_with_rakudo"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked, so half the population is unmeasured"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/w.raku" <<'EOF'
say ('a'..'e').list;
say ('aa'..'ad').list;
say ('x'..'ab').list;
say ('a'..'a').list;
say (1.5..4.5).list;
say (1..3.5).list;
for 'a'..'c' { print $_ }
say "";
for 'x'..'z' -> $c { print $c, "-" }
say "";
my @s = 'a'..'e';
say @s.elems;
say "az".succ;
say "zz".succ;
say "a9".succ;
say "Zz".succ;
say "a9z".succ;
say "9".succ;
say "a-z".succ;
say 5 ~~ 1..10;
say 15 ~~ 1..10;
say 5.5 ~~ 1..10;
say "c" ~~ 'a'..'e';
say "cc" ~~ 'a'..'e';
say (1..20).grep(* ~~ 5..8);
say (1..9).grep({ $_ ~~ 5..8 });
given 5 {
    when 1..3 { say "low" }
    when 4..6 { say "mid" }
    default { say "hi" }
}
my $r = 1..5;
say $r;
say $r.WHAT;
say $r.min, " ", $r.max;
say $r.elems;
say $r.sum;
say $r.list;
say $r.reverse;
say $r.join(",");
say $r.map(* * 2);
say $r.grep(* %% 2);
say $r.excludes-min, $r.excludes-max;
say $r.bounds;
say $r.Str;
say $r.raku;
say 3 ~~ $r;
say 7 ~~ $r;
my @a = $r;
say @a;
say (1..3).minmax;
my $t = 'a'..'c';
say $t;
say $t.list;
say $t.min, $t.max;
say [1..3].elems;
say [1..3];
say [1..3, 4].elems;
sub f(*@a) { @a.elems }
say f(1..3);
sub g($x) { $x.WHAT }
say g(1..3);
say 1..3;
say (1..3).gist;
say (1..3).raku;
put 1..3;
say 'a'..'c';
say (5..1).elems;
say (1..0).list;
EOF
cat > "$W/w.ref" <<'EOF'
(a b c d e)
(aa ab ac ad)
()
(a)
(1.5 2.5 3.5 4.5)
(1 2 3)
abc
x-y-z-
5
ba
aaa
b0
AAa
b0a
10
a-aa
True
False
True
True
True
(5 6 7 8)
(5 6 7 8)
mid
1..5
(Range)
1 5
5
15
(1 2 3 4 5)
(5 4 3 2 1)
1,2,3,4,5
(2 4 6 8 10)
(2 4)
FalseFalse
(1 5)
1 2 3 4 5
1..5
True
False
[1..5]
(1 3)
"a".."c"
(a b c)
ac
3
[1 2 3]
2
3
(Range)
1..3
1..3
1..3
1 2 3
"a".."c"
0
()
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
gate_verdict "$fails" "witness-mode pair(s) wrong: a range / string-increment result that disagrees with Rakudo"
