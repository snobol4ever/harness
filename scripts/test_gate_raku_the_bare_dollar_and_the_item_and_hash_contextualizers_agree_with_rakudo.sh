#!/usr/bin/env bash
# test_gate_raku_the_bare_dollar_and_the_item_and_hash_contextualizers_agree_with_rakudo.sh -- THE BARE ANONYMOUS $, $(...) AND %(...), .item, List/Pair .hash, AND POSTFIX ++/-- ON AN UNDEFINED SCALAR
# (row raku-every-suite-to-100-under-nonet-ceo-1266; found by the Roast compile census: 33 of the 564 files that did not compile hit one of these first).
#
# THE DEFECTS, each measured against Rakudo: a bare `$` (the anonymous state scalar: `$++` counts 0 1 2 across calls, `($ = 10) + ($ = 20)` is 30) was a syntax error; `$(...)` and `%(...)` (the item and hash contextualizers beside `@(...)`)
# were a syntax error; `.item` had no identity method; `.hash` on a List or a Pair had no method; and `$c++` on an undefined scalar stored Nil, so `my $c; say $c++` printed nothing where Rakudo prints 0 and leaves 1.
# THE CURE: rk_tree.c rkb_var names a bare `$` `$__rk_st_anon<offset>` (the __rk_st prefix makes the lowerer register it as a global, so it persists across calls like Rakudo's implicit state `$`) and rk_post_incdec stores
# `__rk_dor(var, 0)`; rk_syntax.c r_term gets the `$(` and `%(` arms beside the `@(` arm (contextualize 'item' / 'hash'); by_name_dispatch.c rt_str_method gets the identity `.item` and `.hash` on a List or Pair (rk_hash_from_list).
# NOT HERE: `my $x = ($state = 5)` (an assignment expression as the DIRECT rhs of a local assignment is refused by graph_native_emittable_mode, on base with an explicit `state $g` too); `.hash` of an odd-sized list (Rakudo throws, SCRIP does not).
#
# THE WITNESS, graded in m3 (--run) and m4 (--compile + link) against a ref cut by Rakudo (/usr/bin/raku), then under SCRIP_GC_STRESS 1 3 5 in both modes.
# FAILED ONCE, measured on SCRIP b6c65dcb1 before the cure: every witness-mode pair red (the first bare `$` does not parse).
#
# EXIT: 0 every witness matches in both modes; 1 a mismatch or a crash on a witness; 2 REFUSED (stale binary, no gcc).
# Usage: bash ../harness/scripts/test_gate_raku_the_bare_dollar_and_the_item_and_hash_contextualizers_agree_with_rakudo.sh   (~8s, no oracle at run time, no network)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_the_bare_dollar_and_the_item_and_hash_contextualizers_agree_with_rakudo"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked, so half the population is unmeasured"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/bd.raku" <<'EOF'
say (1..4).map({ $++ }).join(",");
sub tick { $++ }
say tick(); say tick(); say tick();
sub twice { my $a = $++; my $b = $++; "$a$b" }
say twice(); say twice();
say ($ = 10) + ($ = 20);
say (1..3).map({ $ += $_ }).join(",");
my $c; say $c++; say $c++; say $c;
my $d; say $d--; say $d;
sub counter { state $n = 0; $n++ }
say counter(); say counter(); say counter();
say $(1,2,3).elems;
say %(a=>1,b=>2).keys.sort.join(",");
say %().elems;
say $(<a b>).WHAT;
say %(a=>1).WHAT;
say (a=>1).hash<a>;
say (1,2,3,4).hash.elems;
say 5.item;
say "abc".item;
say (1,2).item.elems;
say %(x=>5)<x>;
EOF
cat > "$W/bd.ref" <<'EOF'
0,1,2,3
0
1
2
00
11
30
1,3,6
0
1
2
0
-1
0
1
2
3
a,b
0
(List)
(Hash)
1
2
5
abc
2
5
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
ST=""; for w in bd; do for m in m3 m4; do ck "$w" "$m"; done; done
for ST in 1 3 5; do for w in bd; do for m in m3 m4; do ck "$w" "$m"; done; done; done
gate_verdict "$fails" "witness-mode pair(s) wrong: a bare-dollar, item or hash-contextualizer result that disagrees with Rakudo"
