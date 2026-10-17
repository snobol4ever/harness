#!/usr/bin/env bash
# test_gate_raku_a_missing_element_is_any_a_hash_assignment_is_kept_and_attribute_defaults_and_array_hash_attributes_agree_with_rakudo.sh -- A MISSING ELEMENT OR KEY IS THE ANY TYPE OBJECT, `say (LIST)`, `%h = pairs;` AS A STATEMENT, PRIVATE ATTRIBUTES AND `.new`, UNSET ATTRIBUTE DEFAULTS, ARRAY AND HASH ATTRIBUTES (`@!b = ...`, `push @!b`, `%!h{$k}`), ATTRIBUTE DEFAULTS THAT ARE NOT LITERALS (`has @.b = 1, 2`, `has $.e = 2 + 3`), RADIX LITERALS (`:16<ff>`, `:10[1, 2, 3]`), BIG INTEGER LITERALS, AND A NEVER-ASSIGNED DYNAMIC VARIABLE
# (row raku-every-suite-to-100-under-nonet-ceo-1266; found by running the 26 master entries that ALL.csv marks xfail=1 and the RakBench kernels that fail, and curing the shared causes; RakRungs 935/960 closes only by curing its xfail entries, CEO-416).
#
# THE DEFECTS, each measured against Rakudo (and the first six against the control build of the sitting's base commit): (1) an element past the end of an array and a missing hash key were Nil: `say @a[99]` printed Nil (Rakudo (Any)), `@a[99].WHAT` Nil, `@a[1,9]` printed (2 ), `%h<x>` Nil; (2) a type object inside a list printed bare (`say (2, Any)` gave 2Any, Rakudo (2 (Any)));
# (3) `say (1,2,3)` with a SPACE before the parenthesis printed 123 (Rakudo takes the parenthesised list as ONE argument: (1 2 3); only `say(1,2,3)` takes three); (4) A STATEMENT `%h = a => 1, b => 2;` WAS DROPPED -- the tree was the bare variable, so every assignment to an already-declared hash (`%k = %j`, `%i = a => 1`) did nothing and only `my %h = ...` worked;
# (5) `@!b = 1, 2;` and `%!h = a => 1;` in a method were dropped the same way, `push @!b, 3` died "error 108: list expected", `@!b.push($x)` and `%!h{$k} = $v` did nothing, and an array assigned to an array attribute was a List; (6) `has $!secret` could be set through `.new(secret => 5)` (Rakudo ignores a private attribute in the default constructor),
# an unset scalar attribute was Nil where Rakudo has (Any), and an unset `has @.l` / `has %.m` was an empty string where Rakudo has [] and {}; (7) the INITIALISER of `has @.b = 1, 2`, `has %.d = ...` was thrown away by the parser and a non-literal `has $.e = 2 + 3` was ignored: S.new.b printed nothing.
# THE CURE: (by_name_dispatch.c) an out-of-range element (__rk_arr_at, __rk_arr_pick) and a missing hash key (hash_get) answer the Any type object, and rk_gist_str renders a type object as (Name) wherever it sits; obj_new does not bind a private field from a named argument and rk_attr_defaults gives an unset field Any / an empty Array / an empty Hash;
# a new builtin __rk_unset (true for Nil, an empty string, a type object) serves the defaults; (rk_tree.c) `say` flattens a parenthesised list only for the call form say(...); stmt_plain builds `%h = list`, `@!b = list` and `%!h = list` (through __rk_to_hash / __rk_to_array), has_items keeps the initialiser of an array or hash attribute, and push / pop / shift / unshift / append / prepend / splice
# on a twigil field is the method call; (lower_raku.c rk_class_default_tweaks) every non-literal, array or hash attribute default becomes an assignment guarded by "not yet set" at the head of the class's TWEAK (created when the class has none, prepended when it has one), so the existing TWEAK chain applies base-class defaults first.
# (8) RADIX LITERALS BUILT AS 0 AND BIG INTEGER LITERALS SATURATED (found through the RakBench kernel send-more-money-subs): `:16<ff>`, `:10[$s, $e, 3]`, `:2[1,0,1]`, `:60[1, 30]` were recognised and then built from the source text through strtoll, so every one printed 0 (Rakudo 255, 123, 5, 90), and `say 12345678901234567890123` printed 9223372036854775807 (atol saturating); rkb_number now folds the digits of an angle-bracket radix literal in C (exact integer, or a double for a fractional one), builds a bracket form as __rk_radix_list(base, list) and any literal beyond 63 bits (decimal, 0x, 0b, 0o, 0d, radix) as __rk_radix_str(base, digits), both folded by rt_mul_big / rt_add_big.
# (9) READING A NEVER-ASSIGNED DYNAMIC VARIABLE (`say $*NOSUCH // 42`) was refused by the native emitter ("variable '*NOSUCH' is read but never assigned"); rk_unassigned_dynamics_are_globals registers a `*` name that no graph assigns, so it reads as undefined (it was the one compile-census regression of the attribute work: S12-introspection/attributes.t, `has Int $!b = $*FOO // 42`).
# NOT HERE (own rows, measured): `:16<1.8>` is a Num where Rakudo has a Rat (the Rat type is absent: `1/3` is a Num, `0.1 + 0.2` is 0.30000000000000004, `2 ** -2` is 0); dynamic scoping through a callee of a sub that rebinds a `*` variable; a typed attribute's unset value is (Any) where Rakudo has (Int) (the type is not recorded); `.^attributes` / `.^methods` / `.^parents` text; a role's attribute defaults; `(Int,)` prints (Int) where Rakudo prints ((Int)); `.raku` of a type object inside a list is quoted; a default applied when an explicit undefined value is passed; BUILD interplay with defaults.
#
# THE WITNESS, graded in m3 (--run) and m4 (--compile + link) against a ref cut by Rakudo (/usr/bin/raku), then under SCRIP_GC_STRESS 1 3 5 in both modes.
# FAILED ONCE, measured on SCRIP ca93e12b8 before the cure: every witness-mode pair red.
#
# EXIT: 0 every witness matches in both modes; 1 a mismatch or a crash on a witness; 2 REFUSED (stale binary, no gcc).
# Usage: bash ../harness/scripts/test_gate_raku_a_missing_element_is_any_a_hash_assignment_is_kept_and_attribute_defaults_and_array_hash_attributes_agree_with_rakudo.sh   (~10s, no oracle at run time, no network)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_a_missing_element_is_any_a_hash_assignment_is_kept_and_attribute_defaults_and_array_hash_attributes_agree_with_rakudo"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked, so half the population is unmeasured"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/w.raku" <<'EOF'
my @a = 1, 2, 3;
say @a[99];
say @a[99].defined;
say @a[99].WHAT;
say @a[99] // "d";
my $x = @a[9];
say $x;
say @a[1, 9];
say @a[5, 6].elems;
my %h = a => 1;
say %h<x>;
say %h<x>.WHAT;
say %h{"y"} // "dd";
say Any;
say (2, Any);
say [Int, Str];
say (1, Int).gist;
say (1, 2, 3);
say ("a", "b");
say (1);
say(1, 2, 3);
say (1, 2, 3), 4;
say (1, 2, 3).elems;
my %g;
%g = a => 1, b => 2;
say %g;
my %i;
%i = a => 1;
say %i;
my %j = a => 1, b => 2;
my %k;
%k = %j;
say %k;
%k = ();
say %k.elems;
class P {
    has $!secret;
    has $.pub;
    method peek { $!secret }
    method both { $.pub ~ "-" ~ ($!secret // "none") }
}
my $p = P.new(secret => 5, pub => "A");
say $p.peek;
say $p.both;
class Q {
    has $.x;
    has @.l;
    has %.m;
}
my $q = Q.new;
say $q.x;
say $q.x.defined;
say $q.l;
say $q.l.WHAT;
say $q.m;
say $q.m.WHAT;
class R {
    has @.b;
    has %.h;
    submethod TWEAK {
        @!b = 1, 2;
        %!h = a => 1, b => 2;
        push @!b, 3;
    }
    method add($v) { @!b.push($v); self }
    method put($k, $v) { %!h{$k} = $v; self }
    method n { @!b.elems }
    method keys { %!h.keys.sort.join(",") }
}
my $r = R.new;
say $r.n;
say $r.keys;
say $r.add(9).n;
say $r.put("z", 1).keys;
say $r.b;
class S {
    has @.b = 1, 2;
    has @.c = <x y>;
    has %.d = a => 1;
    has $.e = 2 + 3;
    has $.f = "k";
}
my $s = S.new;
say $s.b;
say $s.c;
say $s.d;
say $s.e;
say $s.f;
say S.new(b => [7]).b;
say S.new(e => 1).e;
class T {
    has $.x;
    has @.l = 1, 2;
    submethod TWEAK { $!x = @!l.elems; }
}
say T.new.x;
class U is S {
    has @.extra = 4, 5;
}
say U.new.b;
say U.new.extra;
my @c;
++@c[2];
++@c[2];
@c[1]++;
say @c[2], " ", @c[1];
my %ct;
%ct<a> += 2;
%ct<a>++;
++%ct<b>;
say %ct<a>, " ", %ct<b>;
my @d;
@d[1] //= 7;
@d[0] = 3;
@d[0] //= 9;
say @d.join(",");
my @e = 5;
my $old = @e[0]++;
say $old, " ", @e[0];
say :16<ff>;
say :8<777>;
say :36<zz>;
say :2<1_0_1>;
say :16<FF>;
say :16<ffffffffffffffffffff>;
say :16<1.8>;
say :10[1, 2, 3];
my $dd = 7;
say :10[$dd, $dd];
say :2[1, 0, 1];
say :16[1, 15];
say :60[1, 30];
say :8<17> + 1;
say $*NOSUCH // 42;
say 12345678901234567890123;
say 12345678901234567890123 + 1;
say 0xffffffffffffffffffff;
say -12345678901234567890123;
EOF
cat > "$W/w.ref" <<'EOF'
(Any)
False
(Any)
d
(Any)
(2 (Any))
2
(Any)
(Any)
dd
(Any)
(2 (Any))
[(Int) (Str)]
(1 (Int))
(1 2 3)
(a b)
1
123
(1 2 3)4
3
{a => 1, b => 2}
{a => 1}
{a => 1, b => 2}
0
(Any)
A-none
(Any)
False
[]
(Array)
{}
(Hash)
3
a,b
4
a,b,z
[1 2 3 9]
[1 2]
[x y]
{a => 1}
5
k
[7]
1
2
[1 2]
[4 5]
2 1
3 1
3,7
5 6
255
511
1295
5
255
1208925819614629174706175
1.5
123
77
5
31
90
16
42
12345678901234567890123
12345678901234567890124
1208925819614629174706175
-12345678901234567890123
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
gate_verdict "$fails" "witness-mode pair(s) wrong: an element / attribute / hash-assignment / radix result that disagrees with Rakudo"
