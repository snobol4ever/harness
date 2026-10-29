#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_sno_goto_operand_the_sc_parser_prints_the_c_parsers_tree.sh -- THE .sc PARSER AND THE C PARSER AGREE ON A GOTO OPERAND THAT IS AN EXPRESSION
# (hq_raku 2026-10-28, row snobol4-the-sc-parser-takes-a-goto-operand-that-is-an-expression-as-the-c-parser-does; the C side is SCRIP 716bddf56,
# CEO-1926). The C parser hands the goto field's parenthesised operand to the statement grammar unless it is one of the legacy shapes (a label, $L,
# $'s', $(args), $A[i], $A<i>, F(args) with no operator character in the arguments), then classifies the tree: a value form (a literal, a defined
# operator, a concatenation, an alternation, a match, an assignment, unary - ~ + ? . @) is wrapped in TT_NAME, which the lowerer reads as error 212; a bare
# variable is the label; $$X loses one indirection; any other name form (A[1], *X, &K, (X), X @ Y) is the expression tree itself. bootstrap/
# parser_snobol4.sc (Target / GoInner) still reads only the legacy shapes, so it refuses the rest as a parse error where the C parser prints a tree.
# THE INSTRUMENT is the one test_gate_snocone_parsers_match_the_c_parsers_tree_for_tree.sh uses, on 22 one-statement programs written here: out/parser_snobol4
# prints PARSER_TREE_HASH=1 and the .sc chain compiled once to a mode-4 binary prints the same number; a file both refuse agrees, a file only one refuses
# or whose hashes differ is a DISAGREE and is named. The 22 operands are the 17 cells of test_gate_sno_a_value_in_a_by_name_context_is_error_212 plus (X),
# $$X, F(1 + 2), $(A + B) and X @ Y -- the same list as the corpus witness ladder__rung05_goto_a_value_operand_is_error_212_a_name_form_compiles_...
# rc 0 all agree, 1 a disagreement, 2 could not measure.
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP"; exit 2; }
cd "$ROOT" || exit 2
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
B="$ROOT/bootstrap"; CHAIN="$B/global.sc $B/case.sc $B/assign.sc $B/match.sc $B/counter.sc $B/stack.sc $B/tree.sc $B/ShiftReduce.sc $B/tdump.sc $B/gen.sc $B/qize.sc $B/semantic.sc $B/omega.sc $B/trace.sc"
for f in $CHAIN "$B/parser_snobol4.sc"; do [ -f "$f" ] || { echo "⛔ GATE REFUSE(2) [$G]: chain file missing: $f"; exit 2; }; done
. "$HERE/lib_declared_arena.sh" || { echo "⛔ GATE REFUSE(2) [$G]: cannot load lib_declared_arena.sh"; exit 2; }
( . "$HERE/lib_build_currency.sh" && assert_parser_current snobol4 "$ROOT" ) || { echo "⛔ GATE REFUSE(2) [$G]: out/parser_snobol4 is missing or older than its sources -- make parsers"; exit 2; }
SW="$(declared_switches_beside "$B/parser_snobol4.sc")" && [ -n "$SW" ] || { echo "⛔ GATE REFUSE(2) [$G]: bootstrap/parser_snobol4.sc declares no heap or stack"; exit 2; }
TMO="${GATE_TIMEOUT:-120}"
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cat $CHAIN "$B/parser_snobol4.sc" > "$T/chain.sc"
"$SCRIP" --compile "$T/chain.sc" --out="$T/chain.s" </dev/null >/dev/null 2>&1 && gcc -m64 -no-pie -rdynamic "$T/chain.s" -Wl,-rpath,"$ROOT/out" -L"$ROOT/out" -lscrip_rt -lm -lpthread -o "$T/chain.bin" 2>/dev/null \
    || { echo "⛔ GATE REFUSE(2) [$G]: the .sc chain did not compile or link to a mode-4 binary"; exit 2; }
OPS=("X ? 'a'" "1 + 2" "'a' 'b'" "'a' | 'b'" "~X" "\\X" "(X = 1)" "'L'" "1" "-X" "X . Y" "X" "\$X" "A[1]" "F(X)" "*X" "&ANCHOR" "(X)" "\$\$X" "F(1 + 2)" "\$(A + B)" "X @ Y")
N=0; OK=0; BAD=""
for i in "${!OPS[@]}"; do
    n=$(printf 'g%02d' "$i"); printf '        Y = 1 :(%s)\nEND\n' "${OPS[$i]}" > "$T/$n.sno"; N=$((N + 1))
    ( cd "$T"; PARSER_TREE_HASH=1 timeout -k 5 "$TMO" "$ROOT/out/parser_snobol4" - < "$n.sno" > "$T/c.out" 2>/dev/null ); crc=$?
    ( cd "$T"; PARSER_TREE_HASH=1 timeout -k 5 "$TMO" "$T/chain.bin" $SW < "$n.sno" > "$T/s.out" 2>/dev/null ); src=$?
    if [ $crc -eq 124 ] || [ $src -eq 124 ]; then BAD="$BAD
      :(${OPS[$i]})   TIMEOUT (C rc=$crc, .sc rc=$src)"; continue; fi
    cr=0; sr=0; { grep -q '^Parse Error' "$T/c.out" || [ $crc -ne 0 ]; } && cr=1; { grep -q '^Parse Error' "$T/s.out" || [ $src -ne 0 ]; } && sr=1
    if [ $cr = 1 ] && [ $sr = 1 ]; then OK=$((OK + 1))
    elif [ $cr = 0 ] && [ $sr = 0 ] && [ "$(cat "$T/c.out")" = "$(cat "$T/s.out")" ]; then OK=$((OK + 1))
    else BAD="$BAD
      :(${OPS[$i]})   C $([ $cr = 1 ] && echo REFUSED || echo "tree $(head -c 20 "$T/c.out")")   .sc $([ $sr = 1 ] && echo REFUSED || echo "tree $(head -c 20 "$T/s.out")")"; fi
done
echo "GOTO OPERAND [$G]: $OK of $N one-statement programs print the same tree hash through out/parser_snobol4 and the .sc chain (a file both refuse agrees)"
[ -n "$BAD" ] && printf '  ⛔ disagreeing operands:%s\n' "$BAD"
if [ "$OK" = "$N" ]; then echo "GATE PASS [$G]: the .sc parser prints the C parser's tree for every goto operand"; exit 0; fi
echo "GATE FAIL(1) [$G]: $((N - OK)) of $N goto operands disagree"; exit 1
