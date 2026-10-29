#!/usr/bin/env bash
# test_gate_sno_eval_fails_when_its_expression_fails.sh -- EVAL(expr) must FAIL when the expression fails or
# raises, not quietly return the null string.
#
# ⛔ THE DEFECT (ceo 2026-09-14, found in the x64 tests' own exception harness, chks.inc). eval_string_transient
# reported success whenever the chain RAN, and read the result out of the EVAL temp. An expression that FAILED
# never wrote that temp, so EVAL handed back the leftover empty value with a success indication: SQRT(-1.0)
# and 1/0 both "succeeded" as the null string. A SYNTAX error did fail, because the chain could not be built --
# so the one case anyone tests by hand was the one case that worked.
#
# ⭐ WHAT IT COST, AND WHY IT IS WORTH A GATE RATHER THAN A FIX: chks.inc grades every x64 math program by
# EVAL-ing an expression and comparing the observed answer, with a `:F(chks.oops)` branch that reads &ERRTEXT.
# With EVAL never failing, that branch was UNREACHABLE for a whole suite -- the harness silently compared the
# null string to the expected answer, and 10 of the 16 m3 reds were math_* programs stacked on this one root.
# math_ln went from CRASH to 627 pass / 0 fail on the cure alone.
#
# ⛔ THE SHAPE TO REMEMBER: the fail path was not wrong, it was NOT TAKEN. A harness whose error branch can
# never run reports every error as a wrong answer, which reads as dozens of unrelated numeric defects.
#
# The expectations are what SPITBOL does: a failing expression makes EVAL fail. NO ORACLE NEEDED AT RUN TIME --
# the arms assert the FAIL/SUCCEED branch taken, which is the property, not a formatted number.
# rc=0 clean · rc=1 a coercion of failure into success · rc=2 REFUSAL (cannot measure).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
[ -x "$B/scrip" ] || { echo "⛔ REFUSES rc=2: $B/scrip is not built -- cannot measure"; exit 2; }
D="$(mktemp -d)" || { echo "⛔ REFUSES rc=2: no scratch dir"; exit 2; }
trap 'rm -rf "$D"' EXIT

cat > "$D/w.sno" <<'SNO'
        &ERRLIMIT = 1000
        A = EVAL('SQRT(-1.0)')                  :F(A1)
        OUTPUT = 'sqrt=succeeded'               :(B)
A1      OUTPUT = 'sqrt=failed'
B       C = EVAL('1 / 0')                       :F(B1)
        OUTPUT = 'div0=succeeded'               :(D)
B1      OUTPUT = 'div0=failed'
D       E = EVAL('SIZE(')                       :F(D1)
        OUTPUT = 'syntax=succeeded'             :(F)
D1      OUTPUT = 'syntax=failed'
F       G = EVAL('2 + 3')                       :F(F1)
        OUTPUT = 'good=' G                      :(H)
F1      OUTPUT = 'good=WRONGLY-FAILED'
H       H2 = EVAL('SQRT(4.0)')                  :F(H1)
        OUTPUT = 'sqrtok=succeeded'             :(Z)
H1      OUTPUT = 'sqrtok=WRONGLY-FAILED'
Z
END
SNO
cat > "$D/w.ref" <<'REF'
sqrt=failed
div0=failed
syntax=failed
good=5
sqrtok=succeeded
REF

fails=0
for mode in m3 m4; do
    if [ "$mode" = m3 ]; then
        (cd "$D" && timeout -k 5 20 "$B/scrip" w.sno </dev/null > "out.$mode" 2>&1)
    else
        "$B/scrip" --compile --out="$D/w.s" "$D/w.sno" </dev/null >/dev/null 2>&1 \
          && as -o "$D/w.o" "$D/w.s" 2>/dev/null \
          && gcc -o "$D/w.bin" "$D/w.o" "$B/out/libscrip_rt.so" -Wl,-rpath,"$B/out" 2>/dev/null \
          || { echo "⛔ REFUSES rc=2: could not build the m4 arm -- a toolchain failure, not a verdict"; exit 2; }
        (cd "$D" && timeout -k 5 20 ./w.bin </dev/null > "out.$mode" 2>&1)
    fi
    if diff -q "$D/w.ref" "$D/out.$mode" >/dev/null 2>&1; then
        printf '  ok    %s: EVAL fails on a raising and on a failing expression, and still succeeds on a good one\n' "$mode"
    else
        printf '  FAIL  %s:\n' "$mode"; diff "$D/w.ref" "$D/out.$mode" | sed 's/^/          /'; fails=$((fails+1))
    fi
done

[ "$fails" -eq 0 ] || { echo "⛔ GATE FAILED: $fails of 2 mode(s) red."
                        echo "   ⭐ THE TWO POSITIVE ARMS ARE NOT DECORATION: a cure that makes EVAL fail whenever the chain"
                        echo "      ran is as wrong as the defect, and only 'good=5' and 'sqrtok=succeeded' can tell them apart."
                        exit 1; }
echo "✅ GATE OK: EVAL fails when its expression fails or raises, and succeeds when it does not, both modes"
exit 0
