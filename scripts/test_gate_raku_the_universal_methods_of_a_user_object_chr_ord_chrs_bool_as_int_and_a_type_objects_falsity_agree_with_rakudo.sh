#!/usr/bin/env bash
# test_gate_raku_the_universal_methods_of_a_user_object_chr_ord_chrs_bool_as_int_and_a_type_objects_falsity_agree_with_rakudo.sh -- THE MU / ANY METHODS OF A USER OBJECT, chr / ord / chrs IN UTF-8, A Bool AS AN INTEGER, A TYPE OBJECT IS FALSE, AND A ZERO-ITEM push
# (row raku-every-suite-to-100-under-nonet-ceo-1266; found by a 120-file mode-3 Roast sample: 10 of 120 died "GZ-10 rt_call_proc_descr: procedure 'Foo__defined' has no stackless slab", then a probe of 50 universal methods on a plain class).
#
# THE DEFECTS, each measured against Rakudo: (1) a method the class does not define fell through to a procedure that does not exist, so $obj.defined, .Bool, .so, .not, .gist, .Str, .raku, .item, .self, .list, .elems, .head ... all died on EVERY user class
# (only .isa and .WHAT worked); and say $obj printed "Foo" where Rakudo prints Foo.new(x => 1, y => "a") (public attributes in declaration order); (2) .chr truncated to one byte (8364.chr printed a byte, chr(8364) too), .ord read one byte ("é".ord was 195,
# "€".ord 226), 5.ord and chrs(...) / .chrs did not exist; (3) True.Int was 0, so (1 == 1).Int + 1 was 1; True.Num and .Numeric printed nothing; 5.Numeric did not exist; (4) a type object was TRUE in all four truthiness entries (Int ?? "T" !! "F" gave T,
# so Int gave True); (5) push / append / prepend / unshift with no items died "error 22: undefined function called" (the *_pure arm wanted two arguments).
# THE CURE (by_name_dispatch.c, lower_raku.c): rk_mu_method answers the Mu / Any methods of an instance whose class does not define them, tried in meth_call just before the doomed procedure call; rk_obj_default_raku renders Name.new(attr => value, ...) from the public
# attributes and is the gist of an object, also inside a list, array or hash (rk_gist_str); rk_utf8_put encodes chr, ord decodes a code point and takes a non-string receiver, chrs joins a list; a Bool becomes an Int for Int / Num / Numeric / Real / abs; Numeric and Real are the
# identity on a number; rk_typeobj_name makes a type object false in rk_is_truthy, __rk_bool, __rk_bool_val and __rk_mkbool; the *_pure arm accepts a bare array; the function forms chr, ord, chrs join the lowerer's function-form table.
# NOT HERE (own rows, measured): `if $obj` takes the else branch in mode 4 for one shape (class Foo {} + class Bar { has $.x; has $.y; has $!p; method m } + `my $f = Foo.new; my $b = Bar.new; if $b {...}`; true in mode 3 and on the base build, so not from this landing); a user class's
# type object is still true (`Foo ?? 1 !! 0`) and prints Foo where Rakudo prints (Foo); attributes of a base class print before the subclass's (Rakudo: subclass first); `has @.tags` keeps a List where Rakudo has an Array; [+] over Bools; True.sum.
#
# THE WITNESS, graded in m3 (--run) and m4 (--compile + link) against a ref cut by Rakudo (/usr/bin/raku), then under SCRIP_GC_STRESS 1 3 5 in both modes.
# FAILED ONCE, measured on SCRIP 084148a1e before the cure: every witness-mode pair red.
#
# EXIT: 0 every witness matches in both modes; 1 a mismatch or a crash on a witness; 2 REFUSED (stale binary, no gcc).
# Usage: bash ../harness/scripts/test_gate_raku_the_universal_methods_of_a_user_object_chr_ord_chrs_bool_as_int_and_a_type_objects_falsity_agree_with_rakudo.sh   (~10s, no oracle at run time, no network)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_the_universal_methods_of_a_user_object_chr_ord_chrs_bool_as_int_and_a_type_objects_falsity_agree_with_rakudo"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked, so half the population is unmeasured"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/w.raku" <<'EOF'
class Foo { }
class Bar { has $.x = 1; has $.y = "a"; has $!p = 2; method m { 2 } }
my $f = Foo.new; my $b = Bar.new;
say $f.defined; say $b.Bool; say $b.so; say $b.not; say $f.gist; say $b.gist; say $b.raku; say $b.perl;
say $b.item.x; say $b.elems; say $b.head.y; say $b.list.elems; say $b.Seq.elems; say $b.self.m;
say $f; say $b; say [$b]; say [$b, $f]; say "k: {$b.gist}";
say ?$f; say !$f; say $f ~~ Foo; say $b.isa(Bar); say $b.WHAT.gist;
say Int ?? "T" !! "F"; say so Int; say ?Str; say !Int; say (Any ?? 1 !! 0);
say True.Int; say False.Int; say True.Num; say True.Numeric; say (1 == 1).Int + 1;
say 8364.chr; say "é".ord; say "€".ord; say "😀".ord; say chr(8364); say ord("€"); say 5.ord; say 12.ord; say chr(233).chars;
say chrs(72,105); say (8364,65).chrs; say chrs((72,105));
my @a = 1,2; @a.push(); @a.unshift(); @a.append(); @a.prepend(); unshift(@a); push(@a); say @a; say @a.unshift().elems;
say 5.Numeric; say 2.5.Real;
EOF
cat > "$W/w.ref" <<'EOF'
True
True
True
False
Foo.new
Bar.new(x => 1, y => "a")
Bar.new(x => 1, y => "a")
Bar.new(x => 1, y => "a")
1
1
a
1
1
2
Foo.new
Bar.new(x => 1, y => "a")
[Bar.new(x => 1, y => "a")]
[Bar.new(x => 1, y => "a") Foo.new]
k: Bar.new(x => 1, y => "a")
True
False
True
True
(Bar)
F
False
False
True
0
1
0
1
1
2
€
233
8364
128512
€
8364
53
49
1
Hi
€A
Hi
[1 2]
2
5
2.5
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
gate_verdict "$fails" "witness-mode pair(s) wrong: a user-object, chr / ord / chrs, Bool-as-Int or type-object-truthiness result that disagrees with Rakudo"
