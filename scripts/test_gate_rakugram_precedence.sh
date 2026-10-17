#!/usr/bin/env bash
# test_gate_rakugram_precedence.sh — RUNG 4 gate for the Grammar.nqp -> recursive-descent port.
#
# Regenerates Raku's operator-precedence table from Rakudo's Grammar.nqp, compiles the emitted Pratt
# parser, and proves three things about it. The third is the one that matters:
#
#   1. PRECEDENCE   2 + 3 * 4  folds as  (2 + (3 * 4))
#   2. ASSOCIATIVITY  1 - 2 - 3 -> ((1-2)-3) left, 2 ** 3 ** 2 -> (2**(3**2)) right
#      ⛔ Associativity is INVISIBLE to any syntax-only test: a parser that folds 1-2-3 as 1-(2-3)
#         accepts exactly the same language. Only a shape assertion catches it.
#   3. HLL LAYER    ws / identifier / int literals / lookahead -- the hand-written rules that cannot
#                   be generated from Grammar.nqp at all (rung 6). Asserts the SUBTLE cases: that
#                   `a - b` does not lex as the identifier `a-b`, that a leading underscore is not a
#                   number, and that lookahead does not consume. Each of those misparses plausibly
#                   and only shows up much later.
#   6. RUNG 8: :my / {code} / :dba lower as matching no-ops and `A ~ B C` is rewritten to `A C B`;
#      the gate's load-bearing half is THE GUARD -- a consultation of a parse-time variable
#      (`<?{ $*IN_DECL }>`) must STILL refuse, or the no-op declaration is a silent wrong answer.
#   5. LOWERED PRIMITIVES  character classes, backslash escapes, anchors and lookahead operands
#      are real code (rung 7). Rung 3 shipped them as stubs that answered "matched" for any input,
#      so this section asserts what each REJECTS -- the only thing a placeholder cannot fake.
#   4. PARSE-TIME EXTENSION — install a new operator at a precedence BETWEEN two existing levels
#      while parsing, and see it bind correctly. This is the property that makes Raku non-LALR and
#      the reason the bison grammar was retired (Lon 2026-08-30); a gate that did not exercise it
#      would pass just as happily against a frozen table, which is the exact defect being avoided.
#
# REFUSES rc=2 when it cannot measure (no Grammar.nqp, no compiler) rather than reporting green.
set -u
cd "$(dirname "$0")/../../SCRIP" || exit 2
ROOT=$(pwd)
# ⛔ refs/ WAS DELETED ORG-WIDE 2026-09-16: fall through to the shared read-only checkout rather than
# refusing on a path that no longer exists anywhere (hq_raku). $RAKUDO_GRAMMAR still wins if set.
GRAM="${RAKUDO_GRAMMAR:-$ROOT/refs/rakudo-main/src/Perl6/Grammar.nqp}"
[ -f "$GRAM" ] || GRAM=/home/resources/rakudo-main/src/Perl6/Grammar.nqp
[ -f "$GRAM" ] || GRAM=/home/resources/rakudo-main/src/Perl6/Grammar.nqp
[ -f "$GRAM" ] || { echo "⛔ REFUSES rc=2: no Grammar.nqp (wire refs/rakudo-main)"; exit 2; }
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSES rc=2: no gcc"; exit 2; }
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
python3 "$ROOT/tools/rakugram/nqp_prec.py" "$GRAM" "$T/rk_prec_gen.c" --emit > "$T/gen.log" 2>&1 || {
    echo "⛔ REFUSES rc=2: generator failed"; sed -n '1,15p' "$T/gen.log"; exit 2; }
grep -q 'rk_ops_init_builtin' "$T/rk_prec_gen.c" || { echo "⛔ REFUSES rc=2: generator emitted no table"; exit 2; }
nops=$(grep -c 'rk_op_install(' "$T/rk_prec_gen.c")
[ "$nops" -ge 150 ] || { echo "⛔ REFUSES rc=2: only $nops operators extracted (expected >=150) -- the"; \
    echo "   extractor silently matched nothing rather than failing; grading this would be vacuous."; exit 2; }
cp "$ROOT/tools/rakugram/prec_test.c" "$ROOT/tools/rakugram/rk_cur.h" "$T/" || exit 2
gcc -O0 -Wall -o "$T/prec_test" "$T/prec_test.c" -I"$T" 2> "$T/cc.log" || {
    echo "⛔ GATE FAIL: emitted Pratt parser does not compile"; sed -n '1,15p' "$T/cc.log"; exit 1; }
"$T/prec_test"; rc=$?
# ---- rung 6: the hand-written HLL::Grammar layer -------------------------------------------------
echo
cp "$ROOT/tools/rakugram/rk_hll.c" "$ROOT/tools/rakugram/rk_hll.h" "$ROOT/tools/rakugram/rk_hll_test.c" "$T/" || exit 2
gcc -O0 -Wall -Wextra -o "$T/hll_test" "$T/rk_hll_test.c" "$T/rk_hll.c" -I"$T" 2> "$T/hcc.log" || {
    echo "⛔ GATE FAIL: the hand-written HLL layer does not compile"; sed -n '1,15p' "$T/hcc.log"; exit 1; }
"$T/hll_test" || rc=1
# ---- rung 7: character classes, escapes, anchors, lookahead are REAL, not placeholders ----------
# Rung 3 emitted all five as stubs that answered "matched" for any input; 181 rules rode on them and
# 60 could never match (a negative lookahead over an always-true stub fails unconditionally). The C
# test below asserts the REJECTS -- a positive test passes against a stub that matches everything.
# The --selftest first proves the test's hard-coded tables are what nqp_cc.py actually lowers to.
echo
python3 "$ROOT/tools/rakugram/nqp_cc.py" --selftest || { echo "⛔ GATE FAIL: rk_cc_test.c tables drifted from nqp_cc.py"; exit 1; }
python3 "$ROOT/tools/rakugram/nqp_cc.py" --runtime > "$T/rk_cc_rt.c" || exit 2
cp "$ROOT/tools/rakugram/rk_cc_test.c" "$T/" || exit 2
gcc -O0 -Wall -Wextra -Werror -o "$T/cc_test" "$T/rk_cc_test.c" -I"$T" 2> "$T/ccc.log" || {
    echo "⛔ GATE FAIL: the character-class runtime does not compile"; sed -n '1,15p' "$T/ccc.log"; exit 1; }
"$T/cc_test" || rc=1
# the full generated parser must still compile with ZERO implicit declarations -- a lookahead operand
# that resolves to a rule nobody declared is a phantom that warns, links against nothing, and passes.
python3 "$ROOT/tools/rakugram/nqp_emit.py" "$GRAM" "$T/rk_gen.c" > "$T/emit.log" 2>&1 || {
    echo "⛔ REFUSES rc=2: nqp_emit.py failed"; sed -n '1,10p' "$T/emit.log"; exit 2; }
printf '#include "rk_gen.c"\nint main(void){return 0;}\n' > "$T/gen_drv.c"
gcc -O0 -Wall -Wextra -c "$T/gen_drv.c" -o /dev/null -I"$T" 2> "$T/gen.log"
if grep -q 'error:\|implicit declaration' "$T/gen.log"; then
    echo "⛔ GATE FAIL: generated parser has errors or phantom (implicitly declared) rules:"
    grep 'error:\|implicit declaration' "$T/gen.log" | head -5; rc=1
else
    echo "  ok   generated parser: 0 errors, 0 implicit declarations ($(grep -c '^static int rk_' "$T/rk_gen.c") rules)"
fi
if grep -q 'rk_look_stub\|rk_cclass(\|rk_esc_s(' "$T/rk_gen.c"; then
    echo "⛔ GATE FAIL: a placeholder primitive is back in the generated parser"; rc=1
fi
# ---- rung 8: :my / {code} / :dba are matching no-ops, the ~ goal operator is rewritten, AND THE GUARD HOLDS -----
# The guard is the assertion that matters: a declaration being a no-op is only sound while every READ of the
# variable still refuses. If `<?{ $*IN_DECL }>` ever stops refusing without $*IN_DECL being modelled, a rule
# that consults it will run against a value nobody set -- rung 3's silent-wrong-answer class, one level up.
python3 "$ROOT/tools/rakugram/nqp_ast.py" --selftest || { echo "⛔ GATE FAIL: goal-operator rewrite disagrees with its selftest"; rc=1; }
if grep -q "UNIMPLEMENTED LOOK 'pos:?{ \$\*IN_DECL }'" "$T/rk_gen.c"; then
    echo "  ok   guard: <?{ \$*IN_DECL }> consultation still REFUSES while its :my declaration is a no-op"
else
    echo "⛔ GATE FAIL: a parse-time-variable CONSULTATION no longer refuses -- was \$*IN_DECL modelled, writes included? If not, this is a silent wrong answer"; rc=1
fi
xb=$(awk '/^static int rk_xblock\(RkCur \*c\) \{$/{p=1} p{print} p&&/^}$/{exit}' "$T/rk_gen.c")
if [ -n "$xb" ] && ! printf '%s' "$xb" | grep -q UNIMPLEMENTED; then
    echo "  ok   rk_xblock (:my-only rule) EMITS -- :my is a matching no-op"
else
    echo "⛔ GATE FAIL: rk_xblock still refuses (or is missing): the :my no-op did not land"; rc=1
fi
if grep -q "UNIMPLEMENTED GOAL" "$T/rk_gen.c"; then echo "⛔ GATE FAIL: a ~ goal operator reached the emitter unrewritten"; rc=1; fi
if [ "$rc" -eq 0 ]; then
    echo "✅ GATE OK: $nops operators (precedence + associativity + parse-time extension), the"
    echo "   hand-written HLL layer (ws, identifier, int literals, lookahead), and the lowered"
    echo "   character classes / escapes / anchors / lookahead (rejects asserted) all verified."
else echo "⛔ GATE FAIL: see the FAIL rows above."; fi
exit $rc
