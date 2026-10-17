#!/usr/bin/env bash
# test_gate_raku_the_sequence_operator_deduces_arithmetic_and_geometric_series_runs_generators_and_stops_at_its_endpoint_agree_with_rakudo.sh -- `1 ... 5`, `1, 3 ... 9`, `1, 2, 4 ... 64`, `1, 1, * + * ... 21`, `1, { $_ * 2 } ... 64`, `'a' ... 'e'`, `1 ...^ 5`, `1 ... * > 5`, `1, 2 ... *` (lazy, here bounded)
# (row raku-every-suite-to-100-under-nonet-ceo-1266; found by grepping Roast: 82 files use the operator, 7 of them in S03-sequence, and a probe showed `(1, 2 ... 5)` answering (1 2)).
#
# THE DEFECT, measured against Rakudo: `...` was parsed as the range operator `..` (the same TT_TO node, an Icon `to`), with the TERM before it as its left operand and nothing from the comma list: `(1, 2 ... 5)` was the list (1, 2..5) and printed (1 2); `1, 3 ... 9` printed (1 3); `0, 1, *+* ... 50` printed (0 1 ); the swallow loop of x_elem dropped the operator when it could not place it. The sequence operator is a LIST infix, looser than the comma: `1, 2, 4 ... 64` is `(1, 2, 4) ... (64)`.
# THE CURE: (rk_syntax.c x_seq, beside x_cross) `...`, `...^` and their Unicode forms are taken at the list level: the comma list built so far is the seeds, the list after the operator is the endpoint (its first element) followed by whatever should come after the sequence, and a chain `a ... b ... c` is left-associative; the range level no longer sees `...` and x_elem's swallow loop leaves it alone; (rk_tree.c rkb_sequence) the tree is __rk_seq(exclusive, seeds, end); (by_name_dispatch.c rk_sequence) THE SEEDS decide the series exactly as Rakudo does: a trailing Code (a block, `* + 2`, `* + *`, `{ $^a + $^b }`) is the generator and takes as many of the last values as its arity (rk_code_arity from the proc's parameter names); otherwise one numeric seed steps by 1 (by -1 when the endpoint is smaller), two seeds are arithmetic, three or more are arithmetic when the last differences agree, geometric when the last ratios agree (an Int ratio stays Int) and an error otherwise; non-numeric seeds step by the string increment of the previous change; THE ENDPOINT is a value (a number stops the series when it is hit exactly, included unless `...^`, and BEFORE the first value past it in the direction of travel: `1, 2, 4 ... 100` ends at 64, `1, 3, 5 ... 4` at 3, `3, 2 ... 5` is empty), a Code or WhateverCode (`* > 5`: stop after the first value for which it is true, included unless `...^`), a string, or `*` / Inf (lazy in Rakudo; here the series is cut at 1000 elements, so `.head(n)`, `[i]` and `[a..b]` of an infinite series work); the SEEDS count as values of the series (`1, 2 ... 1` is (1)).
# NOT HERE (own rows, measured): real laziness (a series with `*` is materialised to 1000 elements, an endpoint that is never hit by a Code generator runs to the same cap where Rakudo runs forever), Rat arithmetic in a series (`1, 1/2, 1/3` ... prints 0.333 not 1/3, `0.1, 0.2 ... 1` is float with a tolerance), `last` inside the generator, the type-match endpoint (`... Int`), a Junction endpoint, a descending string series ('x' ... 'ab'), the chained `1 ... 3, 7 ... 9`, Seq as the type of the result, the Unicode ellipsis in the S03-sequence/basic.t tests 122-123, and S03-sequence/{arity-2-or-more,limit-arity-2-or-more,misc,nonnumeric,exhaustive}.t.
# THE WITNESS (53 lines cut by the INSTALLED Rakudo 2022.12), graded in m3 (--run) and m4 (--compile + link), then under SCRIP_GC_STRESS 1 3 5 in both modes.
# FAILED ONCE, measured on the sitting's control build cfcfaf46d: 52 of the 52 output lines are absent or wrong.
#
# EXIT: 0 every witness matches in both modes; 1 a mismatch or a crash on a witness; 2 REFUSED (stale binary, no gcc).
# Usage: bash ../harness/scripts/test_gate_raku_the_sequence_operator_deduces_arithmetic_and_geometric_series_runs_generators_and_stops_at_its_endpoint_agree_with_rakudo.sh   (~10s, no oracle at run time, no network)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_the_sequence_operator_deduces_arithmetic_and_geometric_series_runs_generators_and_stops_at_its_endpoint_agree_with_rakudo"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked, so half the population is unmeasured"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/w.raku" <<'EOF'
say (1 ... 5);
say (5 ... 1);
say (1, 2 ... 5);
say (1, 3 ... 10);
say (1, 3 ... 9);
say (10, 8 ... 1);
say (1, 2, 4 ... 64);
say (1, 2, 4 ... 100);
say (2, 4, 8 ... 70);
say (1.5, 2 ... 4);
say (1, 2, 3 ... 3);
say (1 ...^ 5);
say (1, 3 ...^ 9);
say ('a' ... 'e');
say ('a', 'c' ... 'i');
say ('a' ... 'zz').elems;
say (1 ... * > 5);
say (1, 2 ... * >= 7);
say (1, 2 ... { $_ >= 4 });
say (1, 2 ... 2);
say (1, 2 ... 1);
say (3 ... 3);
say (1 ... 0);
say (5, 4 ... 1);
say (1, 1.5 ... 3);
say (1 ... 5, 9);
say (1, 2 ... 3, 7);
say (0, 5 ... 20);
say (1, 2 ... *).head(5);
say (1 ... *)[3];
say (2, 4 ... *)[0..4];
say (1, 1, * + * ... *).head(8);
say (1, -1 ... *).head(4);
say (1, 2, 4 ... *).head(6);
say (10, 20 ... 55);
say (1, 3, 5 ... 4);
say (3, 2 ... 5);
say (1, 1, * + * ... 21);
say (1, { $_ * 2 } ... 64);
say (1, * * 3 ... 243);
say (1, 2, { $^a + $^b } ... 21);
say (1, 1, * + * ... * > 30);
say (1, { $_ + 2 } ... * > 9);
say (1, * + 1 ... 5);
say (1, 2, * + * ... *).head(6);
my @f = 1, 1, * + * ... *; say @f[0..7];
my @a = (1, 2 ... 10); say @a.elems;
say [+] 1 ... 100;
for 1 ... 3 { print $_ }
say (1, 2, 3 ... 6).sum;
say (1 ... 10).grep(* %% 3);
my ($a, $b) = (1, 2 ... 4)[0, 3]; say "$a $b";
say (10, 9 ... 7).reverse;
EOF
cat > "$W/w.ref" <<'EOF'
(1 2 3 4 5)
(5 4 3 2 1)
(1 2 3 4 5)
(1 3 5 7 9)
(1 3 5 7 9)
(10 8 6 4 2)
(1 2 4 8 16 32 64)
(1 2 4 8 16 32 64)
(2 4 8 16 32 64)
(1.5 2 2.5 3 3.5 4)
(1 2 3)
(1 2 3 4)
(1 3 5 7)
(a b c d e)
(a c d e f g h i)
702
(1 2 3 4 5 6)
(1 2 3 4 5 6 7)
(1 2 3 4)
(1 2)
(1)
(3)
(1 0)
(5 4 3 2 1)
(1 1.5 2 2.5 3)
(1 2 3 4 5 9)
(1 2 3 7)
(0 5 10 15 20)
(1 2 3 4 5)
4
(2 4 6 8 10)
(1 1 2 3 5 8 13 21)
(1 -1 -3 -5)
(1 2 4 8 16 32)
(10 20 30 40 50)
(1 3)
()
(1 1 2 3 5 8 13 21)
(1 2 4 8 16 32 64)
(1 3 9 27 81 243)
(1 2 3 5 8 13 21)
(1 1 2 3 5 8 13 21 34)
(1 3 5 7 9 11)
(1 2 3 4 5)
(1 2 3 5 8 13)
(1 1 2 3 5 8 13 21)
10
5050
12321
(3 6 9)
1 4
(7 8 9 10)
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
gate_verdict "$fails" "witness-mode pair(s) wrong: a sequence-operator result that disagrees with Rakudo"
