#!/usr/bin/env bash
# test_gate_raku_nested_and_anonymous_classes_and_the_operator_references_agree_with_rakudo.sh -- A CLASS OR ROLE DECLARED BELOW THE TOP LEVEL (in a block, a sub, an if, a for, a do, another class), AN ANONYMOUS CLASS, AND THE OPERATOR REFERENCES &[+] / &infix:<cmp> / &prefix:<->
# (row raku-every-suite-to-100-under-nonet-ceo-1266; found by classifying the 530 Roast files that do not compile: 31 die "assignment to 'x' has an rhs shape with no native arm", 5 of them on `my $*OUT = class { ... }`; operator references are used by 80 Roast files, anonymous classes by 21).
#
# THE DEFECTS, each measured against Rakudo: (1) the lowerer discovered classes and roles only among the PROGRAM'S OWN TOP-LEVEL STATEMENTS, so `{ class Foo { method m { 42 } }; say Foo.new.m }` printed NOTHING (the whole block silently did nothing), and so for a class declared in an if, a for, a do, a sub or another class's method -- the way Roast
# files wrap each test; (2) an anonymous class `my $c = class { ... }`, `anon class`, `class :: is P`, `(class { ... }).new` died "rhs shape with no native arm" or BOMB "bb_call marshal"; (3) `.new` on a variable holding a class (`my $c = Foo; $c.new`) did nothing, for a named class too;
# (4) an operator reference is a variable named with the source text (&[+], &infix:<cmp>): `reduce(&[+], 1,2,3)` printed nothing, `(3,1,2).sort(&infix:<cmp>)` printed ((<cmp>) 1 2 3), `&infix:<*>(3,4)` died "procedure '(<*>)' has no stackless slab", `my $f = &[+]` was refused by the native emitter.
# THE CURE: (lower_raku.c rk_hoist_nested_types, the first pass of rk_stage2_core) every class or role below the top level moves to the program's top level and is replaced by a type reference (a statement position becomes an empty sequence); an anonymous one gets a generated letters-only name (a name
# with an underscore and digits breaks the method machinery's `self`), and a name already in use (a `my class` repeated in two blocks, or a built-in type's name) gets a fresh one, with the references in its enclosing scope renamed; (by_name_dispatch.c meth_call) `new` on a string that names a user class constructs through obj_new, and a type object's name is read through
# rk_typeobj_name; (rk_tree.c rk_opref, in rkb_var) &[OP], &infix:<OP>, &infix:«OP», &prefix:<OP> become a two-placeholder closure built through the same operator tables as the hyper and reduce forms; the Z[&infix:<+>] bracket form resolves the same way.
# NOT HERE (own rows): a user class's type object as a VALUE is still the string "Foo" (`say Foo` prints Foo where Rakudo prints (Foo), `Foo ?? 1 !! 0` is true); a hoisted class does not see the enclosing block's lexical variables; the display name of a renamed duplicate shows the generated suffix in .WHAT.gist; `unique(:with(&infix:<==>))` and the other named comparator
# arguments; .produce / .classify / .minmax; `sort(&[>])` with a Bool-returning comparator; an operator reference to a user-declared operator sub; `&[..]`.
#
# THE WITNESS, graded in m3 (--run) and m4 (--compile + link) against a ref cut by Rakudo (/usr/bin/raku), then under SCRIP_GC_STRESS 1 3 5 in both modes.
# FAILED ONCE, measured on SCRIP 634e9d9cb before the cure: every witness-mode pair red.
#
# EXIT: 0 every witness matches in both modes; 1 a mismatch or a crash on a witness; 2 REFUSED (stale binary, no gcc).
# Usage: bash ../harness/scripts/test_gate_raku_nested_and_anonymous_classes_and_the_operator_references_agree_with_rakudo.sh   (~10s, no oracle at run time, no network)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_nested_and_anonymous_classes_and_the_operator_references_agree_with_rakudo"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked, so half the population is unmeasured"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/w.raku" <<'EOF'
{
    my class Dup { has $.v = 1; method m { $.v } }
    say Dup.new.m;
}
{
    my class Dup { has $.v = 2; method m { $.v * 10 } }
    say Dup.new.m;
    say Dup.new.m;
}
class Top { method m { "top" } }
{
    my class Top { method m { "inner" } }
    say Top.new.m;
}
say Top.new.m;
for 1..2 -> $i {
    my class Loop { method m { "L" } }
    say Loop.new.m ~ $i;
}
sub mk { return class { method hello { "hello" } } }
say mk().new.hello;
my $o = mk().new; say $o.hello;
{ class Foo { method m { 42 } }; say Foo.new.m; }
sub f { my class Bar { method m { 7 } }; return Bar.new.m }
say f();
if True { class Z1 { method m { 8 } }; say Z1.new.m }
say do { class D1 { method m { 47 } }; D1.new.m };
my $c = class { method m { 42 } }; say $c.new.m;
my $an = anon class { method m { 43 } }; say $an.new.m;
my $o2 = class A1 { method m { 44 } }.new; say $o2.m;
class P { method who { "P" } }; my $pc = class :: is P { }; say $pc.new.who;
say (class { method m { 45 } }).new.m;
my $x = class { has $.a = 3; method get { $.a } }; say $x.new.get; say $x.new(a => 9).get;
my $cn = class { method new { "custom" } }; say $cn.new;
class Outer { method make { class Inner { method hi { "hi" } }; Inner.new.hi } }; say Outer.new.make;
class Foo2 { method m { 42 } }; my $held = Foo2; say $held.new.m;
my @cs = (class { has $.n = 1; method m { $.n } }), (class { has $.n = 2; method m { $.n } }); say @cs[0].new.m + @cs[1].new.m;
my $f1 = &[+]; say $f1(1,2); say reduce(&[+], 1,2,3); say (3,1,2).sort(&infix:<cmp>); say (3,1,2).sort(&infix:«<=>»);
my &g = &infix:<*>; say g(3,4); say (1,2,3).map(&prefix:<->); say [3,1,2].sort(&[<=>]); say 1, 2 Z[&infix:<+>] 3, 4;
say (1,2,3).reduce(&[*]); say &[+](1,2); say &infix:<+>(1,2); say (1,2,3).reduce(&infix:<+>);
my @a2 = <b a c>; say @a2.sort(&infix:<leg>); my $op = &[~]; say $op("a","b"); say (2,3).reduce(&[**]); say (1..4).reduce(&[max]); say &[,](1,2);
EOF
cat > "$W/w.ref" <<'EOF'
1
20
20
inner
top
L1
L2
hello
hello
42
7
8
47
42
43
44
P
45
3
9
custom
hi
42
3
3
6
(1 2 3)
(1 2 3)
12
(-1 -2 -3)
(1 2 3)
(4 6)
6
3
3
6
(a b c)
ab
8
4
(1 2)
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
gate_verdict "$fails" "witness-mode pair(s) wrong: a nested/anonymous class or operator-reference result that disagrees with Rakudo"
