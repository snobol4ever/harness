#!/usr/bin/env bash
# test_gate_sno_the_null_string_concatenated_with_an_unevaluated_expression_is_that_expression_in_both_modes.sh
#
# THE DEFECT (row snobol4-the-null-string-concatenated-with-an-unevaluated-expression-is-that-expression-in-spitbol-where-scrip-makes-a-pattern): the null string is the identity of concatenation, so in
# SPITBOL x = '' ; y = x *POS(0) and *POS(0) x and '' **REM are DATATYPE EXPRESSION (the unevaluated expression comes back unchanged), and a non-null operand makes a PATTERN. SCRIP's lowerer sent every
# concatenation holding a * deferral to the compile-time pattern carrier (SNO$MKPAT), which always yields a PATTERN. THE CURE: sno_is_pattern_rhs refuses a concatenation chain whose every leaf is a variable,
# a null literal or a deferral (and holds a deferral): it lowers as the runtime concatenation, which already answers EXPRESSION for null+expression and PATTERN for anything else (a variable
# operand was always right). The expected output is cut from sbl -bf at run time; a run sbl does not answer is a REFUSAL. Both modes. rc=0 clean · rc=1 a divergence · rc=2 REFUSAL.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
SBL="${SBL:-/home/resources/x64/bin/sbl}"
refuse() { echo "⛔ REFUSES rc=2: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built -- cannot measure"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
[ -x "$SBL" ] || refuse "the SNOBOL4 oracle $SBL is absent -- the expected answers cannot be cut"
"$HERE/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/a.sno" <<'SNO'
        x = ''
        e = *POS(0)
        y = x e
        OUTPUT = 'var-expr ' DATATYPE(y)
        y = e x
        OUTPUT = 'expr-var ' DATATYPE(y)
        y = x *POS(0)
        OUTPUT = 'null-defer ' DATATYPE(y)
        y = *POS(0) x
        OUTPUT = 'defer-null ' DATATYPE(y)
        y = '' *POS(0)
        OUTPUT = 'lit-null-defer ' DATATYPE(y)
        y = 'a' *POS(0)
        OUTPUT = 'str-defer ' DATATYPE(y)
        y = x x *POS(0)
        OUTPUT = 'nn-defer ' DATATYPE(y)
        y = x *POS(0) x
        OUTPUT = 'n-defer-n ' DATATYPE(y)
        y = x *POS(0) 'a'
        OUTPUT = 'n-defer-str ' DATATYPE(y)
        y = x *POS(0) *REM
        OUTPUT = 'n-defer-defer ' DATATYPE(y)
        y = x *POS(0) ARB
        OUTPUT = 'n-defer-pat ' DATATYPE(y)
        y = *POS(0) *REM
        OUTPUT = 'defer-defer ' DATATYPE(y)
        s = 'a'
        y = s *POS(0)
        OUTPUT = 'str-var-defer ' DATATYPE(y)
        p = ARB
        y = p *POS(0)
        OUTPUT = 'pat-var-defer ' DATATYPE(y)
        OUTPUT = 'match ' ('ab' ? x *POS(0) 'ab')
END
SNO
cat > "$D/b.sno" <<'SNO'
loop    line = INPUT                    :F(END)
        x = EVAL(line)                  :S(ok)
        OUTPUT = 'FAIL'                 :(loop)
ok      OUTPUT = DATATYPE(x)            :(loop)
END
SNO
printf "%s\n" "'' **REM" "'' *'abc'" "'a' *'abc'" "'' ARB" "'' 1" > "$D/b.in"
( cd "$D" && timeout -k 5 10 "$SBL" -bf a.sno < /dev/null 2>/dev/null > a.want )
( cd "$D" && timeout -k 5 10 "$SBL" -bf b.sno < b.in 2>/dev/null > b.want )
grep -qx "null-defer EXPRESSION" "$D/a.want" && [ "$(head -1 "$D/b.want")" = "EXPRESSION" ] || refuse "sbl -bf does not answer the null-identity witness as pinned: [$(tr '\n' '|' < "$D/a.want")] [$(tr '\n' '|' < "$D/b.want")]"
m4bin() { timeout -k 5 60 "$B/scrip" --compile "$1.sno" < /dev/null > "$1.s" 2>/dev/null && gcc -no-pie "$1.s" -L"$B/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$B/out" -o "$1.bin" 2>/dev/null; }
red=0; n=0
arm() { n=$((n + 1)); if [ "$2" = ok ]; then echo "  ok   $1"; else echo "  FAIL $1: $2"; red=$((red + 1)); fi; }
( cd "$D" && timeout -k 5 30 "$B/scrip" a.sno < /dev/null > a.m3 2>/dev/null )
( cd "$D" && m4bin a && timeout -k 5 30 ./a.bin < /dev/null > a.m4 2>/dev/null )
( cd "$D" && timeout -k 5 30 "$B/scrip" b.sno < b.in > b.m3 2>/dev/null )
( cd "$D" && m4bin b && timeout -k 5 30 ./b.bin < b.in > b.m4 2>/dev/null )
for m in m3 m4; do
    if [ -f "$D/a.$m" ] && cmp -s "$D/a.want" "$D/a.$m"; then arm "a $m (null variable or literal with a deferral, in every order; non-null controls)" ok
    else arm "a $m" "got [$(tr '\n' '|' 2>/dev/null < "$D/a.$m")] want [$(tr '\n' '|' < "$D/a.want")]"; fi
    if [ -f "$D/b.$m" ] && cmp -s "$D/b.want" "$D/b.$m"; then arm "b $m (the same through EVAL)" ok
    else arm "b $m" "got [$(tr '\n' '|' 2>/dev/null < "$D/b.$m")] want [$(tr '\n' '|' < "$D/b.want")]"; fi
done
if [ $red -eq 0 ]; then
    echo "GATE PASS(0): the null string concatenated with an unevaluated expression is that expression, a non-null operand makes a pattern, as sbl -bf answers, as a statement and through EVAL, both modes; $n arm(s)"
    exit 0
fi
echo "GATE FAIL(1): $red of $n arm(s) diverge"; exit 1
