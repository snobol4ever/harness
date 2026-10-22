#!/usr/bin/env bash
# test_gate_sno_an_error_inside_eval_publishes_its_own_text.sh -- an error raised INSIDE an EVAL'd expression
# publishes the same &ERRTEXT and &ERRTYPE it publishes outside one.
#
# ⛔ THE DEFECT (ceo 2026-09-14, the x64 math family). rt_real_overflow raised the SNOBOL4 error only when
# `g_error == 0`, and eval_chain_run_guarded sets `g_error = -1` for the duration of an EVAL -- so inside an
# EVAL the overflow took the OTHER arm, core_icn_error(204), and returned failure with nothing published.
# Measured on one witness: `1.0e300 * 1.0e300` direct gives errtext="multiplication caused real overflow"
# errtype=263; the SAME expression through EVAL gave errtext=[] errtype=0.
#
# ⭐ THE CLASS, because the fix is small and the shape is not: g_error carried TWO meanings -- Icon's error
# trap AND "an EVAL guard is armed" -- and the arithmetic read it as the first while EVAL wrote it as the
# second. One global, two owners, and the arm that lost is the one that publishes the text a program reads.
# The discriminator is now g_kw_errlimit, which is a SNOBOL4 keyword rather than a language test, so this stays
# inside the no-language-discriminator law.
#
# ⛔ WHAT IT COST: chks.inc grades the x64 math programs by comparing &ERRTEXT against the expected error
# string, so every overflow case compared "" against "division caused real overflow". math_div was 1984
# failures of ONE shape and math_prod the same; both are 15376/0 and 14400/0 after the cure.
#
# ⛔ THE DIRECT ARM MULTIPLIES A VARIABLE (cfo 2026-10-02): `Y = 1.0e300 * 1.0e300` has constant operands, which sbl -bf
# evaluates WHEN IT COMPILES the statement -- ERROR 263 at compile time and the program never ran -- and SCRIP does the
# same since the compile-time pre-evaluation landed; `A = 1.0e300` then `Y = A * A` overflows at run time, as meant.
# The expectation is the oracle's: sbl -bf publishes the text in both positions. rc=0 clean · rc=1 the text
# or the type differs between the two positions · rc=2 REFUSAL (cannot measure).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
[ -x "$B/scrip" ] || { echo "⛔ REFUSES rc=2: $B/scrip is not built -- cannot measure"; exit 2; }
D="$(mktemp -d)" || { echo "⛔ REFUSES rc=2: no scratch dir"; exit 2; }
trap 'rm -rf "$D"' EXIT

cat > "$D/w.sno" <<'SNO'
        &ERRLIMIT = 1000
        X = EVAL('1.0e300 * 1.0e300')           :F(E1)
        OUTPUT = 'in-eval=NO-FAIL'              :(N1)
E1      OUTPUT = 'in-eval=[' &ERRTEXT '] type=' &ERRTYPE
N1      A = 1.0e300
        Y = A * A                               :F(E2)
        OUTPUT = 'direct=NO-FAIL'               :(N2)
E2      OUTPUT = 'direct=[' &ERRTEXT '] type=' &ERRTYPE
N2      Z = EVAL('1.0586114708425298e+03 / 1.3244474893716128e-307')  :F(E3)
        OUTPUT = 'divovf=NO-FAIL'               :(Z9)
E3      OUTPUT = 'divovf=[' &ERRTEXT '] type=' &ERRTYPE
Z9
END
SNO
cat > "$D/w.ref" <<'REF'
in-eval=[multiplication caused real overflow] type=263
direct=[multiplication caused real overflow] type=263
divovf=[division caused real overflow] type=262
REF

fails=0
for mode in m3 m4; do
    if [ "$mode" = m3 ]; then
        (cd "$D" && timeout -k 5 20 "$B/scrip" w.sno </dev/null > "out.$mode" 2>&1)
    else
        "$B/scrip" --compile -o "$D/w.s" "$D/w.sno" </dev/null >/dev/null 2>&1 \
          && as -o "$D/w.o" "$D/w.s" 2>/dev/null \
          && gcc -o "$D/w.bin" "$D/w.o" "$B/out/libscrip_rt.so" -Wl,-rpath,"$B/out" 2>/dev/null \
          || { echo "⛔ REFUSES rc=2: could not build the m4 arm -- a toolchain failure, not a verdict"; exit 2; }
        (cd "$D" && timeout -k 5 20 ./w.bin </dev/null > "out.$mode" 2>&1)
    fi
    if diff -q "$D/w.ref" "$D/out.$mode" >/dev/null 2>&1; then
        printf '  ok    %s: the same error publishes the same text and type inside EVAL and outside it\n' "$mode"
    else
        printf '  FAIL  %s:\n' "$mode"; diff "$D/w.ref" "$D/out.$mode" | sed 's/^/          /'; fails=$((fails+1))
    fi
done

[ "$fails" -eq 0 ] || { echo "⛔ GATE FAILED: $fails of 2 mode(s) red."
                        echo "   ⭐ THE DIRECT ARM IS THE CONTROL: if BOTH positions print empty the defect is in publishing"
                        echo "      generally; if only the in-eval arm is empty it is the guard's g_error marker again."
                        exit 1; }
echo "✅ GATE OK: an error raised inside EVAL publishes the same &ERRTEXT and &ERRTYPE as one raised outside, both modes"
exit 0
