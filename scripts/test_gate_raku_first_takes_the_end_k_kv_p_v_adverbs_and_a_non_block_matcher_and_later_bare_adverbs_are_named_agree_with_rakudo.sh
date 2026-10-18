#!/usr/bin/env bash
# test_gate_raku_first_takes_the_end_k_kv_p_v_adverbs_and_a_non_block_matcher_and_later_bare_adverbs_are_named_agree_with_rakudo.sh -- `first` WITH :end / :k / :kv / :p / :v, A NON-BLOCK MATCHER (type object, regex, value), THE FUNCTION FORM `first MATCHER, LIST, :adverbs`, AND A BARE ADVERB AFTER ANOTHER ONE IS A NAMED ARGUMENT
# (row raku-every-suite-to-100-under-nonet-ceo-1266; found by naming the functions behind the "procedure 'first' has no stackless slab" aborts of S32-list/first-{end-,}{k,kv,p,v}.t and first-end.t).
#
# THE DEFECTS, measured against Rakudo: (1) the function form `first { ... }, @list, :end, :kv` was routed to a user routine named first (none exists), so nine S32-list/first*.t files aborted "procedure 'first' has no stackless slab"; (2) `@list.first(BLOCK, :k)` ignored the adverb:
# the method form passed `:k` as a bare Bool whose name was dropped; (3) a matcher that is not code (a type object, a regex, a value) was never smartmatched; (4) in a call `f(x, :a, :b)` the SECOND bare adverb was taken as a positional argument (named_form's `first` flag), so
# `first {...}, @list, :end, :kv` lost :kv and `h(1, 2, :z, :k)` bound $k from the wrong place.
# THE CURE: (rk_tree.c) a bare colon-pair after the first of a run is named like the first, and `first` joins the methods whose bare adverbs become Pair arguments; (lower_raku.c) `__rk_named_call("first", ...)` of a program with no routine named first is lowered as the method call
# on the flattened positionals with the matcher and the adverbs as arguments; (by_name_dispatch.c __rk_arr_first) the matcher is code or smartmatched, the search runs from the end under :end, and the answer is the value, the index (:k), the (index, value) list (:kv) or the index => value pair (:p).
# NOT HERE (own rows, measured): a Range is not a runtime value (`my $r = 4..6` holds 4, so `first(4..6)` and `5 ~~ $r` fail), Rat (`3/4`, `Rat` as a matcher type), a Junction as a matcher, X::Match::Bool for a Bool matcher, Nil as a distinct value (`.first(...)` on no match prints
# Any where Rakudo prints Nil), a slurpy `*@a` beside a named parameter loses its positionals (`sub f(*@a, :$k)`), `True.raku` is "True" not Bool::True.
# THE WITNESS, graded in m3 (--run) and m4 (--compile + link) against a ref cut by Rakudo (/usr/bin/raku), then under SCRIP_GC_STRESS 1 3 5 in both modes.
# FAILED ONCE, measured on the sitting's control build cfcfaf46d (nothing landed since touches first) before the cure: every witness-mode pair red.
#
# EXIT: 0 every witness matches in both modes; 1 a mismatch or a crash on a witness; 2 REFUSED (stale binary, no gcc).
# Usage: bash ../harness/scripts/test_gate_raku_first_takes_the_end_k_kv_p_v_adverbs_and_a_non_block_matcher_and_later_bare_adverbs_are_named_agree_with_rakudo.sh   (~10s, no oracle at run time, no network)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_first_takes_the_end_k_kv_p_v_adverbs_and_a_non_block_matcher_and_later_bare_adverbs_are_named_agree_with_rakudo"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked, so half the population is unmeasured"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/w.raku" <<'EOF'
my @list = 1...10;
say @list.first({ $_ > 3 });
say @list.first({ $_ > 3 }, :k);
say @list.first({ $_ > 3 }, :kv);
say @list.first({ $_ > 3 }, :p);
say @list.first({ $_ > 3 }, :v);
say @list.first({ $_ > 3 }, :end);
say @list.first({ $_ > 3 }, :end, :k);
say @list.first({ $_ > 3 }, :end, :kv);
say @list.first({ $_ > 3 }, :end, :p);
say @list.first({ $_ > 3 }, :!end, :!k);
say @list.first({ $_ > 30 }, :k).defined;
say @list.first({ $_ > 30 }, :end, :kv).defined;
say (first { $^a % 2 }, @list, :end, :kv);
say (first { $^a % 2 }, 1, 2, 3, 4, 5, 6, 7, 8, :end, :kv);
say (first { $^a % 2 }, @list, :k);
say (first { $^a % 2 }, |@list, :end, :p);
say (first { $^a % 2 }, @list);
say first(Int, 'a', 'b', 3, 4, :k);
say first(Str, 'a', 'b', 3, 4, :end, :kv);
my @fancy = 1, 2, "Hello", 4.Num;
say @fancy.first(Str, :kv);
say @fancy.first(Str, :end, :kv);
say @fancy.first(Int, :end, :kv);
say @fancy.first(Int, :end, :!kv);
my @w = <Philosopher Goblet Prince>;
say @w.first(/o/, :kv);
say @w.first(/o/, :end, :kv);
say @w.first(/ob/, :end, :kv);
say @w.first(/l.*o/, :end, :kv);
say @w.first(/zz/, :k).defined;
say (True, False, Int).first(Bool, :end, :kv);
say first(Bool, True, False, Int, :end, :kv);
say @list.first(5, :kv);
say @list.first(5, :end, :p);
say @list.first("7", :k);
{
    my $count = 0;
    say @list.first({ $count++; $^x % 2 }, :end, :kv);
    say $count;
}
{
    my $count = 0;
    my $m = sub (Int $x) { $count++; $x > 5 };
    say @list.first($m, :p);
    say $count;
}
sub h($a, $b, :$k, :$z) { say "$a $b ", $k.gist, ' ', $z.defined ?? $z.gist !! 'unset' }
h(1, 2, :k, :z);
h(1, 2, :z, :k);
h(1, 2, :k);
EOF
cat > "$W/w.ref" <<'EOF'
4
3
(3 4)
3 => 4
4
10
9
(9 10)
9 => 10
4
False
False
(8 9)
(6 7)
0
8 => 9
1
2
(1 b)
(2 Hello)
(2 Hello)
(1 2)
2
(0 Philosopher)
(1 Goblet)
(1 Goblet)
(0 Philosopher)
False
(1 False)
(1 False)
(4 5)
4 => 5
6
(8 9)
2
5 => 6
6
1 2 True True
1 2 True True
1 2 True unset
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
gate_verdict "$fails" "witness-mode pair(s) wrong: a first() result that disagrees with Rakudo"
