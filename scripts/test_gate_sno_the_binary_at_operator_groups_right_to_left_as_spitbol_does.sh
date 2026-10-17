#!/usr/bin/env bash
# test_gate_sno_the_binary_at_operator_groups_right_to_left_as_spitbol_does.sh -- a chain of the binary slot operator @ in SNOBOL4 source is RIGHT associative (SPITBOL manual Chapter 15: @ priority 5, right), not left.
#
# # ⛔ THE DEFECT (minted by hq_snocone 2026-10-07, row snobol4-the-binary-at-operator-is-right-associative-as-the-spitbol-table-says): snobol4.y read expr5 as  expr5 T_2AT expr6  (left-recursive), so with
#   OPSYN('@','F',2) and F returning '(' X ',' Y ')', the statement  OUTPUT = 1 @ 2 @ 3  printed ((1,2),3) where sbl -bf prints (1,(2,3)). The other slot operators agree with the table (& # % left, ~ right);
#   Snocone's grammar already grouped @ right, so the SNOBOL4 and Snocone trees of the same chain differed.
#   THE CURE: expr5 is  expr6 T_2AT expr5  in src/parsers/snobol4/snobol4.y (and bison's output regenerated), and Expr5 in bootstrap/parser_snobol4.sc is the same by the tail form; the identity deck
#   ../harness/scripts/fixtures/expression_identity_deck.txt gains the chain lines so test_gate_snocone_expressions_are_snobol4_expressions.sh holds the two parsers' trees equal on them.
#
# THE ARMS (expectations cut from sbl -bf AT RUN TIME): each program in m3 and in m4
#   1-2  CHAINS: two, three and four binary @ in a row, @ against + (priority 6), parenthesised either way, a string chain, a chain inside a concatenation   -- RED on base (left-grouped)
#   3-4  CALL ORDER: F prints its operands as it is entered and each operand is a call that prints, so the order of operand evaluation and of the F calls is observable  -- RED on base
#   5-6  CONTROLS: & # % chains stay LEFT, ~ stays RIGHT, + - stay LEFT (the levels the table agrees with already)
# EXIT: 0 all arms pass · 1 an arm failed · 2 REFUSED (no binary, no oracle, no tmpdir, the oracle's answer moved).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="$ROOT/scrip"
RT_DIR="$ROOT/out"
NAME=sno_the_binary_at_operator_groups_right_to_left_as_spitbol_does
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
[ -f "$RT_DIR/libscrip_rt.so" ] || refuse "no $RT_DIR/libscrip_rt.so -- cannot measure mode 4"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="$(sbl_correctness_bin 2>/dev/null || true)"; [ -n "${SBL:-}" ] && [ -x "$SBL" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || refuse "no sbl oracle -- cannot measure (a missing oracle prints a full false table)"
T="$(mktemp -d)" || refuse "no tmpdir"
trap 'rm -rf "$T"' EXIT
cat > "$T/chain.sno" <<'EOS'
        DEFINE('F(X,Y)')
        OPSYN('@','F',2)
        OUTPUT = 1 @ 2 @ 3
        OUTPUT = 1 @ 2 @ 3 @ 4
        OUTPUT = 1 @ 2 + 3 @ 4
        OUTPUT = (1 @ 2) @ 3
        OUTPUT = 1 @ (2 @ 3)
        OUTPUT = 'a' @ 'b' @ 'c' @ 'd' @ 'e'
        OUTPUT = 'x' 1 @ 2 @ 3 'y'
        :(END)
F       F = '(' X ',' Y ')'                     :(RETURN)
END
EOS
cat > "$T/order.sno" <<'EOS'
        DEFINE('F(X,Y)')
        DEFINE('G(N)')
        OPSYN('@','F',2)
        OUTPUT = G(1) @ G(2) @ G(3) @ G(4)
        :(END)
F       OUTPUT = 'F(' X ',' Y ')'
        F = '[' X Y ']'                         :(RETURN)
G       OUTPUT = 'G' N
        G = N                                   :(RETURN)
END
EOS
cat > "$T/ctl.sno" <<'EOS'
        DEFINE('F(X,Y)')
        OPSYN('&','F',2)
        OPSYN('#','F',2)
        OPSYN('%','F',2)
        OPSYN('~','F',2)
        OUTPUT = 1 & 2 & 3
        OUTPUT = 1 # 2 # 3
        OUTPUT = 1 % 2 % 3
        OUTPUT = 1 ~ 2 ~ 3
        OUTPUT = 10 - 2 - 3
        OUTPUT = 2 + 3 - 4 + 5
        :(END)
F       F = '(' X ',' Y ')'                     :(RETURN)
END
EOS
want() { timeout -k 5 30 "$SBL" -bf "$T/$1.sno" < /dev/null > "$T/$1.want" 2>/dev/null; [ -s "$T/$1.want" ] || refuse "sbl -bf produced no output for $1 -- the oracle's answer moved"; }
for p in chain order ctl; do want $p; done
grep -qx '(1,(2,3))' "$T/chain.want" || refuse "sbl -bf no longer groups the binary @ right-to-left"
grep -qx '((1,2),3)' "$T/ctl.want" || refuse "sbl -bf no longer groups the binary & left-to-right"
fail=0; pass=0
arm() { local n="$1" what="$2" ok="$3"
    if [ "$ok" = 1 ]; then pass=$((pass + 1)); echo "  arm $n PASS  $what"; else fail=$((fail + 1)); echo "  arm $n FAIL  $what"; fi; }
same_m3() { timeout -k 5 60 "$SCRIP" "$T/$1.sno" < /dev/null > "$T/$1.m3" 2>&1
    cmp -s "$T/$1.want" "$T/$1.m3" || { diff "$T/$1.want" "$T/$1.m3" | head -6 | cut -c1-160 | sed 's/^/      /'; return 1; }; }
same_m4() { timeout -k 5 120 "$SCRIP" --compile -o "$T/$1.s" "$T/$1.sno" < /dev/null > /dev/null 2>&1 \
        && gcc -no-pie "$T/$1.s" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" -o "$T/$1.bin" 2>/dev/null || { echo "      COMPILE-FAILED"; return 1; }
    timeout -k 5 60 "$T/$1.bin" < /dev/null > "$T/$1.m4" 2>&1
    cmp -s "$T/$1.want" "$T/$1.m4" || { diff "$T/$1.want" "$T/$1.m4" | head -6 | cut -c1-160 | sed 's/^/      /'; return 1; }; }
n=0
for spec in "chain|CHAINS: two to four @ in a row, against +, parenthesised, strings, inside a concatenation" "order|CALL ORDER: operand calls left to right, F calls right to left" "ctl|CONTROLS: & # % + - stay left, ~ stays right"; do
    p="${spec%%|*}"; w="${spec#*|}"
    n=$((n + 1)); same_m3 "$p" && arm $n "m3 $w" 1 || arm $n "m3 $w" 0
    n=$((n + 1)); same_m4 "$p" && arm $n "m4 $w" 1 || arm $n "m4 $w" 0
done
if [ "$fail" -eq 0 ]; then echo "GATE PASS(0) [$NAME]: $pass arms -- a chain of the binary @ groups right to left as SPITBOL's table says, both modes"; exit 0; fi
echo "GATE FAIL(1) [$NAME]: $fail of $((pass + fail)) arms red"; exit 1
