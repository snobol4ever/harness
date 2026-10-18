#!/usr/bin/env bash
# test_gate_raku_the_function_forms_list_item_append_prepend_gist_head_tail_pick_unique_repeated_reduce_rotate_agree_with_rakudo.sh -- THE FUNCTION FORMS list / item / append / prepend / gist / head / tail / pick / unique / repeated / reduce / rotate
# (row raku-every-suite-to-100-under-nonet-ceo-1266; found by a function-form battery over Rakudo's core subs used by 3 or more Roast files, then confirmed with realistic arguments).
#
# THE DEFECT, each measured against Rakudo: list(1,2,3) printed the word "list" (the name fell to Icon's list builtin), item(5), gist(5), append(@a, 3, 4) and prepend(@a, 0) died "error 22: undefined function called", and head(2, (1,2,3)),
# tail(2, @a) and pick(1, (5,)) took the first argument as the list. 193 Roast files use list, 157 item, 25 append, 22 gist, 15 prepend, 12 head / tail / pick.
# THE CURE (lower_raku.c, the function-form block beside split / comb / first / roll / not / hash / slip): four shapes read from Rakudo's own definitions -- receiver first (item, gist, append, prepend, rotate: arg1.NAME(rest)); a count then the list
# (head, tail, pick: the items are the receiver, the count the argument; several items are one __rk_arr); the whole argument list (list, minmax, unique, repeated: NAME(args) is args.NAME, one argument is its own receiver); a function then the list
# (reduce, produce, classify, categorize: the items are the receiver, the function the argument).
# NOT HERE (own rows): minmax / produce / classify as METHODS (they print nothing), reduce(&[+], ...) (an infix reference as a value), cache(...) (Rakudo returns an Array), combinations(n, k) / permutations(n) as functions.
#
# THE WITNESS, graded in m3 (--run) and m4 (--compile + link) against a ref cut by Rakudo (/usr/bin/raku), then under SCRIP_GC_STRESS 1 3 5 in both modes.
# FAILED ONCE, measured on SCRIP c820b5d6b before the cure: every witness-mode pair red.
#
# EXIT: 0 every witness matches in both modes; 1 a mismatch or a crash on a witness; 2 REFUSED (stale binary, no gcc).
# Usage: bash ../harness/scripts/test_gate_raku_the_function_forms_list_item_append_prepend_gist_head_tail_pick_unique_repeated_reduce_rotate_agree_with_rakudo.sh   (~10s, no oracle at run time, no network)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_the_function_forms_list_item_append_prepend_gist_head_tail_pick_unique_repeated_reduce_rotate_agree_with_rakudo"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked, so half the population is unmeasured"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/w.raku" <<'EOF'
say list(1,2,3);
my @a = 1,2,3;
say list(@a); say list(@a).elems; say list(@a,4).elems; say list().elems;
say item(5); say item("x");
my @b = 1,2; append(@b,3,4); say @b; prepend(@b,0); say @b;
append(@b,5); say @b.elems;
say gist(5); say gist("s"); say gist(2.5);
say head(2,(1,2,3)); say head(2,@a); say tail(2,@a); say tail(1,@a); say head(1,4,5,6); say tail(2,4,5,6);
say pick(1,(5,));
say unique(1,1,2); say unique(@a,@a).elems; say repeated(1,1,2,2);
say reduce({$^a*$^b},1,2,3,4); say reduce({$^a + $^b},@a);
say rotate(@a,1); say rotate(@a,-1);
my $c = list(1,2,3).elems + head(1,(7,8)).elems; say $c;
EOF
cat > "$W/w.ref" <<'EOF'
(1 2 3)
(1 2 3)
3
2
0
5
x
[1 2 3 4]
[0 1 2 3 4]
6
5
s
2.5
(1 2)
(1 2)
(2 3)
(3)
(4)
(5 6)
(5)
(1 2)
1
(1 2)
24
6
(2 3 1)
(3 1 2)
4
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
gate_verdict "$fails" "witness-mode pair(s) wrong: a list, item, append, prepend, gist, head, tail, pick, unique, repeated, reduce or rotate function-form result that disagrees with Rakudo"
