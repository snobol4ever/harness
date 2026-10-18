#!/usr/bin/env bash
# test_gate_raku_reversed_meta_operator_agrees_with_rakudo.sh -- THE R META-OPERATOR SWAPS ITS OPERANDS AND REVERSES THE OPERATOR'S ASSOCIATIVITY
# (row raku-reversed-meta-operator-r, found measuring M1 WhateverCode; ceo CEO-1479).
#
# THE DEFECT: the recognizer accepted R- R/ R~ R** R< R<=> ... but the tree builder matched the operator text against each precedence level's own list, found
# no operator called "R-", and dropped the right operand: 5 R- 2 printed 5 where Rakudo prints -3. THE CURE (rk_syntax.c x_in / x_level / x_cmp / x_unary,
# rk_tree.c rkb_op_index_rev): a token whose text is R plus an operator of THAT level is that operator with its operands swapped, at the base operator's own
# precedence, and a chain of R operators groups to the RIGHT (Rakudo: 10 R- 1 R- 1 is -10, not 10) -- x_rchain.
# NOT HERE: the other meta-operators (X Z S, the negations and reductions have their own paths), R on a non-infix-level operator (R.., R,), and R= forms.
# FAILED ONCE, measured on SCRIP c39073e08: the witness prints 5 5 a 2 ... (the right operand lost) in both modes.
#
# EXIT: 0 the witness matches in both modes; 1 a mismatch or a crash; 2 REFUSED (stale binary, no gcc).
# Usage: bash ../harness/scripts/test_gate_raku_reversed_meta_operator_agrees_with_rakudo.sh   (~2s, no oracle at run time, no network)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_reversed_meta_operator_agrees_with_rakudo"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked, so half the population is unmeasured"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/rmeta.raku" <<'EOF'
say (5 R- 2);
say (5 R/ 10);
say ("a" R~ "b");
say (2 R** 3);
say (1 R< 2);
say (3 R<=> 4);
say (7 R% 3);
say (7 R%% 3);
say (2 R* 5);
say (1 R+ 2 R+ 3);
say (10 R- 1 R- 1);
say ("abc" Req "abc");
say (4 Rmin 9);
say (2 R== 2);
EOF
cat > "$W/rmeta.ref" <<'EOF'
-3
2
ba
9
False
More
3
False
10
6
-10
True
4
True
EOF
fails=0; GATE_EXAMINED=0
ck() {
    local w="$1" m="$2" out rc
    GATE_EXAMINED=$((GATE_EXAMINED + 1))
    if [ "$m" = m3 ]; then out="$(timeout -k 5 20 "$ROOT/scrip" --run "$W/$w.raku" 2>/dev/null </dev/null)"; rc=$?
    else
        if ! timeout -k 5 60 "$ROOT/scrip" --compile -o "$W/$w.s" "$W/$w.raku" </dev/null >"$W/$w.cerr" 2>&1 \
           || ! gcc -o "$W/$w.bin" "$W/$w.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread >>"$W/$w.cerr" 2>&1; then
            printf '  FAIL %-7s %s: did not build (%s)\n' "$w" "$m" "$(head -1 "$W/$w.cerr" | cut -c1-110)"; fails=$((fails + 1)); return; fi
        out="$(timeout -k 5 20 "$W/$w.bin" 2>/dev/null </dev/null)"; rc=$?
    fi
    if [ "$rc" -ge 124 ]; then printf '  FAIL %-7s %s: died rc=%s\n' "$w" "$m" "$rc"; fails=$((fails + 1)); return; fi
    if [ "$out" = "$(cat "$W/$w.ref")" ]; then printf '  ok   %-7s %s\n' "$w" "$m"
    else printf '  FAIL %-7s %s: got [%s] want [%s]\n' "$w" "$m" "$(printf '%s' "$out" | tr '\n' ' ' | cut -c1-110)" "$(tr '\n' ' ' < "$W/$w.ref" | cut -c1-110)"; fails=$((fails + 1)); fi
}
for w in rmeta; do for m in m3 m4; do ck "$w" "$m"; done; done
gate_verdict "$fails" "witness-mode pair(s) wrong: an R meta-operator that does not swap its operands as Rakudo does"
