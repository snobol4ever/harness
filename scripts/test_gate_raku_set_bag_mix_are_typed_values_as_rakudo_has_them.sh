#!/usr/bin/env bash
# test_gate_raku_set_bag_mix_are_typed_values_as_rakudo_has_them.sh -- Set, SetHash, Bag, BagHash, Mix and MixHash ARE TYPED VALUES (DATA records of elements, weights and an index), the set operators and the subset / membership relations act on them, and set() / bag() / mix() / Set.new / .Set / .Bag / .Mix build them
# (row raku-every-suite-to-100-under-nonet-ceo-1266; found by probing 57 expressions of S02-types/set.t, bag.t, mix.t and S03-operators/set.t against Rakudo -- 54 differed).
#
# THE DEFECTS, each measured against Rakudo: `set <a b>` printed but its .elems was 0 (a list of keys behind a name, nothing counted); bag / mix did not exist; __rk_set_uni / int / dif / sym / sum / mul were named by the parser and had no runtime arm; the infixes
# (elem) (cont) (<) (<=) (>) (>=) (==) and the Unicode set operators and relations were not in the operator tables, so `$a ∈ $b` was silently dropped to `$a`; Set.new / Bag.new built an empty record; a Set subscript, truthiness and gist did not exist.
# THE CURE (by_name_dispatch.c, lower_raku.c, rk_tree.c): six DATA types behind one QuantHash section (rk_qh_*) holding the elements, their weights and a key->position index; the constructors set() / bag() / mix() and Set.new ... MixHash.new count their items (a Pair is an element),
# the coercions .Set .Bag .Mix .SetHash .BagHash .MixHash read Pairs and Hashes as weights; subscripts, :exists, :delete, truthiness, gist / Str / raku, ===, eqv, ~~ Set / Setty / Baggy, pick / roll / grab, the six set operators (|) (&) (-) (^) (+) (.) with their Unicode names,
# the relations (elem) (cont) (<) (<=) (>) (>=) (==) and their negations and Unicode names, with the result kind Rakudo gives (a Mix beats a Bag beats a Set; (+) and (.) are always baggy); the immutable types refuse a store with Rakudo's own message.
# NOT HERE (own rows): numification (+$set is still True), Seq as a distinct flavor of List (.pairs / .keys return a List), Set of objects other than strings and numbers, the typed hash behind .hash, `%(...)` as an expression.
#
# THE WITNESS, graded in m3 (--run) and m4 (--compile + link) against a ref cut by Rakudo (/usr/bin/raku), then under SCRIP_GC_STRESS 1 3 5 in both modes.
# FAILED ONCE, measured on the base binary before the cure: see the row baton ledger.
#
# EXIT: 0 every witness matches in both modes; 1 a mismatch or a crash on a witness; 2 REFUSED (stale binary, no gcc).
# Usage: bash ../harness/scripts/test_gate_raku_set_bag_mix_are_typed_values_as_rakudo_has_them.sh   (~20s, no oracle at run time, no network)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_set_bag_mix_are_typed_values_as_rakudo_has_them"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked, so half the population is unmeasured"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/qh.raku" <<'EOF'
sub show($x) { $x.pairs.map({ .key ~ "=" ~ .value }).sort.join(",") }
my $s = set <a b c>;
my $b = bag <a b a c a>;
my $mx = (a=>0.5, b=>2).Mix;
say $s.elems; say $s.total; say $s<a>; say $s<z>; say $s<a>:exists; say $s<z>:exists; say $s.keys.sort.join(",");
say $b.elems; say $b.total; say $b<a>; say $b<z>; say show($b); say $b.values.sort.join(","); say $b.kv.elems; say $b.antipairs.elems;
say $mx.total; say $mx<a>; say $mx<b>; say $mx<z>; say show($mx);
say set().elems; say so set(); say so $s; say so bag(); say ?$b; say (set() ?? "t" !! "f"); say ($s ?? "t" !! "f");
say set(<a>).gist; say set(<a>).raku; say set(<a>).Str; say bag(<a a>).gist; say bag(<a a>).Str; say bag(<a a>).raku; say mix(<a>).raku; say (a=>0.5).Mix.gist;
say set(<a>).WHAT; say bag(<a>).WHAT; say mix(<a>).WHAT; say SetHash.new(<a>).WHAT; say BagHash.new(<a>).WHAT; say MixHash.new(<a>).WHAT;
say $s ~~ Set; say $s ~~ Setty; say $b ~~ Bag; say $b ~~ Baggy; say $b ~~ Set; say $mx ~~ Mix; say $mx ~~ Baggy;
say $s.Bag.total; say $b.Set.elems; say $b.Mix.total; say $s.Set === $s;
say show(<a b a>.Bag); say show(<a b a>.Set); say show("abc".Set); say show((a=>3,b=>2).Bag); say show((a=>3,b=>0).Set); say show((a=>3,b=>0).Bag); say show((a=>1.5,b=>2).Mix);
say show(Set.new(<a b a>)); say show(Bag.new(<a b a>)); say show(Mix.new(<a b a>)); say show(BagHash.new(<a b a>)); say show(SetHash.new(<a b a>));
say show(set(1,2,2,3)); say show(bag(1,2,2,3)); say set(1,2,3).keys.sort.join(",");
say show(set(<a b c>) (|) set(<c d>)); say show(set(<a b c>) (&) set(<c d>)); say show(set(<a b c>) (-) set(<c d>)); say show(set(<a b c>) (^) set(<c d>));
say show(set(<a b c>) ∪ set(<c d>)); say show(set(<a b c>) ∩ set(<c d>)); say show(set(<a b c>) ∖ set(<c d>)); say show(set(<a b c>) ⊖ set(<c d>));
say show(bag(<a b c c>) (|) bag(<c d c>)); say show(bag(<a b c c>) (&) bag(<c d c>)); say show(bag(<a b c c>) (+) bag(<c d c>)); say show(bag(<a b c c>) (-) bag(<c d c>)); say show(bag(<a b c c>) (.) bag(<c d c>));
say show(bag(<a b c c>) ⊎ bag(<c d c>)); say show(bag(<a b c c>) ⊍ bag(<c d c>));
say show(set(<a b c>) (+) set(<c d>)); say show(set(<a b c>) (.) set(<c d>)); say show(set(<a b>) (|) bag(<b b>)); say show(set(<a b>) (+) set(<b>));
say show((1,2,3) (|) (2,5)); say show((1,2,3) (&) (2,5));
say set(<a b>) (<=) set(<a b c>); say set(<a b>) (<) set(<a b c>); say set(<a b>) (<) set(<a b>); say set(<a b c>) (>=) set(<a b>); say set(<a b c>) (>) set(<a b c>);
say set(<a b>) ⊆ set(<a b c>); say set(<a b>) ⊂ set(<a b>); say set(<a b c>) ⊇ set(<a b>); say set(<a b c>) ⊃ set(<a b>); say set(<a b c>) ⊄ set(<a b>); say set(<a b>) ⊈ set(<a b>); say set(<a b>) ⊉ set(<a b c>); say set(<a b>) ⊅ set(<a b>);
say (1,2,3) (<=) (1,2,3,4); say bag(<a a b>) (<=) bag(<a a b c>); say bag(<a a a>) (<=) bag(<a a b c>); say bag(<a a b c>) (>=) bag(<a a>);
say "a" (elem) set(<a b>); say "z" ∈ set(<a b>); say "z" ∉ set(<a b>); say set(<a b>) (cont) "a"; say set(<a b>) ∋ "a"; say set(<a b>) ∌ "a";
say set(<a b>) (==) set(<b a>); say set(<a b>) ≡ set(<b a>); say set(<a b>) ≢ set(<b a>); say set(<a b>) ≡ set(<a>); say bag(<a b>) (==) set(<a b>); say bag(<a a>) (==) bag(<a>);
say set(<a b>) eqv set(<b a>); say bag(<a b>) eqv set(<b a>); say set(<a b>) === set(<b a>); say set(<a b>) === set(<a>);
my $sh = SetHash.new(<a b>); $sh<c> = True; $sh<a> = False; say $sh.keys.sort.join(","); $sh<b>:delete; say $sh.elems; say $sh.keys.join(","); say $sh<c>:exists;
my $bh = BagHash.new(<a b a>); $bh<c> = 5; $bh<a>--; $bh<b>++; $bh<a>:delete; say show($bh); say $bh.total; say $bh.elems;
my $mh = MixHash.new(<a b>); $mh<a> = 2.5; $mh<z> = -1; say show($mh); say $mh.total; say $mh.elems;
my $one = set <a>; my $bg = bag <a a a>;
try { $one<c> = True }; say $!.message;
try { $bg<a> = 3 }; say $!.message;
try { $bg<z> = 3 }; say $!.message;
try { $one.grab }; say $!.message;
try { $one<a>:delete }; say $!.message;
say $b.pick(*).sort.join(","); say $b.pick(2).elems; say $b.pick(10).elems; say $b.roll(5).elems; say $s.pick ~~ Str; say $s.pick(*).elems;
my $g = BagHash.new(<a a b>); my $x = $g.grab; say $g.total; say $g.grab(*).elems; say $g.elems;
for bag(<a a b>).pairs.sort { .say }
for $s.keys.sort -> $k { print $k, " " }
say "";
say $s.pairs.map({ .value }).join(","); say $b.keys.elems; say $b.sort.map({ .key ~ .value }).join("");
EOF
cat > "$W/qh.ref" <<'EOF'
3
3
True
False
True
False
a,b,c
3
5
3
0
a=3,b=1,c=1
1,1,3
6
3
2.5
0.5
2
0
a=0.5,b=2
0
False
True
False
True
f
t
Set(a)
Set.new("a")
a
Bag(a(2))
a(2)
("a"=>2).Bag
("a"=>1).Mix
Mix(a(0.5))
(Set)
(Bag)
(Mix)
(SetHash)
(BagHash)
(MixHash)
True
True
True
True
False
True
True
3
3
5
True
a=2,b=1
a=True,b=True
abc=True
a=3,b=2
a=True
a=3
a=1.5,b=2
a=True,b=True
a=2,b=1
a=2,b=1
a=2,b=1
a=True,b=True
1=True,2=True,3=True
1=1,2=2,3=1
1,2,3
a=True,b=True,c=True,d=True
c=True
a=True,b=True
a=True,b=True,d=True
a=True,b=True,c=True,d=True
c=True
a=True,b=True
a=True,b=True,d=True
a=1,b=1,c=2,d=1
c=2
a=1,b=1,c=4,d=1
a=1,b=1
c=4
a=1,b=1,c=4,d=1
c=4
a=1,b=1,c=2,d=1
c=1
a=1,b=2
a=1,b=2
1=True,2=True,3=True,5=True
2=True
True
True
False
True
False
True
False
True
True
True
False
True
True
True
True
False
True
True
False
True
True
True
False
True
True
False
False
True
False
True
False
True
False
b,c
1
c
True
b=2,c=5
7
2
a=2.5,b=1,z=-1
2.5
3
Cannot modify an immutable Set (Set(a))
Cannot modify an immutable Int (3)
Cannot modify an immutable Int (0)
Cannot call 'grab' on an immutable 'Set'
Cannot call 'DELETE-KEY' on an immutable 'Set'
a,a,a,b,c
2
5
5
True
3
2
2
0
a => 2
b => 1
a b c 
True,True,True
3
a3b1c1
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
ST=""; for w in qh; do for m in m3 m4; do ck "$w" "$m"; done; done
for ST in 1 3 5; do for w in qh; do for m in m3 m4; do ck "$w" "$m"; done; done; done
gate_verdict "$fails" "witness-mode pair(s) wrong: a Set / Bag / Mix value, operator or relation that disagrees with Rakudo"
