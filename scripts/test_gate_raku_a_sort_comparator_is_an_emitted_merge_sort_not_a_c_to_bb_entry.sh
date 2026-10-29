#!/usr/bin/env bash
# test_gate_raku_a_sort_comparator_is_an_emitted_merge_sort_not_a_c_to_bb_entry.sh -- A TWO-PARAMETER SORT COMPARATOR IS CALLED FROM EMITTED CODE: NO C-TO-BB ENTRY PER COMPARISON
# (row raku-a-sort-comparator-block-is-entered-from-c-once-per-comparison-the-non-tail-c-to-bb-road-ceo-986-phase-2-ceo-1533, routed by the ceo CEO-1533; Lon 2026-09-20 verbatim: "Ensure that BB's are never called from C except the first time at initial start.").
#
# THE DEFECT: `@a.sort({ $^a <=> $^b })` ran __rk_arr_sort, a C sort loop that called the comparator block through rt_call_proc_descr once per comparison (rt_c2bb_hit site descr.enter.lex): 15 C-to-BB entries over both modes for
# five numbers (30 on the row's witness at 57f4cf251). THE CURE (lower_raku.c rk_sort_cmp_walk, rk_sort_helper): after the anonymous blocks are hoisted, a `.sort` method call whose argument is a two-parameter block is rewritten to a call of a
# per-site helper sub __rk_sortc_<block> that the lowerer builds as a tree -- a stable bottom-up merge sort over a copy of the receiver whose comparison is a DIRECT call of the block's proc by name, exactly the
# shape the emitted map / grep / first / reduce loops use -- so the whole sort is emitted code and the comparator is a box call. A hash receiver, a one-parameter (key) block and the no-block sort are untouched.
# NOT HERE: `.sort(&by)` and `.sort(-> $x, $y { })` do not parse (Confused) and `sort { } , @a` (the function form) is refused by the compile guard on `$^a` -- both measured, both separate defects; the other non-tail C-to-BB roads of CEO-986 phase 2 (TWEAK/BUILD,
# callsame/callwith, the meth_call redispatch, the Str coercion, the map/grep/first block loops) stay on the cfo's list.
#
# THE WITNESS, graded in m3 (--run) and m4 (--compile + link) against a ref cut by Rakudo (/usr/bin/raku), with SCRIP_C2BB_TRACE on every run and the entry count required to be 0, then under SCRIP_GC_STRESS 1 3 5 in both modes:
# ascending / descending numbers, strings by cmp, a stable sort by first letter, an Int-valued comparator, a list literal receiver, the empty and one-element lists, a 40-element sort, the receiver left unchanged, a sort inside a sub, a chained map, a two-key comparator.
# FAILED ONCE, measured on SCRIP 966e0d06b before the cure: 8 of 8 witness-mode pairs red, 1047 C-to-BB entries per run (the output was already equal to Rakudo).
#
# EXIT: 0 every witness matches in both modes with 0 entries; 1 a mismatch, a crash or an entry; 2 REFUSED (stale binary, no gcc).
# Usage: bash ../harness/scripts/test_gate_raku_a_sort_comparator_is_an_emitted_merge_sort_not_a_c_to_bb_entry.sh   (~8s, no oracle at run time, no network)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_a_sort_comparator_is_an_emitted_merge_sort_not_a_c_to_bb_entry"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked, so half the population is unmeasured"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/sortcmp.raku" <<'EOF'
my @a = 5, 3, 9, 1, 7, 3, 8, 2;
say @a.sort({ $^a <=> $^b });
say @a.sort({ $^b <=> $^a });
say @a.sort({ $^a <=> $^b }).join(",");
say <b a d c e>.sort({ $^a cmp $^b });
say <b a d c e>.sort({ $^b cmp $^a });
say <a1 b2 a3 c4 b5 a6>.sort({ $^a.substr(0,1) cmp $^b.substr(0,1) });
say (3, 1, 2).sort({ $^a <=> $^b });
say (3, 1, 2).sort({ $^b - $^a });
say [].sort({ $^a <=> $^b });
say (7,).sort({ $^a <=> $^b });
my @big = (1..40).map({ ($_ * 17) % 41 });
say @big.sort({ $^a <=> $^b }).join(" ");
say @big.sort({ $^b <=> $^a })[0..4];
my @s = @a.sort({ $^a <=> $^b }); say @s; say @s.elems;
sub top3(@x) { return @x.sort({ $^b <=> $^a })[0..2] }
say top3(@a);
say @a;
say @a.sort({ $^a <=> $^b }).map({ $_ * 2 }).join(",");
say (@a.sort({ $^a <=> $^b }), @a.sort({ $^b <=> $^a })).elems;
my @words = <pear fig apple kiwi banana>;
say @words.sort({ $^a.chars <=> $^b.chars });
say @words.sort({ $^a.chars <=> $^b.chars || $^a cmp $^b });
EOF
cat > "$W/sortcmp.ref" <<'EOF'
(1 2 3 3 5 7 8 9)
(9 8 7 5 3 3 2 1)
1,2,3,3,5,7,8,9
(a b c d e)
(e d c b a)
(a1 a3 a6 b2 b5 c4)
(1 2 3)
(3 2 1)
()
(7)
1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40
(40 39 38 37 36)
[1 2 3 3 5 7 8 9]
8
(9 8 7)
[5 3 9 1 7 3 8 2]
2,4,6,6,10,14,16,18
2
(fig pear kiwi apple banana)
(fig kiwi pear apple banana)
EOF
fails=0; GATE_EXAMINED=0
ck() {
    local w="$1" m="$2" out rc
    GATE_EXAMINED=$((GATE_EXAMINED + 1))
    if [ "$m" = m3 ]; then out="$(env ${ST:+SCRIP_GC_STRESS=$ST} SCRIP_C2BB_TRACE="$W/$w.$m.tr" timeout -k 5 120 "$ROOT/scrip" --run "$W/$w.raku" 2>/dev/null </dev/null)"; rc=$?
    else
        if ! timeout -k 5 60 "$ROOT/scrip" --compile --out="$W/$w.s" "$W/$w.raku" </dev/null >"$W/$w.cerr" 2>&1 \
           || ! gcc -o "$W/$w.bin" "$W/$w.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread >>"$W/$w.cerr" 2>&1; then
            printf '  FAIL %-7s %s: did not build (%s)\n' "$w" "$m" "$(head -1 "$W/$w.cerr" | cut -c1-110)"; fails=$((fails + 1)); return; fi
        out="$(env ${ST:+SCRIP_GC_STRESS=$ST} SCRIP_C2BB_TRACE="$W/$w.$m.tr" timeout -k 5 120 "$W/$w.bin" 2>/dev/null </dev/null)"; rc=$?
    fi
    if [ "$rc" -ge 124 ]; then printf '  FAIL %-7s %s: died rc=%s\n' "$w" "$m" "$rc"; fails=$((fails + 1)); return; fi
        ent=0; [ -s "$W/$w.$m.tr" ] && ent=$(grep -c . "$W/$w.$m.tr"); rm -f "$W/$w.$m.tr"
    if [ "$ent" != 0 ]; then printf '  FAIL %-7s %s: %s C-to-BB entries (want 0)\n' "$w" "$m" "$ent"; fails=$((fails + 1)); return; fi
    if [ "$out" = "$(cat "$W/$w.ref")" ]; then printf '  ok   %-7s %s%s\n' "$w" "$m" "${ST:+ stress=$ST}"
    else printf '  FAIL %-7s %s: got [%s] want [%s]\n' "$w" "$m" "$(printf '%s' "$out" | tr '\n' ' ' | cut -c1-110)" "$(tr '\n' ' ' < "$W/$w.ref" | cut -c1-110)"; fails=$((fails + 1)); fi
}
ST=""; for w in sortcmp; do for m in m3 m4; do ck "$w" "$m"; done; done
for ST in 1 3 5; do for w in sortcmp; do for m in m3 m4; do ck "$w" "$m"; done; done; done
gate_verdict "$fails" "witness-mode pair(s) wrong: a sort result that disagrees with Rakudo, or a C-to-BB entry the comparator still makes"
