#!/usr/bin/env bash
# test_gate_raku_a_scalar_gist_and_the_str_of_every_aggregate_and_object_and_put_agree_with_rakudo.sh -- A SCALAR'S .gist, THE .Str OF EVERY LIST / ARRAY / HASH / PAIR / SET / OBJECT BEHIND ~ AND "{...}" INTERPOLATION, AND put
# (row raku-every-suite-to-100-under-nonet-ceo-1266; found by a 120-file mode-3 sample of the Roast files that compile: S02-magicals/USER.t and its one-assertion siblings died on lives-ok { $*USER.gist }).
#
# THE DEFECTS, each measured against Rakudo: (1) .gist on a Str, Int, Num, Bool, bignum or Nil was never implemented -- meth_call failed, so say "abc".gist and say 5.gist printed NOTHING and a lives-ok block ending in .gist died rc 255;
# (2) the single string-coercion entry __rk_str (behind unary ~, the ~ operator and every "{...}" interpolation) returned a List, Array, Hash, Pair, Set, Bag or object UNTOUCHED, so ~@a printed [1 2 3] (the gist), "x" ~ @a printed x (the list
# dropped by the concat), "i: {@a}" printed "i: ", ~%h printed {a => 1} and ~$obj ignored the class's own Str; (3) put had no Raku form -- the name fell to Icon's put (list append) and died "error 108: list expected" on EVERY call.
# THE CURE: by_name_dispatch.c rt_str_method gets the scalar .gist arm (the receiver's own Str text; Nil is "Nil"); __rk_str answers rk_obj_stringify(a, 0) for an object, rk_arr_text for a List/Array/Pair and rk_tbl_text for a Hash -- the same
# per-kind Str text print already used; rk_tree.c lowers put as print with a trailing newline argument (rkb_call, and "put" joins the parser's own names in rkb_listop_substitutes).
# NOT HERE (own rows, measured the same day): a Range as a value (~(1..4), put 1..3, say 1..3 print the first element only); bare say (1,2) / print (1,2) with a space (a List argument; SCRIP flattens it as say(1,2)); Rat and float say precision (say 1/3).
#
# THE WITNESS, graded in m3 (--run) and m4 (--compile + link) against a ref cut by Rakudo (/usr/bin/raku), then under SCRIP_GC_STRESS 1 3 5 in both modes.
# FAILED ONCE, measured on SCRIP aca545b49 before the cure: every witness-mode pair red.
#
# EXIT: 0 every witness matches in both modes; 1 a mismatch or a crash on a witness; 2 REFUSED (stale binary, no gcc).
# Usage: bash ../harness/scripts/test_gate_raku_a_scalar_gist_and_the_str_of_every_aggregate_and_object_and_put_agree_with_rakudo.sh   (~10s, no oracle at run time, no network)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_a_scalar_gist_and_the_str_of_every_aggregate_and_object_and_put_agree_with_rakudo"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked, so half the population is unmeasured"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/st.raku" <<'EOF'
use Test;
class P { method Str { "p!" } }
class Q { has $.x = 3; }
say "abc".gist; say 5.gist; say -7.gist; say 1.5.gist; say True.gist; say False.gist; say 1e20.gist; say "".gist.chars;
my $s0 = "x y"; say $s0.gist; my $n = 42; say $n.gist; my $b0 = True; say $b0.gist;
say "a\nb".gist.lines.elems; say 3.14159.gist; say (2**70).gist; say "é".gist; say Nil.gist; say Int.gist;
say $*USER.gist eq $*USER; say "abc".gist.uc; say (5.gist ~ "!");
lives-ok { $*USER.gist; $*USER.WHAT.gist; }, 'the roast line';
my @a = 1,2,3; my %h = a=>1; my $p = (k => 'v'); my $st = set(<x y>); my $bg = bag(<a a b>);
say ~@a; say "x" ~ @a; say "i: {@a}"; say "i: @a[]";
say ~(1,(2,3)); say ~[1,[2,3]]; say ~();
say ~%h; say "h: {%h}"; say ~$p; say "p: {$p}";
say ~$st.sort; say ~$bg.sort;
say ~P.new; say "o: {P.new}"; say "n: " ~ P.new;
say ~Q.new.x; say ~(1,2).Seq; say ~<a b>; say ~(1,2,3).reverse;
say ~True; say ~5; say ~2.5; say ~"s"; say ~(1/4);
print @a; print "\n"; put @a; put 1,2; put "x"; put @a, "z"; put %h; put P.new; put "a" ~ "b"; put 5; put 2.5; put True;
say "a" ~ 1 ~ (2,3) ~ 4;
my @e; say "e[" ~ @e ~ "]"; say ~@e;
say @a.Str; say @a.gist; say %h.Str; say $p.Str; say (1,2).Str;
EOF
cat > "$W/st.ref" <<'EOF'
abc
5
-7
1.5
True
False
1e+20
0
x y
42
True
2
3.14159
1180591620717411303424
é
Nil
(Int)
True
ABC
5!
ok 1 - the roast line
1 2 3
x1 2 3
i: 1 2 3
i: 1 2 3
1 2 3
1 2 3

a	1
h: a	1
k	v
p: k	v
x	True y	True
a	2 b	1
p!
o: p!
n: p!
3
1 2
a b
3 2 1
True
5
2.5
s
0.25
1 2 3
1 2 3
12
x
1 2 3z
a	1
p!
ab
5
2.5
True
a12 34
e[]

1 2 3
[1 2 3]
a	1
k	v
1 2
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
ST=""; for w in st; do for m in m3 m4; do ck "$w" "$m"; done; done
for ST in 1 3 5; do for w in st; do for m in m3 m4; do ck "$w" "$m"; done; done; done
gate_verdict "$fails" "witness-mode pair(s) wrong: a scalar gist, aggregate Str or put result that disagrees with Rakudo"
