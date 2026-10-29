#!/usr/bin/env bash
# test_gate_sno_a_real_that_overflows_is_not_a_value.sh -- a decimal that will not fit a double FAILS to
# convert; it does not become the IEEE infinity and travel on as an ordinary value.
#
# ⛔ THE DEFECT (ceo 2026-09-14, x64 math_limits2/3). SNOBOL4 HAS NO INFINITY. Every arithmetic overflow path
# already raises through rt_real_overflow -- 261/262/263/264 -- but the CONVERSION path had no such check:
# "string to real" was spelled at eight strtod sites across keywords.c, core.c, by_name_dispatch.c,
# icn_extfn.c and arithmetic.c, and not one asked whether a finite decimal had produced a non-finite double.
# `EVAL('1.797693135E+308')` and `CONVERT('1.797693135E+308','REAL')` both handed back `inf`.
#
# ⭐ THE CURE IS ONE AUTHORITY, WHICH IS WHY THIS GATE TESTS THREE DOORS: rt_str_to_real is now the single
# converter that answers finite-or-fails, and EVAL, CONVERT and the dispatcher's own CONVERT fast path all go
# through it. The same defect reached the same program through different doors this morning -- the coercion
# fix -- and a gate holding one door would have let the next one keep its own spelling.
# ⭐ AMENDED (cfo 2026-09-26): CONVERT and both dispatcher copies now answer through rt_sno_cnv_num, SPITBOL's
# gtnum transcribed (test_gate_sno_convert_reads_a_numeric_string_as_spitbol_gtnum_does.sh), which also fails an
# overflowing decimal -- sbl fails even DBL_MAX's exact decimal, and so does the transcription. EVAL keeps
# rt_str_to_real. This gate's arms read identically on both converters.
#
# ⛔ NOT A ROUNDING GATE, AND THE DISTINCTION IS LOAD-BEARING: the boundary VALUES here are the ones CPython's
# correctly-rounded strtod agrees with, and at the denormal edge our boundary and the ORACLE's differ because
# SPITBOL's own converter is imprecise there (FINDING-2026-09-14-ceo-the-math-limits-family...). This gate
# asserts only what is not in dispute: a decimal beyond the double range does not become a value.
#
# rc=0 clean · rc=1 an infinity leaked into the value space · rc=2 REFUSAL (cannot measure).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
[ -x "$B/scrip" ] || { echo "⛔ REFUSES rc=2: $B/scrip is not built -- cannot measure"; exit 2; }
D="$(mktemp -d)" || { echo "⛔ REFUSES rc=2: no scratch dir"; exit 2; }
trap 'rm -rf "$D"' EXIT

cat > "$D/w.sno" <<'SNO'
        &ERRLIMIT = 1000
        A = EVAL('1.797693135E+308')            :F(A1)
        OUTPUT = 'eval-big=[' A ']'             :(B)
A1      OUTPUT = 'eval-big=failed'
B       C = CONVERT('1.797693135E+308','REAL')  :F(B1)
        OUTPUT = 'convert-big=[' C ']'          :(D)
B1      OUTPUT = 'convert-big=failed'
D       E = EVAL('-1.797693135E+308')           :F(D1)
        OUTPUT = 'eval-negbig=[' E ']'          :(F)
D1      OUTPUT = 'eval-negbig=failed'
F       G = EVAL('1.5e308')                     :F(F1)
        OUTPUT = 'eval-ok=' DATATYPE(G)         :(H)
F1      OUTPUT = 'eval-ok=WRONGLY-FAILED'
H       I = CONVERT('2.5','REAL')               :F(H1)
        OUTPUT = 'convert-ok=' I                :(Z)
H1      OUTPUT = 'convert-ok=WRONGLY-FAILED'
Z
END
SNO
cat > "$D/w.ref" <<'REF'
eval-big=failed
convert-big=failed
eval-negbig=failed
eval-ok=REAL
convert-ok=2.5
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
        printf '  ok    %s: an out-of-range decimal fails through EVAL and CONVERT, and an in-range one still converts\n' "$mode"
    else
        printf '  FAIL  %s:\n' "$mode"; diff "$D/w.ref" "$D/out.$mode" | sed 's/^/          /'; fails=$((fails+1))
    fi
done

[ "$fails" -eq 0 ] || { echo "⛔ GATE FAILED: $fails of 2 mode(s) red."
                        echo "   ⭐ THE TWO POSITIVE ARMS ARE THE CONTROL: a converter that fails everything passes every"
                        echo "      negative arm, and only 'eval-ok=REAL' and 'convert-ok=2.5' tell a cure from a ban."
                        exit 1; }
echo "✅ GATE OK: an out-of-range decimal fails to convert instead of becoming an infinity, both modes, three doors"
exit 0
