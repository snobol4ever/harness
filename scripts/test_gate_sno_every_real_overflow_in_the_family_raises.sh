#!/usr/bin/env bash
# test_gate_sno_every_real_overflow_in_the_family_raises.sh -- EVERY member of the real arithmetic family
# raises on overflow. Not the four that were tested when the check was written; all of them.
#
# ⛔ THE DEFECT (ceo 2026-09-14, x64 math_pow). rt_real_overflow existed and ADD, SUB, MUL, DIV and BINOP_POW
# all called it. BINOP_POW_PROMOTE -- the same operator reached through the promoting path -- returned
# `REALVAL(pow(ld, rd))` with no finite check at all, so `1.2532722125503777 ** 2.6531489453414562e+10` handed
# back `inf` while its sibling one line above raised 266. math_pow: CRASH -> 3600 pass / 0 fail.
#
# ⭐ THIS IS THE NO-PER-OP-FILTER LAW MADE EXECUTABLE. "All members of a BB family are the same; a defect
# reachable through one member is a class defect." The family here is arithmetic overflow, and the member that
# was missing is the one nobody writes a witness for -- the promoting spelling of an operator whose ordinary
# spelling is correct. A gate holding only the operators someone remembered is how the gap survived.
#
# ⛔ SNOBOL4 HAS NO INFINITY: an operation that overflows must raise, never yield a value. Sits beside
# test_gate_sno_a_real_that_overflows_is_not_a_value.sh, which holds the CONVERSION half of the same rule.
#
# rc=0 clean · rc=1 a family member yields an infinity · rc=2 REFUSAL (cannot measure).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
[ -x "$B/scrip" ] || { echo "⛔ REFUSES rc=2: $B/scrip is not built -- cannot measure"; exit 2; }
D="$(mktemp -d)" || { echo "⛔ REFUSES rc=2: no scratch dir"; exit 2; }
trap 'rm -rf "$D"' EXIT

cat > "$D/w.sno" <<'SNO'
        &ERRLIMIT = 1000
        BIG = 1.0e308
        A = BIG * BIG                           :F(A1)
        OUTPUT = 'mul=[' A ']'                  :(B)
A1      OUTPUT = 'mul=' &ERRTEXT
B       C = BIG / 1.0e-300                      :F(B1)
        OUTPUT = 'div=[' C ']'                  :(D)
B1      OUTPUT = 'div=' &ERRTEXT
D       E = BIG + BIG                           :F(D1)
        OUTPUT = 'add=[' E ']'                  :(F)
D1      OUTPUT = 'add=' &ERRTEXT
F       G = (0.0 - BIG) - BIG                   :F(F1)
        OUTPUT = 'sub=[' G ']'                  :(H)
F1      OUTPUT = 'sub=' &ERRTEXT
H       I = EVAL('1.2532722125503777 ** 2.6531489453414562e+10')  :F(H1)
        OUTPUT = 'powpromote=[' I ']'           :(J)
H1      OUTPUT = 'powpromote=' &ERRTEXT
J       K = EVAL('1.0e308 ** 2.0')              :F(J1)
        OUTPUT = 'pow=[' K ']'                  :(L)
J1      OUTPUT = 'pow=' &ERRTEXT
L       M = 2.0 * 3.0                           :F(L1)
        OUTPUT = 'ok=' M                        :(Z)
L1      OUTPUT = 'ok=WRONGLY-FAILED'
Z
END
SNO
cat > "$D/w.ref" <<'REF'
mul=multiplication caused real overflow
div=division caused real overflow
add=addition caused real overflow
sub=subtraction caused real overflow
powpromote=exponentiation caused real overflow
pow=exponentiation caused real overflow
ok=6.
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
        printf '  ok    %s: all six overflow spellings raise, and ordinary arithmetic still computes\n' "$mode"
    else
        printf '  FAIL  %s:\n' "$mode"; diff "$D/w.ref" "$D/out.$mode" | sed 's/^/          /'; fails=$((fails+1))
    fi
done

[ "$fails" -eq 0 ] || { echo "⛔ GATE FAILED: $fails of 2 mode(s) red."
                        echo "   ⛔ A LINE READING '=[inf]' IS THE DEFECT ITSELF: SNOBOL4 has no infinity, so an operation"
                        echo "      that overflows must RAISE. Fix the family, not the one spelling that reported it."
                        echo "   ⭐ THE 'ok=6.' ARM IS THE CONTROL: a change that raises on every multiplication passes"
                        echo "      all six negative arms."
                        exit 1; }
echo "✅ GATE OK: every real-arithmetic overflow spelling raises instead of yielding an infinity, both modes"
exit 0
