#!/usr/bin/env bash
# test_gate_raku_the_list_methods_permutations_combinations_rotor_invert_maxpairs_minpairs_skip_roll_produce_any_all_fmt_and_minmax_agree_with_rakudo.sh -- THE LIST METHODS SCRIP LACKED: permutations, combinations, rotor, pairup, invert, maxpairs, minpairs, skip, roll, produce, unique(:as), .any / .all / .one / .none, fmt, is-lazy, tail, minmax, and pairs / antipairs of a scalar
# (row raku-every-suite-to-100-under-nonet-ceo-1266; found by a census of the 684 zero-argument methods of Rakudo's core types on five receivers (a list, a string, an Int, a Num, a Hash): 744 calls Rakudo accepts, 401 that scrip did not, 129 distinct names; ranked by how many Roast files call them).
#
# THE DEFECT, measured against Rakudo: each of these made the STATEMENT QUIETLY FAIL (meth_call's tail answered FAILDESCR, or the call was never dispatched): `(1,2,3).permutations` (28 Roast files), `.combinations(2)`, `.rotor(2)`, `.invert`, `.maxpairs` / `.minpairs`, `.skip`, `.roll`, `.produce(&[+])`, `.any` / `.all` / `.one` / `.none` as methods, `.fmt("%02d")` printed 00 for every element, `.tail` answered a one-element list (3) where Rakudo answers the element, `.minmax` printed nothing, `5.pairs` / `"a".antipairs`, and `.unique(:as(* %% 2))` took the pair for a list element ("as").
# THE CURE: (by_name_dispatch.c rk_list_more_methods, called first for a list receiver) permutations by the lexicographic next-permutation of the positions (up to 9 elements, the lazy rest is not here), combinations of size n, of every size, or of a size range (a Range value from the previous change), rotor with Int / Pair / cycle arguments and :partial (rk_tree.c passes rotor's `:partial` as a Pair like first's adverbs), pairup, invert (a list value expands), maxpairs / minpairs, skip, roll, the four junction constructors, fmt with a separator, is-lazy, tail with no argument, minmax as a Range value, produce through a rooted callback loop, and the :as adverb of unique / squish / repeated through the same loop; rt_str_method answers pairs / antipairs of a scalar as a one-element list.
# NOT HERE (own rows, measured; the census names the rest): toggle, pairup's odd-count message needs Rakudo's "in block" trace, a Junction compared with an operator (`(1,2,3).all > 0` answers True where Rakudo answers the Junction all(True, True, True)), Hash fmt's newline separator, lazy permutations of more than 9 elements, roll(*), .unique(:with), the hyper / race / lazy / of / default / keyof / dynamic / Supply / Version / encode / path / iterator / serial / tree / uniname / uniprop families, and the numeric methods of a List or Hash (`(3,1,2).sqrt` is sqrt of the element count).
# THE WITNESS (45 lines cut by the INSTALLED Rakudo 2022.12), graded in m3 (--run) and m4 (--compile + link), then under SCRIP_GC_STRESS 1 3 5 in both modes.
# FAILED ONCE, measured on the sitting's control build cfcfaf46d: the statements above print nothing or the wrong value (the control gets 37 of the 45 lines wrong or absent).
#
# EXIT: 0 every witness matches in both modes; 1 a mismatch or a crash on a witness; 2 REFUSED (stale binary, no gcc).
# Usage: bash ../harness/scripts/test_gate_raku_the_list_methods_permutations_combinations_rotor_invert_maxpairs_minpairs_skip_roll_produce_any_all_fmt_and_minmax_agree_with_rakudo.sh   (~10s, no oracle at run time, no network)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_the_list_methods_permutations_combinations_rotor_invert_maxpairs_minpairs_skip_roll_produce_any_all_fmt_and_minmax_agree_with_rakudo"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked, so half the population is unmeasured"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/w.raku" <<'EOF'
say (1,2,3).permutations;
say (1,2,3).permutations.elems;
say (1,2,3).combinations(2);
say (1,2,3).combinations;
say (1,2,3).combinations(1..2);
say <a a b b b c a>.squish;
say <a b b c c c>.squish(:as(*.uc));
say (1,2,2,3,1).unique;
say (1,2,2,3,1).unique(:as(* %% 2));
say (1,2,2,3,1).repeated;
say (1,2,3,4).rotor(2);
say (1,2,3,4,5).rotor(2, :partial);
say (1,2,3,4,5).rotor(2 => -1);
say (a=>1,b=>2).invert;
say {a=>1,b=>2}.invert;
say (3,1,4,1,5).maxpairs;
say (3,1,4,1,5).minpairs;
say (1,2,3,4).skip;
say (1,2,3,4).skip(2);
say (1,2,3).roll.defined;
say (1,2,3).roll(5).elems;
say 5.pairs;
say "a".antipairs;
say (1,2,3).fmt("%02d");
say (1,2,3).fmt("%d", "-");
say (1,2).any.WHAT;
say (1,2,3).is-lazy;
say (1,2,3).tail(2);
say (1,2,3).tail;
say (1,2,3,4).batch(2);
say (1,2,3).antipairs;
say (1,2,3).pairs;
say (1,2,3).produce(&[+]);
say (3,1,2).minmax;
say (1,2,3,4).combinations(2).elems;
say (1,2,3).permutations.map(*.join).join(",");
say <a b c d>.rotor(2, 1 => 1);
say (1,2,3).any.WHAT;
say (3,1,2).minmax.WHAT;
say (a=>1,b=>(2,3)).invert;
say (1,2,3).fmt("%d", ",");
say ().permutations;
say (1,).combinations;
say (1,2,3,4,5,6).rotor(3);
say (1,2,3,4,5,6).rotor(2, 2);
EOF
cat > "$W/w.ref" <<'EOF'
((1 2 3) (1 3 2) (2 1 3) (2 3 1) (3 1 2) (3 2 1))
6
((1 2) (1 3) (2 3))
(() (1) (2) (3) (1 2) (1 3) (2 3) (1 2 3))
((1) (2) (3) (1 2) (1 3) (2 3))
(a b c a)
(a b c)
(1 2 3)
(1 2)
(2 1)
((1 2) (3 4))
((1 2) (3 4) (5))
((1 2) (2 3) (3 4) (4 5))
(1 => a 2 => b)
(1 => a 2 => b)
(4 => 5)
(1 => 1 3 => 1)
(2 3 4)
(3 4)
True
5
(0 => 5)
(a => 0)
01 02 03
1-2-3
(Junction)
False
(2 3)
3
((1 2) (3 4))
(1 => 0 2 => 1 3 => 2)
(0 => 1 1 => 2 2 => 3)
(1 3 6)
1..3
6
123,132,213,231,312,321
((a b) (c))
(Junction)
(Range)
(1 => a 2 => b 3 => b)
1,2,3
(())
(() (1))
((1 2 3) (4 5 6))
((1 2) (3 4) (5 6))
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
gate_verdict "$fails" "witness-mode pair(s) wrong: a list-method result that disagrees with Rakudo"
