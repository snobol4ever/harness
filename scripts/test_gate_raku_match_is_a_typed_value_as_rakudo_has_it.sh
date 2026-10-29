#!/usr/bin/env bash
# test_gate_raku_match_is_a_typed_value_as_rakudo_has_it.sh -- A MATCH IS A VALUE: ~~ AND m// RETURN IT, $/ HOLDS IT, AND ITS PARTS ARE READ THE WAY RAKUDO READS THEM
# (row raku-every-suite-to-100-under-nonet-ceo-1266, Lon 2026-09-25: "use IPC sync-step monitor to crawl the test suites to 100%"; first-refusal census of the 630 Roast files that still refuse: $/ 41).
#
# THE DEFECT: there was no Match value. `my $m = "abcb" ~~ /(b)(c)/; say $m` printed 1; `$/` was refused by the compile guard ("variable '/' is read but never assigned"); $m.from, .to, .orig,
# $m[0], $m<x>, m:g lists of Match, "$0 and $/" interpolation, .match(/re/) and eq/~ on a Match were all absent. Only the runtime's single g_match fed $0 and $<x> (re_capture, re_named_capture).
# THE CURE: a Match is a typed record Match(orig,from,to,ok,text,positional,named) built from g_match by rk_match_obj_in (by_name_dispatch.c): positional is a DT_A of sub-Match values (a quantified group is a
# nested list of them), named is a DT_T name -> Match or list of Match, from/to count code points, and no field holds a delimiter-joined aggregate (the old grammar-only record kept its captures as a
# tab/newline string). ~~ and m:g return it; `$/` is the provider __rk_pre("/") rebuilding it from g_match (no new global); a condition (if/while/unless/ternary/&&) tests with re_test, which sets g_match and
# builds nothing; .match(/re/ [, :g]) is the same smartmatch node; subscripts [i] and <k> read the positional and named slots; "$0", "$/" and "$<k>" interpolate; a Match stringifies as its text in ~, eq,
# join and the Cool string methods and as its gist (the nested ｢..｣ tree) and .raku through say/.gist/.raku. A grammar's .parse result is the same record with named captures only.
# NOT HERE (own rows): a capture group nested inside another capture group is flat (no .caps tree), .ast/.made, a failed match assigned to a scalar says Nil where Rakudo says (Any), \w is ASCII-only,
# the Map type of .hash, and a SUB's own $/ (the one g_match is the last match anywhere).
#
# THE WITNESSES, each graded in m3 (--run) and m4 (--compile + link) against a ref cut by Rakudo (/usr/bin/raku): value (the fields, gist, .raku, nested and quantified captures, prematch/postmatch,
# code-point offsets), slash ($/ and $0 reads, interpolation, eq, string methods), multi (m:g, .match, join).
# Then the same three witnesses under SCRIP_GC_STRESS 1 3 5, both modes (the Match is built inside one runtime call and every capture, list and table reaches the collector as a typed slot).
# FAILED ONCE, measured on SCRIP 57f4cf251 before the cure: 6 of 6 witness-mode pairs red (value prints (Int) 1 1 Nil; slash and m4 refused at the guard on $/; multi prints Any).
#
# EXIT: 0 every witness matches in both modes; 1 a mismatch or a crash on a witness; 2 REFUSED (stale binary, no gcc).
# Usage: bash ../harness/scripts/test_gate_raku_match_is_a_typed_value_as_rakudo_has_it.sh   (~15s, no oracle at run time, no network)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_match_is_a_typed_value_as_rakudo_has_it"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked, so half the population is unmeasured"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/value.raku" <<'EOF'
my $m = "abcb" ~~ /(b)(c)/;
say $m.WHAT; say $m.from; say $m.to; say $m.pos; say $m.orig; say $m.Str; say $m.gist; say $m.raku;
say $m[0].from; say $m[1]; say $m.elems; say $m.list.elems; say $m.hash.elems;
my $n = "2024-10-07" ~~ /$<y>=(\d+)'-'$<m>=(\d+)/;
say $n; say $n<y>; say $n<m>.from; say $n.keys.sort.join(","); say $n.hash.elems;
my $q = "aaa" ~~ /(a)+/; say $q; say $q[0].elems; say $q[0][1].from;
my $s = "x" ~~ /y/; say so $s; say ("x" ~~ /y/) ?? "yes" !! "no";
say ("abcd" ~~ /b/).prematch; say ("abcd" ~~ /b/).postmatch;
say ("héllo wo" ~~ /w/).from; say ("héllo wo" ~~ /w/).to;
EOF
cat > "$W/value.ref" <<'EOF'
(Match)
1
3
3
abcb
bc
｢bc｣
 0 => ｢b｣
 1 => ｢c｣
Match.new(:orig("abcb"), :from(1), :pos(3), :list((Match.new(:orig("abcb"), :from(1), :pos(2)), Match.new(:orig("abcb"), :from(2), :pos(3)))))
1
｢c｣
2
2
0
｢2024-10｣
 y => ｢2024｣
 m => ｢10｣
｢2024｣
5
m,y
2
｢aaa｣
 0 => ｢a｣
 0 => ｢a｣
 0 => ｢a｣
3
1
False
no
a
cd
6
7
EOF
cat > "$W/slash.raku" <<'EOF'
"hello world" ~~ /(w\w+)/;
say $/; say $0; say $/[0].Str; say "got $0 in $/"; say ~$/; say $/ eq "world"; say $/.chars; say $/.uc; say $/.from;
if "foo bar" ~~ /(\w+) \s (\w+)/ { say "$0|$1"; say $/.Str; say $/[1].to }
"2024-10" ~~ /$<y>=(\d+)'-'$<m>=(\d+)/; say "$<y>/$<m>"; say $/<y>;
my $r = "ab" ~~ /(a)(b)/; say $r eq "ab"; say "[$r]";
EOF
cat > "$W/slash.ref" <<'EOF'
｢world｣
 0 => ｢world｣
｢world｣
world
got world in world
world
True
5
WORLD
6
foo|bar
foo bar
7
2024/10
｢2024｣
True
[ab]
EOF
cat > "$W/multi.raku" <<'EOF'
for "a1b22" ~~ m:g/(\d+)/ { say $_; say $_.from }
my @ms = "a1b22".match(/\d+/, :g); say @ms.raku; say @ms.elems; say @ms[1].Str;
say "abc".match(/b/).from; say "abc".match(/b/);
say ("a1b22" ~~ m:g/\d+/).elems; say ("a1b22" ~~ m:g/\d+/).join(",");
EOF
cat > "$W/multi.ref" <<'EOF'
｢1｣
 0 => ｢1｣
1
｢22｣
 0 => ｢22｣
3
[Match.new(:orig("a1b22"), :from(1), :pos(2)), Match.new(:orig("a1b22"), :from(3), :pos(5))]
2
22
1
｢b｣
2
1,22
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
ST=""; for w in value slash multi; do for m in m3 m4; do ck "$w" "$m"; done; done
for ST in 1 3 5; do for w in value slash multi; do for m in m3 m4; do ck "$w" "$m"; done; done; done
gate_verdict "$fails" "witness-mode pair(s) wrong: a Match value, $/ or a capture read that disagrees with Rakudo"
